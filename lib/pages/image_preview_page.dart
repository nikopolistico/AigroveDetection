import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Fullscreen image preview page with Hero animation and pinch/zoom support.
class ImagePreviewPage extends StatefulWidget {
  final File image;
  final String tag;
  final Size?
  imageSize; // original image logical size (pixels used for bbox coords)
  final Rect? bbox; // bounding box in image coordinates
  final String? label; // detected label to display
  final double? confidence; // detection confidence (0..1)

  const ImagePreviewPage({
    super.key,
    required this.image,
    required this.tag,
    this.imageSize,
    this.bbox,
    this.label,
    this.confidence,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  bool _didSetInitial = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _maybeSetInitialTransform(BoxConstraints constraints) {
    if (_didSetInitial) return;
    final bbox = widget.bbox;
    final imgSize = widget.imageSize;
    if (bbox == null || imgSize == null) return;

    final viewportW = constraints.maxWidth;
    final viewportH = constraints.maxHeight;

    final displayScale = viewportW / imgSize.width < viewportH / imgSize.height
        ? viewportW / imgSize.width
        : viewportH / imgSize.height;

    // bbox in displayed pixels
    final bboxDisp = Rect.fromLTWH(
      bbox.left * displayScale,
      bbox.top * displayScale,
      bbox.width * displayScale,
      bbox.height * displayScale,
    );

    // target scale so bbox fills ~85% of viewport
    final sX = (viewportW * 0.85) / bboxDisp.width;
    final sY = (viewportH * 0.85) / bboxDisp.height;
    double S = sX < sY ? sX : sY;
    if (S.isInfinite || S.isNaN) S = 1.0;
    S = S.clamp(1.0, 5.0);

    final bboxCenter = Offset(
      bboxDisp.left + bboxDisp.width / 2,
      bboxDisp.top + bboxDisp.height / 2,
    );
    final viewportCenter = Offset(viewportW / 2, viewportH / 2);

    final t = viewportCenter - (bboxCenter * S);

    final matrix = Matrix4.zero();
    matrix.setEntry(0, 0, S);
    matrix.setEntry(1, 1, S);
    matrix.setEntry(2, 2, 1);
    matrix.setEntry(3, 3, 1);
    matrix.setEntry(0, 3, t.dx);
    matrix.setEntry(1, 3, t.dy);

    _controller.value = matrix;
    _didSetInitial = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Try to compute initial transform once we have constraints
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _maybeSetInitialTransform(constraints),
            );

            final child = widget.imageSize != null
                ? (() {
                    final imgSize = widget.imageSize!;
                    final displayScaleLocal = math.min(
                      constraints.maxWidth / imgSize.width,
                      constraints.maxHeight / imgSize.height,
                    );
                    final displayW = imgSize.width * displayScaleLocal;
                    final displayH = imgSize.height * displayScaleLocal;

                    // compute displayed bbox in pixels (if provided)
                    Rect? bboxDisp;
                    if (widget.bbox != null) {
                      final b = widget.bbox!;
                      bboxDisp = Rect.fromLTWH(
                        b.left * displayScaleLocal,
                        b.top * displayScaleLocal,
                        b.width * displayScaleLocal,
                        b.height * displayScaleLocal,
                      );
                    }

                    return SizedBox(
                      width: displayW,
                      height: displayH,
                      child: Stack(
                        children: [
                          Image.file(widget.image, fit: BoxFit.fill),
                          if (bboxDisp != null)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                return CustomPaint(
                                  size: Size(displayW, displayH),
                                  painter: _BBoxPainter(
                                    bboxDisp!,
                                    _pulseController.value,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  })()
                : Image.file(widget.image, fit: BoxFit.contain);

            return Stack(
              children: [
                Center(
                  child: Hero(
                    tag: widget.tag,
                    child: InteractiveViewer(
                      transformationController: _controller,
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withAlpha(80),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                // Label + confidence overlay (bottom)
                if (widget.label != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.label!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.confidence != null)
                            Text(
                              '${(widget.confidence! * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BBoxPainter extends CustomPainter {
  final Rect bbox;
  final double progress; // 0..1 pulse value

  _BBoxPainter(this.bbox, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // pulse alpha and stroke width based on progress
    final alpha = (160 + (95 * progress)).round().clamp(0, 255);
    final stroke = 2.5 + (2.0 * progress);

    final paint = Paint()
      ..color = Colors.greenAccent.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Draw rounded rect for better visibility
    final rrect = RRect.fromRectAndRadius(bbox, const Radius.circular(6));
    canvas.drawRRect(rrect, paint);

    // Draw a small filled circle at bbox center
    final center = bbox.center;
    final fill = Paint()..color = Colors.greenAccent.withAlpha(alpha);
    canvas.drawCircle(center, 6 + (2 * progress), fill);
  }

  @override
  bool shouldRepaint(covariant _BBoxPainter oldDelegate) {
    return oldDelegate.bbox != bbox || oldDelegate.progress != progress;
  }
}

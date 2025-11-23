import 'package:flutter/material.dart';
import '../models/detection_result.dart';

/// Widget para display ang detection results with bounding boxes
///
/// Kini ang nagpakita sa boxes sa nakitang objects
class DetectionOverlay extends StatelessWidget {
  final List<DetectionResult> detections;
  final Size imageSize;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionPainter(detections, imageSize),
      child: Container(),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size imageSize;

  _DetectionPainter(this.detections, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (var detection in detections) {
      // Scale box from image coordinates to canvas coordinates
      Rect box = Rect.fromLTRB(
        detection.boundingBox.left * scaleX,
        detection.boundingBox.top * scaleY,
        detection.boundingBox.right * scaleX,
        detection.boundingBox.bottom * scaleY,
      );

      // Clamp to canvas bounds
      final canvasBounds = Rect.fromLTWH(0, 0, size.width, size.height);
      box = box.intersect(canvasBounds);

      // If box is too small, inflate to make it visible (debug fallback)
      if (box.width < 8 || box.height < 8) {
        final cx =
            (detection.boundingBox.left + detection.boundingBox.right) /
            2 *
            scaleX;
        final cy =
            (detection.boundingBox.top + detection.boundingBox.bottom) /
            2 *
            scaleY;
        box = Rect.fromCenter(
          center: Offset(cx, cy),
          width: 80,
          height: 80,
        ).intersect(canvasBounds);
      }

      // Visible stroke paint
      final paint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // Background fill with low opacity to highlight
      final fill = Paint()
        ..color = Colors.redAccent.withAlpha((0.08 * 255).round());
      canvas.drawRect(box, fill);
      canvas.drawRect(box, paint);

      // Draw simple label
      final label =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%';
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: box.width - 8);

      final labelBg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          box.left,
          (box.top - textPainter.height - 8).clamp(0.0, size.height - 4),
          textPainter.width + 8,
          textPainter.height + 6,
        ),
        const Radius.circular(6),
      );

      // Draw label background and text
      final labelPaint = Paint()
        ..color = Colors.black.withAlpha((0.6 * 255).round());
      canvas.drawRRect(labelBg, labelPaint);
      textPainter.paint(canvas, Offset(labelBg.left + 4, labelBg.top + 3));

      // Debug print coordinates
      // ignore: avoid_print
      debugPrint('Detection box: ${detection.boundingBox} -> scaled: $box');
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

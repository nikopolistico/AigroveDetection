import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Simple service to call Imagga tagging API and return tag names with confidence
class PredictionService {
  final String imaggaApiKey;
  final String imaggaApiSecret;

  PredictionService({
    required this.imaggaApiKey,
    required this.imaggaApiSecret,
  });

  /// Call Imagga tags endpoint with multipart image upload
  /// Returns a list of maps:{"tag": String, "confidence": double}
  Future<List<Map<String, dynamic>>> getTags(File imageFile) async {
    final uri = Uri.parse('https://api.imagga.com/v2/tags');

    final request = http.MultipartRequest('POST', uri);
    final bytes = await imageFile.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: 'image.jpg'),
    );

    final credentials = base64Encode(
      utf8.encode('$imaggaApiKey:$imaggaApiSecret'),
    );
    request.headers['Authorization'] = 'Basic $credentials';

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Imagga API error: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final Map<String, dynamic> jsonResp = json.decode(response.body);

    final List<Map<String, dynamic>> results = [];

    try {
      final tags = jsonResp['result']?['tags'] as List<dynamic>?;
      if (tags != null) {
        for (final t in tags) {
          final tagObj = t['tag'];
          final tagName = tagObj is Map
              ? (tagObj['en'] ?? tagObj.values.first)
              : t['tag'];
          final confidence = (t['confidence'] is num)
              ? (t['confidence'] as num).toDouble()
              : 0.0;
          results.add({
            'tag': tagName.toString().toLowerCase(),
            'confidence': confidence / 100.0,
          });
        }
      }
    } catch (_) {
      // ignore parsing errors, return empty list
    }

    return results;
  }
}

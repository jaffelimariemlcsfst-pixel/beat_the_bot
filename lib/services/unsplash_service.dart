import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';


class UnsplashService {
  static String get _accessKey => dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
  static const String _baseUrl = 'https://api.unsplash.com';

  // Cache to avoid re-fetching the same keyword
  final Map<String, String> _cache = {};

  Future<String?> fetchImageUrl(String keyword) async {
    if (_cache.containsKey(keyword)) return _cache[keyword];

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search/photos?query=${Uri.encodeComponent(keyword)}&per_page=1&orientation=squarish',
        ),
        headers: {
          'Authorization': 'Client-ID $_accessKey',
        },
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final results = data['results'] as List<dynamic>;
      if (results.isEmpty) return null;

      final url = results.first['urls']['small'] as String?;
      if (url != null) _cache[keyword] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<List<String?>> fetchImagesForOptions(List<String> keywords) async {
    // Fetch all 4 in parallel
    final futures = keywords.map((k) => fetchImageUrl(k));
    return Future.wait(futures);
  }
}
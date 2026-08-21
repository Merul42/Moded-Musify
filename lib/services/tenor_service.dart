import 'dart:convert';

import 'package:http/http.dart' as http;

class TenorGifSearchResult {
  const TenorGifSearchResult({
    required this.url,
    required this.previewUrl,
    required this.width,
    required this.height,
  });

  final String url;
  final String previewUrl;
  final int width;
  final int height;

  factory TenorGifSearchResult.fromJson(Map<String, dynamic> json) {
    final media = (json['media_formats'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final gif = (media['gif'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final preview = (media['tinygif'] as Map<String, dynamic>?) ??
        (media['nanogif'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return TenorGifSearchResult(
      url: (gif['url'] as String?) ?? (json['itemurl'] as String?) ?? '',
      previewUrl: (preview['url'] as String?) ?? (gif['url'] as String?) ?? '',
      width: ((gif['dims'] as List?)?[0] as num?)?.toInt() ?? 0,
      height: ((gif['dims'] as List?)?[1] as num?)?.toInt() ?? 0,
    );
  }
}

class TenorService {
  static const String _apiKey = String.fromEnvironment(
    'TENOR_API_KEY',
    defaultValue: '',
  );

  static bool get hasApiKey => _apiKey.trim().isNotEmpty;

  static Future<List<TenorGifSearchResult>> search(String query, {int limit = 12}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <TenorGifSearchResult>[];
    }
    if (!hasApiKey) {
      throw StateError(
        'TENOR_API_KEY is not configured. Build with --dart-define=TENOR_API_KEY=... ',
      );
    }

    final uri = Uri.https('tenor.googleapis.com', '/v2/search', <String, String>{
      'q': normalized,
      'key': _apiKey,
      'client_key': 'musify',
      'limit': '$limit',
      'media_filter': 'gif',
      'ar': 'wide',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Tenor search failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final results = decoded is Map ? decoded['results'] : null;
    if (results is! List) {
      return const <TenorGifSearchResult>[];
    }

    return results
        .whereType<Map>()
        .map((item) => TenorGifSearchResult.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.url.isNotEmpty)
        .toList(growable: false);
  }
}

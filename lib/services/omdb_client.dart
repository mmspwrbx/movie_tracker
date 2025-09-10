import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OmdbClient {
  OmdbClient(this._dio);
  final Dio _dio;

  String get _apiKey => dotenv.env['OMDB_API_KEY'] ?? '';
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Возвращает {'imdb': '7.8/10', 'rt': '92%'} при успехе, иначе {}.
  Future<Map<String, String>> ratings({required String imdbId}) async {
    if (!isConfigured) return {};
    final res = await _dio.get(
      'https://www.omdbapi.com/',
      queryParameters: {
        'i': imdbId,
        'apikey': _apiKey,
        'tomatoes': 'true',
      },
    );

    if (res.statusCode != 200 ||
        res.data == null ||
        res.data['Response'] != 'True') {
      return {};
    }

    final data = res.data as Map<String, dynamic>;

    final String? imdb = (data['imdbRating'] as String?)?.trim();
    String? rt;
    final ratings = (data['Ratings'] as List?) ?? const [];
    for (final r in ratings) {
      final src = (r['Source'] as String?)?.trim();
      if (src == 'Rotten Tomatoes') {
        rt = (r['Value'] as String?)?.trim();
        break;
      }
    }

    return {
      if (imdb != null && imdb != 'N/A') 'imdb': '$imdb/10',
      if (rt != null && rt != 'N/A') 'rt': rt!,
    };
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OmdbClient {
  OmdbClient(this._dio);
  final Dio _dio;
  String get _apiKey => dotenv.env['OMDB_API_KEY'] ?? '';

  Future<Map<String, String?>> ratings(
      {String? imdbId, String? title, int? year}) async {
    final qp = imdbId != null
        ? {'i': imdbId, 'apikey': _apiKey}
        : {'t': title, 'y': year?.toString(), 'apikey': _apiKey};
    final res = await _dio.get('https://www.omdbapi.com/', queryParameters: qp);
    final data = res.data as Map<String, dynamic>;
    final ratings =
        (data['Ratings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    String? imdb;
    String? rt;
    for (final r in ratings) {
      if (r['Source'] == 'Internet Movie Database')
        imdb = r['Value'] as String?;
      if (r['Source'] == 'Rotten Tomatoes') rt = r['Value'] as String?;
    }
    return {'imdb': imdb, 'rt': rt};
  }
}

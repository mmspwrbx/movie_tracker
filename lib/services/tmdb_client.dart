// lib/services/tmdb_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TmdbMovie {
  const TmdbMovie({
    required this.tmdbId,
    required this.title,
    this.year,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.genres = const [],
    this.runtime,
    this.tmdbRating,
    this.imdbId,
    this.imdbRating,
    this.rottenTomatoes,
    this.screenshots = const [],
  });

  final int tmdbId;
  final String title;
  final int? year;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final List<String> genres;
  final int? runtime;
  final double? tmdbRating;
  final String? imdbId;
  final String? imdbRating;
  final String? rottenTomatoes;
  final List<String> screenshots;

  TmdbMovie copyWith({
    int? tmdbId,
    String? title,
    int? year,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    List<String>? genres,
    int? runtime,
    double? tmdbRating,
    String? imdbId,
    String? imdbRating,
    String? rottenTomatoes,
    List<String>? screenshots,
  }) =>
      TmdbMovie(
        tmdbId: tmdbId ?? this.tmdbId,
        title: title ?? this.title,
        year: year ?? this.year,
        overview: overview ?? this.overview,
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        genres: genres ?? this.genres,
        runtime: runtime ?? this.runtime,
        tmdbRating: tmdbRating ?? this.tmdbRating,
        imdbId: imdbId ?? this.imdbId,
        imdbRating: imdbRating ?? this.imdbRating,
        rottenTomatoes: rottenTomatoes ?? this.rottenTomatoes,
        screenshots: screenshots ?? this.screenshots,
      );
}

class TmdbClient {
  TmdbClient(this._dio);
  final Dio _dio;

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';
  String get _imgBase =>
      dotenv.env['TMDB_IMAGE_BASE'] ?? 'https://image.tmdb.org/t/p/';

  // -------- жанры (ленивый кэш) --------
  Map<int, String>? _genreMap;
  Future<void> _ensureGenres() async {
    if (_genreMap != null) return;
    final res = await _dio.get(
      'https://api.themoviedb.org/3/genre/movie/list',
      queryParameters: {
        'api_key': _apiKey,
        'language': 'ru-RU',
      },
    );
    final List raw = res.data['genres'] ?? [];
    _genreMap = {
      for (final g in raw)
        (g['id'] as num).toInt(): (g['name'] as String?) ?? ''
    };
  }

  // -------- поиск --------
  Future<List<TmdbMovie>> searchMovies(String query) async {
    await _ensureGenres();
    final res = await _dio.get(
      'https://api.themoviedb.org/3/search/movie',
      queryParameters: {
        'api_key': _apiKey,
        'query': query,
        'include_adult': false,
        'language': 'ru-RU',
      },
    );
    final List results = res.data['results'] ?? [];
    return results.map((m) => _mapSearch(m as Map<String, dynamic>)).toList();
  }

  // -------- детали --------
  Future<TmdbMovie> details(int tmdbId) async {
    final res = await _dio.get(
      'https://api.themoviedb.org/3/movie/$tmdbId',
      queryParameters: {
        'api_key': _apiKey,
        'language': 'ru-RU',
        'include_image_language': 'ru,en',
      },
    );
    final d = res.data as Map<String, dynamic>;
    final poster = d['poster_path'];
    final backdrop = d['backdrop_path'];
    final genres = (d['genres'] as List?)
            ?.map((g) => (g['name'] as String?) ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final screenshots = ((d['images']?['backdrops'] as List?) ?? [])
        .take(10)
        .map((b) => b['file_path'] as String)
        .map((p) => '${_imgBase}w780$p')
        .toList();

    return TmdbMovie(
      tmdbId: d['id'],
      title: d['title'] ?? d['name'] ?? '',
      year: (d['release_date'] as String?)?.split('-').firstOrNull != null
          ? int.tryParse((d['release_date'] as String).split('-').first)
          : null,
      overview: d['overview'],
      posterUrl: poster != null ? '${_imgBase}w500$poster' : null,
      backdropUrl: backdrop != null ? '${_imgBase}w780$backdrop' : null,
      genres: genres,
      runtime: d['runtime'],
      tmdbRating: (d['vote_average'] is num)
          ? (d['vote_average'] as num).toDouble()
          : null,
      imdbId: (d['external_ids']?['imdb_id']) as String?,
      screenshots: screenshots,
    );
  }

  /// imdb_id для фильма (для OMDb)
  Future<String?> imdbIdFor(int tmdbId) async {
    final res = await _dio.get(
      'https://api.themoviedb.org/3/movie/$tmdbId/external_ids',
      queryParameters: {
        'api_key': _apiKey,
      },
    );
    return (res.data['imdb_id'] as String?)?.trim().isEmpty == true
        ? null
        : res.data['imdb_id'] as String?;
  }

  /// Рекомендации на основе фильма (TMDb)
  Future<List<TmdbMovie>> recommendations(int tmdbId, {int page = 1}) async {
    await _ensureGenres();
    final res = await _dio.get(
      'https://api.themoviedb.org/3/movie/$tmdbId/recommendations',
      queryParameters: {
        'api_key': _apiKey,
        'language': 'ru-RU',
        'include_adult': false,
        'page': page,
      },
    );
    final results =
        (res.data['results'] as List? ?? []).cast<Map<String, dynamic>>();
    return results.map(_mapSearch).toList();
  }

  // маппинг краткой карточки (search/recommendations)
  TmdbMovie _mapSearch(Map<String, dynamic> m) {
    final poster = m['poster_path'];
    final backdrop = m['backdrop_path'];
    final yearStr = (m['release_date'] as String?)?.split('-').first;
    final vote = m['vote_average'];

    // genre_ids -> имена
    final ids =
        (m['genre_ids'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const <int>[];
    final names = ids.map((id) => _genreMap?[id]).whereType<String>().toList();

    return TmdbMovie(
      tmdbId: m['id'],
      title: m['title'] ?? m['name'] ?? '',
      year: yearStr != null ? int.tryParse(yearStr) : null,
      overview: m['overview'],
      posterUrl: poster != null ? '${_imgBase}w342$poster' : null,
      backdropUrl: backdrop != null ? '${_imgBase}w780$backdrop' : null,
      tmdbRating: (vote is num) ? vote.toDouble() : null,
      genres: names,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

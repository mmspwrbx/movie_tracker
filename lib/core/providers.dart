import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmdb_client.dart';
import '../services/omdb_client.dart';

final tmdbClientProvider = Provider<TmdbClient>((ref) => TmdbClient(Dio()));
final omdbClientProvider = Provider<OmdbClient>((ref) => OmdbClient(Dio()));

/// Детали фильма + подмешиваем внешние рейтинги (IMDb/RT), если есть ключ OMDb.
final movieDetailsProvider =
    FutureProvider.family<TmdbMovie, int>((ref, movieId) async {
  final tmdb = ref.watch(tmdbClientProvider);
  final omdb = ref.watch(omdbClientProvider);

  final base = await tmdb.details(movieId);

  // Если TMDb вернул imdbId и OMDb-ключ настроен — подтянем рейтинги
  if (base.imdbId != null && omdb.isConfigured) {
    try {
      final r = await omdb.ratings(imdbId: base.imdbId!);
      return base.copyWith(
        imdbRating: r['imdb'],
        rottenTomatoes: r['rt'],
      );
    } catch (_) {
      // Если OMDb недоступен — просто вернём базовые данные
    }
  }

  return base;
});

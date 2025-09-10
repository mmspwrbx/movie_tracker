import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';
import '../db/daos/movies_dao.dart';
import '../db/daos/lists_dao.dart';
import '../db/daos/reviews_dao.dart';

final dbProvider = Provider<AppDb>((ref) => AppDb());

final moviesDaoProvider =
    Provider<MoviesDao>((ref) => MoviesDao(ref.watch(dbProvider)));

final listsDaoProvider =
    Provider<ListsDao>((ref) => ListsDao(ref.watch(dbProvider)));

final reviewsDaoProvider =
    Provider<ReviewsDao>((ref) => ReviewsDao(ref.watch(dbProvider)));

/// Рецензия пользователя на конкретный фильм (по ЛОКАЛЬНОМУ ID из таблицы Movies)
final reviewForMovieProvider =
    FutureProvider.family<Review?, int>((ref, movieDbId) {
  return ref.watch(reviewsDaoProvider).getReviewForMovie(movieDbId);
});

/// Средняя оценка по фильму (x10: 0..100), null если оценок нет
final averageRatingX10Provider =
    FutureProvider.family<int?, int>((ref, movieDbId) {
  return ref.watch(reviewsDaoProvider).getAverageRatingX10(movieDbId);
});

/// Входит ли фильм в список «Просмотрено» (listId = 1)
final isInWatchedProvider = FutureProvider.family<bool, int>((ref, movieDbId) {
  return ref.watch(listsDaoProvider).isMovieInList(1, movieDbId);
});

/// Входит ли фильм в список «Хочу посмотреть» (listId = 2)
final isInPlannedProvider = FutureProvider.family<bool, int>((ref, movieDbId) {
  return ref.watch(listsDaoProvider).isMovieInList(2, movieDbId);
});

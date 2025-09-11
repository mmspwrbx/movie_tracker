import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_db.dart';
import '../db/daos/movies_dao.dart';
import '../db/daos/lists_dao.dart';
import '../db/daos/reviews_dao.dart';
import '../db/daos/profile_dao.dart';
import '../db/tables.dart';

final dbProvider = Provider<AppDb>((ref) => AppDb());

// DAOs
final moviesDaoProvider =
    Provider<MoviesDao>((ref) => MoviesDao(ref.watch(dbProvider)));
final listsDaoProvider =
    Provider<ListsDao>((ref) => ListsDao(ref.watch(dbProvider)));
final reviewsDaoProvider =
    Provider<ReviewsDao>((ref) => ReviewsDao(ref.watch(dbProvider)));
final profileDaoProvider =
    Provider<ProfileDao>((ref) => ProfileDao(ref.watch(dbProvider)));

// Рецензии
final reviewForMovieProvider = FutureProvider.family<Review?, int>(
    (ref, id) => ref.watch(reviewsDaoProvider).getReviewForMovie(id));
final averageRatingX10Provider = FutureProvider.family<int?, int>(
    (ref, id) => ref.watch(reviewsDaoProvider).getAverageRatingX10(id));

// Присутствие в списках
final isInWatchedProvider = FutureProvider.family<bool, int>((ref, movieDbId) =>
    ref.watch(listsDaoProvider).isMovieInList(1, movieDbId));
final isInPlannedProvider = FutureProvider.family<bool, int>((ref, movieDbId) =>
    ref.watch(listsDaoProvider).isMovieInList(2, movieDbId));

// Профиль (стрим только здесь!)
final profileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final dao = ref.watch(profileDaoProvider);
  return dao.watchProfile();
});

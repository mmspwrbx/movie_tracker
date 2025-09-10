import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'reviews_dao.g.dart';

@DriftAccessor(tables: [Reviews])
class ReviewsDao extends DatabaseAccessor<AppDb> with _$ReviewsDaoMixin {
  ReviewsDao(AppDb db) : super(db);

  /// Сохраняем/обновляем единственную рецензию на фильм (X10: 0..100, шаг 5 = 0.5)
  Future<void> upsertReviewForMovie({
    required int movieId, // локальный Movies.id
    required int? ratingX10, // может быть null
    String? reviewText,
    bool spoiler = false,
  }) async {
    final existing = await (select(reviews)
          ..where((r) => r.movieId.equals(movieId)))
        .getSingleOrNull();

    if (existing == null) {
      await into(reviews).insert(ReviewsCompanion.insert(
        movieId: movieId,
        rating: Value(ratingX10),
        reviewText: Value(reviewText),
        spoiler: Value(spoiler),
      ));
    } else {
      await (update(reviews)..where((r) => r.movieId.equals(movieId))).write(
        ReviewsCompanion(
          rating: Value(ratingX10),
          reviewText: Value(reviewText),
          spoiler: Value(spoiler),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<Review?> getReviewForMovie(int movieId) =>
      (select(reviews)..where((r) => r.movieId.equals(movieId)))
          .getSingleOrNull();

  Future<List<Review>> getReviewsForMovie(int movieId) =>
      (select(reviews)..where((r) => r.movieId.equals(movieId))).get();

  /// Средняя оценка в X10 (0..100), округлённая до int
  Future<int?> getAverageRatingX10(int movieId) async {
    final avgExp = reviews.rating.avg();
    final row = await (selectOnly(reviews)
          ..addColumns([avgExp])
          ..where(reviews.movieId.equals(movieId)))
        .getSingleOrNull();
    final avg = row?.read(avgExp); // double?
    if (avg == null) return null;
    return avg.round();
  }
}

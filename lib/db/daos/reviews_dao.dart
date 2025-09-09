import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'reviews_dao.g.dart';

@DriftAccessor(tables: [Reviews])
class ReviewsDao extends DatabaseAccessor<AppDb> with _$ReviewsDaoMixin {
  ReviewsDao(AppDb db) : super(db);

  Future<int> addReview(ReviewsCompanion review) =>
      into(reviews).insert(review);

  Future<List<Review>> getReviewsForMovie(int movieId) =>
      (select(reviews)..where((r) => r.movieId.equals(movieId))).get();
}

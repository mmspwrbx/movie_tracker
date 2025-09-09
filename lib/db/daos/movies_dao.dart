import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'movies_dao.g.dart';

@DriftAccessor(tables: [Movies])
class MoviesDao extends DatabaseAccessor<AppDb> with _$MoviesDaoMixin {
  MoviesDao(AppDb db) : super(db);

  Future<int> insertMovie(MoviesCompanion movie) =>
      into(movies).insertOnConflictUpdate(movie);

  Future<Movie?> getMovieByTmdb(int tmdbId) =>
      (select(movies)..where((m) => m.tmdbId.equals(tmdbId))).getSingleOrNull();

  Future<List<Movie>> getAllMovies() => select(movies).get();
}

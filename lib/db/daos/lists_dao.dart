import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'lists_dao.g.dart';

@DriftAccessor(tables: [MovieLists, MovieListItems, Movies])
class ListsDao extends DatabaseAccessor<AppDb> with _$ListsDaoMixin {
  ListsDao(AppDb db) : super(db);

  Future<int> createList(MovieListsCompanion list) =>
      into(movieLists).insert(list);

  Future<List<MovieList>> getAllLists() => select(movieLists).get();

  Future<void> addMovieToList(int listId, int movieId) async {
    await into(movieListItems).insertOnConflictUpdate(MovieListItemsCompanion(
      listId: Value(listId),
      movieId: Value(movieId),
    ));
  }

  Future<List<Movie>> getMoviesInList(int listId) async {
    final q = select(movies).join([
      innerJoin(
        movieListItems,
        movieListItems.movieId.equalsExp(movies.id),
      )
    ])
      ..where(movieListItems.listId.equals(listId));

    final rows = await q.get();
    return rows.map((r) => r.readTable(movies)).toList();
  }

  Future<int> removeMovieFromList(int listId, int movieId) {
    return (delete(movieListItems)
          ..where(
              (tbl) => tbl.listId.equals(listId) & tbl.movieId.equals(movieId)))
        .go();
  }

  Future<int> countMoviesInList(int listId) async {
    final q = movieListItems.select()
      ..where((tbl) => tbl.listId.equals(listId));
    final rows = await q.get();
    return rows.length;
  }
}

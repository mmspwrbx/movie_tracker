import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'lists_dao.g.dart';

@DriftAccessor(tables: [MovieLists, MovieListItems, Movies])
class ListsDao extends DatabaseAccessor<AppDb> with _$ListsDaoMixin {
  ListsDao(super.db);

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

  Future<bool> isMovieInList(int listId, int movieId) async {
    final row = await (select(movieListItems)
          ..where((t) => t.listId.equals(listId) & t.movieId.equals(movieId)))
        .getSingleOrNull();
    return row != null;
  }

  // Топ жанров в конкретном списке (по умолчанию "просмотрено" = listId: 1)
  Future<List<MapEntry<String, int>>> topGenresInList(int listId,
      {int limit = 3}) async {
    final query = select(movies).join([
      innerJoin(movieListItems, movieListItems.movieId.equalsExp(movies.id)),
    ])
      ..where(movieListItems.listId.equals(listId));

    final rows = await query.get();
    final counter = <String, int>{};

    for (final r in rows) {
      final m = r.readTable(movies);
      final genres = m.genres ?? const <String>[];
      for (final g in genres) {
        if (g.trim().isEmpty) continue;
        counter[g] = (counter[g] ?? 0) + 1;
      }
    }

    final list = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // по убыванию
    return list.take(limit).toList();
  }

// Суммарная длительность фильмов (в минутах) в списке
  Future<int> totalRuntimeInList(int listId) async {
    final query = select(movies).join([
      innerJoin(movieListItems, movieListItems.movieId.equalsExp(movies.id)),
    ])
      ..where(movieListItems.listId.equals(listId));

    final rows = await query.get();
    var sum = 0;
    for (final r in rows) {
      final m = r.readTable(movies);
      sum += (m.runtime ?? 0);
    }
    return sum;
  }
}

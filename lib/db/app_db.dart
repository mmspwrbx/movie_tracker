import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';
import 'daos/movies_dao.dart';
import 'daos/lists_dao.dart';
import 'daos/reviews_dao.dart';

part 'app_db.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = File('${Directory.current.path}/movie_tracker.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [Movies, MovieLists, MovieListItems, Reviews],
  daos: [MoviesDao, ListsDao, ReviewsDao],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // системные списки
          await into(movieLists).insertOnConflictUpdate(
            MovieListsCompanion(
              id: const Value(1),
              name: const Value('Просмотрено'),
              type: const Value('watched'),
            ),
          );
          await into(movieLists).insertOnConflictUpdate(
            MovieListsCompanion(
              id: const Value(2),
              name: const Value('Хочу посмотреть'),
              type: const Value('planned'),
            ),
          );
        },
      );
}

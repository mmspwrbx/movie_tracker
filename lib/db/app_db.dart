import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';
import 'daos/movies_dao.dart';
import 'daos/lists_dao.dart';
import 'daos/reviews_dao.dart';
import 'daos/profile_dao.dart';

part 'app_db.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Стабильная директория для данных приложения (Linux/Windows/macOS/Android/iOS)
    final supportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(supportDir.path, 'db'));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final file = File(p.join(dbDir.path, 'movie_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    Movies,
    MovieLists,
    MovieListItems,
    Reviews,
    UserProfiles, // профиль
  ],
  daos: [
    MoviesDao,
    ListsDao,
    ReviewsDao,
    ProfileDao, // DAO профиля
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  // Поднимаем версию схемы — добавилась таблица профиля
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // со старой схемы (v1) создаём таблицу профиля
          if (from < 2) {
            await m.createTable(userProfiles);
          }
        },
        beforeOpen: (details) async {
          // системные списки (идемпотентно)
          await into(movieLists).insertOnConflictUpdate(
            const MovieListsCompanion(
              id: Value(1),
              name: Value('Просмотрено'),
              type: Value('watched'),
            ),
          );
          await into(movieLists).insertOnConflictUpdate(
            const MovieListsCompanion(
              id: Value(2),
              name: Value('Хочу посмотреть'),
              type: Value('planned'),
            ),
          );
        },
      );
}

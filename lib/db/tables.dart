import 'package:drift/drift.dart';

@DataClassName('Movie')
class Movies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tmdbId => integer()();
  TextColumn get title => text()();
  IntColumn get year => integer().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  // важно: map до .nullable(), чтобы был корректный null-aware конвертер
  TextColumn get genres => text().map(const StringListConverter()).nullable()();
  IntColumn get runtime => integer().nullable()();
}

@DataClassName('MovieList')
class MovieLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()
      .withDefault(const Constant('custom'))(); // watched | planned | custom
}

@DataClassName('MovieListItem')
class MovieListItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().references(MovieLists, #id)();
  IntColumn get movieId => integer().references(Movies, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Review')
class Reviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get movieId => integer().references(Movies, #id)();
  IntColumn get rating => integer().nullable()(); // 0–10
  TextColumn get reviewText => text().nullable()();
  BoolColumn get spoiler => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Конвертер для списка жанров
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) =>
      fromDb.isEmpty ? <String>[] : fromDb.split(',');
  @override
  String toSql(List<String> value) => value.join(',');
}

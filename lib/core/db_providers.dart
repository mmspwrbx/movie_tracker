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

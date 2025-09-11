import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class ProfileDao extends DatabaseAccessor<AppDb> with _$ProfileDaoMixin {
  ProfileDao(AppDb db) : super(db);

  Future<UserProfile?> getProfile() => select(userProfiles).getSingleOrNull();
  Stream<UserProfile?> watchProfile() =>
      select(userProfiles).watchSingleOrNull();

  Future<int> createProfile(UserProfilesCompanion data) =>
      into(userProfiles).insert(data);

  Future<void> upsertProfile(UserProfilesCompanion data) async {
    final existing = await getProfile();
    if (existing == null) {
      await createProfile(data);
    } else {
      await (update(userProfiles)..where((t) => t.id.equals(existing.id)))
          .write(UserProfilesCompanion(
        displayName: data.displayName,
        email: data.email,
        avatarPath: data.avatarPath,
      ));
    }
  }

  Future<void> setAvatar(String? path) async {
    final existing = await getProfile();
    if (existing == null) {
      await createProfile(UserProfilesCompanion(avatarPath: Value(path)));
    } else {
      await (update(userProfiles)..where((t) => t.id.equals(existing.id)))
          .write(UserProfilesCompanion(avatarPath: Value(path)));
    }
  }
}

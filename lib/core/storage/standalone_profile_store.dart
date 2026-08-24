import 'package:drift/drift.dart';

import '../../models/profile_models.dart';
import '../errors/app_exception.dart';
import 'app_database.dart';
import 'profile_codec.dart';
import 'secure_storage.dart';

class StandaloneProfileStore {
  const StandaloneProfileStore({
    required this._database,
    required this._secureStorage,
    this.codec = const ProfileCodec(),
  });

  final AppDatabase _database;
  final SecureStorage _secureStorage;
  final ProfileCodec codec;

  Future<void> save(ConnectionProfile profile) async {
    if (!profile.isStandalone) {
      throw const AppException('只有独立配置可以保存到通用配置库。');
    }
    final secureRef = SecureKeys.standaloneProfile(profile.id);
    final previous = await _secureStorage.read(secureRef);
    await _secureStorage.write(secureRef, codec.encode(profile));
    try {
      await _database
          .into(_database.standaloneProfiles)
          .insertOnConflictUpdate(
            StandaloneProfilesCompanion.insert(
              id: profile.id,
              name: profile.displayName,
              origin: profile.origin.name,
              secureRef: secureRef,
              createdAt: profile.createdAt,
              updatedAt: profile.lastUpdatedAt,
            ),
          );
    } catch (_) {
      if (previous == null) {
        await _secureStorage.delete(secureRef);
      } else {
        await _secureStorage.write(secureRef, previous);
      }
      rethrow;
    }
  }

  Future<List<ConnectionProfile>> list() async {
    final rows = await (_database.select(
      _database.standaloneProfiles,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
    final profiles = <ConnectionProfile>[];
    for (final row in rows) {
      final encoded = await _secureStorage.read(row.secureRef);
      if (encoded != null) profiles.add(codec.decode(encoded));
    }
    return profiles;
  }

  Future<void> delete(String id) async {
    final row = await (_database.select(
      _database.standaloneProfiles,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    await (_database.delete(
      _database.standaloneProfiles,
    )..where((item) => item.id.equals(id))).go();
    if (row != null) await _secureStorage.delete(row.secureRef);
  }
}

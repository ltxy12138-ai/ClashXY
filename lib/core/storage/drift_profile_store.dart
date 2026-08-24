import 'package:drift/drift.dart';

import '../../models/device_models.dart';
import '../../models/profile_models.dart';
import '../provisioning/local_profile_store.dart';
import 'app_database.dart';
import 'profile_codec.dart';
import 'secure_storage.dart';

class DriftProfileStore implements LocalProfileStore {
  const DriftProfileStore({
    required this._database,
    required this._secureStorage,
    this.codec = const ProfileCodec(),
  });

  final AppDatabase _database;
  final SecureStorage _secureStorage;
  final ProfileCodec codec;

  @override
  Future<void> saveProfile(
    ConnectionProfile profile,
    LocalDevice device,
  ) async {
    final secureRef = 'profile.${profile.id}';
    await _secureStorage.write(secureRef, codec.encode(profile));
    try {
      await _database.transaction(() async {
        await _database
            .into(_database.profiles)
            .insertOnConflictUpdate(
              ProfilesCompanion.insert(
                id: profile.id,
                panelId: profile.panelId,
                remoteClientId: profile.remoteClientId,
                displayName: profile.displayName,
                protocolSummary: profile.proxies
                    .map((proxy) => proxy.protocol.name)
                    .join(','),
                secureRef: secureRef,
                createdAt: profile.createdAt,
              ),
            );
        await _database
            .into(_database.devices)
            .insertOnConflictUpdate(
              DevicesCompanion.insert(
                id: device.id,
                profileId: device.profileId,
                name: device.name,
                createdAt: device.createdAt,
                lastConnectedAt: Value(device.lastConnectedAt),
              ),
            );
      });
    } catch (_) {
      await _secureStorage.delete(secureRef);
      rethrow;
    }
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final row = await (_database.select(
      _database.profiles,
    )..where((profile) => profile.id.equals(profileId))).getSingleOrNull();
    await _database.transaction(() async {
      await (_database.delete(
        _database.devices,
      )..where((device) => device.profileId.equals(profileId))).go();
      await (_database.delete(
        _database.profiles,
      )..where((profile) => profile.id.equals(profileId))).go();
    });
    if (row != null) await _secureStorage.delete(row.secureRef);
  }

  @override
  Future<List<ConnectionProfile>> listProfiles() async {
    final rows = await _database.select(_database.profiles).get();
    final result = <ConnectionProfile>[];
    for (final row in rows) {
      final value = await _secureStorage.read(row.secureRef);
      if (value != null) result.add(codec.decode(value));
    }
    return result;
  }

  @override
  Future<List<LocalDevice>> listDevices() async {
    final rows = await _database.select(_database.devices).get();
    return rows
        .map(
          (row) => LocalDevice(
            id: row.id,
            profileId: row.profileId,
            name: row.name,
            createdAt: row.createdAt,
            lastConnectedAt: row.lastConnectedAt,
          ),
        )
        .toList(growable: false);
  }
}

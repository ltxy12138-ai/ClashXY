import '../../models/device_models.dart';
import '../../models/profile_models.dart';

abstract interface class LocalProfileStore {
  Future<void> saveProfile(ConnectionProfile profile, LocalDevice device);

  Future<void> deleteProfile(String profileId);

  Future<List<ConnectionProfile>> listProfiles();

  Future<List<LocalDevice>> listDevices();
}

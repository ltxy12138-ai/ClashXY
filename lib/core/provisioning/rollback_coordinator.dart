import '../security/app_logger.dart';
import 'local_profile_store.dart';
import 'remote_client_provisioner.dart';

class RollbackCoordinator {
  const RollbackCoordinator({
    required this._remote,
    required this._local,
    required this._logger,
  });

  final RemoteClientProvisioner _remote;
  final LocalProfileStore _local;
  final AppLogger _logger;

  Future<bool> rollback({
    required int remoteClientId,
    String? profileId,
  }) async {
    var succeeded = true;
    if (profileId != null) {
      try {
        await _local.deleteProfile(profileId);
      } catch (error, stackTrace) {
        succeeded = false;
        _logger.log(
          LogLevel.warning,
          'Local rollback failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    try {
      await _remote.delete(remoteClientId);
    } catch (error, stackTrace) {
      succeeded = false;
      _logger.log(
        LogLevel.error,
        'Remote rollback failed for client $remoteClientId.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return succeeded;
  }
}

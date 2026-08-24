import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../models/device_models.dart';
import '../../models/panel_models.dart';
import '../../models/profile_models.dart';
import '../panel/panel_connector.dart';
import 'credential_generator.dart';
import 'device_identity_service.dart';
import 'inbound_selector.dart';
import 'local_profile_store.dart';
import 'profile_factory.dart';
import 'profile_validator.dart';
import 'provisioning_state.dart';
import 'remote_client_provisioner.dart';
import 'rollback_coordinator.dart';

class ProvisioningService {
  ProvisioningService({
    required this._panel,
    required this._identity,
    required this._credentials,
    required this._selector,
    required this._remote,
    required this._profiles,
    required this._validator,
    required this._local,
    required this._rollback,
    required this.panelId,
  });

  final PanelConnector _panel;
  final DeviceIdentityService _identity;
  final CredentialGenerator _credentials;
  final InboundSelector _selector;
  final RemoteClientProvisioner _remote;
  final ProfileFactory _profiles;
  final ProfileValidator _validator;
  final LocalProfileStore _local;
  final RollbackCoordinator _rollback;
  final String panelId;
  final StreamController<ProvisioningState> _states =
      StreamController<ProvisioningState>.broadcast();

  Stream<ProvisioningState> get states => _states.stream;

  Future<ConnectionProfile> provision({
    InboundPreference preference = InboundPreference.automatic,
    String? displayName,
  }) async {
    RemoteClient? remoteClient;
    String? profileId;
    try {
      _states.add(const ProvisioningPreparing());
      final deviceId = await _identity.getOrCreate();
      final resolvedDisplayName = resolveManagedDeviceDisplayName(
        displayName,
        deviceId,
      );
      final inbounds = _selector.select(
        await _panel.listInbounds(),
        preference,
      );
      final credentials = _credentials.generate();

      _states.add(const ProvisioningCreatingRemote());
      remoteClient = await _remote.create(
        deviceName: deviceId,
        inbounds: inbounds,
        credentials: credentials,
      );
      final proxies = _profiles.parseLinks(remoteClient.links);
      _validator.validateAll(proxies);

      profileId = '$panelId-profile-${remoteClient.id}';
      final now = DateTime.now().toUtc();
      final profile = ConnectionProfile(
        id: profileId,
        panelId: panelId,
        remoteClientId: remoteClient.id,
        displayName: resolvedDisplayName,
        proxies: proxies,
        createdAt: now,
      );
      final device = LocalDevice(
        id: '$panelId-${remoteClient.id}-$deviceId',
        profileId: profileId,
        name: deviceId,
        createdAt: now,
      );

      _states.add(const ProvisioningSavingLocal());
      await _local.saveProfile(profile, device);
      _states.add(ProvisioningComplete(profile));
      return profile;
    } catch (error) {
      var rollbackSucceeded = true;
      if (remoteClient != null) {
        rollbackSucceeded = await _rollback.rollback(
          remoteClientId: remoteClient.id,
          profileId: profileId,
        );
      }
      final message = error is AppException
          ? error.message
          : 'Device provisioning failed.';
      _states.add(
        ProvisioningFailed(message, rollbackSucceeded: rollbackSucceeded),
      );
      throw ProvisioningException(message, cause: error);
    }
  }

  Future<void> dispose() => _states.close();
}

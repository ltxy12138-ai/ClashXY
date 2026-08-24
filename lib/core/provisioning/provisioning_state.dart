import '../../models/profile_models.dart';

sealed class ProvisioningState {
  const ProvisioningState();
}

final class ProvisioningIdle extends ProvisioningState {
  const ProvisioningIdle();
}

final class ProvisioningPreparing extends ProvisioningState {
  const ProvisioningPreparing();
}

final class ProvisioningCreatingRemote extends ProvisioningState {
  const ProvisioningCreatingRemote();
}

final class ProvisioningSavingLocal extends ProvisioningState {
  const ProvisioningSavingLocal();
}

final class ProvisioningComplete extends ProvisioningState {
  const ProvisioningComplete(this.profile);

  final ConnectionProfile profile;
}

final class ProvisioningFailed extends ProvisioningState {
  const ProvisioningFailed(this.message, {required this.rollbackSucceeded});

  final String message;
  final bool rollbackSucceeded;
}

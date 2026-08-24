import '../mihomo/health_checker.dart';

enum NetworkRecoveryAction { restore, waitForNetwork, reconnect }

NetworkRecoveryAction decideNetworkRecovery(HealthReport? report) {
  if (report == null || !report.connectivity) {
    return NetworkRecoveryAction.waitForNetwork;
  }
  return report.healthy
      ? NetworkRecoveryAction.restore
      : NetworkRecoveryAction.reconnect;
}

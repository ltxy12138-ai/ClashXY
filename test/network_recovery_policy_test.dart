import 'package:clashxy/core/mihomo/health_checker.dart';
import 'package:clashxy/core/runtime/network_recovery_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits instead of restarting while external connectivity is absent', () {
    expect(
      decideNetworkRecovery(
        const HealthReport(
          process: true,
          controller: true,
          tun: true,
          proxy: true,
          connectivity: false,
        ),
      ),
      NetworkRecoveryAction.waitForNetwork,
    );
    expect(decideNetworkRecovery(null), NetworkRecoveryAction.waitForNetwork);
  });

  test('restores a healthy connection without restarting Mihomo', () {
    expect(
      decideNetworkRecovery(
        const HealthReport(
          process: true,
          controller: true,
          tun: true,
          proxy: true,
          connectivity: true,
        ),
      ),
      NetworkRecoveryAction.restore,
    );
  });

  test(
    'restarts only when the network is up and the data plane is unhealthy',
    () {
      expect(
        decideNetworkRecovery(
          const HealthReport(
            process: true,
            controller: false,
            tun: true,
            proxy: false,
            connectivity: true,
          ),
        ),
        NetworkRecoveryAction.reconnect,
      );
    },
  );
}

import '../../models/connection_models.dart';
import '../../platform/platform_vpn_service.dart';
import 'controller_client.dart';
import 'process_manager.dart';

class HealthReport {
  const HealthReport({
    required this.process,
    required this.controller,
    required this.tun,
    required this.proxy,
    required this.connectivity,
    this.status,
  });

  final bool process;
  final bool controller;
  final bool tun;
  final bool proxy;
  final bool connectivity;
  final MihomoStatus? status;

  bool get healthy => process && controller && tun && proxy && connectivity;
}

class HealthChecker {
  const HealthChecker({required this.process, required this.platform});

  final ProcessManager process;
  final PlatformVpnService platform;

  Future<HealthReport> check({
    required ControllerClient controller,
    required String tunDevice,
    required bool tunEnabled,
  }) async {
    MihomoStatus? status;
    var controllerOk = false;
    var proxyOk = false;
    try {
      status = await controller.status();
      controllerOk = status.version.isNotEmpty;
      final proxies = await controller.proxies();
      proxyOk = proxies['proxies'] is Map;
    } catch (_) {
      controllerOk = false;
    }
    return HealthReport(
      process: process.running,
      controller: controllerOk,
      tun: !tunEnabled || await platform.adapterExists(tunDevice),
      proxy: proxyOk,
      connectivity: await platform.hasInternetConnectivity(),
      status: status,
    );
  }
}

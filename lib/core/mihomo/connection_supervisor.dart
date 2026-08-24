import 'dart:async';
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../../models/app_settings.dart';
import '../../models/clash_models.dart';
import '../../models/connection_models.dart';
import '../../models/profile_models.dart';
import '../../platform/platform_vpn_service.dart';
import 'binary_manager.dart';
import 'config_manager.dart';
import 'controller_client.dart';
import 'crash_recovery_backoff.dart';
import 'health_checker.dart';
import 'mihomo_engine.dart';
import 'process_manager.dart';

class ConnectionSupervisor implements MihomoEngine {
  ConnectionSupervisor({
    required this.binary,
    required this.config,
    required this.process,
    required this.platform,
    required this.health,
    required this.settings,
    CrashRecoveryBackoff? crashRecovery,
  }) : crashRecovery = crashRecovery ?? CrashRecoveryBackoff() {
    _exitSubscription = process.exits.listen(_handleExit);
  }

  final BinaryManager binary;
  final ConfigManager config;
  final ProcessManager process;
  final PlatformVpnService platform;
  final HealthChecker health;
  final AppSettings settings;
  final CrashRecoveryBackoff crashRecovery;
  final StreamController<AppConnectionState> _states =
      StreamController<AppConnectionState>.broadcast();
  final StreamController<TrafficSample> _traffic =
      StreamController<TrafficSample>.broadcast();
  final StreamController<CoreLogEntry> _logs =
      StreamController<CoreLogEntry>.broadcast();

  late final StreamSubscription<int> _exitSubscription;
  StreamSubscription<TrafficSample>? _trafficSubscription;
  StreamSubscription<CoreLogEntry>? _logSubscription;
  RuntimeConfigHandle? _configHandle;
  ControllerClient? _controller;
  ConnectionProfile? _profile;
  Timer? _crashRecoveryTimer;
  Timer? _crashStabilityTimer;
  Future<void>? _unexpectedExitRecovery;
  bool _stopping = false;
  bool _starting = false;
  bool _handlingUnexpectedExit = false;
  bool _disposed = false;
  int _crashRecoveryGeneration = 0;

  @override
  Stream<AppConnectionState> get states => _states.stream;

  @override
  Stream<TrafficSample> get traffic => _traffic.stream;

  Stream<CoreLogEntry> get logs => _logs.stream;

  @override
  Future<void> start(ConnectionProfile profile) async {
    _cancelCrashRecovery(resetAttempts: true);
    await _start(profile, recoveryAttempt: false);
  }

  Future<void> _start(
    ConnectionProfile profile, {
    required bool recoveryAttempt,
    int? recoveryGeneration,
  }) async {
    if (process.running ||
        _starting ||
        _stopping ||
        _recoveryWasCancelled(recoveryAttempt, recoveryGeneration)) {
      return;
    }
    _starting = true;
    if (!recoveryAttempt) _states.add(const Connecting());
    _profile = profile;
    try {
      if (!await platform.isAdministrator()) {
        throw const MihomoException('Windows TUN 需要管理员权限。');
      }
      final executable = await binary.ensureInstalled();
      final handle = await config.write(profile, settings);
      _configHandle = handle;
      final controller = ControllerClient(
        baseUrl: Uri.parse('http://127.0.0.1:${settings.controllerPort}'),
        secret: handle.secret,
      );
      _controller = controller;
      // Validation may prepare GeoIP/GeoSite and provider caches. It runs
      // without binding ports or creating TUN, so the user's current VPN can
      // remain available during this bootstrap step.
      await process.validate(executable: executable, config: handle.file);
      await _runPreflightChecks();
      if (_recoveryWasCancelled(recoveryAttempt, recoveryGeneration)) {
        await _cleanup();
        return;
      }
      await process.start(executable: executable, config: handle.file);
      await _waitUntilReady(controller);
      if (_recoveryWasCancelled(recoveryAttempt, recoveryGeneration)) {
        await _cleanup();
        return;
      }
      // Mihomo has loaded the configuration. Keep the controller secret only
      // in memory and remove the plaintext YAML while the connection runs.
      await config.clear(handle);
      _trafficSubscription = controller.traffic().listen(
        _traffic.add,
        onError: (Object _) {},
      );
      _logSubscription = controller.logs().listen(
        _logs.add,
        onError: (Object _) {},
      );
      _states.add(Connected(since: DateTime.now().toUtc()));
      _armStableRecoveryReset();
      _starting = false;
      if (!process.running) {
        _handleExit(process.lastExitCode ?? -1);
      }
    } catch (error) {
      await _cleanup();
      if (_recoveryWasCancelled(recoveryAttempt, recoveryGeneration)) return;
      final message = error is AppException ? error.message : '无法启动 Mihomo。';
      if (recoveryAttempt && !_stopping && !_disposed) {
        _scheduleCrashRecovery(profile, message);
        return;
      }
      _states.add(ConnectionFailure(message));
      throw MihomoException(message, cause: error);
    } finally {
      _starting = false;
    }
  }

  Future<void> _runPreflightChecks() async {
    await _ensurePortAvailable(settings.mixedPort, '本机代理端口');
    await _ensurePortAvailable(settings.controllerPort, '控制端口');
    if (!settings.tunEnabled) return;
    final adapters = await platform.activeMihomoTunAdapters();
    if (adapters.isNotEmpty) {
      throw MihomoException(
        '检测到其他 Mihomo TUN 正在运行（${adapters.join('、')}）。'
        '请先在其他 Clash/Mihomo 客户端中断开连接或退出后重试。',
      );
    }
  }

  Future<void> _ensurePortAvailable(int port, String label) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
    } on SocketException {
      throw MihomoException(
        '$label $port 已被其他应用占用。请先退出其他 Clash/Mihomo 客户端，'
        '或在设置中修改端口。',
      );
    } finally {
      await socket?.close();
    }
  }

  Future<void> _waitUntilReady(ControllerClient controller) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      if (!process.running) {
        throw MihomoException(process.describeFailure(process.lastExitCode));
      }
      try {
        final status = await controller.status();
        final adapter =
            !settings.tunEnabled ||
            await platform.adapterExists(settings.tunDevice);
        if (status.version.isNotEmpty && adapter) return;
      } catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    throw MihomoException(
      settings.tunEnabled
          ? 'Mihomo 已启动，但 Windows TUN 未能在 20 秒内就绪。'
          : 'Mihomo 控制器未能在 20 秒内就绪。',
      cause: lastError,
    );
  }

  void _scheduleCrashRecovery(ConnectionProfile profile, String message) {
    if (_stopping || _disposed) return;
    _crashStabilityTimer?.cancel();
    _crashStabilityTimer = null;
    final attempt = crashRecovery.next();
    if (attempt == null) {
      _states.add(
        ConnectionFailure(
          '$message 已连续 ${crashRecovery.maxAttempts} 次自动恢复失败，'
          'ClashXY 已停止重试；请检查配置或系统网络后手动连接。',
        ),
      );
      return;
    }
    final generation = ++_crashRecoveryGeneration;
    _states.add(Reconnecting(attempt: attempt.number));
    _crashRecoveryTimer?.cancel();
    _crashRecoveryTimer = Timer(attempt.delay, () {
      _crashRecoveryTimer = null;
      if (_disposed || _stopping || generation != _crashRecoveryGeneration) {
        return;
      }
      unawaited(
        _start(profile, recoveryAttempt: true, recoveryGeneration: generation),
      );
    });
  }

  bool _recoveryWasCancelled(bool recoveryAttempt, int? generation) {
    return recoveryAttempt &&
        (_disposed || generation != _crashRecoveryGeneration);
  }

  void _armStableRecoveryReset() {
    _crashStabilityTimer?.cancel();
    _crashStabilityTimer = null;
    if (crashRecovery.attempts == 0) return;
    final generation = _crashRecoveryGeneration;
    _crashStabilityTimer = Timer(crashRecovery.stablePeriod, () {
      _crashStabilityTimer = null;
      if (!_disposed &&
          process.running &&
          generation == _crashRecoveryGeneration) {
        crashRecovery.reset();
      }
    });
  }

  void _cancelCrashRecovery({required bool resetAttempts}) {
    _crashRecoveryGeneration++;
    _crashRecoveryTimer?.cancel();
    _crashRecoveryTimer = null;
    _crashStabilityTimer?.cancel();
    _crashStabilityTimer = null;
    if (resetAttempts) crashRecovery.reset();
  }

  @override
  Future<void> stop() async {
    _cancelCrashRecovery(resetAttempts: true);
    if (_stopping) return;
    await _unexpectedExitRecovery;
    if (_stopping) return;
    if (!process.running && _configHandle == null) {
      final hadProfile = _profile != null;
      _profile = null;
      if (hadProfile) _states.add(const Disconnected());
      return;
    }
    _stopping = true;
    _states.add(const Stopping());
    try {
      await _cleanup();
      _profile = null;
      _states.add(const Disconnected());
    } finally {
      _stopping = false;
    }
  }

  Future<void> _cleanup() async {
    await _trafficSubscription?.cancel();
    await _logSubscription?.cancel();
    _trafficSubscription = null;
    _logSubscription = null;
    await process.stop();
    await config.clear(_configHandle);
    _configHandle = null;
    _controller?.dispose();
    _controller = null;
  }

  @override
  Future<MihomoStatus> status() async {
    final controller = _controller;
    if (controller == null) {
      throw const MihomoException('Mihomo 尚未连接。');
    }
    return controller.status();
  }

  Future<HealthReport> healthReport() async {
    final controller = _controller;
    if (controller == null) {
      return const HealthReport(
        process: false,
        controller: false,
        tun: false,
        proxy: false,
        connectivity: false,
      );
    }
    return health.check(
      controller: controller,
      tunDevice: settings.tunDevice,
      tunEnabled: settings.tunEnabled,
    );
  }

  @override
  Future<DelayResult> testDelay(String proxyName) async {
    final controller = _controller;
    if (controller == null || _profile == null) {
      throw const MihomoException('Mihomo 尚未连接。');
    }
    return controller.delay(proxyName);
  }

  Future<List<ProxyGroupState>> proxyGroups() {
    return _requireController().proxyGroups();
  }

  Future<List<ProxyProviderState>> providers() {
    return _requireController().providers();
  }

  Future<void> updateProvider(String name) {
    return _requireController().updateProvider(name);
  }

  Future<List<RuleProviderState>> ruleProviders() {
    return _requireController().ruleProviders();
  }

  Future<void> updateRuleProvider(String name) {
    return _requireController().updateRuleProvider(name);
  }

  Future<void> selectProxy(String group, String proxy) {
    return _requireController().selectProxy(group, proxy);
  }

  Future<List<ClashRuleEntry>> rules() {
    return _requireController().rules();
  }

  Future<ConnectionSnapshot> connections() {
    return _requireController().connections();
  }

  Future<void> closeConnection(String id) {
    return _requireController().closeConnection(id);
  }

  Future<void> closeAllConnections() {
    return _requireController().closeAllConnections();
  }

  Future<void> setMode(String mode) {
    return _requireController().setMode(mode);
  }

  ControllerClient _requireController() {
    final controller = _controller;
    if (controller == null) {
      throw const MihomoException('Mihomo 尚未连接。');
    }
    return controller;
  }

  void _handleExit(int code) {
    final profile = _profile;
    if (_stopping ||
        _starting ||
        _disposed ||
        _handlingUnexpectedExit ||
        _configHandle == null ||
        profile == null) {
      return;
    }
    _handlingUnexpectedExit = true;
    _crashStabilityTimer?.cancel();
    _crashStabilityTimer = null;
    final generation = ++_crashRecoveryGeneration;
    final recovery = _prepareCrashRecovery(
      profile,
      process.describeFailure(code),
      generation,
    );
    _unexpectedExitRecovery = recovery;
    unawaited(
      recovery.whenComplete(() {
        if (identical(_unexpectedExitRecovery, recovery)) {
          _unexpectedExitRecovery = null;
        }
      }),
    );
  }

  Future<void> _prepareCrashRecovery(
    ConnectionProfile profile,
    String message,
    int generation,
  ) async {
    try {
      await _cleanup();
      await platform.cleanupStaleNetworkState(
        deviceName: settings.tunDevice,
        coreExecutablePath: binary.currentExecutablePath,
      );
    } catch (_) {
      if (!_disposed && !_stopping && generation == _crashRecoveryGeneration) {
        _states.add(
          const ConnectionFailure('Mihomo 意外退出后的 TUN/DNS 状态清理失败，请手动重连或重启系统。'),
        );
      }
      return;
    } finally {
      _handlingUnexpectedExit = false;
    }
    if (_disposed || _stopping || generation != _crashRecoveryGeneration) {
      return;
    }
    _scheduleCrashRecovery(profile, message);
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _exitSubscription.cancel();
    await process.dispose();
    await _states.close();
    await _traffic.close();
    await _logs.close();
  }
}

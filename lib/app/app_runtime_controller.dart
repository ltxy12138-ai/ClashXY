import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exception.dart';
import '../core/mihomo/binary_manager.dart';
import '../core/mihomo/config_manager.dart';
import '../core/mihomo/connection_supervisor.dart';
import '../core/mihomo/health_checker.dart';
import '../core/mihomo/mihomo_config_builder.dart';
import '../core/mihomo/process_manager.dart';
import '../core/panel/panel_connector.dart';
import '../core/panel/panel_setup_service.dart';
import '../core/panel/two_sui_http_client.dart';
import '../core/profiles/profile_import_service.dart';
import '../core/provisioning/credential_generator.dart';
import '../core/provisioning/device_identity_service.dart';
import '../core/provisioning/inbound_selector.dart';
import '../core/provisioning/profile_factory.dart';
import '../core/provisioning/profile_validator.dart';
import '../core/provisioning/provisioning_service.dart';
import '../core/provisioning/remote_client_provisioner.dart';
import '../core/provisioning/rollback_coordinator.dart';
import '../core/runtime/async_operation_gate.dart';
import '../core/runtime/network_monitor.dart';
import '../core/runtime/network_recovery_policy.dart';
import '../core/runtime/system_power_monitor.dart';
import '../core/security/app_logger.dart';
import '../core/storage/drift_profile_store.dart';
import '../core/storage/panel_store.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/settings_store.dart';
import '../core/storage/standalone_profile_store.dart';
import '../models/app_settings.dart';
import '../models/clash_models.dart';
import '../models/connection_models.dart';
import '../models/panel_models.dart';
import '../models/profile_models.dart';
import '../platform/windows/flutter_asset_mihomo_binary_source.dart';
import '../platform/windows/windows_network_monitor.dart';
import '../platform/windows/windows_power_monitor.dart';
import '../platform/windows/windows_platform_vpn_service.dart';
import '../platform/windows/windows_startup_registration.dart';
import 'app_runtime_state.dart';
import 'app_runtime_message.dart';

typedef NetworkMonitorFactory = NetworkMonitor Function(AppSettings settings);
typedef SystemPowerMonitorFactory = SystemPowerMonitor Function();

NetworkMonitor _defaultNetworkMonitorFactory(AppSettings settings) =>
    WindowsNetworkMonitor(excludedInterfaceNames: <String>[settings.tunDevice]);

SystemPowerMonitor _defaultSystemPowerMonitorFactory() => WindowsPowerMonitor();

class AppRuntimeController extends StateNotifier<AppRuntimeState> {
  AppRuntimeController({
    required this.logger,
    required this.secureStorage,
    required this.panelStore,
    required this.profileStore,
    required this.standaloneProfileStore,
    required this.profileImportService,
    required this.settingsStore,
    required this.startupRegistration,
    NetworkMonitorFactory? networkMonitorFactory,
    SystemPowerMonitorFactory? systemPowerMonitorFactory,
  }) : networkMonitorFactory =
           networkMonitorFactory ?? _defaultNetworkMonitorFactory,
       systemPowerMonitorFactory =
           systemPowerMonitorFactory ?? _defaultSystemPowerMonitorFactory,
       super(const AppRuntimeState());

  static const String _coreSha256 =
      'cf894375dbc00ab6708c1314ac35bbd29059f4c37f315353aaca7f1a9c566de6';

  final AppLogger logger;
  final SecureStorage secureStorage;
  final PanelStore panelStore;
  final DriftProfileStore profileStore;
  final StandaloneProfileStore standaloneProfileStore;
  final ProfileImportService profileImportService;
  final SettingsStore settingsStore;
  final StartupRegistration startupRegistration;
  final NetworkMonitorFactory networkMonitorFactory;
  final SystemPowerMonitorFactory systemPowerMonitorFactory;
  final PanelSetupService _setup = const PanelSetupService();

  PanelConnector? _panel;
  ConnectionSupervisor? _engine;
  StreamSubscription<AppConnectionState>? _connectionSubscription;
  StreamSubscription<TrafficSample>? _trafficSubscription;
  StreamSubscription<CoreLogEntry>? _logSubscription;
  NetworkMonitor? _networkMonitor;
  StreamSubscription<NetworkSnapshot>? _networkSubscription;
  SystemPowerMonitor? _systemPowerMonitor;
  StreamSubscription<SystemPowerEvent>? _systemPowerSubscription;
  Timer? _subscriptionRefreshTimer;
  Timer? _networkRecoveryTimer;
  bool _checkingSubscriptions = false;
  bool _refreshingConnections = false;
  bool _networkAvailable = true;
  bool _suspended = false;
  String? _suspendedProfileId;
  int _networkGeneration = 0;
  DateTime? _lastConnectedSince;
  final AsyncOperationGate _connectionGate = AsyncOperationGate();

  Future<void> initialize() async {
    try {
      var settings = await settingsStore.load();
      try {
        final launchAtStartup = await startupRegistration.isEnabled();
        if (launchAtStartup != settings.launchAtStartup) {
          settings = settings.copyWith(launchAtStartup: launchAtStartup);
          await settingsStore.save(settings);
        }
      } catch (error, stackTrace) {
        logger.log(
          LogLevel.warning,
          'Could not read Windows startup registration.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      await _createEngine(settings);
      await _startNetworkMonitoring(settings);
      await _startSystemPowerMonitoring();
      final panels = await panelStore.list();
      final profiles = await _listProfiles();
      final devices = await profileStore.listDevices();
      PanelAccount? connectedPanel;
      RuntimeMessage? message;
      for (final panel in panels) {
        final tokenRef = await panelStore.tokenRef(panel.id);
        if (tokenRef == null || tokenRef.isEmpty) continue;
        final token = await secureStorage.read(tokenRef);
        if (token == null || token.isEmpty) {
          message = const RuntimeMessage(RuntimeMessageCode.tokenMissing);
        } else {
          try {
            final connector = _connector(panel.baseUrl);
            await connector.useToken(token);
            _panel = connector;
            connectedPanel = panel;
            break;
          } catch (error, stackTrace) {
            logger.log(
              LogLevel.warning,
              'Stored panel token could not be used.',
              error: error,
              stackTrace: stackTrace,
            );
            message = _runtimeError(
              RuntimeMessageCode.panelSessionInvalid,
              error,
            );
          }
        }
      }
      state = state.copyWith(
        stage: profiles.isEmpty && connectedPanel == null
            ? AppStage.onboarding
            : AppStage.ready,
        panel: connectedPanel,
        profiles: profiles,
        localDevices: devices,
        settings: settings,
        message: message,
      );
      if (connectedPanel != null) await refreshRemote();
      if (settings.autoConnect && profiles.isNotEmpty) {
        if (_networkAvailable) {
          await connect(profiles.first);
        } else {
          state = state.copyWith(
            activeProfileId: profiles.first.id,
            connection: const WaitingForNetwork(),
          );
        }
      }
      _startSubscriptionRefreshTimer();
      unawaited(_refreshDueSubscriptions());
    } catch (error, stackTrace) {
      logger.log(
        LogLevel.error,
        '应用初始化失败。',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        stage: AppStage.onboarding,
        busy: false,
        message: _runtimeError(RuntimeMessageCode.initializationFailed, error),
      );
    }
  }

  Future<bool> addSubscription({
    required String name,
    required String url,
  }) async {
    state = state.copyWith(
      busy: true,
      message: const RuntimeMessage(RuntimeMessageCode.downloadingSubscription),
    );
    try {
      final profile = await profileImportService.fromSubscription(
        name: name,
        url: Uri.parse(url.trim()),
      );
      await standaloneProfileStore.save(profile);
      await _reloadLocal();
      state = state.copyWith(
        stage: AppStage.ready,
        busy: false,
        message: const RuntimeMessage(RuntimeMessageCode.subscriptionAdded),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.subscriptionAddFailed, error),
      );
      return false;
    }
  }

  Future<bool> importLocalConfig({
    required String name,
    required String yaml,
  }) async {
    try {
      final profile = profileImportService.fromLocalYaml(
        name: name,
        yaml: yaml,
      );
      return await _saveImported(profile, RuntimeMessageCode.localImported);
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.importFailed, error),
      );
      return false;
    }
  }

  Future<bool> importCustomConfig({
    required String name,
    required String yaml,
  }) async {
    try {
      final profile = profileImportService.fromCustomYaml(
        name: name,
        yaml: yaml,
      );
      return await _saveImported(profile, RuntimeMessageCode.customSaved);
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.importFailed, error),
      );
      return false;
    }
  }

  Future<void> refreshSubscription(
    ConnectionProfile profile, {
    bool silent = false,
  }) async {
    final url = profile.subscriptionUrl;
    if (profile.origin != ProfileOrigin.subscription || url == null) return;
    if (!silent) {
      state = state.copyWith(
        busy: true,
        message: const RuntimeMessage(RuntimeMessageCode.updatingSubscription),
      );
    }
    try {
      final downloaded = await profileImportService.fromSubscription(
        name: profile.displayName,
        url: url,
        existingId: profile.id,
      );
      final refreshed = downloaded.copyWith(
        createdAt: profile.createdAt,
        autoUpdateInterval: profile.autoUpdateInterval,
      );
      await standaloneProfileStore.save(refreshed);
      await _reloadLocal();
      if (!silent) {
        state = state.copyWith(
          busy: false,
          message: const RuntimeMessage(RuntimeMessageCode.subscriptionUpdated),
        );
      }
    } catch (error, stackTrace) {
      if (silent) {
        logger.log(
          LogLevel.warning,
          '后台订阅更新失败。',
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        state = state.copyWith(
          busy: false,
          message: _runtimeError(
            RuntimeMessageCode.subscriptionUpdateFailed,
            error,
          ),
        );
      }
    }
  }

  Future<bool> updateStandaloneProfile({
    required ConnectionProfile profile,
    required String name,
    Uri? subscriptionUrl,
    required Duration autoUpdateInterval,
  }) async {
    if (!profile.isStandalone || name.trim().isEmpty) return false;
    state = state.copyWith(busy: true, message: null);
    try {
      var updated = profile.copyWith(
        displayName: name.trim(),
        autoUpdateInterval: autoUpdateInterval,
      );
      if (profile.origin == ProfileOrigin.subscription) {
        final url = subscriptionUrl;
        if (url == null ||
            url.scheme != 'https' ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty) {
          throw const AppException('订阅地址必须使用 HTTPS，且不能包含 URL 用户凭据。');
        }
        if (url != profile.subscriptionUrl) {
          final downloaded = await profileImportService.fromSubscription(
            name: name.trim(),
            url: url,
            existingId: profile.id,
          );
          updated = downloaded.copyWith(
            createdAt: profile.createdAt,
            autoUpdateInterval: autoUpdateInterval,
          );
        } else {
          updated = updated.copyWith(subscriptionUrl: url);
        }
      }
      await standaloneProfileStore.save(updated);
      await _reloadLocal();
      state = state.copyWith(
        busy: false,
        message: const RuntimeMessage(RuntimeMessageCode.profileUpdated),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.profileUpdateFailed, error),
      );
      return false;
    }
  }

  Future<bool> replaceStandaloneYaml({
    required ConnectionProfile profile,
    required String yaml,
  }) async {
    if (!profile.isStandalone) return false;
    state = state.copyWith(busy: true, message: null);
    try {
      final updated = profileImportService.replaceYaml(
        profile: profile,
        yaml: yaml,
      );
      await standaloneProfileStore.save(updated);
      await _reloadLocal();
      state = state.copyWith(
        busy: false,
        message: const RuntimeMessage(RuntimeMessageCode.yamlUpdated),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.profileUpdateFailed, error),
      );
      return false;
    }
  }

  void _startSubscriptionRefreshTimer() {
    _subscriptionRefreshTimer?.cancel();
    _subscriptionRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(_refreshDueSubscriptions()),
    );
  }

  Future<void> _startNetworkMonitoring(AppSettings settings) async {
    _networkRecoveryTimer?.cancel();
    _networkGeneration++;
    await _networkSubscription?.cancel();
    await _networkMonitor?.dispose();
    final monitor = networkMonitorFactory(settings);
    _networkMonitor = monitor;
    _networkSubscription = monitor.changes.listen(_handleNetworkChange);
    await monitor.start();
    _networkAvailable = monitor.current?.available ?? true;
  }

  Future<void> _startSystemPowerMonitoring() async {
    await _systemPowerSubscription?.cancel();
    await _systemPowerMonitor?.dispose();
    final monitor = systemPowerMonitorFactory();
    _systemPowerMonitor = monitor;
    _systemPowerSubscription = monitor.events.listen(_handleSystemPowerEvent);
    await monitor.start();
  }

  void _handleSystemPowerEvent(SystemPowerEvent event) {
    switch (event) {
      case SystemPowerEvent.suspend:
        _suspended = true;
        _suspendedProfileId = state.activeProfileId;
        _networkRecoveryTimer?.cancel();
        _networkGeneration++;
        if (state.activeProfileId != null &&
            state.connection is! Disconnected &&
            state.connection is! ConnectionFailure &&
            state.connection is! Stopping) {
          state = state.copyWith(connection: const WaitingForNetwork());
        }
        return;
      case SystemPowerEvent.resume:
        _suspended = false;
        unawaited(_scheduleResumeRecovery());
    }
  }

  Future<void> _scheduleResumeRecovery() async {
    try {
      await _networkMonitor?.checkNow();
    } catch (error, stackTrace) {
      logger.log(
        LogLevel.warning,
        'Post-resume network check failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_suspended) return;
    _networkAvailable =
        _networkMonitor?.current?.available ?? _networkAvailable;
    final profileId = state.activeProfileId ?? _suspendedProfileId;
    if (profileId == null || state.connection is Stopping) {
      return;
    }
    final generation = ++_networkGeneration;
    _networkRecoveryTimer?.cancel();
    if (!_networkAvailable) {
      state = state.copyWith(
        activeProfileId: profileId,
        connection: const WaitingForNetwork(),
      );
      return;
    }
    state = state.copyWith(
      activeProfileId: profileId,
      connection: const Reconnecting(attempt: 1),
    );
    _networkRecoveryTimer = Timer(
      const Duration(seconds: 3),
      () => unawaited(_recoverAfterNetworkChange(generation)),
    );
  }

  void _handleNetworkChange(NetworkSnapshot snapshot) {
    _networkAvailable = snapshot.available;
    if (_suspended) return;
    final connection = state.connection;
    final activeProfileId = state.activeProfileId;
    if (activeProfileId == null ||
        connection is Disconnected ||
        connection is ConnectionFailure ||
        connection is Stopping ||
        connection is Connecting) {
      return;
    }
    final generation = ++_networkGeneration;
    _networkRecoveryTimer?.cancel();
    if (!snapshot.available) {
      state = state.copyWith(connection: const WaitingForNetwork());
      return;
    }
    if (connection is WaitingForNetwork) {
      state = state.copyWith(connection: const Reconnecting(attempt: 1));
    }
    _networkRecoveryTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_recoverAfterNetworkChange(generation)),
    );
  }

  Future<void> _recoverAfterNetworkChange(int generation) async {
    if (_suspended || generation != _networkGeneration || !_networkAvailable) {
      return;
    }
    final profileId = state.activeProfileId ?? _suspendedProfileId;
    final engine = _engine;
    if (profileId == null || engine == null) return;
    if (state.activeProfileId == null) {
      state = state.copyWith(activeProfileId: profileId);
    }
    final profile = state.profiles
        .where((candidate) => candidate.id == profileId)
        .firstOrNull;
    if (profile == null) return;
    if (_lastConnectedSince == null) {
      state = state.copyWith(connection: const Reconnecting(attempt: 1));
      await connect(profile);
      return;
    }

    HealthReport? report;
    try {
      report = await engine.healthReport().timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      logger.log(
        LogLevel.warning,
        'Network-change health check failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (generation != _networkGeneration || !_networkAvailable) return;
    switch (decideNetworkRecovery(report)) {
      case NetworkRecoveryAction.waitForNetwork:
        state = state.copyWith(connection: const WaitingForNetwork());
        _networkRecoveryTimer = Timer(
          const Duration(seconds: 5),
          () => unawaited(_recoverAfterNetworkChange(generation)),
        );
        return;
      case NetworkRecoveryAction.restore:
        if (state.connection is WaitingForNetwork ||
            state.connection is Reconnecting) {
          state = state.copyWith(
            connection: Connected(
              since: _lastConnectedSince ?? DateTime.now().toUtc(),
            ),
          );
        }
        unawaited(refreshClashData());
        return;
      case NetworkRecoveryAction.reconnect:
        break;
    }
    state = state.copyWith(connection: const Reconnecting(attempt: 1));
    await connect(profile);
  }

  void _cancelPendingNetworkRecovery() {
    _networkRecoveryTimer?.cancel();
    _networkRecoveryTimer = null;
    _networkGeneration++;
  }

  Future<void> _refreshDueSubscriptions() async {
    if (_checkingSubscriptions) return;
    _checkingSubscriptions = true;
    try {
      final now = DateTime.now().toUtc();
      final due = state.profiles.where(
        (profile) =>
            profile.autoUpdateEnabled &&
            now.difference(profile.lastUpdatedAt) >= profile.autoUpdateInterval,
      );
      for (final profile in due.toList(growable: false)) {
        await refreshSubscription(profile, silent: true);
      }
    } finally {
      _checkingSubscriptions = false;
    }
  }

  Future<bool> _saveImported(
    ConnectionProfile profile,
    RuntimeMessageCode successCode,
  ) async {
    state = state.copyWith(busy: true, message: null);
    try {
      await standaloneProfileStore.save(profile);
      await _reloadLocal();
      state = state.copyWith(
        stage: AppStage.ready,
        busy: false,
        message: RuntimeMessage(successCode),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.importFailed, error),
      );
      return false;
    }
  }

  Future<void> testPanel(String text) async {
    state = state.copyWith(busy: true, message: null);
    try {
      final result = await _setup.test(Uri.parse(text.trim()));
      state = state.copyWith(
        busy: false,
        message: RuntimeMessage(
          result.reachable
              ? RuntimeMessageCode.panelReachable
              : RuntimeMessageCode.panelUnexpected,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.panelTestFailed, error),
      );
    }
  }

  Future<bool> configurePanel({
    required String url,
    required String username,
    required String password,
    required String code,
  }) async {
    if (state.panel != null) {
      state = state.copyWith(
        message: const RuntimeMessage(RuntimeMessageCode.panelAlreadyConnected),
      );
      return false;
    }
    state = state.copyWith(busy: true, needsTwoFactor: false, message: null);
    TwoSuiHttpClient? administrator;
    ProvisionedToken? createdToken;
    String? tokenRef;
    try {
      final normalized = TwoSuiHttpClient.normalizePanelUrl(
        Uri.parse(url.trim()),
      );
      administrator = _connector(normalized);
      final session = await administrator.login(
        LoginRequest(
          baseUrl: administrator.baseUrl,
          username: username.trim(),
          password: password,
          code: code.trim(),
        ),
      );
      if (session.requiresTwoFactor) {
        state = state.copyWith(
          busy: false,
          needsTwoFactor: true,
          message: const RuntimeMessage(RuntimeMessageCode.twoFactorRequired),
        );
        return false;
      }

      final panelId = _panelIdFor(normalized, username.trim());
      createdToken = await administrator.createToken(
        description: 'ClashXY Windows',
        expiresAt: DateTime.now().add(const Duration(days: 3650)),
      );
      await administrator.useToken(createdToken.value);
      tokenRef = SecureKeys.panelToken(panelId);
      await secureStorage.write(tokenRef, createdToken.value);
      final account = PanelAccount(
        id: panelId,
        name: normalized.host,
        baseUrl: normalized,
        username: username.trim(),
        createdAt: DateTime.now().toUtc(),
        tokenId: createdToken.id,
      );
      await panelStore.save(account, tokenRef: tokenRef);

      final connector = _connector(normalized);
      await connector.useToken(createdToken.value);
      _panel = connector;
      await administrator.logout();
      state = state.copyWith(
        stage: AppStage.ready,
        busy: false,
        needsTwoFactor: false,
        panel: account,
        message: const RuntimeMessage(RuntimeMessageCode.panelConnected),
      );
      await refreshRemote();
      return true;
    } catch (error, stackTrace) {
      if (createdToken != null && administrator != null) {
        try {
          await administrator.deleteToken(createdToken.id);
        } catch (_) {}
      }
      if (tokenRef != null) await secureStorage.delete(tokenRef);
      logger.log(
        LogLevel.warning,
        '面板连接失败。',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.panelConnectFailed, error),
      );
      return false;
    }
  }

  Future<void> provisionAndConnect({String? displayName}) async {
    final panel = _panel;
    if (panel == null) {
      state = state.copyWith(
        message: const RuntimeMessage(RuntimeMessageCode.connectPanelFirst),
      );
      return;
    }
    state = state.copyWith(
      busy: true,
      message: const RuntimeMessage(RuntimeMessageCode.creatingDevice),
    );
    final remote = RemoteClientProvisioner(panel);
    final rollback = RollbackCoordinator(
      remote: remote,
      local: profileStore,
      logger: logger,
    );
    final service = ProvisioningService(
      panel: panel,
      identity: DeviceIdentityService(secureStorage),
      credentials: CredentialGenerator(),
      selector: const InboundSelector(),
      remote: remote,
      profiles: const ProfileFactory(),
      validator: const ProfileValidator(),
      local: profileStore,
      rollback: rollback,
      panelId: state.panel!.id,
    );
    try {
      final profile = await service.provision(
        preference: _preference(),
        displayName: displayName,
      );
      await _reloadLocal();
      state = state.copyWith(
        busy: false,
        message: const RuntimeMessage(
          RuntimeMessageCode.deviceCreatedConnecting,
        ),
      );
      await connect(profile);
      await refreshRemote();
    } catch (error, stackTrace) {
      logger.log(
        LogLevel.error,
        '设备创建失败。',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.deviceCreateFailed, error),
      );
    } finally {
      await service.dispose();
    }
  }

  Future<void> connect([ConnectionProfile? selected]) async {
    _cancelPendingNetworkRecovery();
    await _connectionGate.run(() async {
      final profile = selected ?? state.profiles.firstOrNull;
      final engine = _engine;
      if (profile == null || engine == null) {
        state = state.copyWith(
          message: const RuntimeMessage(RuntimeMessageCode.addProfileFirst),
        );
        return;
      }
      if (state.activeProfileId == profile.id &&
          state.connection is Connected) {
        return;
      }
      try {
        if (state.connection is! Disconnected) {
          await engine.stop();
        }
        state = state.copyWith(activeProfileId: profile.id, message: null);
        await engine.start(profile);
      } catch (error) {
        state = state.copyWith(
          activeProfileId: null,
          message: _runtimeError(RuntimeMessageCode.connectFailed, error),
        );
      }
    });
  }

  Future<void> disconnect() async {
    _cancelPendingNetworkRecovery();
    _suspendedProfileId = null;
    await _connectionGate.run(() async {
      await _engine?.stop();
    });
  }

  Future<void> testDelay([String? selectedProxy]) async {
    if (state.delayTestStatus == DelayTestStatus.testing) return;
    final activeProfile = state.profiles
        .where((profile) => profile.id == state.activeProfileId)
        .firstOrNull;
    final profileProxy = activeProfile?.proxies.firstOrNull?.name;
    final groupProxy = state.proxyGroups.firstOrNull?.selected;
    final proxyName = selectedProxy ?? profileProxy ?? groupProxy;
    if (proxyName == null || _engine == null) {
      state = state.copyWith(
        delay: null,
        delayTestStatus: DelayTestStatus.failed,
        message: const RuntimeMessage(RuntimeMessageCode.noDelayProxy),
      );
      return;
    }
    state = state.copyWith(
      delay: null,
      delayTestStatus: DelayTestStatus.testing,
      message: null,
    );
    try {
      final result = await _engine!.testDelay(proxyName);
      state = state.copyWith(
        delay: result,
        delayTestStatus: DelayTestStatus.success,
        proxyDelays: <String, int>{
          ...state.proxyDelays,
          result.proxyName: result.milliseconds,
        },
        message: null,
      );
    } catch (error) {
      state = state.copyWith(
        delay: null,
        delayTestStatus: DelayTestStatus.failed,
        message: _runtimeError(RuntimeMessageCode.delayTestFailed, error),
      );
    }
  }

  Future<void> refreshClashData() async {
    final engine = _engine;
    if (engine == null || state.connection is! Connected) return;
    try {
      final status = await engine.status();
      final groups = await engine.proxyGroups();
      List<ProxyProviderState> providers;
      List<RuleProviderState> ruleProviders;
      try {
        providers = await engine.providers();
      } catch (_) {
        providers = const <ProxyProviderState>[];
      }
      try {
        ruleProviders = await engine.ruleProviders();
      } catch (_) {
        ruleProviders = const <RuleProviderState>[];
      }
      final rules = await engine.rules();
      final connections = await engine.connections();
      state = state.copyWith(
        proxyGroups: groups,
        proxyProviders: providers,
        ruleProviders: ruleProviders,
        rules: rules,
        connectionSnapshot: connections,
        coreMode: status.mode,
        message: null,
      );
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.refreshClashFailed, error),
      );
    }
  }

  Future<void> refreshConnections() async {
    final engine = _engine;
    if (engine == null ||
        state.connection is! Connected ||
        _refreshingConnections) {
      return;
    }
    _refreshingConnections = true;
    try {
      state = state.copyWith(connectionSnapshot: await engine.connections());
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(
          RuntimeMessageCode.refreshConnectionsFailed,
          error,
        ),
      );
    } finally {
      _refreshingConnections = false;
    }
  }

  void clearCoreLogs() {
    state = state.copyWith(coreLogs: const <CoreLogEntry>[]);
  }

  Future<void> selectProxy(String group, String proxy) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.selectProxy(group, proxy);
      state = state.copyWith(proxyGroups: await engine.proxyGroups());
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.switchProxyFailed, error),
      );
    }
  }

  Future<void> testGroupDelays(ProxyGroupState group) async {
    final engine = _engine;
    if (engine == null || group.options.isEmpty || state.delayTesting) return;
    state = state.copyWith(
      delayTesting: true,
      message: const RuntimeMessage(RuntimeMessageCode.testingAll),
    );
    final names = group.options.toSet().toList(growable: false);
    final results = <String, int>{};
    var next = 0;
    Future<void> worker() async {
      while (next < names.length) {
        final name = names[next++];
        try {
          final result = await engine.testDelay(name);
          results[name] = result.milliseconds;
        } catch (_) {}
      }
    }

    final workerCount = names.length < 6 ? names.length : 6;
    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    state = state.copyWith(
      delayTesting: false,
      proxyDelays: <String, int>{...state.proxyDelays, ...results},
      message: RuntimeMessage(
        results.isEmpty
            ? RuntimeMessageCode.testNoResults
            : RuntimeMessageCode.testComplete,
      ),
    );
  }

  Future<void> updateProvider(String name) async {
    final engine = _engine;
    if (engine == null) return;
    state = state.copyWith(
      busy: true,
      message: const RuntimeMessage(RuntimeMessageCode.updatingProvider),
    );
    try {
      await engine.updateProvider(name);
      state = state.copyWith(
        busy: false,
        proxyProviders: await engine.providers(),
        proxyGroups: await engine.proxyGroups(),
        message: const RuntimeMessage(RuntimeMessageCode.providerUpdated),
      );
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.providerUpdateFailed, error),
      );
    }
  }

  Future<void> updateRuleProvider(String name) async {
    final engine = _engine;
    if (engine == null) return;
    state = state.copyWith(
      busy: true,
      message: const RuntimeMessage(RuntimeMessageCode.updatingRuleProvider),
    );
    try {
      await engine.updateRuleProvider(name);
      state = state.copyWith(
        busy: false,
        ruleProviders: await engine.ruleProviders(),
        rules: await engine.rules(),
        message: const RuntimeMessage(RuntimeMessageCode.ruleProviderUpdated),
      );
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(
          RuntimeMessageCode.ruleProviderUpdateFailed,
          error,
        ),
      );
    }
  }

  Future<void> closeConnection(String id) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.closeConnection(id);
      await refreshConnections();
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.closeConnectionFailed, error),
      );
    }
  }

  Future<void> closeAllConnections() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.closeAllConnections();
      await refreshConnections();
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.closeAllFailed, error),
      );
    }
  }

  Future<void> setCoreMode(String mode) async {
    if (!const <String>{'rule', 'global', 'direct'}.contains(mode)) return;
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.setMode(mode);
      state = state.copyWith(coreMode: mode);
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.switchModeFailed, error),
      );
    }
  }

  Future<void> refreshRemote() async {
    final panel = _panel;
    if (panel == null) return;
    try {
      final clients = await panel.listClients();
      final online = await panel.listOnlineClients();
      final status = await panel.getServerStatus();
      final traffic = await panel.getTraffic();
      state = state.copyWith(
        remoteDevices: clients,
        onlineDevices: online,
        serverStatus: status,
        serverTraffic: traffic,
      );
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.refreshPanelFailed, error),
      );
    }
  }

  Future<void> disconnectPanelLocal() async {
    final account = state.panel;
    if (account == null || state.busy) return;
    state = state.copyWith(busy: true, message: null);
    try {
      await _detachPanel(account);
      state = state.copyWith(
        busy: false,
        message: const RuntimeMessage(RuntimeMessageCode.panelDisconnected),
      );
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.panelDisconnectFailed, error),
      );
    }
  }

  Future<bool> revokeAndDisconnectPanel({
    required String password,
    required String code,
  }) async {
    final account = state.panel;
    if (account == null || state.busy) return false;
    final tokenId = account.tokenId;
    if (tokenId == null || tokenId.isEmpty) {
      state = state.copyWith(
        message: const RuntimeMessage(RuntimeMessageCode.panelTokenIdMissing),
      );
      return false;
    }
    state = state.copyWith(busy: true, needsTwoFactor: false, message: null);
    final administrator = _connector(account.baseUrl);
    try {
      final session = await administrator.login(
        LoginRequest(
          baseUrl: account.baseUrl,
          username: account.username,
          password: password,
          code: code.trim(),
        ),
      );
      if (session.requiresTwoFactor) {
        state = state.copyWith(
          busy: false,
          needsTwoFactor: true,
          message: const RuntimeMessage(RuntimeMessageCode.twoFactorRequired),
        );
        return false;
      }
      await administrator.deleteToken(tokenId);
      await administrator.logout();
      await _detachPanel(account);
      state = state.copyWith(
        busy: false,
        needsTwoFactor: false,
        message: const RuntimeMessage(RuntimeMessageCode.panelTokenRevoked),
      );
      return true;
    } catch (error, stackTrace) {
      logger.log(
        LogLevel.warning,
        'Panel token revocation failed.',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        busy: false,
        message: _runtimeError(
          RuntimeMessageCode.panelTokenRevokeFailed,
          error,
        ),
      );
      return false;
    }
  }

  Future<void> _detachPanel(PanelAccount account) async {
    final tokenRef = await panelStore.tokenRef(account.id);
    if (tokenRef != null && tokenRef.isNotEmpty) {
      await secureStorage.delete(tokenRef);
    }
    await panelStore.detach(account.id);
    _panel = null;
    state = state.copyWith(
      stage: state.profiles.isEmpty ? AppStage.onboarding : AppStage.ready,
      panel: null,
      remoteDevices: const <RemoteClient>[],
      onlineDevices: const <OnlineClient>[],
      serverStatus: null,
      serverTraffic: null,
    );
  }

  Future<void> deleteDevice(ConnectionProfile profile) async {
    if (profile.isStandalone) {
      state = state.copyWith(
        busy: true,
        message: const RuntimeMessage(RuntimeMessageCode.deletingProfile),
      );
      try {
        await disconnect();
        await standaloneProfileStore.delete(profile.id);
        await _reloadLocal();
        state = state.copyWith(
          busy: false,
          message: const RuntimeMessage(RuntimeMessageCode.profileDeleted),
        );
      } catch (error) {
        state = state.copyWith(
          busy: false,
          message: _runtimeError(RuntimeMessageCode.deleteProfileFailed, error),
        );
      }
      return;
    }
    final panel = _panel;
    if (panel == null || profile.panelId != state.panel?.id) {
      state = state.copyWith(
        busy: true,
        message: const RuntimeMessage(RuntimeMessageCode.deletingProfile),
      );
      try {
        if (state.activeProfileId == profile.id) await disconnect();
        await profileStore.deleteProfile(profile.id);
        await _reloadLocal();
        state = state.copyWith(
          busy: false,
          message: const RuntimeMessage(
            RuntimeMessageCode.detachedPanelProfileDeleted,
          ),
        );
      } catch (error) {
        state = state.copyWith(
          busy: false,
          message: _runtimeError(RuntimeMessageCode.deleteProfileFailed, error),
        );
      }
      return;
    }
    state = state.copyWith(
      busy: true,
      message: const RuntimeMessage(RuntimeMessageCode.deletingDevice),
    );
    try {
      await disconnect();
      await panel.deleteClient(profile.remoteClientId);
      await profileStore.deleteProfile(profile.id);
      await _reloadLocal();
      await refreshRemote();
      state = state.copyWith(
        busy: false,
        message: const RuntimeMessage(RuntimeMessageCode.deviceDeleted),
      );
    } catch (error) {
      state = state.copyWith(
        busy: false,
        message: _runtimeError(RuntimeMessageCode.deleteDeviceFailed, error),
      );
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    try {
      if (settings.launchAtStartup != state.settings.launchAtStartup) {
        await startupRegistration.setEnabled(settings.launchAtStartup);
      }
      await settingsStore.save(settings);
      state = state.copyWith(settings: settings);
      if (state.connection is Disconnected) {
        await _createEngine(settings);
        await _startNetworkMonitoring(settings);
      }
    } catch (error) {
      state = state.copyWith(
        message: _runtimeError(RuntimeMessageCode.startupUpdateFailed, error),
      );
    }
  }

  Future<void> _reloadLocal() async {
    state = state.copyWith(
      profiles: await _listProfiles(),
      localDevices: await profileStore.listDevices(),
    );
  }

  Future<List<ConnectionProfile>> _listProfiles() async {
    final standalone = await standaloneProfileStore.list();
    final managed = await profileStore.listProfiles();
    return <ConnectionProfile>[...standalone, ...managed];
  }

  Future<void> _createEngine(AppSettings settings) async {
    await _connectionSubscription?.cancel();
    await _trafficSubscription?.cancel();
    await _logSubscription?.cancel();
    await _engine?.dispose();
    final support = await getApplicationSupportDirectory();
    final platform = const WindowsPlatformVpnService();
    final process = ProcessManager(logger);
    final configManager = ConfigManager(
      supportDirectory: support,
      builder: MihomoConfigBuilder(),
    );
    await configManager.clearStale();
    final engine = ConnectionSupervisor(
      binary: BinaryManager(
        supportDirectory: support,
        source: const FlutterAssetMihomoBinarySource(),
        expectedSha256: _coreSha256,
      ),
      config: configManager,
      process: process,
      platform: platform,
      health: HealthChecker(process: process, platform: platform),
      settings: settings,
    );
    _engine = engine;
    _connectionSubscription = engine.states.listen((connection) {
      state = state.copyWith(connection: connection);
      if (connection case Connected(:final since)) {
        _lastConnectedSince = since;
        _suspendedProfileId = null;
        unawaited(refreshClashData());
      } else if (connection is Disconnected ||
          connection is ConnectionFailure) {
        _lastConnectedSince = null;
        state = state.copyWith(
          traffic: null,
          delay: null,
          delayTestStatus: DelayTestStatus.idle,
          proxyGroups: const <ProxyGroupState>[],
          proxyProviders: const <ProxyProviderState>[],
          ruleProviders: const <RuleProviderState>[],
          proxyDelays: const <String, int>{},
          delayTesting: false,
          rules: const <ClashRuleEntry>[],
          connectionSnapshot: null,
          coreLogs: const <CoreLogEntry>[],
          coreMode: '',
          activeProfileId: null,
        );
      }
    });
    _trafficSubscription = engine.traffic.listen(
      (traffic) => state = state.copyWith(traffic: traffic),
    );
    _logSubscription = engine.logs.listen((entry) {
      final logs = <CoreLogEntry>[entry, ...state.coreLogs];
      state = state.copyWith(
        coreLogs: logs.length > 500 ? logs.sublist(0, 500) : logs,
      );
    });
  }

  TwoSuiHttpClient _connector(Uri url) {
    return TwoSuiHttpClient(baseUrl: url, logger: logger);
  }

  String _panelIdFor(Uri url, String username) {
    final digest = sha256.convert(utf8.encode('$url\n$username')).toString();
    return 'panel-${digest.substring(0, 16)}';
  }

  InboundPreference _preference() {
    return switch (state.settings.protocol) {
      'vlessReality' => InboundPreference.vlessReality,
      'hysteria2' => InboundPreference.hysteria2,
      _ => InboundPreference.automatic,
    };
  }

  RuntimeMessage _runtimeError(RuntimeMessageCode code, Object error) =>
      RuntimeMessage.fromError(code, error);

  @override
  void dispose() {
    _subscriptionRefreshTimer?.cancel();
    _networkRecoveryTimer?.cancel();
    unawaited(_networkSubscription?.cancel());
    unawaited(_networkMonitor?.dispose());
    unawaited(_systemPowerSubscription?.cancel());
    unawaited(_systemPowerMonitor?.dispose());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_trafficSubscription?.cancel());
    unawaited(_logSubscription?.cancel());
    unawaited(_engine?.dispose());
    super.dispose();
  }
}

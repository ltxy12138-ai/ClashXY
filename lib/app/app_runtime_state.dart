import '../models/app_settings.dart';
import '../models/clash_models.dart';
import '../models/connection_models.dart';
import '../models/device_models.dart';
import '../models/panel_models.dart';
import '../models/profile_models.dart';
import 'app_runtime_message.dart';

enum AppStage { booting, onboarding, ready }

enum DelayTestStatus { idle, testing, success, failed }

enum CoreUpdateApplyStage { downloading, installing, rollingBack }

enum CoreUpdateFailureReason {
  checkFailed,
  applyFailed,
  rollbackFailed,
  disconnectRequired,
}

sealed class CoreUpdateState {
  const CoreUpdateState({
    required this.currentVersion,
    required this.canRollback,
  });

  final String currentVersion;
  final bool canRollback;

  bool get busy => this is CoreUpdateChecking || this is CoreUpdateApplying;
}

final class CoreUpdateIdle extends CoreUpdateState {
  const CoreUpdateIdle({super.currentVersion = '', super.canRollback = false});
}

final class CoreUpdateChecking extends CoreUpdateState {
  const CoreUpdateChecking({
    required super.currentVersion,
    required super.canRollback,
  });
}

final class CoreUpdateAvailable extends CoreUpdateState {
  const CoreUpdateAvailable({
    required super.currentVersion,
    required super.canRollback,
    required this.latestVersion,
  });

  final String latestVersion;
}

final class CoreUpdateCurrent extends CoreUpdateState {
  const CoreUpdateCurrent({
    required super.currentVersion,
    required super.canRollback,
  });
}

final class CoreUpdateApplying extends CoreUpdateState {
  const CoreUpdateApplying({
    required super.currentVersion,
    required super.canRollback,
    required this.targetVersion,
    required this.stage,
  });

  final String targetVersion;
  final CoreUpdateApplyStage stage;
}

final class CoreUpdateSucceeded extends CoreUpdateState {
  const CoreUpdateSucceeded({
    required super.currentVersion,
    required super.canRollback,
    required this.rolledBack,
  });

  final bool rolledBack;
}

final class CoreUpdateFailed extends CoreUpdateState {
  const CoreUpdateFailed({
    required super.currentVersion,
    required super.canRollback,
    required this.reason,
  });

  final CoreUpdateFailureReason reason;
}

class AppRuntimeState {
  const AppRuntimeState({
    this.stage = AppStage.booting,
    this.busy = false,
    this.needsTwoFactor = false,
    this.message,
    this.panel,
    this.profiles = const <ConnectionProfile>[],
    this.localDevices = const <LocalDevice>[],
    this.remoteDevices = const <RemoteClient>[],
    this.onlineDevices = const <OnlineClient>[],
    this.connection = const Disconnected(),
    this.traffic,
    this.delay,
    this.delayTestStatus = DelayTestStatus.idle,
    this.serverStatus,
    this.serverTraffic,
    this.proxyGroups = const <ProxyGroupState>[],
    this.proxyProviders = const <ProxyProviderState>[],
    this.ruleProviders = const <RuleProviderState>[],
    this.proxyDelays = const <String, int>{},
    this.delayTesting = false,
    this.rules = const <ClashRuleEntry>[],
    this.connectionSnapshot,
    this.coreLogs = const <CoreLogEntry>[],
    this.coreMode = '',
    this.activeProfileId,
    this.settings = const AppSettings(),
    this.coreUpdate = const CoreUpdateIdle(),
  });

  final AppStage stage;
  final bool busy;
  final bool needsTwoFactor;
  final RuntimeMessage? message;
  final PanelAccount? panel;
  final List<ConnectionProfile> profiles;
  final List<LocalDevice> localDevices;
  final List<RemoteClient> remoteDevices;
  final List<OnlineClient> onlineDevices;
  final AppConnectionState connection;
  final TrafficSample? traffic;
  final DelayResult? delay;
  final DelayTestStatus delayTestStatus;
  final ServerStatus? serverStatus;
  final TrafficStats? serverTraffic;
  final List<ProxyGroupState> proxyGroups;
  final List<ProxyProviderState> proxyProviders;
  final List<RuleProviderState> ruleProviders;
  final Map<String, int> proxyDelays;
  final bool delayTesting;
  final List<ClashRuleEntry> rules;
  final ConnectionSnapshot? connectionSnapshot;
  final List<CoreLogEntry> coreLogs;
  final String coreMode;
  final String? activeProfileId;
  final AppSettings settings;
  final CoreUpdateState coreUpdate;

  AppRuntimeState copyWith({
    AppStage? stage,
    bool? busy,
    bool? needsTwoFactor,
    Object? message = _unset,
    Object? panel = _unset,
    List<ConnectionProfile>? profiles,
    List<LocalDevice>? localDevices,
    List<RemoteClient>? remoteDevices,
    List<OnlineClient>? onlineDevices,
    AppConnectionState? connection,
    Object? traffic = _unset,
    Object? delay = _unset,
    DelayTestStatus? delayTestStatus,
    Object? serverStatus = _unset,
    Object? serverTraffic = _unset,
    List<ProxyGroupState>? proxyGroups,
    List<ProxyProviderState>? proxyProviders,
    List<RuleProviderState>? ruleProviders,
    Map<String, int>? proxyDelays,
    bool? delayTesting,
    List<ClashRuleEntry>? rules,
    Object? connectionSnapshot = _unset,
    List<CoreLogEntry>? coreLogs,
    String? coreMode,
    Object? activeProfileId = _unset,
    AppSettings? settings,
    CoreUpdateState? coreUpdate,
  }) {
    return AppRuntimeState(
      stage: stage ?? this.stage,
      busy: busy ?? this.busy,
      needsTwoFactor: needsTwoFactor ?? this.needsTwoFactor,
      message: identical(message, _unset)
          ? this.message
          : message as RuntimeMessage?,
      panel: identical(panel, _unset) ? this.panel : panel as PanelAccount?,
      profiles: profiles ?? this.profiles,
      localDevices: localDevices ?? this.localDevices,
      remoteDevices: remoteDevices ?? this.remoteDevices,
      onlineDevices: onlineDevices ?? this.onlineDevices,
      connection: connection ?? this.connection,
      traffic: identical(traffic, _unset)
          ? this.traffic
          : traffic as TrafficSample?,
      delay: identical(delay, _unset) ? this.delay : delay as DelayResult?,
      delayTestStatus: delayTestStatus ?? this.delayTestStatus,
      serverStatus: identical(serverStatus, _unset)
          ? this.serverStatus
          : serverStatus as ServerStatus?,
      serverTraffic: identical(serverTraffic, _unset)
          ? this.serverTraffic
          : serverTraffic as TrafficStats?,
      proxyGroups: proxyGroups ?? this.proxyGroups,
      proxyProviders: proxyProviders ?? this.proxyProviders,
      ruleProviders: ruleProviders ?? this.ruleProviders,
      proxyDelays: proxyDelays ?? this.proxyDelays,
      delayTesting: delayTesting ?? this.delayTesting,
      rules: rules ?? this.rules,
      connectionSnapshot: identical(connectionSnapshot, _unset)
          ? this.connectionSnapshot
          : connectionSnapshot as ConnectionSnapshot?,
      coreLogs: coreLogs ?? this.coreLogs,
      coreMode: coreMode ?? this.coreMode,
      activeProfileId: identical(activeProfileId, _unset)
          ? this.activeProfileId
          : activeProfileId as String?,
      settings: settings ?? this.settings,
      coreUpdate: coreUpdate ?? this.coreUpdate,
    );
  }
}

const Object _unset = Object();

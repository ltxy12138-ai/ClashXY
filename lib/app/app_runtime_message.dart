import 'package:clashxy/l10n/app_localizations.dart';

import '../core/errors/app_exception.dart';

enum RuntimeMessageCode {
  tokenMissing,
  initializationFailed,
  downloadingSubscription,
  subscriptionAdded,
  subscriptionAddFailed,
  importFailed,
  localImported,
  customSaved,
  updatingSubscription,
  subscriptionUpdated,
  subscriptionUpdateFailed,
  profileUpdated,
  profileUpdateFailed,
  panelReachable,
  panelUnexpected,
  panelTestFailed,
  twoFactorRequired,
  panelConnected,
  panelConnectFailed,
  panelAlreadyConnected,
  panelSessionInvalid,
  panelDisconnected,
  panelDisconnectFailed,
  panelTokenIdMissing,
  panelTokenRevoked,
  panelTokenRevokeFailed,
  connectPanelFirst,
  creatingDevice,
  deviceCreatedConnecting,
  deviceCreateFailed,
  addProfileFirst,
  connectFailed,
  noDelayProxy,
  delayTestFailed,
  refreshClashFailed,
  refreshConnectionsFailed,
  switchProxyFailed,
  testingAll,
  testNoResults,
  testComplete,
  updatingProvider,
  providerUpdated,
  providerUpdateFailed,
  closeConnectionFailed,
  closeAllFailed,
  switchModeFailed,
  refreshPanelFailed,
  deletingProfile,
  profileDeleted,
  detachedPanelProfileDeleted,
  deleteProfileFailed,
  deletingDevice,
  deviceDeleted,
  deleteDeviceFailed,
  startupUpdateFailed,
  yamlUpdated,
  updatingRuleProvider,
  ruleProviderUpdated,
  ruleProviderUpdateFailed,
}

class RuntimeMessage {
  const RuntimeMessage(this.code, {this.detail});

  factory RuntimeMessage.fromError(RuntimeMessageCode code, Object error) {
    return RuntimeMessage(
      code,
      detail: error is AppException ? error.message : null,
    );
  }

  final RuntimeMessageCode code;
  final String? detail;

  String resolve(AppLocalizations l10n) {
    final message = switch (code) {
      RuntimeMessageCode.tokenMissing => l10n.runtimeTokenMissing,
      RuntimeMessageCode.initializationFailed =>
        l10n.runtimeInitializationFailed,
      RuntimeMessageCode.downloadingSubscription =>
        l10n.runtimeDownloadingSubscription,
      RuntimeMessageCode.subscriptionAdded => l10n.runtimeSubscriptionAdded,
      RuntimeMessageCode.subscriptionAddFailed =>
        l10n.runtimeSubscriptionAddFailed,
      RuntimeMessageCode.importFailed => l10n.runtimeImportFailed,
      RuntimeMessageCode.localImported => l10n.runtimeLocalImported,
      RuntimeMessageCode.customSaved => l10n.runtimeCustomSaved,
      RuntimeMessageCode.updatingSubscription =>
        l10n.runtimeUpdatingSubscription,
      RuntimeMessageCode.subscriptionUpdated => l10n.runtimeSubscriptionUpdated,
      RuntimeMessageCode.subscriptionUpdateFailed =>
        l10n.runtimeSubscriptionUpdateFailed,
      RuntimeMessageCode.profileUpdated => l10n.runtimeProfileUpdated,
      RuntimeMessageCode.profileUpdateFailed => l10n.runtimeProfileUpdateFailed,
      RuntimeMessageCode.panelReachable => l10n.runtimePanelReachable,
      RuntimeMessageCode.panelUnexpected => l10n.runtimePanelUnexpected,
      RuntimeMessageCode.panelTestFailed => l10n.runtimePanelTestFailed,
      RuntimeMessageCode.twoFactorRequired => l10n.runtimeTwoFactorRequired,
      RuntimeMessageCode.panelConnected => l10n.runtimePanelConnected,
      RuntimeMessageCode.panelConnectFailed => l10n.runtimePanelConnectFailed,
      RuntimeMessageCode.panelAlreadyConnected =>
        l10n.runtimePanelAlreadyConnected,
      RuntimeMessageCode.panelSessionInvalid => l10n.runtimePanelSessionInvalid,
      RuntimeMessageCode.panelDisconnected => l10n.runtimePanelDisconnected,
      RuntimeMessageCode.panelDisconnectFailed =>
        l10n.runtimePanelDisconnectFailed,
      RuntimeMessageCode.panelTokenIdMissing => l10n.runtimePanelTokenIdMissing,
      RuntimeMessageCode.panelTokenRevoked => l10n.runtimePanelTokenRevoked,
      RuntimeMessageCode.panelTokenRevokeFailed =>
        l10n.runtimePanelTokenRevokeFailed,
      RuntimeMessageCode.connectPanelFirst => l10n.runtimeConnectPanelFirst,
      RuntimeMessageCode.creatingDevice => l10n.runtimeCreatingDevice,
      RuntimeMessageCode.deviceCreatedConnecting =>
        l10n.runtimeDeviceCreatedConnecting,
      RuntimeMessageCode.deviceCreateFailed => l10n.runtimeDeviceCreateFailed,
      RuntimeMessageCode.addProfileFirst => l10n.runtimeAddProfileFirst,
      RuntimeMessageCode.connectFailed => l10n.runtimeConnectFailed,
      RuntimeMessageCode.noDelayProxy => l10n.runtimeNoDelayProxy,
      RuntimeMessageCode.delayTestFailed => l10n.runtimeDelayTestFailed,
      RuntimeMessageCode.refreshClashFailed => l10n.runtimeRefreshClashFailed,
      RuntimeMessageCode.refreshConnectionsFailed =>
        l10n.runtimeRefreshConnectionsFailed,
      RuntimeMessageCode.switchProxyFailed => l10n.runtimeSwitchProxyFailed,
      RuntimeMessageCode.testingAll => l10n.runtimeTestingAll,
      RuntimeMessageCode.testNoResults => l10n.runtimeTestNoResults,
      RuntimeMessageCode.testComplete => l10n.runtimeTestComplete,
      RuntimeMessageCode.updatingProvider => l10n.runtimeUpdatingProvider,
      RuntimeMessageCode.providerUpdated => l10n.runtimeProviderUpdated,
      RuntimeMessageCode.providerUpdateFailed =>
        l10n.runtimeProviderUpdateFailed,
      RuntimeMessageCode.closeConnectionFailed =>
        l10n.runtimeCloseConnectionFailed,
      RuntimeMessageCode.closeAllFailed => l10n.runtimeCloseAllFailed,
      RuntimeMessageCode.switchModeFailed => l10n.runtimeSwitchModeFailed,
      RuntimeMessageCode.refreshPanelFailed => l10n.runtimeRefreshPanelFailed,
      RuntimeMessageCode.deletingProfile => l10n.runtimeDeletingProfile,
      RuntimeMessageCode.profileDeleted => l10n.runtimeProfileDeleted,
      RuntimeMessageCode.detachedPanelProfileDeleted =>
        l10n.runtimeDetachedPanelProfileDeleted,
      RuntimeMessageCode.deleteProfileFailed => l10n.runtimeDeleteProfileFailed,
      RuntimeMessageCode.deletingDevice => l10n.runtimeDeletingDevice,
      RuntimeMessageCode.deviceDeleted => l10n.runtimeDeviceDeleted,
      RuntimeMessageCode.deleteDeviceFailed => l10n.runtimeDeleteDeviceFailed,
      RuntimeMessageCode.startupUpdateFailed => l10n.runtimeStartupUpdateFailed,
      RuntimeMessageCode.yamlUpdated => l10n.runtimeYamlUpdated,
      RuntimeMessageCode.updatingRuleProvider =>
        l10n.runtimeUpdatingRuleProvider,
      RuntimeMessageCode.ruleProviderUpdated => l10n.runtimeRuleProviderUpdated,
      RuntimeMessageCode.ruleProviderUpdateFailed =>
        l10n.runtimeRuleProviderUpdateFailed,
    };
    final technicalDetail = detail?.trim();
    if (technicalDetail == null || technicalDetail.isEmpty) return message;
    if (l10n.localeName.startsWith('en') &&
        RegExp(r'[\u3400-\u9fff]').hasMatch(technicalDetail)) {
      return message;
    }
    return '$message\n${l10n.runtimeTechnicalDetail(technicalDetail)}';
  }
}

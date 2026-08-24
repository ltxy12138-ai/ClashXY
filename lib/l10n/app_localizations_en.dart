// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get appTitle => 'ClashXY';

  @override
  String get systemLanguage => 'Follow system';

  @override
  String get language => 'Language';

  @override
  String get navHome => 'Home';

  @override
  String get navProxies => 'Proxies';

  @override
  String get navProfiles => 'Profiles';

  @override
  String get navConnections => 'Connections';

  @override
  String get navDevices => '2S-UI';

  @override
  String get navSettings => 'Settings';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get export => 'Export';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get refresh => 'Refresh';

  @override
  String get back => 'Back';

  @override
  String get unknown => 'Unknown';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get disabled => 'Disabled';

  @override
  String get homeNoProfiles => 'No profile added';

  @override
  String homeProfilesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles available',
      one: '1 profile available',
    );
    return '$_temp0';
  }

  @override
  String get connectionDisconnected => 'Disconnected';

  @override
  String get connectionConnecting => 'Connecting…';

  @override
  String get connectionConnected => 'Connected';

  @override
  String get connectionWaitingNetwork => 'Waiting for network';

  @override
  String connectionReconnecting(int attempt) {
    return 'Reconnecting · attempt $attempt';
  }

  @override
  String get connectionStopping => 'Disconnecting…';

  @override
  String connectionError(String message) {
    return 'Error · $message';
  }

  @override
  String get connectionErrorGeneric => 'Connection error';

  @override
  String get addProfile => 'Add profile';

  @override
  String get uploadSpeed => 'Upload speed';

  @override
  String get downloadSpeed => 'Download speed';

  @override
  String get proxyDelay => 'Proxy delay';

  @override
  String get delayTesting => 'Testing…';

  @override
  String get delayFailed => 'Test failed';

  @override
  String get setupFirstProfile => 'Add your first profile';

  @override
  String get setupIntro =>
      'ClashXY is a full Mihomo / Clash client. Use a subscription or YAML directly; 2S-UI management is optional.';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get subscriptionSubtitle =>
      'Use an HTTPS Clash / Mihomo subscription URL';

  @override
  String get importLocalConfig => 'Import local profile';

  @override
  String get importLocalSubtitle => 'Select a .yaml or .yml file';

  @override
  String get customYaml => 'Custom YAML';

  @override
  String get customYamlSubtitle =>
      'Paste and save a complete Clash / Mihomo profile';

  @override
  String get connectTwoSuiOptional => 'Connect 2S-UI (optional)';

  @override
  String get connectTwoSuiSubtitle =>
      'Sign in to a panel, provision devices, and manage remote clients';

  @override
  String get connectPanelTitle => 'Connect to 2S-UI panel';

  @override
  String get connectPanelSecurity =>
      'HTTPS only. The administrator password is used only to create a dedicated API token and is never stored.';

  @override
  String get panelAddress => 'Panel URL';

  @override
  String get panelAddressValidation => 'Enter an HTTPS panel URL.';

  @override
  String get username => 'Username';

  @override
  String get usernameValidation => 'Enter the username.';

  @override
  String get password => 'Password';

  @override
  String get passwordValidation => 'Enter the password.';

  @override
  String get twoFactorCode => 'Two-factor code';

  @override
  String get testConnection => 'Test connection';

  @override
  String get fileReadFailed => 'Could not read the selected profile file.';

  @override
  String get subscriptionName => 'Profile name';

  @override
  String get profileNameValidation => 'Enter a profile name.';

  @override
  String get subscriptionNameHint => 'My subscription';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get subscriptionUrlValidation =>
      'Enter a valid HTTPS subscription URL.';

  @override
  String get subscriptionUrlNoCredentials =>
      'Enter an HTTPS URL without URL credentials.';

  @override
  String get customProfileNameHint => 'My profile';

  @override
  String get yamlContent => 'YAML content';

  @override
  String get yamlEmptyValidation => 'Profile content cannot be empty.';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesIntro =>
      'Subscriptions, local YAML, custom profiles, and 2S-UI profiles can be used together.';

  @override
  String get noProfiles => 'No profiles are available yet.';

  @override
  String get addFirstProfile => 'Add first profile';

  @override
  String get twoSuiNotConnected => '2S-UI is not connected';

  @override
  String get twoSuiManagementOptional => '2S-UI management (optional)';

  @override
  String get twoSuiNotRequired =>
      'Subscriptions and custom profiles continue to work without it.';

  @override
  String get connectPanel => 'Connect panel';

  @override
  String get refreshPanelStatus => 'Refresh panel status';

  @override
  String get panelAccount => 'Panel account';

  @override
  String signedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get managePanelAccount => 'Manage account';

  @override
  String get disconnectPanelTitle => 'Disconnect this panel?';

  @override
  String get disconnectPanelBody =>
      'Existing 2S-UI VPN profiles remain available locally. Remote clients are not deleted. You can connect a different panel afterward.';

  @override
  String get disconnectLocally => 'Disconnect locally';

  @override
  String get disconnectLocallySubtitle =>
      'Remove the token from this PC but leave it active in 2S-UI.';

  @override
  String get revokeAndDisconnect => 'Revoke token and disconnect';

  @override
  String get revokeAndDisconnectSubtitle =>
      'Sign in once with the administrator password, revoke this app\'s token, then remove it locally.';

  @override
  String get tokenRevokeUnavailable =>
      'This account was saved by an older app version, so its token ID is unavailable. Disconnect it locally, then remove the old token in 2S-UI.';

  @override
  String get reauthenticatePanel => 'Confirm panel administrator';

  @override
  String get reauthenticatePanelBody =>
      'The password and two-factor code are used only for this revocation request and are not stored.';

  @override
  String get revokeToken => 'Revoke token';

  @override
  String get version => 'Version';

  @override
  String get uptime => 'Uptime';

  @override
  String seconds(int count) {
    return '$count s';
  }

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String get addProfileTitle => 'Add profile';

  @override
  String get deleteManagedTitle => 'Delete 2S-UI device?';

  @override
  String get deleteProfileTitle => 'Delete profile?';

  @override
  String get deleteManagedBody =>
      'The VPN will disconnect. The remote 2S-UI client and local secure profile will both be deleted.';

  @override
  String get deleteDetachedManagedBody =>
      'This panel is not connected. Only the local secure profile will be deleted; the remote 2S-UI client will not be changed.';

  @override
  String get deleteProfileBody =>
      'The local profile and its secure data will be deleted. The subscription service is not changed.';

  @override
  String get currentProfile => 'Active';

  @override
  String get updateSubscription => 'Update subscription';

  @override
  String get activeProfileTooltip => 'This profile is active';

  @override
  String get connectProfileTooltip => 'Connect this profile';

  @override
  String get moreActions => 'More actions';

  @override
  String get exportProfile => 'Export profile';

  @override
  String get profileOriginSubscription => 'Subscription';

  @override
  String get profileOriginLocal => 'Local YAML';

  @override
  String get profileOriginCustom => 'Custom YAML';

  @override
  String get profileOriginTwoSui => '2S-UI';

  @override
  String proxyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count proxies',
      one: '1 proxy',
    );
    return '$_temp0';
  }

  @override
  String nodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
    );
    return '$_temp0';
  }

  @override
  String providerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count proxy providers',
      one: '1 proxy provider',
    );
    return '$_temp0';
  }

  @override
  String autoUpdateValue(String interval) {
    return 'Auto update: $interval';
  }

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get editProfile => 'Edit profile';

  @override
  String get editAdvancedYaml => 'Edit advanced YAML';

  @override
  String get editAdvancedYamlSubtitle =>
      'All Clash / Mihomo keys are supported. Local controller, port, TUN, and security boundaries are applied when connecting.';

  @override
  String get subscriptionYamlRefreshWarning =>
      'Refreshing this subscription will replace manual YAML changes.';

  @override
  String get autoUpdate => 'Automatic update';

  @override
  String get manualUpdate => 'Manual update';

  @override
  String everyHours(int hours) {
    return 'Every $hours hours';
  }

  @override
  String get everyDay => 'Daily';

  @override
  String everyDays(int days) {
    return 'Every $days days';
  }

  @override
  String get everyWeek => 'Weekly';

  @override
  String get profileChangesNextConnect =>
      'Changes to a running profile take effect on the next connection.';

  @override
  String createdAt(String time) {
    return 'Created: $time';
  }

  @override
  String contentUpdatedAt(String time) {
    return 'Content updated: $time';
  }

  @override
  String get exportSensitiveTitle => 'Export sensitive profile?';

  @override
  String get exportSensitiveBody =>
      'The exported YAML may contain subscription URLs, server addresses, UUIDs, and passwords. Store it securely and do not publish it.';

  @override
  String get understandAndExport => 'I understand, export';

  @override
  String get yamlProfileFile => 'YAML profile';

  @override
  String get proxiesTitle => 'Proxies';

  @override
  String get refreshProxyGroups => 'Refresh proxy groups';

  @override
  String get runMode => 'Mode';

  @override
  String get modeRule => 'Rule';

  @override
  String get modeGlobal => 'Global';

  @override
  String get modeDirect => 'Direct';

  @override
  String get proxyProviders => 'Proxy providers';

  @override
  String get ruleProviders => 'Rule providers';

  @override
  String ruleProviderSummary(String behavior, String vehicle, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$behavior · $vehicle · $_temp0';
  }

  @override
  String get updateRuleProvider => 'Update rule provider';

  @override
  String get searchNodes => 'Search nodes';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get sortByDelay => 'Sort by delay';

  @override
  String get testingNodes => 'Testing node delays concurrently…';

  @override
  String get connectToViewProxies =>
      'Connect a profile to view proxy groups and switch nodes.';

  @override
  String get noSelectableGroups =>
      'The current profile has no selectable proxy groups.';

  @override
  String get updateProvider => 'Update provider';

  @override
  String providerUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String providerVehicle(String vehicle) {
    return 'Type: $vehicle';
  }

  @override
  String quotaUsed(String used, String total) {
    return 'Used $used / $total';
  }

  @override
  String expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String get noMatchingNodes => 'No matching nodes';

  @override
  String get selectNode => 'Select node';

  @override
  String groupOptions(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return '$type · $_temp0';
  }

  @override
  String get testCurrentNode => 'Test current node delay';

  @override
  String get testGroup => 'Test this group';

  @override
  String get connectionsTitle => 'Runtime details';

  @override
  String get refreshRuntime => 'Refresh all runtime data';

  @override
  String get tabConnections => 'Active connections';

  @override
  String get tabRules => 'Rules';

  @override
  String get tabLogs => 'Logs';

  @override
  String get connectToViewRuntime =>
      'Connect a profile to view runtime details.';

  @override
  String connectionSummary(int count, String upload, String download) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active connections',
      one: '1 active connection',
    );
    return '$_temp0 · Upload $upload · Download $download';
  }

  @override
  String get refreshEveryTwoSeconds => 'Refresh every 2 seconds';

  @override
  String get closeAll => 'Close all';

  @override
  String get searchConnections =>
      'Search host, destination, network, or proxy chain';

  @override
  String get noActiveConnections => 'No active connections.';

  @override
  String get noMatchingConnections => 'No matching connections.';

  @override
  String get closeConnection => 'Close connection';

  @override
  String get searchRules => 'Search rule type, content, or policy';

  @override
  String get noRules => 'The current profile returned no rules.';

  @override
  String get noMatchingRules => 'No matching rules.';

  @override
  String get searchLogs => 'Search logs';

  @override
  String get allLevels => 'All levels';

  @override
  String get clearLogs => 'Clear in-memory logs';

  @override
  String get noLogs => 'No core logs yet.';

  @override
  String get noMatchingLogs => 'No matching logs.';

  @override
  String get devicesTitle => '2S-UI devices';

  @override
  String get localDevices => 'This device';

  @override
  String get noPanelConnected => 'No 2S-UI panel is connected.';

  @override
  String get noLocalDevices => 'No local 2S-UI device profile exists yet.';

  @override
  String get connectTwoSui => 'Connect 2S-UI';

  @override
  String get createLocalDevice => 'Create local device';

  @override
  String get deviceDisplayName => 'Device display name';

  @override
  String get deviceDisplayNameHint => 'For example: Shanghai office PC';

  @override
  String get deviceDisplayNameValidation => 'Enter a device display name.';

  @override
  String get machineIdentityNote =>
      'ClashXY generates a separate stable machine ID for 2S-UI compatibility. Renaming this label will not change that identity.';

  @override
  String get remoteClients => 'Remote clients';

  @override
  String get noRemoteClients => 'The panel returned no remote clients.';

  @override
  String clientNumber(int id) {
    return 'Client #$id';
  }

  @override
  String get deleteDeviceTitle => 'Delete this device?';

  @override
  String get deleteDeviceBody =>
      'The VPN will disconnect. The remote 2S-UI client and local secure profile will both be deleted.';

  @override
  String get deleteDeviceTooltip => 'Delete device';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get startup => 'Start with Windows';

  @override
  String get startupPending =>
      'Open ClashXY automatically after you sign in to Windows.';

  @override
  String get autoConnect => 'Auto connect';

  @override
  String get autoConnectSubtitle =>
      'Connect the first profile after the app starts.';

  @override
  String get newDeviceProtocol => 'Protocol for new 2S-UI devices';

  @override
  String get newDeviceProtocolSubtitle =>
      'Used only when the next 2S-UI device is created.';

  @override
  String get automatic => 'Automatic';

  @override
  String get windowsTun => 'Windows TUN';

  @override
  String get windowsTunSubtitle =>
      'Route system traffic through Mihomo. Administrator access is required.';

  @override
  String get coreLogs => 'Core logs';

  @override
  String get coreLogsSubtitle =>
      'Sensitive information is redacted before logs are written.';

  @override
  String get settingsNextConnect =>
      'Connection settings take effect the next time you connect.';

  @override
  String get advancedSettings => 'Advanced Clash settings';

  @override
  String get advancedSettingsSubtitle =>
      'Local safety boundaries still keep the controller and DNS listener on loopback.';

  @override
  String get mixedPort => 'Mixed proxy port';

  @override
  String get controllerPort => 'Controller port';

  @override
  String get validPort => 'Enter a port from 1024 to 65535.';

  @override
  String get portMustDiffer =>
      'This port must differ from the other local ports.';

  @override
  String get allowLan => 'Allow LAN connections';

  @override
  String get allowLanWarning =>
      'Exposes the mixed proxy port to the local network. Imported authentication is kept when present.';

  @override
  String get tunStack => 'TUN stack';

  @override
  String get tunStackMixed => 'Mixed';

  @override
  String get tunStackSystem => 'System';

  @override
  String get tunStackGvisor => 'gVisor';

  @override
  String get tunMtu => 'TUN MTU';

  @override
  String get validMtu => 'Enter an MTU from 1280 to 9000.';

  @override
  String get tunStrictRoute => 'Strict route';

  @override
  String get tunAutoRoute => 'Automatic route';

  @override
  String get tunAutoDetect => 'Auto-detect interface';

  @override
  String get tunDeviceName => 'TUN device name';

  @override
  String get valueCannotBeEmpty => 'This value cannot be empty.';

  @override
  String get dnsOverride => 'Override profile DNS';

  @override
  String get dnsOverrideSubtitle =>
      'When off, imported DNS settings are preserved with a loopback listener.';

  @override
  String get dnsEnabled => 'Enable built-in DNS';

  @override
  String get dnsMode => 'Enhanced DNS mode';

  @override
  String get dnsModeFakeIp => 'Fake IP';

  @override
  String get dnsModeRedirHost => 'Redir host';

  @override
  String get dnsListenPort => 'DNS listen port';

  @override
  String get dnsNameserver => 'Primary nameserver';

  @override
  String get snifferOverride => 'Override profile sniffer';

  @override
  String get snifferOverrideSubtitle =>
      'Apply the following sniffer switch instead of the imported setting.';

  @override
  String get snifferEnabled => 'Enable protocol sniffer';

  @override
  String get coreUpdateTitle => 'Mihomo Core update';

  @override
  String get coreUpdateSubtitle =>
      'Checks the official stable MetaCubeX/mihomo Windows x64 compatible release.';

  @override
  String coreCurrentVersion(String version) {
    return 'Installed version: $version';
  }

  @override
  String get coreVersionUnknown => 'unknown';

  @override
  String get coreUpdateIdle =>
      'Check for a verified Core update when you are ready.';

  @override
  String get coreCheckForUpdates => 'Check for updates';

  @override
  String get coreChecking => 'Checking the official release…';

  @override
  String coreUpdateAvailable(String version) {
    return 'Verified version $version is available.';
  }

  @override
  String get coreUpToDate => 'The installed Core is up to date.';

  @override
  String get coreDownloadInstall => 'Download and install';

  @override
  String coreDownloading(String version) {
    return 'Downloading verified version $version…';
  }

  @override
  String coreInstalling(String version) {
    return 'Validating and switching to version $version…';
  }

  @override
  String coreUpdateSucceeded(String version) {
    return 'Core version $version was installed. The previous version is available for rollback.';
  }

  @override
  String get coreRollback => 'Roll back';

  @override
  String get coreRollingBack => 'Validating and restoring the previous Core…';

  @override
  String coreRollbackSucceeded(String version) {
    return 'Rolled back to Core version $version.';
  }

  @override
  String get coreUpdateCheckFailed =>
      'Could not check the official Mihomo release.';

  @override
  String get coreUpdateApplyFailed =>
      'Core update failed. The installed version was preserved or restored.';

  @override
  String get coreRollbackFailed =>
      'Core rollback failed. The installed version was preserved.';

  @override
  String get coreUpdateDisconnectRequired =>
      'Disconnect the VPN before installing or rolling back the Core.';

  @override
  String get coreUpdateSecurityNote =>
      'Only HTTPS release metadata and assets with an official SHA-256 digest are accepted. Switching is staged and retains one verified previous version.';

  @override
  String get runtimeTokenMissing =>
      'The saved 2S-UI token is missing. Sign in to the panel again.';

  @override
  String get runtimeInitializationFailed => 'Could not initialize ClashXY.';

  @override
  String get runtimeDownloadingSubscription => 'Downloading subscription…';

  @override
  String get runtimeSubscriptionAdded => 'Subscription added.';

  @override
  String get runtimeSubscriptionAddFailed => 'Could not add subscription.';

  @override
  String get runtimeImportFailed => 'Could not import profile.';

  @override
  String get runtimeLocalImported => 'Local profile imported.';

  @override
  String get runtimeCustomSaved => 'Custom profile saved.';

  @override
  String get runtimeUpdatingSubscription => 'Updating subscription…';

  @override
  String get runtimeSubscriptionUpdated => 'Subscription updated.';

  @override
  String get runtimeSubscriptionUpdateFailed =>
      'Could not update subscription.';

  @override
  String get runtimeProfileUpdated => 'Profile updated.';

  @override
  String get runtimeProfileUpdateFailed => 'Could not update profile.';

  @override
  String get runtimeYamlUpdated => 'Advanced YAML updated.';

  @override
  String get runtimePanelReachable => 'The HTTPS panel connection is working.';

  @override
  String get runtimePanelUnexpected =>
      'The panel returned an unexpected response.';

  @override
  String get runtimePanelTestFailed => 'Panel connection test failed.';

  @override
  String get runtimeTwoFactorRequired =>
      'Enter the current two-factor code to continue.';

  @override
  String get runtimePanelConnected =>
      'Panel connected. The administrator password was not saved.';

  @override
  String get runtimePanelConnectFailed => 'Could not connect to the panel.';

  @override
  String get runtimePanelAlreadyConnected =>
      'Disconnect the current 2S-UI panel before connecting another one.';

  @override
  String get runtimePanelSessionInvalid =>
      'The saved 2S-UI session is no longer valid. Disconnect it locally and sign in again.';

  @override
  String get runtimePanelDisconnected =>
      'The panel was disconnected locally. Existing VPN profiles remain available.';

  @override
  String get runtimePanelDisconnectFailed =>
      'Could not disconnect the panel locally.';

  @override
  String get runtimePanelTokenIdMissing =>
      'The saved token ID is unavailable. Disconnect locally and remove the old token in 2S-UI.';

  @override
  String get runtimePanelTokenRevoked =>
      'The app token was revoked and the panel was disconnected.';

  @override
  String get runtimePanelTokenRevokeFailed =>
      'Could not revoke the panel token.';

  @override
  String get runtimeConnectPanelFirst => 'Connect a 2S-UI panel first.';

  @override
  String get runtimeCreatingDevice => 'Creating local device…';

  @override
  String get runtimeDeviceCreatedConnecting => 'Device created. Connecting…';

  @override
  String get runtimeDeviceCreateFailed => 'Could not create the device.';

  @override
  String get runtimeAddProfileFirst => 'Add a profile first.';

  @override
  String get runtimeConnectFailed => 'Connection failed.';

  @override
  String get runtimeNoDelayProxy =>
      'The current profile has no proxy available for delay testing.';

  @override
  String get runtimeDelayTestFailed => 'Proxy delay test failed.';

  @override
  String get runtimeRefreshClashFailed =>
      'Could not refresh Mihomo runtime data.';

  @override
  String get runtimeRefreshConnectionsFailed =>
      'Could not refresh active connections.';

  @override
  String get runtimeSwitchProxyFailed => 'Could not switch proxy.';

  @override
  String get runtimeTestingAll => 'Testing all proxies…';

  @override
  String get runtimeTestNoResults =>
      'The delay test returned no available results.';

  @override
  String get runtimeTestComplete => 'Delay test complete.';

  @override
  String get runtimeUpdatingProvider => 'Updating proxy provider…';

  @override
  String get runtimeProviderUpdated => 'Proxy provider updated.';

  @override
  String get runtimeProviderUpdateFailed => 'Could not update proxy provider.';

  @override
  String get runtimeUpdatingRuleProvider => 'Updating rule provider…';

  @override
  String get runtimeRuleProviderUpdated => 'Rule provider updated.';

  @override
  String get runtimeRuleProviderUpdateFailed =>
      'Could not update rule provider.';

  @override
  String get runtimeCloseConnectionFailed => 'Could not close the connection.';

  @override
  String get runtimeCloseAllFailed => 'Could not close all connections.';

  @override
  String get runtimeSwitchModeFailed => 'Could not change the runtime mode.';

  @override
  String get runtimeRefreshPanelFailed => 'Could not refresh panel data.';

  @override
  String get runtimeDeletingProfile => 'Deleting profile…';

  @override
  String get runtimeProfileDeleted => 'Profile deleted.';

  @override
  String get runtimeDetachedPanelProfileDeleted =>
      'Local profile deleted. The remote 2S-UI client was not changed.';

  @override
  String get runtimeDeleteProfileFailed => 'Could not delete profile.';

  @override
  String get runtimeDeletingDevice => 'Deleting device…';

  @override
  String get runtimeDeviceDeleted => 'Device deleted.';

  @override
  String get runtimeDeleteDeviceFailed => 'Could not delete device.';

  @override
  String get runtimeStartupUpdateFailed =>
      'Could not update Windows startup registration.';

  @override
  String get trayShow => 'Show ClashXY';

  @override
  String get trayQuit => 'Quit ClashXY';

  @override
  String runtimeTechnicalDetail(String detail) {
    return 'Details: $detail';
  }
}

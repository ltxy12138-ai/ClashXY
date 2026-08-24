import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ClashXY'**
  String get appTitle;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get systemLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navProxies.
  ///
  /// In en, this message translates to:
  /// **'Proxies'**
  String get navProxies;

  /// No description provided for @navProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get navProfiles;

  /// No description provided for @navConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get navConnections;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'2S-UI'**
  String get navDevices;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @homeNoProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profile added'**
  String get homeNoProfiles;

  /// No description provided for @homeProfilesAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 profile available} other{{count} profiles available}}'**
  String homeProfilesAvailable(int count);

  /// No description provided for @connectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionDisconnected;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionConnecting;

  /// No description provided for @connectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionConnected;

  /// No description provided for @connectionWaitingNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for network'**
  String get connectionWaitingNetwork;

  /// No description provided for @connectionReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting · attempt {attempt}'**
  String connectionReconnecting(int attempt);

  /// No description provided for @connectionStopping.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get connectionStopping;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Error · {message}'**
  String connectionError(String message);

  /// No description provided for @connectionErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionErrorGeneric;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addProfile;

  /// No description provided for @uploadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Upload speed'**
  String get uploadSpeed;

  /// No description provided for @downloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Download speed'**
  String get downloadSpeed;

  /// No description provided for @proxyDelay.
  ///
  /// In en, this message translates to:
  /// **'Proxy delay'**
  String get proxyDelay;

  /// No description provided for @delayTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get delayTesting;

  /// No description provided for @delayFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get delayFailed;

  /// No description provided for @setupFirstProfile.
  ///
  /// In en, this message translates to:
  /// **'Add your first profile'**
  String get setupFirstProfile;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'ClashXY is a full Mihomo / Clash client. Use a subscription or YAML directly; 2S-UI management is optional.'**
  String get setupIntro;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// No description provided for @subscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use an HTTPS Clash / Mihomo subscription URL'**
  String get subscriptionSubtitle;

  /// No description provided for @importLocalConfig.
  ///
  /// In en, this message translates to:
  /// **'Import local profile'**
  String get importLocalConfig;

  /// No description provided for @importLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a .yaml or .yml file'**
  String get importLocalSubtitle;

  /// No description provided for @customYaml.
  ///
  /// In en, this message translates to:
  /// **'Custom YAML'**
  String get customYaml;

  /// No description provided for @customYamlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste and save a complete Clash / Mihomo profile'**
  String get customYamlSubtitle;

  /// No description provided for @connectTwoSuiOptional.
  ///
  /// In en, this message translates to:
  /// **'Connect 2S-UI (optional)'**
  String get connectTwoSuiOptional;

  /// No description provided for @connectTwoSuiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to a panel, provision devices, and manage remote clients'**
  String get connectTwoSuiSubtitle;

  /// No description provided for @connectPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to 2S-UI panel'**
  String get connectPanelTitle;

  /// No description provided for @connectPanelSecurity.
  ///
  /// In en, this message translates to:
  /// **'HTTPS only. The administrator password is used only to create a dedicated API token and is never stored.'**
  String get connectPanelSecurity;

  /// No description provided for @panelAddress.
  ///
  /// In en, this message translates to:
  /// **'Panel URL'**
  String get panelAddress;

  /// No description provided for @panelAddressValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS panel URL.'**
  String get panelAddressValidation;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter the username.'**
  String get usernameValidation;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter the password.'**
  String get passwordValidation;

  /// No description provided for @twoFactorCode.
  ///
  /// In en, this message translates to:
  /// **'Two-factor code'**
  String get twoFactorCode;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @fileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected profile file.'**
  String get fileReadFailed;

  /// No description provided for @subscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get subscriptionName;

  /// No description provided for @profileNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a profile name.'**
  String get profileNameValidation;

  /// No description provided for @subscriptionNameHint.
  ///
  /// In en, this message translates to:
  /// **'My subscription'**
  String get subscriptionNameHint;

  /// No description provided for @subscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subscriptionUrl;

  /// No description provided for @subscriptionUrlValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTPS subscription URL.'**
  String get subscriptionUrlValidation;

  /// No description provided for @subscriptionUrlNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS URL without URL credentials.'**
  String get subscriptionUrlNoCredentials;

  /// No description provided for @customProfileNameHint.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get customProfileNameHint;

  /// No description provided for @yamlContent.
  ///
  /// In en, this message translates to:
  /// **'YAML content'**
  String get yamlContent;

  /// No description provided for @yamlEmptyValidation.
  ///
  /// In en, this message translates to:
  /// **'Profile content cannot be empty.'**
  String get yamlEmptyValidation;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesTitle;

  /// No description provided for @profilesIntro.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions, local YAML, custom profiles, and 2S-UI profiles can be used together.'**
  String get profilesIntro;

  /// No description provided for @noProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profiles are available yet.'**
  String get noProfiles;

  /// No description provided for @addFirstProfile.
  ///
  /// In en, this message translates to:
  /// **'Add first profile'**
  String get addFirstProfile;

  /// No description provided for @twoSuiNotConnected.
  ///
  /// In en, this message translates to:
  /// **'2S-UI is not connected'**
  String get twoSuiNotConnected;

  /// No description provided for @twoSuiManagementOptional.
  ///
  /// In en, this message translates to:
  /// **'2S-UI management (optional)'**
  String get twoSuiManagementOptional;

  /// No description provided for @twoSuiNotRequired.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions and custom profiles continue to work without it.'**
  String get twoSuiNotRequired;

  /// No description provided for @connectPanel.
  ///
  /// In en, this message translates to:
  /// **'Connect panel'**
  String get connectPanel;

  /// No description provided for @refreshPanelStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh panel status'**
  String get refreshPanelStatus;

  /// No description provided for @panelAccount.
  ///
  /// In en, this message translates to:
  /// **'Panel account'**
  String get panelAccount;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String signedInAs(String username);

  /// No description provided for @managePanelAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage account'**
  String get managePanelAccount;

  /// No description provided for @disconnectPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect this panel?'**
  String get disconnectPanelTitle;

  /// No description provided for @disconnectPanelBody.
  ///
  /// In en, this message translates to:
  /// **'Existing 2S-UI VPN profiles remain available locally. Remote clients are not deleted. You can connect a different panel afterward.'**
  String get disconnectPanelBody;

  /// No description provided for @disconnectLocally.
  ///
  /// In en, this message translates to:
  /// **'Disconnect locally'**
  String get disconnectLocally;

  /// No description provided for @disconnectLocallySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the token from this PC but leave it active in 2S-UI.'**
  String get disconnectLocallySubtitle;

  /// No description provided for @revokeAndDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Revoke token and disconnect'**
  String get revokeAndDisconnect;

  /// No description provided for @revokeAndDisconnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in once with the administrator password, revoke this app\'s token, then remove it locally.'**
  String get revokeAndDisconnectSubtitle;

  /// No description provided for @tokenRevokeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This account was saved by an older app version, so its token ID is unavailable. Disconnect it locally, then remove the old token in 2S-UI.'**
  String get tokenRevokeUnavailable;

  /// No description provided for @reauthenticatePanel.
  ///
  /// In en, this message translates to:
  /// **'Confirm panel administrator'**
  String get reauthenticatePanel;

  /// No description provided for @reauthenticatePanelBody.
  ///
  /// In en, this message translates to:
  /// **'The password and two-factor code are used only for this revocation request and are not stored.'**
  String get reauthenticatePanelBody;

  /// No description provided for @revokeToken.
  ///
  /// In en, this message translates to:
  /// **'Revoke token'**
  String get revokeToken;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @uptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String seconds(int count);

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @addProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addProfileTitle;

  /// No description provided for @deleteManagedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete 2S-UI device?'**
  String get deleteManagedTitle;

  /// No description provided for @deleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete profile?'**
  String get deleteProfileTitle;

  /// No description provided for @deleteManagedBody.
  ///
  /// In en, this message translates to:
  /// **'The VPN will disconnect. The remote 2S-UI client and local secure profile will both be deleted.'**
  String get deleteManagedBody;

  /// No description provided for @deleteDetachedManagedBody.
  ///
  /// In en, this message translates to:
  /// **'This panel is not connected. Only the local secure profile will be deleted; the remote 2S-UI client will not be changed.'**
  String get deleteDetachedManagedBody;

  /// No description provided for @deleteProfileBody.
  ///
  /// In en, this message translates to:
  /// **'The local profile and its secure data will be deleted. The subscription service is not changed.'**
  String get deleteProfileBody;

  /// No description provided for @currentProfile.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get currentProfile;

  /// No description provided for @updateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Update subscription'**
  String get updateSubscription;

  /// No description provided for @activeProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'This profile is active'**
  String get activeProfileTooltip;

  /// No description provided for @connectProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connect this profile'**
  String get connectProfileTooltip;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @exportProfile.
  ///
  /// In en, this message translates to:
  /// **'Export profile'**
  String get exportProfile;

  /// No description provided for @profileOriginSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get profileOriginSubscription;

  /// No description provided for @profileOriginLocal.
  ///
  /// In en, this message translates to:
  /// **'Local YAML'**
  String get profileOriginLocal;

  /// No description provided for @profileOriginCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom YAML'**
  String get profileOriginCustom;

  /// No description provided for @profileOriginTwoSui.
  ///
  /// In en, this message translates to:
  /// **'2S-UI'**
  String get profileOriginTwoSui;

  /// No description provided for @proxyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 proxy} other{{count} proxies}}'**
  String proxyCount(int count);

  /// No description provided for @nodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 node} other{{count} nodes}}'**
  String nodeCount(int count);

  /// No description provided for @providerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 proxy provider} other{{count} proxy providers}}'**
  String providerCount(int count);

  /// No description provided for @autoUpdateValue.
  ///
  /// In en, this message translates to:
  /// **'Auto update: {interval}'**
  String autoUpdateValue(String interval);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @editAdvancedYaml.
  ///
  /// In en, this message translates to:
  /// **'Edit advanced YAML'**
  String get editAdvancedYaml;

  /// No description provided for @editAdvancedYamlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All Clash / Mihomo keys are supported. Local controller, port, TUN, and security boundaries are applied when connecting.'**
  String get editAdvancedYamlSubtitle;

  /// No description provided for @subscriptionYamlRefreshWarning.
  ///
  /// In en, this message translates to:
  /// **'Refreshing this subscription will replace manual YAML changes.'**
  String get subscriptionYamlRefreshWarning;

  /// No description provided for @autoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Automatic update'**
  String get autoUpdate;

  /// No description provided for @manualUpdate.
  ///
  /// In en, this message translates to:
  /// **'Manual update'**
  String get manualUpdate;

  /// No description provided for @everyHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} hours'**
  String everyHours(int hours);

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get everyDay;

  /// No description provided for @everyDays.
  ///
  /// In en, this message translates to:
  /// **'Every {days} days'**
  String everyDays(int days);

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get everyWeek;

  /// No description provided for @profileChangesNextConnect.
  ///
  /// In en, this message translates to:
  /// **'Changes to a running profile take effect on the next connection.'**
  String get profileChangesNextConnect;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created: {time}'**
  String createdAt(String time);

  /// No description provided for @contentUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Content updated: {time}'**
  String contentUpdatedAt(String time);

  /// No description provided for @exportSensitiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Export sensitive profile?'**
  String get exportSensitiveTitle;

  /// No description provided for @exportSensitiveBody.
  ///
  /// In en, this message translates to:
  /// **'The exported YAML may contain subscription URLs, server addresses, UUIDs, and passwords. Store it securely and do not publish it.'**
  String get exportSensitiveBody;

  /// No description provided for @understandAndExport.
  ///
  /// In en, this message translates to:
  /// **'I understand, export'**
  String get understandAndExport;

  /// No description provided for @yamlProfileFile.
  ///
  /// In en, this message translates to:
  /// **'YAML profile'**
  String get yamlProfileFile;

  /// No description provided for @proxiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxies'**
  String get proxiesTitle;

  /// No description provided for @refreshProxyGroups.
  ///
  /// In en, this message translates to:
  /// **'Refresh proxy groups'**
  String get refreshProxyGroups;

  /// No description provided for @runMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get runMode;

  /// No description provided for @modeRule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get modeRule;

  /// No description provided for @modeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get modeGlobal;

  /// No description provided for @modeDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get modeDirect;

  /// No description provided for @proxyProviders.
  ///
  /// In en, this message translates to:
  /// **'Proxy providers'**
  String get proxyProviders;

  /// No description provided for @ruleProviders.
  ///
  /// In en, this message translates to:
  /// **'Rule providers'**
  String get ruleProviders;

  /// No description provided for @ruleProviderSummary.
  ///
  /// In en, this message translates to:
  /// **'{behavior} · {vehicle} · {count, plural, =1{1 rule} other{{count} rules}}'**
  String ruleProviderSummary(String behavior, String vehicle, int count);

  /// No description provided for @updateRuleProvider.
  ///
  /// In en, this message translates to:
  /// **'Update rule provider'**
  String get updateRuleProvider;

  /// No description provided for @searchNodes.
  ///
  /// In en, this message translates to:
  /// **'Search nodes'**
  String get searchNodes;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @sortByDelay.
  ///
  /// In en, this message translates to:
  /// **'Sort by delay'**
  String get sortByDelay;

  /// No description provided for @testingNodes.
  ///
  /// In en, this message translates to:
  /// **'Testing node delays concurrently…'**
  String get testingNodes;

  /// No description provided for @connectToViewProxies.
  ///
  /// In en, this message translates to:
  /// **'Connect a profile to view proxy groups and switch nodes.'**
  String get connectToViewProxies;

  /// No description provided for @noSelectableGroups.
  ///
  /// In en, this message translates to:
  /// **'The current profile has no selectable proxy groups.'**
  String get noSelectableGroups;

  /// No description provided for @updateProvider.
  ///
  /// In en, this message translates to:
  /// **'Update provider'**
  String get updateProvider;

  /// No description provided for @providerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String providerUpdated(String time);

  /// No description provided for @providerVehicle.
  ///
  /// In en, this message translates to:
  /// **'Type: {vehicle}'**
  String providerVehicle(String vehicle);

  /// No description provided for @quotaUsed.
  ///
  /// In en, this message translates to:
  /// **'Used {used} / {total}'**
  String quotaUsed(String used, String total);

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresOn(String date);

  /// No description provided for @noMatchingNodes.
  ///
  /// In en, this message translates to:
  /// **'No matching nodes'**
  String get noMatchingNodes;

  /// No description provided for @selectNode.
  ///
  /// In en, this message translates to:
  /// **'Select node'**
  String get selectNode;

  /// No description provided for @groupOptions.
  ///
  /// In en, this message translates to:
  /// **'{type} · {count, plural, =1{1 option} other{{count} options}}'**
  String groupOptions(String type, int count);

  /// No description provided for @testCurrentNode.
  ///
  /// In en, this message translates to:
  /// **'Test current node delay'**
  String get testCurrentNode;

  /// No description provided for @testGroup.
  ///
  /// In en, this message translates to:
  /// **'Test this group'**
  String get testGroup;

  /// No description provided for @connectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime details'**
  String get connectionsTitle;

  /// No description provided for @refreshRuntime.
  ///
  /// In en, this message translates to:
  /// **'Refresh all runtime data'**
  String get refreshRuntime;

  /// No description provided for @tabConnections.
  ///
  /// In en, this message translates to:
  /// **'Active connections'**
  String get tabConnections;

  /// No description provided for @tabRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get tabRules;

  /// No description provided for @tabLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get tabLogs;

  /// No description provided for @connectToViewRuntime.
  ///
  /// In en, this message translates to:
  /// **'Connect a profile to view runtime details.'**
  String get connectToViewRuntime;

  /// No description provided for @connectionSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active connection} other{{count} active connections}} · Upload {upload} · Download {download}'**
  String connectionSummary(int count, String upload, String download);

  /// No description provided for @refreshEveryTwoSeconds.
  ///
  /// In en, this message translates to:
  /// **'Refresh every 2 seconds'**
  String get refreshEveryTwoSeconds;

  /// No description provided for @closeAll.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get closeAll;

  /// No description provided for @searchConnections.
  ///
  /// In en, this message translates to:
  /// **'Search host, destination, network, or proxy chain'**
  String get searchConnections;

  /// No description provided for @noActiveConnections.
  ///
  /// In en, this message translates to:
  /// **'No active connections.'**
  String get noActiveConnections;

  /// No description provided for @noMatchingConnections.
  ///
  /// In en, this message translates to:
  /// **'No matching connections.'**
  String get noMatchingConnections;

  /// No description provided for @closeConnection.
  ///
  /// In en, this message translates to:
  /// **'Close connection'**
  String get closeConnection;

  /// No description provided for @searchRules.
  ///
  /// In en, this message translates to:
  /// **'Search rule type, content, or policy'**
  String get searchRules;

  /// No description provided for @noRules.
  ///
  /// In en, this message translates to:
  /// **'The current profile returned no rules.'**
  String get noRules;

  /// No description provided for @noMatchingRules.
  ///
  /// In en, this message translates to:
  /// **'No matching rules.'**
  String get noMatchingRules;

  /// No description provided for @searchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get searchLogs;

  /// No description provided for @allLevels.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get allLevels;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear in-memory logs'**
  String get clearLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No core logs yet.'**
  String get noLogs;

  /// No description provided for @noMatchingLogs.
  ///
  /// In en, this message translates to:
  /// **'No matching logs.'**
  String get noMatchingLogs;

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'2S-UI devices'**
  String get devicesTitle;

  /// No description provided for @localDevices.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get localDevices;

  /// No description provided for @noPanelConnected.
  ///
  /// In en, this message translates to:
  /// **'No 2S-UI panel is connected.'**
  String get noPanelConnected;

  /// No description provided for @noLocalDevices.
  ///
  /// In en, this message translates to:
  /// **'No local 2S-UI device profile exists yet.'**
  String get noLocalDevices;

  /// No description provided for @connectTwoSui.
  ///
  /// In en, this message translates to:
  /// **'Connect 2S-UI'**
  String get connectTwoSui;

  /// No description provided for @createLocalDevice.
  ///
  /// In en, this message translates to:
  /// **'Create local device'**
  String get createLocalDevice;

  /// No description provided for @deviceDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Device display name'**
  String get deviceDisplayName;

  /// No description provided for @deviceDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Shanghai office PC'**
  String get deviceDisplayNameHint;

  /// No description provided for @deviceDisplayNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a device display name.'**
  String get deviceDisplayNameValidation;

  /// No description provided for @machineIdentityNote.
  ///
  /// In en, this message translates to:
  /// **'ClashXY generates a separate stable machine ID for 2S-UI compatibility. Renaming this label will not change that identity.'**
  String get machineIdentityNote;

  /// No description provided for @remoteClients.
  ///
  /// In en, this message translates to:
  /// **'Remote clients'**
  String get remoteClients;

  /// No description provided for @noRemoteClients.
  ///
  /// In en, this message translates to:
  /// **'The panel returned no remote clients.'**
  String get noRemoteClients;

  /// No description provided for @clientNumber.
  ///
  /// In en, this message translates to:
  /// **'Client #{id}'**
  String clientNumber(int id);

  /// No description provided for @deleteDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this device?'**
  String get deleteDeviceTitle;

  /// No description provided for @deleteDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'The VPN will disconnect. The remote 2S-UI client and local secure profile will both be deleted.'**
  String get deleteDeviceBody;

  /// No description provided for @deleteDeviceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete device'**
  String get deleteDeviceTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @startup.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get startup;

  /// No description provided for @startupPending.
  ///
  /// In en, this message translates to:
  /// **'Open ClashXY automatically after you sign in to Windows.'**
  String get startupPending;

  /// No description provided for @autoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto connect'**
  String get autoConnect;

  /// No description provided for @autoConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect the first profile after the app starts.'**
  String get autoConnectSubtitle;

  /// No description provided for @newDeviceProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol for new 2S-UI devices'**
  String get newDeviceProtocol;

  /// No description provided for @newDeviceProtocolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used only when the next 2S-UI device is created.'**
  String get newDeviceProtocolSubtitle;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @windowsTun.
  ///
  /// In en, this message translates to:
  /// **'Windows TUN'**
  String get windowsTun;

  /// No description provided for @windowsTunSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Route system traffic through Mihomo. Administrator access is required.'**
  String get windowsTunSubtitle;

  /// No description provided for @coreLogs.
  ///
  /// In en, this message translates to:
  /// **'Core logs'**
  String get coreLogs;

  /// No description provided for @coreLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sensitive information is redacted before logs are written.'**
  String get coreLogsSubtitle;

  /// No description provided for @settingsNextConnect.
  ///
  /// In en, this message translates to:
  /// **'Connection settings take effect the next time you connect.'**
  String get settingsNextConnect;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Clash settings'**
  String get advancedSettings;

  /// No description provided for @advancedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local safety boundaries still keep the controller and DNS listener on loopback.'**
  String get advancedSettingsSubtitle;

  /// No description provided for @mixedPort.
  ///
  /// In en, this message translates to:
  /// **'Mixed proxy port'**
  String get mixedPort;

  /// No description provided for @controllerPort.
  ///
  /// In en, this message translates to:
  /// **'Controller port'**
  String get controllerPort;

  /// No description provided for @validPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1024 to 65535.'**
  String get validPort;

  /// No description provided for @portMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'This port must differ from the other local ports.'**
  String get portMustDiffer;

  /// No description provided for @allowLan.
  ///
  /// In en, this message translates to:
  /// **'Allow LAN connections'**
  String get allowLan;

  /// No description provided for @allowLanWarning.
  ///
  /// In en, this message translates to:
  /// **'Exposes the mixed proxy port to the local network. Imported authentication is kept when present.'**
  String get allowLanWarning;

  /// No description provided for @tunStack.
  ///
  /// In en, this message translates to:
  /// **'TUN stack'**
  String get tunStack;

  /// No description provided for @tunStackMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get tunStackMixed;

  /// No description provided for @tunStackSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get tunStackSystem;

  /// No description provided for @tunStackGvisor.
  ///
  /// In en, this message translates to:
  /// **'gVisor'**
  String get tunStackGvisor;

  /// No description provided for @tunMtu.
  ///
  /// In en, this message translates to:
  /// **'TUN MTU'**
  String get tunMtu;

  /// No description provided for @validMtu.
  ///
  /// In en, this message translates to:
  /// **'Enter an MTU from 1280 to 9000.'**
  String get validMtu;

  /// No description provided for @tunStrictRoute.
  ///
  /// In en, this message translates to:
  /// **'Strict route'**
  String get tunStrictRoute;

  /// No description provided for @tunAutoRoute.
  ///
  /// In en, this message translates to:
  /// **'Automatic route'**
  String get tunAutoRoute;

  /// No description provided for @tunAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect interface'**
  String get tunAutoDetect;

  /// No description provided for @tunDeviceName.
  ///
  /// In en, this message translates to:
  /// **'TUN device name'**
  String get tunDeviceName;

  /// No description provided for @valueCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'This value cannot be empty.'**
  String get valueCannotBeEmpty;

  /// No description provided for @dnsOverride.
  ///
  /// In en, this message translates to:
  /// **'Override profile DNS'**
  String get dnsOverride;

  /// No description provided for @dnsOverrideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, imported DNS settings are preserved with a loopback listener.'**
  String get dnsOverrideSubtitle;

  /// No description provided for @dnsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable built-in DNS'**
  String get dnsEnabled;

  /// No description provided for @dnsMode.
  ///
  /// In en, this message translates to:
  /// **'Enhanced DNS mode'**
  String get dnsMode;

  /// No description provided for @dnsModeFakeIp.
  ///
  /// In en, this message translates to:
  /// **'Fake IP'**
  String get dnsModeFakeIp;

  /// No description provided for @dnsModeRedirHost.
  ///
  /// In en, this message translates to:
  /// **'Redir host'**
  String get dnsModeRedirHost;

  /// No description provided for @dnsListenPort.
  ///
  /// In en, this message translates to:
  /// **'DNS listen port'**
  String get dnsListenPort;

  /// No description provided for @dnsNameserver.
  ///
  /// In en, this message translates to:
  /// **'Primary nameserver'**
  String get dnsNameserver;

  /// No description provided for @snifferOverride.
  ///
  /// In en, this message translates to:
  /// **'Override profile sniffer'**
  String get snifferOverride;

  /// No description provided for @snifferOverrideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply the following sniffer switch instead of the imported setting.'**
  String get snifferOverrideSubtitle;

  /// No description provided for @snifferEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable protocol sniffer'**
  String get snifferEnabled;

  /// No description provided for @coreUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Mihomo Core update'**
  String get coreUpdateTitle;

  /// No description provided for @coreUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checks the official stable MetaCubeX/mihomo Windows x64 compatible release.'**
  String get coreUpdateSubtitle;

  /// No description provided for @coreCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed version: {version}'**
  String coreCurrentVersion(String version);

  /// No description provided for @coreVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get coreVersionUnknown;

  /// No description provided for @coreUpdateIdle.
  ///
  /// In en, this message translates to:
  /// **'Check for a verified Core update when you are ready.'**
  String get coreUpdateIdle;

  /// No description provided for @coreCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get coreCheckForUpdates;

  /// No description provided for @coreChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the official release…'**
  String get coreChecking;

  /// No description provided for @coreUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Verified version {version} is available.'**
  String coreUpdateAvailable(String version);

  /// No description provided for @coreUpToDate.
  ///
  /// In en, this message translates to:
  /// **'The installed Core is up to date.'**
  String get coreUpToDate;

  /// No description provided for @coreDownloadInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get coreDownloadInstall;

  /// No description provided for @coreDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading verified version {version}…'**
  String coreDownloading(String version);

  /// No description provided for @coreInstalling.
  ///
  /// In en, this message translates to:
  /// **'Validating and switching to version {version}…'**
  String coreInstalling(String version);

  /// No description provided for @coreUpdateSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Core version {version} was installed. The previous version is available for rollback.'**
  String coreUpdateSucceeded(String version);

  /// No description provided for @coreRollback.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get coreRollback;

  /// No description provided for @coreRollingBack.
  ///
  /// In en, this message translates to:
  /// **'Validating and restoring the previous Core…'**
  String get coreRollingBack;

  /// No description provided for @coreRollbackSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Rolled back to Core version {version}.'**
  String coreRollbackSucceeded(String version);

  /// No description provided for @coreUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the official Mihomo release.'**
  String get coreUpdateCheckFailed;

  /// No description provided for @coreUpdateApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Core update failed. The installed version was preserved or restored.'**
  String get coreUpdateApplyFailed;

  /// No description provided for @coreRollbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Core rollback failed. The installed version was preserved.'**
  String get coreRollbackFailed;

  /// No description provided for @coreUpdateDisconnectRequired.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the VPN before installing or rolling back the Core.'**
  String get coreUpdateDisconnectRequired;

  /// No description provided for @coreUpdateSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Only HTTPS release metadata and assets with an official SHA-256 digest are accepted. Switching is staged and retains one verified previous version.'**
  String get coreUpdateSecurityNote;

  /// No description provided for @runtimeTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'The saved 2S-UI token is missing. Sign in to the panel again.'**
  String get runtimeTokenMissing;

  /// No description provided for @runtimeInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize ClashXY.'**
  String get runtimeInitializationFailed;

  /// No description provided for @runtimeDownloadingSubscription.
  ///
  /// In en, this message translates to:
  /// **'Downloading subscription…'**
  String get runtimeDownloadingSubscription;

  /// No description provided for @runtimeSubscriptionAdded.
  ///
  /// In en, this message translates to:
  /// **'Subscription added.'**
  String get runtimeSubscriptionAdded;

  /// No description provided for @runtimeSubscriptionAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add subscription.'**
  String get runtimeSubscriptionAddFailed;

  /// No description provided for @runtimeImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import profile.'**
  String get runtimeImportFailed;

  /// No description provided for @runtimeLocalImported.
  ///
  /// In en, this message translates to:
  /// **'Local profile imported.'**
  String get runtimeLocalImported;

  /// No description provided for @runtimeCustomSaved.
  ///
  /// In en, this message translates to:
  /// **'Custom profile saved.'**
  String get runtimeCustomSaved;

  /// No description provided for @runtimeUpdatingSubscription.
  ///
  /// In en, this message translates to:
  /// **'Updating subscription…'**
  String get runtimeUpdatingSubscription;

  /// No description provided for @runtimeSubscriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subscription updated.'**
  String get runtimeSubscriptionUpdated;

  /// No description provided for @runtimeSubscriptionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update subscription.'**
  String get runtimeSubscriptionUpdateFailed;

  /// No description provided for @runtimeProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get runtimeProfileUpdated;

  /// No description provided for @runtimeProfileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update profile.'**
  String get runtimeProfileUpdateFailed;

  /// No description provided for @runtimeYamlUpdated.
  ///
  /// In en, this message translates to:
  /// **'Advanced YAML updated.'**
  String get runtimeYamlUpdated;

  /// No description provided for @runtimePanelReachable.
  ///
  /// In en, this message translates to:
  /// **'The HTTPS panel connection is working.'**
  String get runtimePanelReachable;

  /// No description provided for @runtimePanelUnexpected.
  ///
  /// In en, this message translates to:
  /// **'The panel returned an unexpected response.'**
  String get runtimePanelUnexpected;

  /// No description provided for @runtimePanelTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Panel connection test failed.'**
  String get runtimePanelTestFailed;

  /// No description provided for @runtimeTwoFactorRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the current two-factor code to continue.'**
  String get runtimeTwoFactorRequired;

  /// No description provided for @runtimePanelConnected.
  ///
  /// In en, this message translates to:
  /// **'Panel connected. The administrator password was not saved.'**
  String get runtimePanelConnected;

  /// No description provided for @runtimePanelConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the panel.'**
  String get runtimePanelConnectFailed;

  /// No description provided for @runtimePanelAlreadyConnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the current 2S-UI panel before connecting another one.'**
  String get runtimePanelAlreadyConnected;

  /// No description provided for @runtimePanelSessionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The saved 2S-UI session is no longer valid. Disconnect it locally and sign in again.'**
  String get runtimePanelSessionInvalid;

  /// No description provided for @runtimePanelDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The panel was disconnected locally. Existing VPN profiles remain available.'**
  String get runtimePanelDisconnected;

  /// No description provided for @runtimePanelDisconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect the panel locally.'**
  String get runtimePanelDisconnectFailed;

  /// No description provided for @runtimePanelTokenIdMissing.
  ///
  /// In en, this message translates to:
  /// **'The saved token ID is unavailable. Disconnect locally and remove the old token in 2S-UI.'**
  String get runtimePanelTokenIdMissing;

  /// No description provided for @runtimePanelTokenRevoked.
  ///
  /// In en, this message translates to:
  /// **'The app token was revoked and the panel was disconnected.'**
  String get runtimePanelTokenRevoked;

  /// No description provided for @runtimePanelTokenRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke the panel token.'**
  String get runtimePanelTokenRevokeFailed;

  /// No description provided for @runtimeConnectPanelFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect a 2S-UI panel first.'**
  String get runtimeConnectPanelFirst;

  /// No description provided for @runtimeCreatingDevice.
  ///
  /// In en, this message translates to:
  /// **'Creating local device…'**
  String get runtimeCreatingDevice;

  /// No description provided for @runtimeDeviceCreatedConnecting.
  ///
  /// In en, this message translates to:
  /// **'Device created. Connecting…'**
  String get runtimeDeviceCreatedConnecting;

  /// No description provided for @runtimeDeviceCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the device.'**
  String get runtimeDeviceCreateFailed;

  /// No description provided for @runtimeAddProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a profile first.'**
  String get runtimeAddProfileFirst;

  /// No description provided for @runtimeConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get runtimeConnectFailed;

  /// No description provided for @runtimeNoDelayProxy.
  ///
  /// In en, this message translates to:
  /// **'The current profile has no proxy available for delay testing.'**
  String get runtimeNoDelayProxy;

  /// No description provided for @runtimeDelayTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Proxy delay test failed.'**
  String get runtimeDelayTestFailed;

  /// No description provided for @runtimeRefreshClashFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh Mihomo runtime data.'**
  String get runtimeRefreshClashFailed;

  /// No description provided for @runtimeRefreshConnectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh active connections.'**
  String get runtimeRefreshConnectionsFailed;

  /// No description provided for @runtimeSwitchProxyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch proxy.'**
  String get runtimeSwitchProxyFailed;

  /// No description provided for @runtimeTestingAll.
  ///
  /// In en, this message translates to:
  /// **'Testing all proxies…'**
  String get runtimeTestingAll;

  /// No description provided for @runtimeTestNoResults.
  ///
  /// In en, this message translates to:
  /// **'The delay test returned no available results.'**
  String get runtimeTestNoResults;

  /// No description provided for @runtimeTestComplete.
  ///
  /// In en, this message translates to:
  /// **'Delay test complete.'**
  String get runtimeTestComplete;

  /// No description provided for @runtimeUpdatingProvider.
  ///
  /// In en, this message translates to:
  /// **'Updating proxy provider…'**
  String get runtimeUpdatingProvider;

  /// No description provided for @runtimeProviderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Proxy provider updated.'**
  String get runtimeProviderUpdated;

  /// No description provided for @runtimeProviderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update proxy provider.'**
  String get runtimeProviderUpdateFailed;

  /// No description provided for @runtimeUpdatingRuleProvider.
  ///
  /// In en, this message translates to:
  /// **'Updating rule provider…'**
  String get runtimeUpdatingRuleProvider;

  /// No description provided for @runtimeRuleProviderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Rule provider updated.'**
  String get runtimeRuleProviderUpdated;

  /// No description provided for @runtimeRuleProviderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update rule provider.'**
  String get runtimeRuleProviderUpdateFailed;

  /// No description provided for @runtimeCloseConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not close the connection.'**
  String get runtimeCloseConnectionFailed;

  /// No description provided for @runtimeCloseAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not close all connections.'**
  String get runtimeCloseAllFailed;

  /// No description provided for @runtimeSwitchModeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the runtime mode.'**
  String get runtimeSwitchModeFailed;

  /// No description provided for @runtimeRefreshPanelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh panel data.'**
  String get runtimeRefreshPanelFailed;

  /// No description provided for @runtimeDeletingProfile.
  ///
  /// In en, this message translates to:
  /// **'Deleting profile…'**
  String get runtimeDeletingProfile;

  /// No description provided for @runtimeProfileDeleted.
  ///
  /// In en, this message translates to:
  /// **'Profile deleted.'**
  String get runtimeProfileDeleted;

  /// No description provided for @runtimeDetachedPanelProfileDeleted.
  ///
  /// In en, this message translates to:
  /// **'Local profile deleted. The remote 2S-UI client was not changed.'**
  String get runtimeDetachedPanelProfileDeleted;

  /// No description provided for @runtimeDeleteProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete profile.'**
  String get runtimeDeleteProfileFailed;

  /// No description provided for @runtimeDeletingDevice.
  ///
  /// In en, this message translates to:
  /// **'Deleting device…'**
  String get runtimeDeletingDevice;

  /// No description provided for @runtimeDeviceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Device deleted.'**
  String get runtimeDeviceDeleted;

  /// No description provided for @runtimeDeleteDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete device.'**
  String get runtimeDeleteDeviceFailed;

  /// No description provided for @runtimeStartupUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update Windows startup registration.'**
  String get runtimeStartupUpdateFailed;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show ClashXY'**
  String get trayShow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit ClashXY'**
  String get trayQuit;

  /// No description provided for @runtimeTechnicalDetail.
  ///
  /// In en, this message translates to:
  /// **'Details: {detail}'**
  String runtimeTechnicalDetail(String detail);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

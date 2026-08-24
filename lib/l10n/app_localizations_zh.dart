// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get languageName => '简体中文';

  @override
  String get appTitle => 'ClashXY';

  @override
  String get systemLanguage => '跟随系统';

  @override
  String get language => '语言';

  @override
  String get navHome => '首页';

  @override
  String get navProxies => '代理';

  @override
  String get navProfiles => '配置';

  @override
  String get navConnections => '连接';

  @override
  String get navDevices => '2S-UI';

  @override
  String get navSettings => '设置';

  @override
  String get add => '添加';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get export => '导出';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get refresh => '刷新';

  @override
  String get back => '返回';

  @override
  String get unknown => '未知';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get disabled => '已禁用';

  @override
  String get homeNoProfiles => '尚未添加配置';

  @override
  String homeProfilesAvailable(int count) {
    return '$count 个配置可用';
  }

  @override
  String get connectionDisconnected => '未连接';

  @override
  String get connectionConnecting => '正在连接…';

  @override
  String get connectionConnected => '已连接';

  @override
  String get connectionWaitingNetwork => '正在等待网络';

  @override
  String connectionReconnecting(int attempt) {
    return '正在重连 · 第 $attempt 次';
  }

  @override
  String get connectionStopping => '正在断开…';

  @override
  String connectionError(String message) {
    return '错误 · $message';
  }

  @override
  String get connectionErrorGeneric => '连接错误';

  @override
  String get addProfile => '添加配置';

  @override
  String get uploadSpeed => '上传速度';

  @override
  String get downloadSpeed => '下载速度';

  @override
  String get proxyDelay => '代理延迟';

  @override
  String get delayTesting => '测速中…';

  @override
  String get delayFailed => '测速失败';

  @override
  String get setupFirstProfile => '添加第一个配置';

  @override
  String get setupIntro =>
      'ClashXY 是一个完整的 Mihomo / Clash 客户端。你可以直接使用订阅或 YAML；2S-UI 管理是可选功能。';

  @override
  String get addSubscription => '添加订阅';

  @override
  String get subscriptionSubtitle => '使用 HTTPS Clash / Mihomo 订阅地址';

  @override
  String get importLocalConfig => '导入本地配置';

  @override
  String get importLocalSubtitle => '选择 .yaml 或 .yml 文件';

  @override
  String get customYaml => '自定义 YAML';

  @override
  String get customYamlSubtitle => '粘贴并保存完整 Clash / Mihomo 配置';

  @override
  String get connectTwoSuiOptional => '连接 2S-UI（可选）';

  @override
  String get connectTwoSuiSubtitle => '登录面板、创建设备并管理远程客户端';

  @override
  String get connectPanelTitle => '连接 2S-UI 面板';

  @override
  String get connectPanelSecurity => '仅支持 HTTPS。管理员密码只用于创建独立 API 令牌，不会保存到本机。';

  @override
  String get panelAddress => '面板地址';

  @override
  String get panelAddressValidation => '请输入 HTTPS 面板地址。';

  @override
  String get username => '用户名';

  @override
  String get usernameValidation => '请输入用户名。';

  @override
  String get password => '密码';

  @override
  String get passwordValidation => '请输入密码。';

  @override
  String get twoFactorCode => '双重验证码';

  @override
  String get testConnection => '测试连接';

  @override
  String get fileReadFailed => '无法读取所选配置文件。';

  @override
  String get subscriptionName => '配置名称';

  @override
  String get profileNameValidation => '请输入配置名称。';

  @override
  String get subscriptionNameHint => '我的订阅';

  @override
  String get subscriptionUrl => '订阅地址';

  @override
  String get subscriptionUrlValidation => '请输入有效的 HTTPS 订阅地址。';

  @override
  String get subscriptionUrlNoCredentials => '请输入不含 URL 用户凭据的 HTTPS 地址。';

  @override
  String get customProfileNameHint => '我的配置';

  @override
  String get yamlContent => 'YAML 内容';

  @override
  String get yamlEmptyValidation => '配置内容不能为空。';

  @override
  String get profilesTitle => '配置';

  @override
  String get profilesIntro => '订阅、本地 YAML、自定义配置与 2S-UI 配置可以同时使用。';

  @override
  String get noProfiles => '还没有可用配置。';

  @override
  String get addFirstProfile => '添加第一个配置';

  @override
  String get twoSuiNotConnected => '未连接 2S-UI';

  @override
  String get twoSuiManagementOptional => '2S-UI 管理（可选）';

  @override
  String get twoSuiNotRequired => '不影响订阅或自定义配置的正常使用。';

  @override
  String get connectPanel => '连接面板';

  @override
  String get refreshPanelStatus => '刷新面板状态';

  @override
  String get panelAccount => '面板账户';

  @override
  String signedInAs(String username) {
    return '当前账户：$username';
  }

  @override
  String get managePanelAccount => '管理账户';

  @override
  String get disconnectPanelTitle => '断开此面板？';

  @override
  String get disconnectPanelBody =>
      '已有的 2S-UI VPN 配置会保留在本机，远程客户端不会被删除；之后可以连接其他面板。';

  @override
  String get disconnectLocally => '仅在本机断开';

  @override
  String get disconnectLocallySubtitle => '从本机移除令牌，但令牌仍保留在 2S-UI 中。';

  @override
  String get revokeAndDisconnect => '撤销令牌并断开';

  @override
  String get revokeAndDisconnectSubtitle => '临时使用管理员密码登录，撤销本应用的专用令牌，然后清除本地关联。';

  @override
  String get tokenRevokeUnavailable =>
      '此账户由旧版本保存，缺少令牌 ID。请先在本机断开，再到 2S-UI 中手动删除旧令牌。';

  @override
  String get reauthenticatePanel => '确认面板管理员身份';

  @override
  String get reauthenticatePanelBody => '密码和双重验证码仅用于本次撤销请求，不会保存。';

  @override
  String get revokeToken => '撤销令牌';

  @override
  String get version => '版本';

  @override
  String get uptime => '运行时间';

  @override
  String seconds(int count) {
    return '$count 秒';
  }

  @override
  String get upload => '上传';

  @override
  String get download => '下载';

  @override
  String get addProfileTitle => '添加配置';

  @override
  String get deleteManagedTitle => '删除 2S-UI 设备？';

  @override
  String get deleteProfileTitle => '删除配置？';

  @override
  String get deleteManagedBody => 'VPN 将断开，远程 2S-UI 客户端和本地安全配置都会被删除。';

  @override
  String get deleteDetachedManagedBody =>
      '该面板当前未连接，只会删除本地安全配置，不会修改远程 2S-UI 客户端。';

  @override
  String get deleteProfileBody => '将删除本地配置及其安全数据，不会修改订阅服务端。';

  @override
  String get currentProfile => '当前运行';

  @override
  String get updateSubscription => '更新订阅';

  @override
  String get activeProfileTooltip => '当前配置正在运行';

  @override
  String get connectProfileTooltip => '连接此配置';

  @override
  String get moreActions => '更多操作';

  @override
  String get exportProfile => '导出配置';

  @override
  String get profileOriginSubscription => '订阅';

  @override
  String get profileOriginLocal => '本地 YAML';

  @override
  String get profileOriginCustom => '自定义 YAML';

  @override
  String get profileOriginTwoSui => '2S-UI';

  @override
  String proxyCount(int count) {
    return '$count 个代理';
  }

  @override
  String nodeCount(int count) {
    return '$count 个节点';
  }

  @override
  String providerCount(int count) {
    return '$count 个代理提供器';
  }

  @override
  String autoUpdateValue(String interval) {
    return '自动更新：$interval';
  }

  @override
  String updatedAt(String time) {
    return '更新于 $time';
  }

  @override
  String get editProfile => '编辑配置';

  @override
  String get editAdvancedYaml => '编辑高级 YAML';

  @override
  String get editAdvancedYamlSubtitle =>
      '支持所有 Clash / Mihomo 配置项；连接时仍会应用本地控制器、端口、TUN 和安全边界。';

  @override
  String get subscriptionYamlRefreshWarning => '下次更新此订阅时会覆盖手动修改的 YAML。';

  @override
  String get autoUpdate => '自动更新';

  @override
  String get manualUpdate => '手动更新';

  @override
  String everyHours(int hours) {
    return '每 $hours 小时';
  }

  @override
  String get everyDay => '每天';

  @override
  String everyDays(int days) {
    return '每 $days 天';
  }

  @override
  String get everyWeek => '每周';

  @override
  String get profileChangesNextConnect => '正在运行的配置将在下次连接时应用修改。';

  @override
  String createdAt(String time) {
    return '创建：$time';
  }

  @override
  String contentUpdatedAt(String time) {
    return '内容更新：$time';
  }

  @override
  String get exportSensitiveTitle => '导出敏感配置？';

  @override
  String get exportSensitiveBody =>
      '导出的 YAML 可能包含订阅地址、服务器地址、UUID 和密码。请妥善保存，不要公开发布。';

  @override
  String get understandAndExport => '理解风险并导出';

  @override
  String get yamlProfileFile => 'YAML 配置';

  @override
  String get proxiesTitle => '代理';

  @override
  String get refreshProxyGroups => '刷新代理组';

  @override
  String get runMode => '运行模式';

  @override
  String get modeRule => '规则';

  @override
  String get modeGlobal => '全局';

  @override
  String get modeDirect => '直连';

  @override
  String get proxyProviders => '代理提供器';

  @override
  String get ruleProviders => '规则提供器';

  @override
  String ruleProviderSummary(String behavior, String vehicle, int count) {
    return '$behavior · $vehicle · $count 条规则';
  }

  @override
  String get updateRuleProvider => '更新规则提供器';

  @override
  String get searchNodes => '搜索节点';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get sortByDelay => '按延迟排序';

  @override
  String get testingNodes => '正在并发测试节点延迟…';

  @override
  String get connectToViewProxies => '连接配置后即可查看代理组并切换节点。';

  @override
  String get noSelectableGroups => '当前配置没有可选择的代理组。';

  @override
  String get updateProvider => '更新 Provider';

  @override
  String providerUpdated(String time) {
    return '更新于 $time';
  }

  @override
  String providerVehicle(String vehicle) {
    return '类型：$vehicle';
  }

  @override
  String quotaUsed(String used, String total) {
    return '已用 $used / $total';
  }

  @override
  String expiresOn(String date) {
    return '到期 $date';
  }

  @override
  String get noMatchingNodes => '没有匹配节点';

  @override
  String get selectNode => '选择节点';

  @override
  String groupOptions(String type, int count) {
    return '$type · $count 个选项';
  }

  @override
  String get testCurrentNode => '测试当前节点延迟';

  @override
  String get testGroup => '批量测试此组';

  @override
  String get connectionsTitle => '运行详情';

  @override
  String get refreshRuntime => '刷新全部运行数据';

  @override
  String get tabConnections => '活动连接';

  @override
  String get tabRules => '规则';

  @override
  String get tabLogs => '日志';

  @override
  String get connectToViewRuntime => '连接配置后即可查看运行详情。';

  @override
  String connectionSummary(int count, String upload, String download) {
    return '$count 个活动连接 · 上传 $upload · 下载 $download';
  }

  @override
  String get refreshEveryTwoSeconds => '每 2 秒刷新';

  @override
  String get closeAll => '全部关闭';

  @override
  String get searchConnections => '搜索域名、目标地址、网络或代理链';

  @override
  String get noActiveConnections => '当前没有活动连接。';

  @override
  String get noMatchingConnections => '没有匹配的活动连接。';

  @override
  String get closeConnection => '关闭连接';

  @override
  String get searchRules => '搜索规则类型、内容或策略';

  @override
  String get noRules => '当前配置没有返回规则。';

  @override
  String get noMatchingRules => '没有匹配规则。';

  @override
  String get searchLogs => '搜索日志内容';

  @override
  String get allLevels => '全部级别';

  @override
  String get clearLogs => '清空内存日志';

  @override
  String get noLogs => '暂时没有核心日志。';

  @override
  String get noMatchingLogs => '没有匹配日志。';

  @override
  String get devicesTitle => '2S-UI 设备';

  @override
  String get localDevices => '本机设备';

  @override
  String get noPanelConnected => '尚未连接 2S-UI 面板。';

  @override
  String get noLocalDevices => '还没有本机 2S-UI 设备配置。';

  @override
  String get connectTwoSui => '连接 2S-UI';

  @override
  String get createLocalDevice => '创建本机设备';

  @override
  String get remoteClients => '远程客户端';

  @override
  String get noRemoteClients => '面板没有返回远程客户端。';

  @override
  String clientNumber(int id) {
    return 'Client #$id';
  }

  @override
  String get deleteDeviceTitle => '删除此设备？';

  @override
  String get deleteDeviceBody => 'VPN 将断开，远程 2S-UI 客户端和本地安全配置都会被删除。';

  @override
  String get deleteDeviceTooltip => '删除设备';

  @override
  String get settingsTitle => '设置';

  @override
  String get startup => '开机启动';

  @override
  String get startupPending => '登录 Windows 后自动打开 ClashXY。';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoConnectSubtitle => '应用启动后自动连接首个配置。';

  @override
  String get newDeviceProtocol => '2S-UI 新建设备协议';

  @override
  String get newDeviceProtocolSubtitle => '仅用于下一次从 2S-UI 创建设备。';

  @override
  String get automatic => '自动选择';

  @override
  String get windowsTun => 'Windows TUN';

  @override
  String get windowsTunSubtitle => '通过 Mihomo 接管系统流量，需要管理员权限。';

  @override
  String get coreLogs => '核心日志';

  @override
  String get coreLogsSubtitle => '写入日志前会自动隐藏敏感信息。';

  @override
  String get settingsNextConnect => '影响连接的设置将在下次连接时生效。';

  @override
  String get advancedSettings => 'Clash 高级设置';

  @override
  String get advancedSettingsSubtitle => '本地安全边界仍会把控制器和 DNS 监听限制在回环地址。';

  @override
  String get mixedPort => '混合代理端口';

  @override
  String get controllerPort => '控制器端口';

  @override
  String get validPort => '请输入 1024 到 65535 之间的端口。';

  @override
  String get portMustDiffer => '此端口不能与其他本地端口相同。';

  @override
  String get allowLan => '允许局域网连接';

  @override
  String get allowLanWarning => '将混合代理端口暴露到局域网；如果导入配置包含认证会予以保留。';

  @override
  String get tunStack => 'TUN 协议栈';

  @override
  String get tunStackMixed => '混合';

  @override
  String get tunStackSystem => '系统';

  @override
  String get tunStackGvisor => 'gVisor';

  @override
  String get tunMtu => 'TUN MTU';

  @override
  String get validMtu => '请输入 1280 到 9000 之间的 MTU。';

  @override
  String get tunStrictRoute => '严格路由';

  @override
  String get tunAutoRoute => '自动路由';

  @override
  String get tunAutoDetect => '自动检测出口网卡';

  @override
  String get tunDeviceName => 'TUN 设备名称';

  @override
  String get valueCannotBeEmpty => '此项不能为空。';

  @override
  String get dnsOverride => '覆盖配置中的 DNS';

  @override
  String get dnsOverrideSubtitle => '关闭时保留导入的 DNS 设置，但监听地址仍限制为回环地址。';

  @override
  String get dnsEnabled => '启用内置 DNS';

  @override
  String get dnsMode => 'DNS 增强模式';

  @override
  String get dnsModeFakeIp => 'Fake IP';

  @override
  String get dnsModeRedirHost => 'Redir Host';

  @override
  String get dnsListenPort => 'DNS 监听端口';

  @override
  String get dnsNameserver => '主要 DNS 服务器';

  @override
  String get snifferOverride => '覆盖配置中的嗅探设置';

  @override
  String get snifferOverrideSubtitle => '使用下面的嗅探开关代替导入配置中的设置。';

  @override
  String get snifferEnabled => '启用协议嗅探';

  @override
  String get runtimeTokenMissing => '已保存的 2S-UI 令牌缺失，请重新登录面板。';

  @override
  String get runtimeInitializationFailed => '无法初始化 ClashXY。';

  @override
  String get runtimeDownloadingSubscription => '正在下载订阅…';

  @override
  String get runtimeSubscriptionAdded => '订阅已添加。';

  @override
  String get runtimeSubscriptionAddFailed => '订阅添加失败。';

  @override
  String get runtimeImportFailed => '配置导入失败。';

  @override
  String get runtimeLocalImported => '本地配置已导入。';

  @override
  String get runtimeCustomSaved => '自定义配置已保存。';

  @override
  String get runtimeUpdatingSubscription => '正在更新订阅…';

  @override
  String get runtimeSubscriptionUpdated => '订阅已更新。';

  @override
  String get runtimeSubscriptionUpdateFailed => '订阅更新失败。';

  @override
  String get runtimeProfileUpdated => '配置已更新。';

  @override
  String get runtimeProfileUpdateFailed => '无法更新配置。';

  @override
  String get runtimeYamlUpdated => '高级 YAML 已更新。';

  @override
  String get runtimePanelReachable => 'HTTPS 面板连接正常。';

  @override
  String get runtimePanelUnexpected => '面板返回了非预期响应。';

  @override
  String get runtimePanelTestFailed => '面板连接测试失败。';

  @override
  String get runtimeTwoFactorRequired => '请输入当前双重验证码后继续。';

  @override
  String get runtimePanelConnected => '面板已连接，管理员密码未保存。';

  @override
  String get runtimePanelConnectFailed => '面板连接失败。';

  @override
  String get runtimePanelAlreadyConnected => '请先断开当前 2S-UI 面板，再连接其他面板。';

  @override
  String get runtimePanelSessionInvalid => '已保存的 2S-UI 会话已失效，请在本机断开后重新登录。';

  @override
  String get runtimePanelDisconnected => '已在本机断开面板，已有 VPN 配置仍可继续使用。';

  @override
  String get runtimePanelDisconnectFailed => '无法在本机断开面板。';

  @override
  String get runtimePanelTokenIdMissing =>
      '缺少已保存的令牌 ID，请在本机断开并到 2S-UI 中手动删除旧令牌。';

  @override
  String get runtimePanelTokenRevoked => '已撤销本应用令牌并断开面板。';

  @override
  String get runtimePanelTokenRevokeFailed => '无法撤销面板令牌。';

  @override
  String get runtimeConnectPanelFirst => '请先连接 2S-UI 面板。';

  @override
  String get runtimeCreatingDevice => '正在创建本机设备…';

  @override
  String get runtimeDeviceCreatedConnecting => '设备已创建，正在连接…';

  @override
  String get runtimeDeviceCreateFailed => '设备创建失败。';

  @override
  String get runtimeAddProfileFirst => '请先添加一个配置。';

  @override
  String get runtimeConnectFailed => '连接失败。';

  @override
  String get runtimeNoDelayProxy => '当前配置没有可测速的代理节点。';

  @override
  String get runtimeDelayTestFailed => '代理延迟测试失败。';

  @override
  String get runtimeRefreshClashFailed => '无法刷新 Mihomo 运行数据。';

  @override
  String get runtimeRefreshConnectionsFailed => '无法刷新活动连接。';

  @override
  String get runtimeSwitchProxyFailed => '节点切换失败。';

  @override
  String get runtimeTestingAll => '正在批量测速…';

  @override
  String get runtimeTestNoResults => '批量测速未得到可用结果。';

  @override
  String get runtimeTestComplete => '批量测速完成。';

  @override
  String get runtimeUpdatingProvider => '正在更新代理提供器…';

  @override
  String get runtimeProviderUpdated => '代理提供器已更新。';

  @override
  String get runtimeProviderUpdateFailed => '代理提供器更新失败。';

  @override
  String get runtimeUpdatingRuleProvider => '正在更新规则提供器…';

  @override
  String get runtimeRuleProviderUpdated => '规则提供器已更新。';

  @override
  String get runtimeRuleProviderUpdateFailed => '规则提供器更新失败。';

  @override
  String get runtimeCloseConnectionFailed => '无法关闭连接。';

  @override
  String get runtimeCloseAllFailed => '无法关闭全部连接。';

  @override
  String get runtimeSwitchModeFailed => '无法切换运行模式。';

  @override
  String get runtimeRefreshPanelFailed => '无法刷新面板数据。';

  @override
  String get runtimeDeletingProfile => '正在删除配置…';

  @override
  String get runtimeProfileDeleted => '配置已删除。';

  @override
  String get runtimeDetachedPanelProfileDeleted => '本地配置已删除，远程 2S-UI 客户端未修改。';

  @override
  String get runtimeDeleteProfileFailed => '无法删除配置。';

  @override
  String get runtimeDeletingDevice => '正在删除设备…';

  @override
  String get runtimeDeviceDeleted => '设备已删除。';

  @override
  String get runtimeDeleteDeviceFailed => '无法删除设备。';

  @override
  String get runtimeStartupUpdateFailed => '无法更新 Windows 开机启动设置。';

  @override
  String get trayShow => '显示 ClashXY';

  @override
  String get trayQuit => '退出 ClashXY';

  @override
  String runtimeTechnicalDetail(String detail) {
    return '详细信息：$detail';
  }
}

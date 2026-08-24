class AppSettings {
  const AppSettings({
    this.controllerPort = 9099,
    this.mixedPort = 7890,
    this.tunDevice = 'ClashXY',
    this.launchAtStartup = false,
    this.autoConnect = false,
    this.protocol = 'automatic',
    this.tunEnabled = true,
    this.ipv6Enabled = false,
    this.logsEnabled = true,
    this.localeCode = 'system',
    this.allowLan = false,
    this.tunStack = 'mixed',
    this.tunMtu = 9000,
    this.tunStrictRoute = true,
    this.tunAutoRoute = true,
    this.tunAutoDetectInterface = true,
    this.dnsOverrideEnabled = false,
    this.dnsEnabled = true,
    this.dnsMode = 'fake-ip',
    this.dnsListenPort = 1053,
    this.dnsNameserver = 'https://1.1.1.1/dns-query',
    this.snifferOverrideEnabled = false,
    this.snifferEnabled = true,
  });

  final int controllerPort;
  final int mixedPort;
  final String tunDevice;
  final bool launchAtStartup;
  final bool autoConnect;
  final String protocol;
  final bool tunEnabled;
  final bool ipv6Enabled;
  final bool logsEnabled;
  final String localeCode;
  final bool allowLan;
  final String tunStack;
  final int tunMtu;
  final bool tunStrictRoute;
  final bool tunAutoRoute;
  final bool tunAutoDetectInterface;
  final bool dnsOverrideEnabled;
  final bool dnsEnabled;
  final String dnsMode;
  final int dnsListenPort;
  final String dnsNameserver;
  final bool snifferOverrideEnabled;
  final bool snifferEnabled;

  AppSettings copyWith({
    int? controllerPort,
    int? mixedPort,
    String? tunDevice,
    bool? launchAtStartup,
    bool? autoConnect,
    String? protocol,
    bool? tunEnabled,
    bool? ipv6Enabled,
    bool? logsEnabled,
    String? localeCode,
    bool? allowLan,
    String? tunStack,
    int? tunMtu,
    bool? tunStrictRoute,
    bool? tunAutoRoute,
    bool? tunAutoDetectInterface,
    bool? dnsOverrideEnabled,
    bool? dnsEnabled,
    String? dnsMode,
    int? dnsListenPort,
    String? dnsNameserver,
    bool? snifferOverrideEnabled,
    bool? snifferEnabled,
  }) {
    return AppSettings(
      controllerPort: controllerPort ?? this.controllerPort,
      mixedPort: mixedPort ?? this.mixedPort,
      tunDevice: tunDevice ?? this.tunDevice,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      autoConnect: autoConnect ?? this.autoConnect,
      protocol: protocol ?? this.protocol,
      tunEnabled: tunEnabled ?? this.tunEnabled,
      ipv6Enabled: ipv6Enabled ?? this.ipv6Enabled,
      logsEnabled: logsEnabled ?? this.logsEnabled,
      localeCode: localeCode ?? this.localeCode,
      allowLan: allowLan ?? this.allowLan,
      tunStack: tunStack ?? this.tunStack,
      tunMtu: tunMtu ?? this.tunMtu,
      tunStrictRoute: tunStrictRoute ?? this.tunStrictRoute,
      tunAutoRoute: tunAutoRoute ?? this.tunAutoRoute,
      tunAutoDetectInterface:
          tunAutoDetectInterface ?? this.tunAutoDetectInterface,
      dnsOverrideEnabled: dnsOverrideEnabled ?? this.dnsOverrideEnabled,
      dnsEnabled: dnsEnabled ?? this.dnsEnabled,
      dnsMode: dnsMode ?? this.dnsMode,
      dnsListenPort: dnsListenPort ?? this.dnsListenPort,
      dnsNameserver: dnsNameserver ?? this.dnsNameserver,
      snifferOverrideEnabled:
          snifferOverrideEnabled ?? this.snifferOverrideEnabled,
      snifferEnabled: snifferEnabled ?? this.snifferEnabled,
    );
  }
}

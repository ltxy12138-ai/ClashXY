enum ProxyProtocol { vlessReality, hysteria2 }

enum ProfileOrigin { twoSui, subscription, localFile, custom }

class ProxyProfile {
  const ProxyProfile({
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    required this.authentication,
    required this.options,
  });

  final String name;
  final ProxyProtocol protocol;
  final String server;
  final int port;
  final String authentication;
  final Map<String, String> options;
}

class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.panelId,
    required this.remoteClientId,
    required this.displayName,
    required this.proxies,
    required this.createdAt,
    this.origin = ProfileOrigin.twoSui,
    this.rawConfig,
    this.subscriptionUrl,
    this.updatedAt,
    this.autoUpdateInterval = Duration.zero,
  });

  final String id;
  final String panelId;
  final int remoteClientId;
  final String displayName;
  final List<ProxyProfile> proxies;
  final DateTime createdAt;
  final ProfileOrigin origin;
  final Map<String, Object?>? rawConfig;
  final Uri? subscriptionUrl;
  final DateTime? updatedAt;
  final Duration autoUpdateInterval;

  bool get isStandalone => origin != ProfileOrigin.twoSui;
  bool get autoUpdateEnabled =>
      origin == ProfileOrigin.subscription &&
      autoUpdateInterval > Duration.zero;
  DateTime get lastUpdatedAt => updatedAt ?? createdAt;

  ConnectionProfile copyWith({
    String? displayName,
    DateTime? createdAt,
    List<ProxyProfile>? proxies,
    Object? rawConfig = _unset,
    Object? subscriptionUrl = _unset,
    Object? updatedAt = _unset,
    Duration? autoUpdateInterval,
  }) {
    return ConnectionProfile(
      id: id,
      panelId: panelId,
      remoteClientId: remoteClientId,
      displayName: displayName ?? this.displayName,
      proxies: proxies ?? this.proxies,
      createdAt: createdAt ?? this.createdAt,
      origin: origin,
      rawConfig: identical(rawConfig, _unset)
          ? this.rawConfig
          : rawConfig as Map<String, Object?>?,
      subscriptionUrl: identical(subscriptionUrl, _unset)
          ? this.subscriptionUrl
          : subscriptionUrl as Uri?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
      autoUpdateInterval: autoUpdateInterval ?? this.autoUpdateInterval,
    );
  }
}

const Object _unset = Object();

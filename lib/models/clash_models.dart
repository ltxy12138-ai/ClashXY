class ProxyGroupState {
  const ProxyGroupState({
    required this.name,
    required this.type,
    required this.options,
    required this.selected,
    required this.alive,
  });

  final String name;
  final String type;
  final List<String> options;
  final String? selected;
  final bool alive;
}

class ProxyProviderState {
  const ProxyProviderState({
    required this.name,
    required this.vehicleType,
    required this.updatedAt,
    required this.proxyCount,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.totalBytes,
    required this.expireAt,
  });

  final String name;
  final String vehicleType;
  final DateTime? updatedAt;
  final int proxyCount;
  final int uploadBytes;
  final int downloadBytes;
  final int totalBytes;
  final DateTime? expireAt;
}

class ClashRuleEntry {
  const ClashRuleEntry({
    required this.type,
    required this.payload,
    required this.proxy,
  });

  final String type;
  final String payload;
  final String proxy;
}

class RuleProviderState {
  const RuleProviderState({
    required this.name,
    required this.behavior,
    required this.vehicleType,
    required this.updatedAt,
    required this.ruleCount,
  });

  final String name;
  final String behavior;
  final String vehicleType;
  final DateTime? updatedAt;
  final int ruleCount;
}

class ClashConnectionEntry {
  const ClashConnectionEntry({
    required this.id,
    required this.network,
    required this.host,
    required this.destination,
    required this.chains,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.startedAt,
  });

  final String id;
  final String network;
  final String host;
  final String destination;
  final List<String> chains;
  final int uploadBytes;
  final int downloadBytes;
  final DateTime? startedAt;
}

class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.connections,
    required this.uploadTotal,
    required this.downloadTotal,
  });

  final List<ClashConnectionEntry> connections;
  final int uploadTotal;
  final int downloadTotal;
}

class CoreLogEntry {
  const CoreLogEntry({
    required this.level,
    required this.message,
    required this.capturedAt,
  });

  final String level;
  final String message;
  final DateTime capturedAt;
}

abstract interface class NetworkMonitor {
  Stream<NetworkSnapshot> get changes;

  NetworkSnapshot? get current;

  Future<void> start();

  Future<void> checkNow();

  Future<void> dispose();
}

class NetworkSnapshot {
  NetworkSnapshot(Iterable<String> endpoints)
    : endpoints = List<String>.unmodifiable(endpoints.toList()..sort());

  final List<String> endpoints;

  bool get available => endpoints.isNotEmpty;

  bool sameAs(NetworkSnapshot other) {
    if (identical(this, other)) return true;
    if (endpoints.length != other.endpoints.length) return false;
    for (var index = 0; index < endpoints.length; index++) {
      if (endpoints[index] != other.endpoints[index]) return false;
    }
    return true;
  }
}

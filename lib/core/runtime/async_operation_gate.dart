class AsyncOperationGate {
  bool _active = false;

  bool get active => _active;

  Future<bool> run(Future<void> Function() operation) async {
    if (_active) return false;
    _active = true;
    try {
      await operation();
      return true;
    } finally {
      _active = false;
    }
  }
}

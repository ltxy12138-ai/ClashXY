enum SystemPowerEvent { suspend, resume }

abstract interface class SystemPowerMonitor {
  Stream<SystemPowerEvent> get events;

  Future<void> start();

  Future<void> dispose();
}

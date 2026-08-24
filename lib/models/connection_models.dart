sealed class AppConnectionState {
  const AppConnectionState();
}

final class Disconnected extends AppConnectionState {
  const Disconnected();
}

final class Connecting extends AppConnectionState {
  const Connecting();
}

final class Connected extends AppConnectionState {
  const Connected({required this.since});

  final DateTime since;
}

final class WaitingForNetwork extends AppConnectionState {
  const WaitingForNetwork();
}

final class Reconnecting extends AppConnectionState {
  const Reconnecting({required this.attempt});

  final int attempt;
}

final class Stopping extends AppConnectionState {
  const Stopping();
}

final class ConnectionFailure extends AppConnectionState {
  const ConnectionFailure(this.message);

  final String message;
}

class TrafficSample {
  const TrafficSample({
    required this.uploadBytesPerSecond,
    required this.downloadBytesPerSecond,
    required this.capturedAt,
  });

  final int uploadBytesPerSecond;
  final int downloadBytesPerSecond;
  final DateTime capturedAt;
}

class DelayResult {
  const DelayResult({required this.proxyName, required this.milliseconds});

  final String proxyName;
  final int milliseconds;
}

class MihomoStatus {
  const MihomoStatus({required this.version, required this.mode});

  final String version;
  final String mode;
}

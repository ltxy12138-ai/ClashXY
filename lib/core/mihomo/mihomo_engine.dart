import '../../models/connection_models.dart';
import '../../models/profile_models.dart';

abstract interface class MihomoEngine {
  Stream<AppConnectionState> get states;

  Stream<TrafficSample> get traffic;

  Future<void> start(ConnectionProfile profile);

  Future<void> stop();

  Future<MihomoStatus> status();

  Future<DelayResult> testDelay(String proxyName);
}

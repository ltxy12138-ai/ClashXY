import 'dart:async';
import 'dart:io';

import '../../core/runtime/network_monitor.dart';

typedef NetworkSnapshotLoader = Future<NetworkSnapshot> Function();

class WindowsNetworkMonitor implements NetworkMonitor {
  WindowsNetworkMonitor({
    this._interval = const Duration(seconds: 3),
    Iterable<String> excludedInterfaceNames = const <String>[],
    NetworkSnapshotLoader? loader,
  }) : _loader =
           loader ??
           _platformLoader(
             excludedInterfaceNames
                 .map((name) => name.trim().toLowerCase())
                 .where((name) => name.isNotEmpty)
                 .toSet(),
           );

  final Duration _interval;
  final NetworkSnapshotLoader _loader;
  final StreamController<NetworkSnapshot> _changes =
      StreamController<NetworkSnapshot>.broadcast(sync: true);

  Timer? _timer;
  NetworkSnapshot? _last;
  bool _checking = false;
  bool _disposed = false;

  @override
  Stream<NetworkSnapshot> get changes => _changes.stream;

  @override
  NetworkSnapshot? get current => _last;

  @override
  Future<void> start() async {
    if (_disposed || _timer != null) return;
    await _sample(emitChange: false);
    if (_disposed) return;
    _timer = Timer.periodic(_interval, (_) => unawaited(checkNow()));
  }

  @override
  Future<void> checkNow() => _sample(emitChange: true);

  Future<void> _sample({required bool emitChange}) async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      final next = await _loader();
      final previous = _last;
      _last = next;
      if (emitChange && previous != null && !previous.sameAs(next)) {
        _changes.add(next);
      }
    } catch (_) {
      // A failed sample is not proof that the network disappeared. Keep the
      // last good snapshot and retry on the next interval.
    } finally {
      _checking = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _changes.close();
  }

  static NetworkSnapshotLoader _platformLoader(Set<String> excludedNames) {
    return () async {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any,
      );
      final endpoints = <String>[];
      for (final interface in interfaces) {
        if (excludedNames.contains(interface.name.trim().toLowerCase())) {
          continue;
        }
        for (final address in interface.addresses) {
          if (address.isLoopback || address.isLinkLocal) continue;
          endpoints.add(
            '${interface.name}|${address.type.name}|${address.address}',
          );
        }
      }
      return NetworkSnapshot(endpoints);
    };
  }
}

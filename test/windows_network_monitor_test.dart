import 'dart:async';
import 'dart:io';

import 'package:clashxy/core/runtime/network_monitor.dart';
import 'package:clashxy/platform/windows/windows_network_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('samples the current Windows interfaces', () async {
    final monitor = WindowsNetworkMonitor(interval: const Duration(hours: 1));
    await monitor.start();
    expect(monitor.current, isNotNull);
    await monitor.dispose();
  }, skip: !Platform.isWindows);

  test('emits only when the network snapshot changes', () async {
    var current = NetworkSnapshot(<String>['Wi-Fi|IPv4|192.0.2.10']);
    final monitor = WindowsNetworkMonitor(
      interval: const Duration(hours: 1),
      loader: () async => current,
    );
    final emitted = <NetworkSnapshot>[];
    final subscription = monitor.changes.listen(emitted.add);

    await monitor.start();
    await monitor.checkNow();
    expect(emitted, isEmpty);

    current = NetworkSnapshot(<String>['Ethernet|IPv4|192.0.2.20']);
    await monitor.checkNow();
    expect(emitted, hasLength(1));
    expect(emitted.single.available, isTrue);

    await subscription.cancel();
    await monitor.dispose();
  });

  test(
    'reports loss and restoration without treating sample errors as loss',
    () async {
      var current = NetworkSnapshot(<String>['Wi-Fi|IPv4|192.0.2.10']);
      var fail = false;
      final monitor = WindowsNetworkMonitor(
        interval: const Duration(hours: 1),
        loader: () async {
          if (fail) throw StateError('temporary enumeration failure');
          return current;
        },
      );
      final emitted = <NetworkSnapshot>[];
      final subscription = monitor.changes.listen(emitted.add);

      await monitor.start();
      fail = true;
      await monitor.checkNow();
      expect(emitted, isEmpty);

      fail = false;
      current = NetworkSnapshot(const <String>[]);
      await monitor.checkNow();
      current = NetworkSnapshot(<String>['Ethernet|IPv6|2001:db8::10']);
      await monitor.checkNow();

      expect(emitted.map((snapshot) => snapshot.available), <bool>[
        false,
        true,
      ]);
      await subscription.cancel();
      await monitor.dispose();
    },
  );

  test('serializes overlapping samples', () async {
    final pending = Completer<NetworkSnapshot>();
    var calls = 0;
    final monitor = WindowsNetworkMonitor(
      interval: const Duration(hours: 1),
      loader: () {
        calls++;
        return calls == 1
            ? Future<NetworkSnapshot>.value(NetworkSnapshot(<String>['A']))
            : pending.future;
      },
    );

    await monitor.start();
    final first = monitor.checkNow();
    await monitor.checkNow();
    expect(calls, 2);
    pending.complete(NetworkSnapshot(<String>['B']));
    await first;
    await monitor.dispose();
  });
}

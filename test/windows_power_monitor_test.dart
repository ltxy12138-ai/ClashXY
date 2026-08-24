import 'package:clashxy/core/runtime/system_power_monitor.dart';
import 'package:clashxy/platform/windows/windows_power_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps native suspend and resume events without duplicates', () async {
    final source = _FakePowerEventSource();
    final monitor = WindowsPowerMonitor(source: source);
    final events = <SystemPowerEvent>[];
    final subscription = monitor.events.listen(events.add);

    await monitor.start();
    await monitor.start();
    source.emit('unrelated');
    source.emit('suspend');
    source.emit('suspend');
    source.emit('resume');
    source.emit('resume');

    expect(events, <SystemPowerEvent>[
      SystemPowerEvent.suspend,
      SystemPowerEvent.resume,
    ]);
    expect(source.attachments, 1);

    await subscription.cancel();
    await monitor.dispose();
  });

  test('detaches the native listener when disposed', () async {
    final source = _FakePowerEventSource();
    final monitor = WindowsPowerMonitor(source: source);
    await monitor.start();

    await monitor.dispose();

    expect(source.listener, isNull);
    expect(source.detachments, 1);
    source.emit('resume');
  });
}

class _FakePowerEventSource implements WindowsPowerEventSource {
  WindowsPowerEventListener? listener;
  int attachments = 0;
  int detachments = 0;

  @override
  void setListener(WindowsPowerEventListener? listener) {
    this.listener = listener;
    if (listener == null) {
      detachments++;
    } else {
      attachments++;
    }
  }

  void emit(String event) => listener?.call(event);
}

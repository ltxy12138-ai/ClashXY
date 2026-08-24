import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/runtime/system_power_monitor.dart';

typedef WindowsPowerEventListener = void Function(String event);

abstract interface class WindowsPowerEventSource {
  void setListener(WindowsPowerEventListener? listener);
}

class MethodChannelWindowsPowerEventSource implements WindowsPowerEventSource {
  MethodChannelWindowsPowerEventSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.clashxy.app/system_power';

  final MethodChannel _channel;

  @override
  void setListener(WindowsPowerEventListener? listener) {
    _channel.setMethodCallHandler(
      listener == null
          ? null
          : (call) async {
              listener(call.method);
            },
    );
  }
}

class WindowsPowerMonitor implements SystemPowerMonitor {
  WindowsPowerMonitor({WindowsPowerEventSource? source})
    : _source = source ?? MethodChannelWindowsPowerEventSource();

  final WindowsPowerEventSource _source;
  final StreamController<SystemPowerEvent> _events =
      StreamController<SystemPowerEvent>.broadcast(sync: true);

  SystemPowerEvent? _lastEvent;
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<SystemPowerEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    if (_disposed || _started) return;
    _started = true;
    _source.setListener(_handleNativeEvent);
  }

  void _handleNativeEvent(String method) {
    if (_disposed) return;
    final event = switch (method) {
      'suspend' => SystemPowerEvent.suspend,
      'resume' => SystemPowerEvent.resume,
      _ => null,
    };
    if (event == null || event == _lastEvent) return;
    _lastEvent = event;
    _events.add(event);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _source.setListener(null);
    await _events.close();
  }
}

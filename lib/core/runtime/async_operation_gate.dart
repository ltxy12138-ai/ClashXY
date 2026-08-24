import 'dart:async';
import 'dart:collection';

class AsyncOperationGate {
  bool _active = false;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  bool get active => _active;

  Future<bool> run(Future<void> Function() operation) async {
    if (_active) return false;
    _active = true;
    try {
      await operation();
      return true;
    } finally {
      _releaseNext();
    }
  }

  Future<void> enqueue(Future<void> Function() operation) async {
    if (_active) {
      final ready = Completer<void>();
      _waiters.addLast(ready);
      await ready.future;
    } else {
      _active = true;
    }
    try {
      await operation();
    } finally {
      _releaseNext();
    }
  }

  void _releaseNext() {
    if (_waiters.isEmpty) {
      _active = false;
      return;
    }
    _waiters.removeFirst().complete();
  }
}

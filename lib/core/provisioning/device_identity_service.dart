import 'dart:io';
import 'dart:math';

import '../storage/secure_storage.dart';

String resolveManagedDeviceDisplayName(String? requested, String clientId) {
  final normalized = requested?.trim() ?? '';
  return normalized.isEmpty ? clientId : normalized;
}

class DeviceIdentityService {
  DeviceIdentityService(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  final SecureStorage _storage;
  final Random _random;

  static const String _key = 'device.identity';

  Future<String> getOrCreate() async {
    final existing = await _storage.read(_key);
    if (existing != null && _valid.hasMatch(existing)) return existing;
    final machine = (Platform.environment['COMPUTERNAME'] ?? 'windows')
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = List<int>.generate(
      6,
      (_) => _random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final identity = 'clashxy-${machine.isEmpty ? 'device' : machine}-$suffix';
    await _storage.write(_key, identity);
    return identity;
  }

  static final RegExp _valid = RegExp(
    // Keep accepting identities created by releases before the ClashXY rename.
    r'^(?:clashxy|mytunnel|mymihomo)-[a-z0-9_-]+-[0-9a-f]{12}$',
  );
}

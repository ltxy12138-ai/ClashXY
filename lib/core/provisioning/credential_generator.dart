import 'dart:math';

class DeviceCredentials {
  const DeviceCredentials({
    required this.uuid,
    required this.sharedPassword,
    required this.shortPassword,
    required this.longPassword,
  });

  final String uuid;
  final String sharedPassword;
  final String shortPassword;
  final String longPassword;
}

class CredentialGenerator {
  CredentialGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  DeviceCredentials generate() {
    return DeviceCredentials(
      uuid: _uuidV4(),
      sharedPassword: _hex(16),
      shortPassword: _hex(8),
      longPassword: _hex(16),
    );
  }

  String _hex(int bytes) => List<int>.generate(
    bytes,
    (_) => _random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

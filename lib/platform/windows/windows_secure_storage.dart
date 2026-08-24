import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/storage/secure_storage.dart';

class WindowsSecureStorage implements SecureStorage {
  const WindowsSecureStorage({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

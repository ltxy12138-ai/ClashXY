abstract interface class SecureStorage {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);
}

class SecureKeys {
  const SecureKeys._();

  static String panelPassword(String panelId) => 'panel.$panelId.password';
  static String panelToken(String panelId) => 'panel.$panelId.token';
  static String standaloneProfile(String profileId) =>
      'standalone.profile.$profileId';
}

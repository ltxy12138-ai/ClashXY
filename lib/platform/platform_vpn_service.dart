abstract interface class PlatformVpnService {
  Future<bool> isAdministrator();

  Future<bool> adapterExists(String deviceName);

  Future<List<String>> activeMihomoTunAdapters();

  Future<bool> hasInternetConnectivity();

  Future<void> cleanupStaleNetworkState({
    required String deviceName,
    required String coreExecutablePath,
  });
}

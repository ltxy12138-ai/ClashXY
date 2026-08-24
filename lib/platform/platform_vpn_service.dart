abstract interface class PlatformVpnService {
  Future<bool> isAdministrator();

  Future<bool> adapterExists(String deviceName);

  Future<List<String>> activeMihomoTunAdapters();

  Future<bool> hasInternetConnectivity();
}

import '../../models/panel_models.dart';

abstract interface class PanelConnector {
  Future<PanelSession> login(LoginRequest request);

  Future<void> logout();

  Future<ProvisionedToken> createToken({
    required String description,
    required DateTime expiresAt,
  });

  Future<void> useToken(String token);

  Future<void> deleteToken(String tokenId);

  Future<List<Inbound>> listInbounds();

  Future<List<RemoteClient>> listClients();

  Future<RemoteClient> getClient(int id);

  Future<RemoteClient> createClient(CreateClientRequest request);

  Future<RemoteClient> updateClient(UpdateClientRequest request);

  Future<void> deleteClient(int id);

  Future<ServerStatus> getServerStatus();

  Future<TrafficStats> getTraffic();

  Future<List<OnlineClient>> listOnlineClients();
}

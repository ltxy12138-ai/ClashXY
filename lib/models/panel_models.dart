enum PanelProtocol { http, https }

class PanelAccount {
  const PanelAccount({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.createdAt,
    this.tokenId,
  });

  final String id;
  final String name;
  final Uri baseUrl;
  final String username;
  final DateTime createdAt;
  final String? tokenId;
}

class LoginRequest {
  const LoginRequest({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.code = '',
  });

  final Uri baseUrl;
  final String username;
  final String password;
  final String code;
}

class PanelSession {
  const PanelSession({required this.requiresTwoFactor});

  final bool requiresTwoFactor;
}

class ProvisionedToken {
  const ProvisionedToken({required this.id, required this.value});

  final String id;
  final String value;
}

class Inbound {
  const Inbound({
    required this.id,
    required this.tag,
    required this.protocol,
    required this.port,
    required this.enabled,
  });

  final int id;
  final String tag;
  final String protocol;
  final int port;
  final bool enabled;
}

class RemoteClient {
  const RemoteClient({
    required this.id,
    required this.name,
    required this.enabled,
    required this.raw,
    this.links = const <String>[],
  });

  final int id;
  final String name;
  final bool enabled;
  final Map<String, Object?> raw;
  final List<String> links;
}

class CreateClientRequest {
  const CreateClientRequest({required this.name, required this.configuration});

  final String name;
  final Map<String, Object?> configuration;
}

class UpdateClientRequest {
  const UpdateClientRequest({required this.client});

  final RemoteClient client;
}

class ServerStatus {
  const ServerStatus({
    required this.running,
    required this.uptimeSeconds,
    required this.version,
  });

  final bool running;
  final int uptimeSeconds;
  final String version;
}

class TrafficStats {
  const TrafficStats({required this.uploadBytes, required this.downloadBytes});

  final int uploadBytes;
  final int downloadBytes;
}

class OnlineClient {
  const OnlineClient({required this.id, required this.name, this.ipAddress});

  final int id;
  final String name;
  final String? ipAddress;
}

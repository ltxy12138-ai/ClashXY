import '../../models/panel_models.dart';
import '../panel/panel_connector.dart';
import 'credential_generator.dart';

class RemoteClientProvisioner {
  const RemoteClientProvisioner(this._panel);

  final PanelConnector _panel;

  Future<RemoteClient> create({
    required String deviceName,
    required List<Inbound> inbounds,
    required DeviceCredentials credentials,
  }) {
    final config = <String, Object?>{
      'mixed': {'username': deviceName, 'password': credentials.sharedPassword},
      'socks': {'username': deviceName, 'password': credentials.sharedPassword},
      'http': {'username': deviceName, 'password': credentials.sharedPassword},
      'shadowsocks': {'name': deviceName, 'password': credentials.longPassword},
      'shadowsocks16': {
        'name': deviceName,
        'password': credentials.shortPassword,
      },
      'shadowtls': {'name': deviceName, 'password': credentials.longPassword},
      'vmess': {'name': deviceName, 'uuid': credentials.uuid, 'alterId': 0},
      'vless': {
        'name': deviceName,
        'uuid': credentials.uuid,
        'flow': 'xtls-rprx-vision',
      },
      'anytls': {'name': deviceName, 'password': credentials.sharedPassword},
      'trojan': {'name': deviceName, 'password': credentials.sharedPassword},
      'naive': {'username': deviceName, 'password': credentials.sharedPassword},
      'hysteria': {'name': deviceName, 'auth_str': credentials.sharedPassword},
      'tuic': {
        'name': deviceName,
        'uuid': credentials.uuid,
        'password': credentials.sharedPassword,
      },
      'hysteria2': {'name': deviceName, 'password': credentials.sharedPassword},
    };
    return _panel.createClient(
      CreateClientRequest(
        name: deviceName,
        configuration: <String, Object?>{
          'enable': true,
          'config': config,
          'inbounds': inbounds.map((inbound) => inbound.id).toList(),
          'links': <Object?>[],
          'volume': 0,
          'expiry': 0,
          'desc': 'Managed by ClashXY',
          'group': 'ClashXY',
          'limitIp': 0,
          'delayStart': false,
          'autoReset': true,
          'resetDays': 30,
          'nextReset': 0,
        },
      ),
    );
  }

  Future<void> delete(int id) => _panel.deleteClient(id);
}

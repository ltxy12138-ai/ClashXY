import 'dart:convert';

import '../../models/profile_models.dart';

class ProfileCodec {
  const ProfileCodec();

  String encode(ConnectionProfile profile) {
    return jsonEncode(<String, Object?>{
      'id': profile.id,
      'panelId': profile.panelId,
      'remoteClientId': profile.remoteClientId,
      'displayName': profile.displayName,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt?.toIso8601String(),
      'autoUpdateMinutes': profile.autoUpdateInterval.inMinutes,
      'origin': profile.origin.name,
      'rawConfig': profile.rawConfig,
      'subscriptionUrl': profile.subscriptionUrl?.toString(),
      'proxies': profile.proxies
          .map(
            (proxy) => <String, Object?>{
              'name': proxy.name,
              'protocol': proxy.protocol.name,
              'server': proxy.server,
              'port': proxy.port,
              'authentication': proxy.authentication,
              'options': proxy.options,
            },
          )
          .toList(),
    });
  }

  ConnectionProfile decode(String value) {
    final map = jsonDecode(value) as Map<String, Object?>;
    final proxyRows = (map['proxies'] as List? ?? const <Object?>[])
        .cast<Map>();
    final originName = map['origin'] as String?;
    final subscriptionUrl = map['subscriptionUrl'] as String?;
    final updatedAt = map['updatedAt'] as String?;
    return ConnectionProfile(
      id: map['id']! as String,
      panelId: map['panelId'] as String? ?? '',
      remoteClientId: map['remoteClientId'] as int? ?? 0,
      displayName: map['displayName']! as String,
      createdAt: DateTime.parse(map['createdAt']! as String),
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt),
      autoUpdateInterval: Duration(
        minutes: map['autoUpdateMinutes'] as int? ?? 0,
      ),
      origin: originName == null
          ? ProfileOrigin.twoSui
          : ProfileOrigin.values.byName(originName),
      rawConfig: _asStringMap(map['rawConfig']),
      subscriptionUrl: subscriptionUrl == null
          ? null
          : Uri.parse(subscriptionUrl),
      proxies: proxyRows
          .map((row) {
            final options = (row['options']! as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
            return ProxyProfile(
              name: row['name']! as String,
              protocol: ProxyProtocol.values.byName(row['protocol']! as String),
              server: row['server']! as String,
              port: row['port']! as int,
              authentication: row['authentication']! as String,
              options: options,
            );
          })
          .toList(growable: false),
    );
  }

  Map<String, Object?>? _asStringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}

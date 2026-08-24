import '../../core/errors/app_exception.dart';
import '../../models/profile_models.dart';

class ProfileFactory {
  const ProfileFactory();

  ProxyProfile parseLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty || uri.port <= 0) {
      throw const ProvisioningException(
        '2S-UI returned an invalid client link.',
      );
    }

    return switch (uri.scheme.toLowerCase()) {
      'vless' => _parseVless(uri),
      'hysteria2' || 'hy2' => _parseHysteria2(uri),
      _ => throw ProvisioningException(
        'Unsupported proxy protocol: ${uri.scheme}',
      ),
    };
  }

  List<ProxyProfile> parseLinks(Iterable<String> links) {
    final profiles = links.map(parseLink).toList(growable: false);
    if (profiles.isEmpty) {
      throw const ProvisioningException(
        '2S-UI did not return any client links.',
      );
    }
    return profiles;
  }

  ProxyProfile _parseVless(Uri uri) {
    final query = uri.queryParameters;
    final security = query['security'];
    final publicKey = query['pbk'];
    final shortId = query['sid'];
    final serverName = query['sni'];
    if (security != 'reality' ||
        publicKey == null ||
        publicKey.isEmpty ||
        shortId == null ||
        shortId.isEmpty ||
        serverName == null ||
        serverName.isEmpty) {
      throw const ProvisioningException(
        'VLESS link is missing required REALITY parameters.',
      );
    }

    final uuid = uri.userInfo;
    if (!_uuid.hasMatch(uuid)) {
      throw const ProvisioningException('VLESS link contains an invalid UUID.');
    }

    return ProxyProfile(
      name: _displayName(uri, 'VLESS'),
      protocol: ProxyProtocol.vlessReality,
      server: uri.host,
      port: uri.port,
      authentication: uuid,
      options: <String, String>{
        ...query,
        'security': 'reality',
        'pbk': publicKey,
        'sid': shortId,
        'sni': serverName,
      },
    );
  }

  ProxyProfile _parseHysteria2(Uri uri) {
    final password = uri.userInfo;
    if (password.isEmpty) {
      throw const ProvisioningException(
        'Hysteria2 link does not contain a password.',
      );
    }
    return ProxyProfile(
      name: _displayName(uri, 'Hysteria2'),
      protocol: ProxyProtocol.hysteria2,
      server: uri.host,
      port: uri.port,
      authentication: password,
      options: Map<String, String>.from(uri.queryParameters),
    );
  }

  String _displayName(Uri uri, String fallback) {
    final fragment = Uri.decodeComponent(uri.fragment).trim();
    return fragment.isEmpty ? fallback : fragment;
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
}

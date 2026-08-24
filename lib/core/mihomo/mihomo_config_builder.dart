import 'dart:math';

import '../../core/errors/app_exception.dart';
import '../../models/app_settings.dart';
import '../../models/profile_models.dart';

class MihomoRuntimeConfig {
  const MihomoRuntimeConfig({required this.document, required this.secret});

  final Map<String, Object?> document;
  final String secret;
}

class MihomoConfigBuilder {
  MihomoConfigBuilder({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  MihomoRuntimeConfig build(ConnectionProfile profile, AppSettings settings) {
    final secret = _hex(24);
    final imported = profile.rawConfig;
    if (imported != null) {
      return MihomoRuntimeConfig(
        secret: secret,
        document: _secureImportedConfig(imported, settings, secret),
      );
    }
    if (profile.proxies.isEmpty) {
      throw const MihomoException('连接配置中没有可用代理。');
    }
    final proxies = profile.proxies.map(_proxy).toList(growable: false);
    final names = profile.proxies
        .map((proxy) => proxy.name)
        .toList(growable: false);
    return MihomoRuntimeConfig(
      secret: secret,
      document: <String, Object?>{
        'mixed-port': settings.mixedPort,
        'allow-lan': settings.allowLan,
        'bind-address': settings.allowLan ? '*' : '127.0.0.1',
        'mode': 'rule',
        'log-level': settings.logsEnabled ? 'info' : 'silent',
        'ipv6': settings.ipv6Enabled,
        'external-controller': '127.0.0.1:${settings.controllerPort}',
        'secret': secret,
        'tun': _tunConfig(settings),
        'dns': _defaultDns(settings),
        if (settings.snifferOverrideEnabled)
          'sniffer': _snifferConfig(settings.snifferEnabled),
        'proxies': proxies,
        'proxy-groups': <Object?>[
          <String, Object?>{
            'name': 'CLASHXY',
            'type': 'select',
            'proxies': names,
          },
        ],
        'rules': <String>['MATCH,CLASHXY'],
      },
    );
  }

  Map<String, Object?> _secureImportedConfig(
    Map<String, Object?> source,
    AppSettings settings,
    String secret,
  ) {
    final document = _deepCopyMap(source);
    final proxies = document['proxies'];
    final providers = document['proxy-providers'];
    if (!(proxies is List && proxies.isNotEmpty) &&
        !(providers is Map && providers.isNotEmpty)) {
      throw const MihomoException('导入配置中没有 proxies 或 proxy-providers。');
    }

    for (final key in const <String>[
      'external-controller-tls',
      'external-controller-cors',
      'external-ui',
      'external-ui-name',
      'external-ui-url',
    ]) {
      document.remove(key);
    }
    if (!settings.allowLan) document.remove('authentication');
    document
      ..['mixed-port'] = settings.mixedPort
      ..['allow-lan'] = settings.allowLan
      ..['bind-address'] = settings.allowLan ? '*' : '127.0.0.1'
      ..['log-level'] = settings.logsEnabled ? 'info' : 'silent'
      ..['ipv6'] = settings.ipv6Enabled
      ..['external-controller'] = '127.0.0.1:${settings.controllerPort}'
      ..['secret'] = secret;

    final importedTun = _asMap(document['tun']);
    document['tun'] = <String, Object?>{
      ...importedTun,
      ..._tunConfig(settings),
    };

    final importedDns = _asMap(document['dns']);
    if (settings.dnsOverrideEnabled) {
      document['dns'] = _defaultDns(settings);
    } else if (settings.tunEnabled) {
      document['dns'] = <String, Object?>{
        ..._defaultDns(settings),
        ...importedDns,
        'enable': true,
        'listen': '127.0.0.1:${settings.dnsListenPort}',
      };
    } else if (importedDns.isNotEmpty) {
      document['dns'] = <String, Object?>{
        ...importedDns,
        if (importedDns['listen'] != null)
          'listen': '127.0.0.1:${settings.dnsListenPort}',
      };
    }
    if (settings.snifferOverrideEnabled) {
      document['sniffer'] = _snifferConfig(settings.snifferEnabled);
    }
    return document;
  }

  Map<String, Object?> _tunConfig(AppSettings settings) => <String, Object?>{
    'enable': settings.tunEnabled,
    'stack': settings.tunStack,
    'device': settings.tunDevice,
    'mtu': settings.tunMtu,
    if (settings.dnsEnabled) 'dns-hijack': <String>['any:53'],
    'auto-route': settings.tunAutoRoute,
    'auto-detect-interface': settings.tunAutoDetectInterface,
    'strict-route': settings.tunStrictRoute,
  };

  Map<String, Object?> _defaultDns(AppSettings settings) => <String, Object?>{
    'enable': settings.dnsEnabled,
    'listen': '127.0.0.1:${settings.dnsListenPort}',
    'enhanced-mode': settings.dnsMode,
    'fake-ip-range': '198.18.0.1/16',
    'nameserver': <String>[settings.dnsNameserver],
  };

  Map<String, Object?> _snifferConfig(bool enabled) => <String, Object?>{
    'enable': enabled,
    'force-dns-mapping': true,
    'parse-pure-ip': true,
    'sniff': <String, Object?>{
      'HTTP': <String, Object?>{
        'ports': <String>['80', '8080-8880'],
      },
      'TLS': <String, Object?>{
        'ports': <String>['443', '8443'],
      },
      'QUIC': <String, Object?>{
        'ports': <String>['443', '8443'],
      },
    },
  };

  Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) return <String, Object?>{};
    return value.map((key, item) => MapEntry(key.toString(), _deepCopy(item)));
  }

  Map<String, Object?> _deepCopyMap(Map<String, Object?> value) {
    return value.map((key, item) => MapEntry(key, _deepCopy(item)));
  }

  Object? _deepCopy(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _deepCopy(item)),
      );
    }
    if (value is List) {
      return value.map<Object?>(_deepCopy).toList(growable: false);
    }
    return value;
  }

  Map<String, Object?> _proxy(ProxyProfile profile) {
    return switch (profile.protocol) {
      ProxyProtocol.vlessReality => <String, Object?>{
        'name': profile.name,
        'type': 'vless',
        'server': profile.server,
        'port': profile.port,
        'uuid': profile.authentication,
        'network': profile.options['type'] ?? 'tcp',
        'tls': true,
        'udp': true,
        'servername': profile.options['sni'],
        'flow': profile.options['flow'] ?? 'xtls-rprx-vision',
        'client-fingerprint': profile.options['fp'] ?? 'chrome',
        'reality-opts': <String, Object?>{
          'public-key': profile.options['pbk'],
          'short-id': profile.options['sid'],
        },
      },
      ProxyProtocol.hysteria2 => <String, Object?>{
        'name': profile.name,
        'type': 'hysteria2',
        'server': profile.server,
        'port': profile.port,
        'password': profile.authentication,
        if (profile.options['sni'] != null) 'sni': profile.options['sni'],
        'skip-cert-verify':
            profile.options['insecure'] == '1' ||
            profile.options['insecure'] == 'true',
        if (profile.options['obfs'] != null) 'obfs': profile.options['obfs'],
        if (profile.options['obfs-password'] != null)
          'obfs-password': profile.options['obfs-password'],
      },
    };
  }

  String _hex(int bytes) => List<int>.generate(
    bytes,
    (_) => _random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

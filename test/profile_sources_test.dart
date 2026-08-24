import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clashxy/core/mihomo/mihomo_config_builder.dart';
import 'package:clashxy/core/profiles/clash_config_parser.dart';
import 'package:clashxy/core/profiles/profile_import_service.dart';
import 'package:clashxy/core/storage/profile_codec.dart';
import 'package:clashxy/models/app_settings.dart';
import 'package:clashxy/models/profile_models.dart';

void main() {
  group('Clash config import', () {
    test('accepts proxies and normalizes YAML collections', () {
      const yaml = '''
proxies:
  - name: Edge
    type: socks5
    server: edge.example.test
    port: 1080
proxy-groups:
  - name: AUTO
    type: select
    proxies: [Edge]
rules:
  - MATCH,AUTO
''';
      final config = const ClashConfigParser().parse(yaml);
      expect(config['proxies'], isA<List<Object?>>());
      expect(config['proxy-groups'], isA<List<Object?>>());
      expect(config['rules'], <Object?>['MATCH,AUTO']);
    });

    test('accepts provider-only configs and rejects empty configs', () {
      final config = const ClashConfigParser().parse('''
proxy-providers:
  airport:
    type: http
    url: https://example.test/provider.yaml
''');
      expect(config['proxy-providers'], isA<Map<String, Object?>>());
      expect(
        () => const ClashConfigParser().parse('mode: rule'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'subscription requires HTTPS and produces standalone profile',
      () async {
        final client = MockClient((request) async {
          expect(request.headers['user-agent'], 'clash.meta');
          return http.Response(
            'proxies:\n  - {name: Edge, type: socks5, server: edge.test, port: 1}',
            200,
          );
        });
        final service = ProfileImportService(client: client);
        final profile = await service.fromSubscription(
          name: '机场订阅',
          url: Uri.parse('https://example.test/sub'),
        );
        expect(profile.origin, ProfileOrigin.subscription);
        expect(profile.subscriptionUrl, Uri.parse('https://example.test/sub'));
        expect(profile.rawConfig?['proxies'], isNotEmpty);
        expect(profile.updatedAt, isNotNull);
        expect(profile.autoUpdateInterval, const Duration(days: 1));
        expect(
          () => service.fromSubscription(
            name: '不安全',
            url: Uri.parse('http://example.test/sub'),
          ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('profile codec', () {
    test('decodes legacy 2S-UI profile without origin fields', () {
      final legacy = jsonEncode(<String, Object?>{
        'id': 'legacy',
        'panelId': 'primary',
        'remoteClientId': 7,
        'displayName': '旧设备',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'proxies': <Object?>[],
      });
      final profile = const ProfileCodec().decode(legacy);
      expect(profile.origin, ProfileOrigin.twoSui);
      expect(profile.isStandalone, isFalse);
      expect(profile.updatedAt, isNull);
      expect(profile.autoUpdateInterval, Duration.zero);
    });

    test('round-trips subscription URL and complete config', () {
      final profile = ConnectionProfile(
        id: 'source-1',
        panelId: '',
        remoteClientId: 0,
        displayName: '订阅',
        proxies: const <ProxyProfile>[],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 8, 21),
        autoUpdateInterval: const Duration(hours: 12),
        origin: ProfileOrigin.subscription,
        rawConfig: const <String, Object?>{
          'proxies': <Object?>[
            <String, Object?>{'name': 'Edge'},
          ],
        },
        subscriptionUrl: Uri.parse('https://example.test/secret-token'),
      );
      final decoded = const ProfileCodec().decode(
        const ProfileCodec().encode(profile),
      );
      expect(decoded.origin, ProfileOrigin.subscription);
      expect(decoded.subscriptionUrl, profile.subscriptionUrl);
      expect(decoded.updatedAt, DateTime.utc(2026, 8, 21));
      expect(decoded.autoUpdateInterval, const Duration(hours: 12));
      expect(decoded.rawConfig?['proxies'], isNotEmpty);
    });
  });

  test(
    'imported config keeps Clash behavior but enforces local boundaries',
    () {
      final source = <String, Object?>{
        'allow-lan': true,
        'bind-address': '*',
        'external-controller': '0.0.0.0:9090',
        'external-ui': '/unsafe/path',
        'secret': 'attacker-controlled',
        'mode': 'global',
        'proxies': <Object?>[
          <String, Object?>{
            'name': 'Edge',
            'type': 'socks5',
            'server': 'edge.test',
            'port': 1080,
          },
        ],
        'proxy-groups': <Object?>[
          <String, Object?>{
            'name': 'SELECT',
            'type': 'select',
            'proxies': <Object?>['Edge'],
          },
        ],
        'rules': <Object?>['MATCH,SELECT'],
        'dns': <String, Object?>{'listen': '0.0.0.0:53'},
      };
      final result = MihomoConfigBuilder().build(
        ConnectionProfile(
          id: 'custom',
          panelId: '',
          remoteClientId: 0,
          displayName: '自定义',
          proxies: const <ProxyProfile>[],
          createdAt: DateTime.utc(2026),
          origin: ProfileOrigin.custom,
          rawConfig: source,
        ),
        const AppSettings(),
      );
      expect(result.document['allow-lan'], isFalse);
      expect(result.document['bind-address'], '127.0.0.1');
      expect(result.document['external-controller'], '127.0.0.1:9099');
      expect(result.document['secret'], result.secret);
      expect(result.document['secret'], isNot('attacker-controlled'));
      expect(result.document, isNot(contains('external-ui')));
      expect(result.document['mode'], 'global');
      expect(result.document['rules'], <Object?>['MATCH,SELECT']);
      expect((result.document['tun']! as Map)['enable'], isTrue);
      expect((result.document['dns']! as Map)['listen'], '127.0.0.1:1053');
      expect(source['external-controller'], '0.0.0.0:9090');
    },
  );

  test('advanced settings safely override network, TUN, DNS, and sniffer', () {
    final source = <String, Object?>{
      'authentication': <String>['user:password'],
      'proxies': <Object?>[
        <String, Object?>{
          'name': 'Edge',
          'type': 'socks5',
          'server': 'edge.test',
          'port': 1080,
        },
      ],
      'dns': <String, Object?>{
        'enable': false,
        'nameserver': <String>['https://old.example/dns-query'],
      },
      'sniffer': <String, Object?>{'enable': false},
    };
    final result = MihomoConfigBuilder().build(
      ConnectionProfile(
        id: 'advanced',
        panelId: '',
        remoteClientId: 0,
        displayName: 'Advanced',
        proxies: const <ProxyProfile>[],
        createdAt: DateTime.utc(2026),
        origin: ProfileOrigin.custom,
        rawConfig: source,
      ),
      const AppSettings(
        mixedPort: 7891,
        allowLan: true,
        tunStack: 'system',
        tunMtu: 1500,
        tunStrictRoute: false,
        dnsOverrideEnabled: true,
        dnsMode: 'redir-host',
        dnsListenPort: 1054,
        dnsNameserver: 'https://dns.example/dns-query',
        snifferOverrideEnabled: true,
        snifferEnabled: true,
      ),
    );

    expect(result.document['allow-lan'], isTrue);
    expect(result.document['bind-address'], '*');
    expect(result.document['authentication'], <String>['user:password']);
    final tun = result.document['tun']! as Map;
    expect(tun['stack'], 'system');
    expect(tun['mtu'], 1500);
    expect(tun['strict-route'], isFalse);
    final dns = result.document['dns']! as Map;
    expect(dns['listen'], '127.0.0.1:1054');
    expect(dns['enhanced-mode'], 'redir-host');
    expect(dns['nameserver'], <String>['https://dns.example/dns-query']);
    expect((result.document['sniffer']! as Map)['enable'], isTrue);
  });

  test('advanced YAML replacement preserves profile identity and source', () {
    final service = ProfileImportService();
    addTearDown(service.dispose);
    final original = ConnectionProfile(
      id: 'source-1',
      panelId: '',
      remoteClientId: 0,
      displayName: 'Subscription',
      proxies: const <ProxyProfile>[],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
      origin: ProfileOrigin.subscription,
      rawConfig: const <String, Object?>{
        'proxies': <Object?>[
          <String, Object?>{'name': 'Old'},
        ],
      },
      subscriptionUrl: Uri.parse('https://example.test/sub'),
    );

    final updated = service.replaceYaml(
      profile: original,
      yaml: 'proxies:\n  - {name: New, type: direct}',
    );

    expect(updated.id, original.id);
    expect(updated.origin, ProfileOrigin.subscription);
    expect(updated.subscriptionUrl, original.subscriptionUrl);
    expect(
      (updated.rawConfig!['proxies']! as List).single,
      containsPair('name', 'New'),
    );
    expect(updated.updatedAt, isNot(original.updatedAt));
  });
}

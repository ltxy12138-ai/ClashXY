import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:clashxy/core/mihomo/mihomo_config_builder.dart';
import 'package:clashxy/core/mihomo/process_manager.dart';
import 'package:clashxy/core/panel/two_sui_http_client.dart';
import 'package:clashxy/core/provisioning/credential_generator.dart';
import 'package:clashxy/core/provisioning/device_identity_service.dart';
import 'package:clashxy/core/provisioning/inbound_selector.dart';
import 'package:clashxy/core/provisioning/profile_factory.dart';
import 'package:clashxy/core/provisioning/profile_validator.dart';
import 'package:clashxy/core/runtime/async_operation_gate.dart';
import 'package:clashxy/core/security/secret_redactor.dart';
import 'package:clashxy/core/security/app_logger.dart';
import 'package:clashxy/models/app_settings.dart';
import 'package:clashxy/models/panel_models.dart';
import 'package:clashxy/models/profile_models.dart';

void main() {
  group('security boundaries', () {
    test('panel URLs require HTTPS and normalize a trailing slash', () {
      expect(
        TwoSuiHttpClient.normalizePanelUrl(Uri.parse('https://panel.test/app')),
        Uri.parse('https://panel.test/app/'),
      );
      expect(
        () => TwoSuiHttpClient.normalizePanelUrl(
          Uri.parse('http://panel.test/app/'),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('redactor removes key values, bearer tokens and URI credentials', () {
      const redactor = SecretRedactor();
      final value = redactor.redact(
        'PASSWORD=hunter2 Authorization:abc Bearer token.value '
        'vless://uuid-secret@example.test:443',
      );
      expect(value, isNot(contains('hunter2')));
      expect(value, isNot(contains('token.value')));
      expect(value, isNot(contains('uuid-secret')));
      expect(value, contains('<redacted>'));
    });
  });

  group('Mihomo startup diagnostics', () {
    test(
      'turns the observed Windows TUN conflict into an actionable error',
      () async {
        final process = ProcessManager(const RedactingLogger());
        expect(
          process.describeFailure(
            1,
            output: 'configure tun interface: set ipv4 address: The object already exists',
          ),
          contains('其他 VPN/Clash 客户端冲突'),
        );
        await process.dispose();
      },
    );

    test('turns a listener collision into a port conflict error', () async {
      final process = ProcessManager(const RedactingLogger());
      expect(
        process.describeFailure(
          1,
          output: 'listen tcp: address already in use',
        ),
        contains('端口已被其他应用占用'),
      );
      await process.dispose();
    });

    test('explains GeoIP bootstrap failures without exposing URLs', () async {
      final process = ProcessManager(const RedactingLogger());
      expect(
        process.describeFailure(
          1,
          output: 'failed to download geoip.metadb: connection timeout',
        ),
        contains('保持现有网络代理可用'),
      );
      await process.dispose();
    });
  });

  test('connection operation gate drops duplicate clicks', () async {
    final gate = AsyncOperationGate();
    final entered = Completer<void>();
    final release = Completer<void>();
    var calls = 0;

    final first = gate.run(() async {
      calls++;
      entered.complete();
      await release.future;
    });
    await entered.future;
    final duplicateAccepted = await gate.run(() async => calls++);
    release.complete();

    expect(duplicateAccepted, isFalse);
    expect(await first, isTrue);
    expect(calls, 1);
  });

  test('queued lifecycle work waits for the active operation', () async {
    final gate = AsyncOperationGate();
    final entered = Completer<void>();
    final release = Completer<void>();
    final order = <String>[];

    final active = gate.run(() async {
      order.add('active-start');
      entered.complete();
      await release.future;
      order.add('active-end');
    });
    await entered.future;
    final queued = gate.enqueue(() async => order.add('queued'));

    await Future<void>.delayed(Duration.zero);
    expect(order, <String>['active-start']);
    release.complete();
    await active;
    await queued;

    expect(order, <String>['active-start', 'active-end', 'queued']);
    expect(gate.active, isFalse);
  });

  group('provisioning', () {
    const factory = ProfileFactory();

    test('keeps a human display name separate from the client ID', () {
      expect(
        resolveManagedDeviceDisplayName(
          '  上海办公电脑  ',
          'clashxy-pc-bba5df2d6b3a',
        ),
        '上海办公电脑',
      );
    });

    test('falls back to the client ID when no display name is supplied', () {
      const clientId = 'clashxy-pc-bba5df2d6b3a';
      expect(resolveManagedDeviceDisplayName(null, clientId), clientId);
      expect(resolveManagedDeviceDisplayName('   ', clientId), clientId);
    });

    test('parses and validates VLESS REALITY', () {
      final profile = factory.parseLink(
        'vless://550e8400-e29b-41d4-a716-446655440000@edge.example.test:443'
        '?security=reality&pbk=public-key&sid=a1b2c3d4&sni=cdn.example.test'
        '&fp=chrome&flow=xtls-rprx-vision#Edge',
      );
      expect(profile.protocol, ProxyProtocol.vlessReality);
      expect(profile.server, 'edge.example.test');
      expect(profile.name, 'Edge');
      expect(() => const ProfileValidator().validate(profile), returnsNormally);
    });

    test('parses Hysteria2', () {
      final profile = factory.parseLink(
        'hysteria2://password@hy2.example.test:8443?sni=cdn.example.test#HY2',
      );
      expect(profile.protocol, ProxyProtocol.hysteria2);
      expect(profile.authentication, 'password');
    });

    test('selects automatic supported inbounds only', () {
      final selected = const InboundSelector().select(const <Inbound>[
        Inbound(id: 1, tag: 'vmess', protocol: 'vmess', port: 1, enabled: true),
        Inbound(
          id: 2,
          tag: 'vless',
          protocol: 'vless',
          port: 443,
          enabled: true,
        ),
        Inbound(
          id: 3,
          tag: 'hy2',
          protocol: 'hysteria2',
          port: 8443,
          enabled: true,
        ),
      ], InboundPreference.automatic);
      expect(selected.map((inbound) => inbound.id), <int>[2, 3]);
    });

    test('credentials contain a UUID v4 and independent passwords', () {
      final credentials = CredentialGenerator().generate();
      expect(
        credentials.uuid,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(credentials.sharedPassword, hasLength(32));
      expect(credentials.shortPassword, hasLength(16));
    });
  });

  test('Mihomo config is structured and enables Windows TUN', () {
    const proxy = ProxyProfile(
      name: 'Edge',
      protocol: ProxyProtocol.vlessReality,
      server: 'edge.example.test',
      port: 443,
      authentication: '550e8400-e29b-41d4-a716-446655440000',
      options: <String, String>{
        'security': 'reality',
        'pbk': 'public-key',
        'sid': 'a1b2c3d4',
        'sni': 'cdn.example.test',
      },
    );
    final config = MihomoConfigBuilder().build(
      ConnectionProfile(
        id: 'profile-1',
        panelId: 'primary',
        remoteClientId: 1,
        displayName: 'PC',
        proxies: const <ProxyProfile>[proxy],
        createdAt: DateTime.utc(2026),
      ),
      const AppSettings(),
    );
    expect((config.document['tun']! as Map)['enable'], isTrue);
    expect(config.document['external-controller'], '127.0.0.1:9099');
    expect(config.secret, hasLength(48));
  });
}

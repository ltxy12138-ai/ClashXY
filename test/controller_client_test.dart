import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clashxy/core/mihomo/controller_client.dart';

void main() {
  test('parses proxy groups and selects a node with bearer auth', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer local-secret');
      if (request.method == 'GET' && request.url.path == '/proxies') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'proxies': <String, Object?>{
              'SELECT': <String, Object?>{
                'type': 'Selector',
                'all': <String>['Edge A', 'Edge B'],
                'now': 'Edge A',
                'alive': true,
              },
              'Edge A': <String, Object?>{'type': 'VLESS'},
            },
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.path == '/proxies/SELECT') {
        expect(jsonDecode(request.body), <String, Object?>{'name': 'Edge B'});
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final controller = ControllerClient(
      baseUrl: Uri.parse('http://127.0.0.1:9099'),
      secret: 'local-secret',
      client: client,
    );
    final groups = await controller.proxyGroups();
    expect(groups, hasLength(1));
    expect(groups.single.name, 'SELECT');
    expect(groups.single.selected, 'Edge A');
    await controller.selectProxy('SELECT', 'Edge B');
  });

  test('parses active connections, rules and closes connections', () async {
    final client = MockClient((request) async {
      switch ((request.method, request.url.path)) {
        case ('GET', '/connections'):
          return http.Response(
            jsonEncode(<String, Object?>{
              'uploadTotal': 10,
              'downloadTotal': 20,
              'connections': <Object?>[
                <String, Object?>{
                  'id': 'connection-1',
                  'upload': 3,
                  'download': 4,
                  'start': '2026-08-21T00:00:00Z',
                  'chains': <String>['Edge', 'SELECT'],
                  'metadata': <String, Object?>{
                    'network': 'tcp',
                    'host': 'example.test',
                    'destinationIP': '203.0.113.1',
                    'destinationPort': '443',
                  },
                },
              ],
            }),
            200,
          );
        case ('GET', '/rules'):
          return http.Response(
            jsonEncode(<String, Object?>{
              'rules': <Object?>[
                <String, Object?>{
                  'type': 'Domain',
                  'payload': 'example.test',
                  'proxy': 'SELECT',
                },
              ],
            }),
            200,
          );
        case ('DELETE', '/connections/connection-1'):
        case ('DELETE', '/connections'):
          return http.Response('', 204);
        default:
          return http.Response('', 404);
      }
    });
    final controller = ControllerClient(
      baseUrl: Uri.parse('http://127.0.0.1:9099'),
      secret: 'secret',
      client: client,
    );
    final snapshot = await controller.connections();
    expect(snapshot.connections.single.host, 'example.test');
    expect(snapshot.connections.single.chains, <String>['Edge', 'SELECT']);
    expect((await controller.rules()).single.proxy, 'SELECT');
    await controller.closeConnection('connection-1');
    await controller.closeAllConnections();
  });
  test('parses and updates proxy providers', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer provider-secret');
      if (request.method == 'GET' && request.url.path == '/providers/proxies') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'providers': <String, Object?>{
              'My Provider': <String, Object?>{
                'vehicleType': 'HTTP',
                'updatedAt': '2026-08-21T01:02:03Z',
                'proxies': <Object?>[
                  <String, Object?>{'name': 'A'},
                  <String, Object?>{'name': 'B'},
                ],
                'subscriptionInfo': <String, Object?>{
                  'Upload': 10,
                  'Download': 20,
                  'Total': 1000,
                  'Expire': 2000000000,
                },
              },
            },
          }),
          200,
        );
      }
      if (request.method == 'PUT' &&
          request.url.pathSegments.last == 'My Provider') {
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final controller = ControllerClient(
      baseUrl: Uri.parse('http://127.0.0.1:9099'),
      secret: 'provider-secret',
      client: client,
    );
    final providers = await controller.providers();
    expect(providers, hasLength(1));
    expect(providers.single.name, 'My Provider');
    expect(providers.single.proxyCount, 2);
    expect(providers.single.totalBytes, 1000);
    expect(providers.single.updatedAt, DateTime.utc(2026, 8, 21, 1, 2, 3));
    expect(providers.single.expireAt, isNotNull);
    await controller.updateProvider('My Provider');
  });

  test('parses and updates rule providers', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer rule-secret');
      if (request.method == 'GET' && request.url.path == '/providers/rules') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'providers': <String, Object?>{
              'Reject List': <String, Object?>{
                'behavior': 'domain',
                'vehicleType': 'HTTP',
                'updatedAt': '2026-08-24T01:02:03Z',
                'ruleCount': 42,
              },
            },
          }),
          200,
        );
      }
      if (request.method == 'PUT' &&
          request.url.path == '/providers/rules/Reject%20List') {
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final controller = ControllerClient(
      baseUrl: Uri.parse('http://127.0.0.1:9099'),
      secret: 'rule-secret',
      client: client,
    );

    final providers = await controller.ruleProviders();

    expect(providers, hasLength(1));
    expect(providers.single.name, 'Reject List');
    expect(providers.single.behavior, 'domain');
    expect(providers.single.ruleCount, 42);
    await controller.updateRuleProvider('Reject List');
  });

  test('delay falls back after a transient controller 503', () async {
    final targets = <String>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/proxies/Edge/delay');
      targets.add(request.url.queryParameters['url']!);
      if (targets.length == 1) return http.Response('', 503);
      return http.Response(jsonEncode(<String, int>{'delay': 142}), 200);
    });
    final controller = ControllerClient(
      baseUrl: Uri.parse('http://127.0.0.1:9099'),
      secret: 'secret',
      client: client,
    );

    final result = await controller.delay('Edge');

    expect(result.milliseconds, 142);
    expect(targets, hasLength(2));
    expect(targets.first, 'http://1.1.1.1');
    expect(targets[1], 'http://www.gstatic.com/generate_204');
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clashxy/core/panel/two_sui_http_client.dart';
import 'package:clashxy/core/security/app_logger.dart';
import 'package:clashxy/models/panel_models.dart';

void main() {
  test(
    'login provisions and verifies a token without exposing the cookie',
    () async {
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/app/api/login':
            expect(request.method, 'POST');
            return _json(
              const {'success': true, 'msg': '', 'obj': null},
              headers: const {'set-cookie': 's-ui=session-secret; Path=/'},
            );
          case '/app/api/addToken':
            expect(request.headers['cookie'], 's-ui=session-secret');
            return _json(const {
              'success': true,
              'msg': '',
              'obj': 'device-token',
            });
          case '/app/api/tokens':
            return _json({
              'success': true,
              'msg': '',
              'obj': [
                {'id': '7', 'desc': 'ClashXY', 'token': '****', 'expiry': 10},
              ],
            });
          case '/app/apiv2/status':
            expect(request.headers['token'], 'device-token');
            return _json({
              'success': true,
              'msg': '',
              'obj': {
                'sys': {'uptime': 42, 'version': '1.7.1'},
              },
            });
          case '/app/api/deleteToken':
            expect(request.headers['cookie'], 's-ui=session-secret');
            expect(Uri.splitQueryString(request.body)['id'], '7');
            return _json(const {'success': true, 'msg': '', 'obj': null});
          default:
            return http.Response('not found', 404);
        }
      });
      final connector = TwoSuiHttpClient(
        baseUrl: Uri.parse('https://panel.test/app/'),
        logger: const _SilentLogger(),
        client: client,
      );
      final session = await connector.login(
        LoginRequest(
          baseUrl: connector.baseUrl,
          username: 'admin',
          password: 'password',
        ),
      );
      expect(session.requiresTwoFactor, isFalse);
      final token = await connector.createToken(
        description: 'ClashXY',
        expiresAt: DateTime.now().add(const Duration(days: 10)),
      );
      expect(token.id, '7');
      expect(token.value, 'device-token');
      await connector.useToken(token.value);
      await connector.deleteToken(token.id);
    },
  );

  test('maps inbounds, client CRUD, stats and online clients', () async {
    final actions = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['token'], 'token');
      switch (request.url.path) {
        case '/app/apiv2/status':
          return _json({
            'success': true,
            'msg': '',
            'obj': {
              'sys': {'uptime': 1, 'version': '1.7.1'},
            },
          });
        case '/app/apiv2/inbounds':
          return _json({
            'success': true,
            'msg': '',
            'obj': {
              'inbounds': [
                {
                  'id': 3,
                  'tag': 'reality',
                  'type': 'vless',
                  'listen_port': 443,
                },
              ],
            },
          });
        case '/app/apiv2/clients':
          return _json({
            'success': true,
            'msg': '',
            'obj': {
              'clients': [
                {
                  'id': 12,
                  'name': 'clashxy-pc',
                  'enable': true,
                  'links': [
                    {'uri': 'hysteria2://password@hy2.test:443#HY2'},
                  ],
                },
              ],
            },
          });
        case '/app/apiv2/save':
          final form = Uri.splitQueryString(request.body);
          actions.add(form['action']!);
          return _json({
            'success': true,
            'msg': '',
            'obj': {
              'clients': [
                {'id': 12, 'name': 'clashxy-pc', 'enable': true},
              ],
            },
          });
        case '/app/apiv2/stats':
          return _json({
            'success': true,
            'msg': '',
            'obj': {'up': 11, 'down': 22},
          });
        case '/app/apiv2/onlines':
          return _json({
            'success': true,
            'msg': '',
            'obj': {
              'onlines': [
                {'id': 12, 'name': 'clashxy-pc', 'ip': '192.0.2.1'},
              ],
            },
          });
        default:
          return http.Response('not found', 404);
      }
    });
    final connector = TwoSuiHttpClient(
      baseUrl: Uri.parse('https://panel.test/app/'),
      logger: const _SilentLogger(),
      client: client,
    );
    await connector.useToken('token');
    expect((await connector.listInbounds()).single.protocol, 'vless');
    expect((await connector.listClients()).single.links, hasLength(1));
    final created = await connector.createClient(
      const CreateClientRequest(
        name: 'clashxy-pc',
        configuration: {'enable': true},
      ),
    );
    await connector.updateClient(UpdateClientRequest(client: created));
    await connector.deleteClient(created.id);
    expect(actions, <String>['new', 'edit', 'del']);
    final traffic = await connector.getTraffic();
    expect(traffic.uploadBytes, 11);
    expect(traffic.downloadBytes, 22);
    expect((await connector.listOnlineClients()).single.ipAddress, '192.0.2.1');
  });
}

http.Response _json(Object value, {Map<String, String>? headers}) {
  return http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

class _SilentLogger implements AppLogger {
  const _SilentLogger();

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

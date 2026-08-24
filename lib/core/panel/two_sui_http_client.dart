import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import '../security/app_logger.dart';
import 'panel_connector.dart';
import '../../models/panel_models.dart';

class TwoSuiHttpClient implements PanelConnector {
  TwoSuiHttpClient({
    required Uri baseUrl,
    required this._logger,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.allowInsecureHttp = false,
  }) : baseUrl = normalizePanelUrl(
         baseUrl,
         allowInsecureHttp: allowInsecureHttp,
       ),
       _client = client ?? http.Client();

  final Uri baseUrl;
  final Duration timeout;
  final bool allowInsecureHttp;
  final AppLogger _logger;
  final http.Client _client;
  String? _cookie;
  String? _token;

  static Uri normalizePanelUrl(Uri input, {bool allowInsecureHttp = false}) {
    if (!input.hasScheme || input.host.isEmpty) {
      throw const PanelException('Panel URL must include a scheme and host.');
    }
    if (input.scheme != 'https' && input.scheme != 'http') {
      throw const PanelException('Panel URL must use HTTPS or HTTP.');
    }
    if (input.scheme == 'http' && !allowInsecureHttp) {
      throw const PanelException('Plain HTTP panels are disabled.');
    }
    if (input.userInfo.isNotEmpty || input.hasQuery || input.hasFragment) {
      throw const PanelException(
        'Panel URL must not contain credentials, a query, or a fragment.',
      );
    }
    final path = input.path.endsWith('/') ? input.path : '${input.path}/';
    return Uri(
      scheme: input.scheme,
      host: input.host,
      port: input.hasPort ? input.port : null,
      path: path.isEmpty ? '/' : path,
    );
  }

  @override
  Future<PanelSession> login(LoginRequest request) async {
    if (request.baseUrl != baseUrl) {
      throw const PanelException('Login request targets a different panel.');
    }
    final response = await _form('api/login', <String, String>{
      'user': request.username,
      'pass': request.password,
      'code': request.code,
    }, authenticated: false);
    _captureCookie(response);
    final envelope = _decodeEnvelope(response);
    final object = _asMap(envelope.object);
    final requiresTwoFactor = object?['twoFa'] == true;
    if (!envelope.success && !requiresTwoFactor) {
      throw PanelException(
        _safeMessage(envelope.message, 'Panel login failed.'),
      );
    }
    if (envelope.success && _cookie == null) {
      throw const PanelException(
        'Panel login succeeded without a session cookie.',
      );
    }
    return PanelSession(requiresTwoFactor: requiresTwoFactor);
  }

  @override
  Future<void> logout() async {
    try {
      await _request('GET', 'api/logout', useToken: false);
    } finally {
      _cookie = null;
      _token = null;
    }
  }

  @override
  Future<ProvisionedToken> createToken({
    required String description,
    required DateTime expiresAt,
  }) async {
    final days = expiresAt.difference(DateTime.now()).inDays.clamp(1, 3650);
    final response = await _form('api/addToken', <String, String>{
      'desc': description,
      'expiry': '$days',
    });
    final envelope = _expectSuccess(response, operation: 'create API token');
    final value = envelope.object?.toString() ?? '';
    if (value.isEmpty) {
      throw const PanelException('Panel did not return the new API token.');
    }

    final list = _expectSuccess(
      await _request('GET', 'api/tokens', useToken: false),
      operation: 'list API tokens',
    );
    final record = _asList(list.object)
        .map(_asMap)
        .whereType<Map<String, Object?>>()
        .where((item) => item['desc']?.toString() == description)
        .lastOrNull;
    final id = record?['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const PanelException('Created API token could not be identified.');
    }
    return ProvisionedToken(id: id, value: value);
  }

  @override
  Future<void> useToken(String token) async {
    if (token.trim().isEmpty) {
      throw const PanelException('API token must not be empty.');
    }
    _token = token;
    await getServerStatus();
  }

  @override
  Future<void> deleteToken(String tokenId) async {
    _expectSuccess(
      await _form('api/deleteToken', <String, String>{'id': tokenId}),
      operation: 'delete API token',
    );
  }

  @override
  Future<List<Inbound>> listInbounds() async {
    final envelope = _expectSuccess(
      await _request('GET', 'apiv2/inbounds'),
      operation: 'list inbounds',
    );
    final rows = _asList(_asMap(envelope.object)?['inbounds']);
    return rows.map(_mapInbound).toList(growable: false);
  }

  @override
  Future<List<RemoteClient>> listClients() async {
    final envelope = _expectSuccess(
      await _request('GET', 'apiv2/clients'),
      operation: 'list clients',
    );
    final rows = _asList(_asMap(envelope.object)?['clients']);
    return rows.map(_mapClient).toList(growable: false);
  }

  @override
  Future<RemoteClient> getClient(int id) async {
    return _loadClient(id);
  }

  Future<RemoteClient> _loadClient(int id, {bool sync = false}) async {
    final envelope = _expectSuccess(
      await _request('GET', 'apiv2/clients?id=$id${sync ? '&sync=true' : ''}'),
      operation: 'get client',
    );
    final rows = _asList(_asMap(envelope.object)?['clients']);
    if (rows.isEmpty) {
      throw PanelException('Client $id was not found.');
    }
    return _mapClient(rows.first);
  }

  @override
  Future<RemoteClient> createClient(CreateClientRequest request) async {
    final payload = Map<String, Object?>.from(request.configuration)
      ..['name'] = request.name;
    final envelope = _expectSuccess(
      await _save('new', jsonEncode(payload)),
      operation: 'create client',
    );
    final rows = _asList(_asMap(envelope.object)?['clients']);
    final created = rows
        .map(_asMap)
        .whereType<Map<String, Object?>>()
        .where((item) => item['name']?.toString() == request.name)
        .firstOrNull;
    final id = _asInt(created?['id']);
    if (id <= 0) {
      throw const PanelException(
        'Created client was absent from the snapshot.',
      );
    }
    return _loadClient(id, sync: true);
  }

  @override
  Future<RemoteClient> updateClient(UpdateClientRequest request) async {
    _expectSuccess(
      await _save('edit', jsonEncode(request.client.raw)),
      operation: 'update client',
    );
    return _loadClient(request.client.id, sync: true);
  }

  @override
  Future<void> deleteClient(int id) async {
    _expectSuccess(
      await _save('del', jsonEncode(id)),
      operation: 'delete client',
    );
  }

  @override
  Future<ServerStatus> getServerStatus() async {
    final envelope = _expectSuccess(
      await _request('GET', 'apiv2/status?r=sys'),
      operation: 'read server status',
    );
    final object = _asMap(envelope.object) ?? const <String, Object?>{};
    final sys = _asMap(object['sys']) ?? object;
    return ServerStatus(
      running: true,
      uptimeSeconds: _asInt(sys['uptime']),
      version: sys['version']?.toString() ?? '',
    );
  }

  @override
  Future<TrafficStats> getTraffic() async {
    final envelope = _expectSuccess(
      await _request('GET', 'apiv2/stats'),
      operation: 'read traffic stats',
    );
    final object = _asMap(envelope.object) ?? const <String, Object?>{};
    return TrafficStats(
      uploadBytes: _asInt(object['up'] ?? object['upload']),
      downloadBytes: _asInt(object['down'] ?? object['download']),
    );
  }

  @override
  Future<List<OnlineClient>> listOnlineClients() async {
    final envelope = _expectSuccess(
      await _request('GET', 'apiv2/onlines'),
      operation: 'list online clients',
    );
    final object = envelope.object;
    final rows = object is List<Object?>
        ? object
        : _asList(_asMap(object)?['onlines'] ?? _asMap(object)?['clients']);
    return rows
        .map((row) {
          final item = _asMap(row) ?? const <String, Object?>{};
          return OnlineClient(
            id: _asInt(item['id'] ?? item['clientId']),
            name: item['name']?.toString() ?? '',
            ipAddress: item['ip']?.toString(),
          );
        })
        .toList(growable: false);
  }

  Future<http.Response> _save(String action, String data) {
    return _form('apiv2/save', <String, String>{
      'object': 'clients',
      'action': action,
      'data': data,
      'initUsers': '',
    }, useToken: true);
  }

  Future<http.Response> _form(
    String path,
    Map<String, String> body, {
    bool authenticated = true,
    bool useToken = false,
  }) {
    return _request(
      'POST',
      path,
      body: body,
      useCookie: authenticated,
      useToken: useToken,
    );
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? body,
    bool useCookie = true,
    bool useToken = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (useCookie && _cookie != null) headers['Cookie'] = _cookie!;
    if (useToken && _token != null) headers['Token'] = _token!;
    final uri = baseUrl.resolve(path);
    _logger.log(
      LogLevel.debug,
      '$method ${uri.scheme}://${uri.host}${uri.path}',
    );
    try {
      final response = method == 'POST'
          ? await _client
                .post(uri, headers: headers, body: body)
                .timeout(timeout)
          : await _client.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PanelException(
          'Panel request failed with HTTP ${response.statusCode}.',
        );
      }
      return response;
    } on TimeoutException catch (error) {
      throw PanelException('Panel request timed out.', cause: error);
    } on PanelException {
      rethrow;
    } catch (error) {
      throw PanelException('Panel request failed.', cause: error);
    }
  }

  void _captureCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    final match = RegExp(r'(?:^|,\s*)(s-ui=[^;,]+)').firstMatch(setCookie);
    if (match != null) _cookie = match.group(1);
  }

  _Envelope _expectSuccess(
    http.Response response, {
    required String operation,
  }) {
    final envelope = _decodeEnvelope(response);
    if (!envelope.success) {
      throw PanelException(
        _safeMessage(envelope.message, 'Panel could not $operation.'),
      );
    }
    return envelope;
  }

  _Envelope _decodeEnvelope(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final map = _asMap(decoded);
      if (map == null || map['success'] is! bool) {
        throw const FormatException('invalid envelope');
      }
      return _Envelope(
        success: map['success']! as bool,
        message: map['msg']?.toString() ?? '',
        object: map['obj'],
      );
    } catch (error) {
      throw PanelException('Panel returned invalid JSON.', cause: error);
    }
  }

  String _safeMessage(String message, String fallback) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }

  static Inbound _mapInbound(Object? value) {
    final item = _asMap(value) ?? const <String, Object?>{};
    return Inbound(
      id: _asInt(item['id']),
      tag: item['tag']?.toString() ?? '',
      protocol: item['type']?.toString() ?? '',
      port: _asInt(item['listen_port'] ?? item['port']),
      enabled: item['enable'] != false,
    );
  }

  static RemoteClient _mapClient(Object? value) {
    final item = _asMap(value) ?? const <String, Object?>{};
    final links = _asList(item['links'])
        .map((link) {
          if (link is String) return link;
          return _asMap(link)?['uri']?.toString() ?? '';
        })
        .where((link) => link.isNotEmpty)
        .toList(growable: false);
    return RemoteClient(
      id: _asInt(item['id']),
      name: item['name']?.toString() ?? '',
      enabled: item['enable'] == true,
      raw: Map<String, Object?>.from(item),
      links: links,
    );
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _asList(Object? value) {
    return value is List ? value.cast<Object?>() : const <Object?>[];
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _Envelope {
  const _Envelope({
    required this.success,
    required this.message,
    required this.object,
  });

  final bool success;
  final String message;
  final Object? object;
}

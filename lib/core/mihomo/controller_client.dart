import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../models/clash_models.dart';
import '../../models/connection_models.dart';

class ControllerClient {
  ControllerClient({
    required this.baseUrl,
    required this.secret,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final String secret;
  final Duration timeout;
  final http.Client _client;

  Map<String, String> get _headers => <String, String>{
    'Authorization': 'Bearer $secret',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<MihomoStatus> status() async {
    final version = await _get('/version');
    final configs = await _get('/configs');
    return MihomoStatus(
      version: version['version']?.toString() ?? '',
      mode: configs['mode']?.toString() ?? '',
    );
  }

  Future<Map<String, Object?>> proxies() => _get('/proxies');

  Future<List<ProxyGroupState>> proxyGroups() async {
    final response = await _get('/proxies');
    final rows = _asMap(response['proxies']) ?? const <String, Object?>{};
    final result = <ProxyGroupState>[];
    for (final entry in rows.entries) {
      final value = _asMap(entry.value);
      final all = value?['all'];
      if (value == null || all is! List || all.isEmpty) continue;
      result.add(
        ProxyGroupState(
          name: entry.key,
          type: value['type']?.toString() ?? '',
          options: all.map((item) => item.toString()).toList(growable: false),
          selected: value['now']?.toString(),
          alive: value['alive'] != false,
        ),
      );
    }
    return result;
  }

  Future<List<ProxyProviderState>> providers() async {
    final response = await _get('/providers/proxies');
    final rows = _asMap(response['providers']) ?? const <String, Object?>{};
    final result = <ProxyProviderState>[];
    for (final entry in rows.entries) {
      final value = _asMap(entry.value);
      if (value == null) continue;
      final info =
          _asMap(value['subscriptionInfo']) ?? const <String, Object?>{};
      final proxies = value['proxies'];
      result.add(
        ProxyProviderState(
          name: entry.key,
          vehicleType: value['vehicleType']?.toString() ?? '',
          updatedAt: _asDateTime(value['updatedAt']),
          proxyCount: proxies is List ? proxies.length : 0,
          uploadBytes: _asInt(info['Upload'] ?? info['upload']),
          downloadBytes: _asInt(info['Download'] ?? info['download']),
          totalBytes: _asInt(info['Total'] ?? info['total']),
          expireAt: _asUnixTime(info['Expire'] ?? info['expire']),
        ),
      );
    }
    return result;
  }

  Future<void> updateProvider(String name) async {
    await _request(
      'PUT',
      '/providers/proxies/${Uri.encodeComponent(name)}',
      expectedStatus: const <int>{204},
    );
  }

  Future<List<RuleProviderState>> ruleProviders() async {
    final response = await _get('/providers/rules');
    final rows = _asMap(response['providers']) ?? const <String, Object?>{};
    final result = <RuleProviderState>[];
    for (final entry in rows.entries) {
      final value = _asMap(entry.value);
      if (value == null) continue;
      final rules = value['rules'];
      result.add(
        RuleProviderState(
          name: entry.key,
          behavior: value['behavior']?.toString() ?? '',
          vehicleType: value['vehicleType']?.toString() ?? '',
          updatedAt: _asDateTime(value['updatedAt']),
          ruleCount: _asInt(value['ruleCount']) > 0
              ? _asInt(value['ruleCount'])
              : rules is List
              ? rules.length
              : 0,
        ),
      );
    }
    return result;
  }

  Future<void> updateRuleProvider(String name) async {
    await _request(
      'PUT',
      '/providers/rules/${Uri.encodeComponent(name)}',
      expectedStatus: const <int>{204},
    );
  }

  Future<void> selectProxy(String group, String proxy) async {
    await _request(
      'PUT',
      '/proxies/${Uri.encodeComponent(group)}',
      body: <String, Object?>{'name': proxy},
      expectedStatus: const <int>{204},
    );
  }

  Future<List<ClashRuleEntry>> rules() async {
    final response = await _get('/rules');
    final rows = response['rules'];
    if (rows is! List) return const <ClashRuleEntry>[];
    return rows
        .map(_asMap)
        .whereType<Map<String, Object?>>()
        .map(
          (row) => ClashRuleEntry(
            type: row['type']?.toString() ?? '',
            payload: row['payload']?.toString() ?? '',
            proxy: row['proxy']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<ConnectionSnapshot> connections() async {
    final response = await _get('/connections');
    final rows = response['connections'];
    final connections = <ClashConnectionEntry>[];
    if (rows is List) {
      for (final item in rows) {
        final row = _asMap(item);
        if (row == null) continue;
        final metadata = _asMap(row['metadata']) ?? const <String, Object?>{};
        final chains = row['chains'];
        final destination = [
          metadata['destinationIP']?.toString() ?? '',
          metadata['destinationPort']?.toString() ?? '',
        ].where((part) => part.isNotEmpty).join(':');
        connections.add(
          ClashConnectionEntry(
            id: row['id']?.toString() ?? '',
            network: metadata['network']?.toString() ?? '',
            host: metadata['host']?.toString() ?? '',
            destination: destination,
            chains: chains is List
                ? chains.map((item) => item.toString()).toList(growable: false)
                : const <String>[],
            uploadBytes: _asInt(row['upload']),
            downloadBytes: _asInt(row['download']),
            startedAt: DateTime.tryParse(row['start']?.toString() ?? ''),
          ),
        );
      }
    }
    return ConnectionSnapshot(
      connections: connections,
      uploadTotal: _asInt(response['uploadTotal']),
      downloadTotal: _asInt(response['downloadTotal']),
    );
  }

  Future<void> closeConnection(String id) async {
    await _request(
      'DELETE',
      '/connections/${Uri.encodeComponent(id)}',
      expectedStatus: const <int>{204},
    );
  }

  Future<void> closeAllConnections() async {
    await _request('DELETE', '/connections', expectedStatus: const <int>{204});
  }

  Future<void> setMode(String mode) async {
    await _request(
      'PATCH',
      '/configs',
      body: <String, Object?>{'mode': mode},
      expectedStatus: const <int>{204},
    );
  }

  Future<DelayResult> delay(String proxyName, {Uri? testUrl}) async {
    if (testUrl != null) {
      return _delayOnce(proxyName, testUrl);
    }
    Object? lastError;
    for (final target in _delayTestUrls) {
      try {
        return await _delayOnce(proxyName, target);
      } catch (error) {
        lastError = error;
      }
    }
    throw MihomoException('代理延迟测试失败：测速地址暂时不可用。', cause: lastError);
  }

  Future<DelayResult> _delayOnce(String proxyName, Uri target) async {
    final path =
        '/proxies/${Uri.encodeComponent(proxyName)}/delay'
        '?timeout=4000&url=${Uri.encodeQueryComponent(target.toString())}';
    final result = await _get(path);
    final delay = _asInt(result['delay']);
    if (delay <= 0) throw const MihomoException('代理延迟测试失败。');
    return DelayResult(proxyName: proxyName, milliseconds: delay);
  }

  static final List<Uri> _delayTestUrls = <Uri>[
    // Avoid DNS for the first attempt. Some networks intermittently block the
    // configured DoH endpoint even while an established proxy stays usable.
    Uri.parse('http://1.1.1.1'),
    Uri.parse('http://www.gstatic.com/generate_204'),
    Uri.parse('http://connectivitycheck.platform.hicloud.com/generate_204'),
  ];

  Stream<TrafficSample> traffic() async* {
    final socket = await _connectSocket('/traffic');
    try {
      await for (final message in socket) {
        final map = _decodeSocketMap(message);
        if (map == null) continue;
        yield TrafficSample(
          uploadBytesPerSecond: _asInt(map['up']),
          downloadBytesPerSecond: _asInt(map['down']),
          capturedAt: DateTime.now().toUtc(),
        );
      }
    } finally {
      await socket.close();
    }
  }

  Stream<CoreLogEntry> logs({String level = 'info'}) async* {
    final socket = await _connectSocket(
      '/logs?level=${Uri.encodeQueryComponent(level)}',
    );
    try {
      await for (final message in socket) {
        final map = _decodeSocketMap(message);
        if (map == null) continue;
        yield CoreLogEntry(
          level: map['type']?.toString() ?? level,
          message: map['payload']?.toString() ?? '',
          capturedAt: DateTime.now().toUtc(),
        );
      }
    } finally {
      await socket.close();
    }
  }

  Future<WebSocket> _connectSocket(String path) {
    final wsScheme = baseUrl.scheme == 'https' ? 'wss' : 'ws';
    final resolved = baseUrl.resolve(path);
    final uri = resolved.replace(scheme: wsScheme);
    return WebSocket.connect(
      uri.toString(),
      headers: <String, String>{'Authorization': 'Bearer $secret'},
    ).timeout(timeout);
  }

  Map<String, Object?>? _decodeSocketMap(Object? message) {
    try {
      final text = message is List<int>
          ? utf8.decode(message)
          : message.toString();
      return _asMap(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _get(String path) async {
    final response = await _request(
      'GET',
      path,
      expectedStatus: const <int>{200},
    );
    try {
      final map = _asMap(jsonDecode(utf8.decode(response.bodyBytes)));
      if (map == null) throw const FormatException('expected object');
      return map;
    } catch (error) {
      throw MihomoException('Mihomo 控制器返回了无效数据。', cause: error);
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    required Set<int> expectedStatus,
  }) async {
    try {
      final uri = baseUrl.resolve(path);
      final encoded = body == null ? null : jsonEncode(body);
      final response = switch (method) {
        'GET' => _client.get(uri, headers: _headers),
        'PUT' => _client.put(uri, headers: _headers, body: encoded),
        'PATCH' => _client.patch(uri, headers: _headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: _headers),
        _ => throw ArgumentError.value(method, 'method'),
      };
      final result = await response.timeout(timeout);
      if (!expectedStatus.contains(result.statusCode)) {
        throw MihomoException('Mihomo 控制器返回 HTTP ${result.statusCode}。');
      }
      return result;
    } on MihomoException {
      rethrow;
    } catch (error) {
      throw MihomoException('Mihomo 控制器请求失败。', cause: error);
    }
  }

  void dispose() => _client.close();

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static DateTime? _asDateTime(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : DateTime.tryParse(text);
  }

  static DateTime? _asUnixTime(Object? value) {
    final seconds = _asInt(value);
    return seconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

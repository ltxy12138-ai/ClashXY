import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/profile_models.dart';
import '../errors/app_exception.dart';
import 'clash_config_parser.dart';

class ProfileImportService {
  ProfileImportService({
    this._parser = const ClashConfigParser(),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final ClashConfigParser _parser;
  final http.Client _client;

  Future<ConnectionProfile> fromSubscription({
    required String name,
    required Uri url,
    String? existingId,
  }) async {
    if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
      throw const AppException('订阅地址必须使用 HTTPS，且不能包含 URL 用户凭据。');
    }
    final response = await _client
        .get(
          url,
          headers: const <String, String>{
            'Accept': 'text/yaml, application/yaml, text/plain, */*',
            'User-Agent': 'clash.meta',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException('订阅下载失败：HTTP ${response.statusCode}。');
    }
    if (response.bodyBytes.length > 10 * 1024 * 1024) {
      throw const AppException('订阅内容超过 10 MB 安全限制。');
    }
    final yaml = utf8.decode(response.bodyBytes, allowMalformed: false);
    return _profile(
      name: name,
      origin: ProfileOrigin.subscription,
      config: _parser.parse(yaml),
      subscriptionUrl: url,
      existingId: existingId,
    );
  }

  ConnectionProfile fromLocalYaml({
    required String name,
    required String yaml,
  }) {
    return _profile(
      name: name,
      origin: ProfileOrigin.localFile,
      config: _parser.parse(yaml),
    );
  }

  ConnectionProfile fromCustomYaml({
    required String name,
    required String yaml,
  }) {
    return _profile(
      name: name,
      origin: ProfileOrigin.custom,
      config: _parser.parse(yaml),
    );
  }

  ConnectionProfile replaceYaml({
    required ConnectionProfile profile,
    required String yaml,
  }) {
    if (!profile.isStandalone) {
      throw const AppException('Only standalone profiles can replace YAML.');
    }
    return profile.copyWith(
      rawConfig: _parser.parse(yaml),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  void dispose() => _client.close();

  ConnectionProfile _profile({
    required String name,
    required ProfileOrigin origin,
    required Map<String, Object?> config,
    Uri? subscriptionUrl,
    String? existingId,
  }) {
    final normalizedName = name.trim().isEmpty ? '未命名配置' : name.trim();
    final now = DateTime.now().toUtc();
    return ConnectionProfile(
      id: existingId ?? 'source-${now.microsecondsSinceEpoch}',
      panelId: '',
      remoteClientId: 0,
      displayName: normalizedName,
      proxies: const <ProxyProfile>[],
      createdAt: now,
      updatedAt: now,
      autoUpdateInterval: origin == ProfileOrigin.subscription
          ? const Duration(days: 1)
          : Duration.zero,
      origin: origin,
      rawConfig: config,
      subscriptionUrl: subscriptionUrl,
    );
  }
}

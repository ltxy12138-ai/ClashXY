import 'package:yaml/yaml.dart';

import '../errors/app_exception.dart';

class ClashConfigParser {
  const ClashConfigParser();

  Map<String, Object?> parse(String yaml) {
    if (yaml.trim().isEmpty) {
      throw const AppException('配置内容不能为空。');
    }
    final Object? decoded;
    try {
      decoded = loadYaml(yaml);
    } catch (error) {
      throw AppException('配置不是有效的 YAML。', cause: error);
    }
    final value = _convert(decoded);
    if (value is! Map<String, Object?>) {
      throw const AppException('Clash 配置根节点必须是对象。');
    }
    final proxies = value['proxies'];
    final providers = value['proxy-providers'];
    final hasProxies = proxies is List && proxies.isNotEmpty;
    final hasProviders = providers is Map && providers.isNotEmpty;
    if (!hasProxies && !hasProviders) {
      throw const AppException('配置中没有 proxies 或 proxy-providers。');
    }
    return value;
  }

  Object? _convert(Object? value) {
    if (value is YamlMap || value is Map) {
      return (value as Map).map<String, Object?>(
        (key, item) => MapEntry(key.toString(), _convert(item)),
      );
    }
    if (value is YamlList || value is List) {
      return (value as List).map<Object?>(_convert).toList(growable: false);
    }
    if (value is num || value is bool || value is String || value == null) {
      return value;
    }
    return value.toString();
  }
}

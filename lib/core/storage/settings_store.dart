import 'dart:convert';

import '../../models/app_settings.dart';
import 'app_database.dart';

class SettingsStore {
  const SettingsStore(this._database);

  final AppDatabase _database;
  static const String _key = 'app';

  Future<AppSettings> load() async {
    final row = await (_database.select(
      _database.settings,
    )..where((setting) => setting.key.equals(_key))).getSingleOrNull();
    if (row == null) return const AppSettings();
    final value = jsonDecode(row.value) as Map<String, Object?>;
    return AppSettings(
      controllerPort: value['controllerPort'] as int? ?? 9099,
      mixedPort: value['mixedPort'] as int? ?? 7890,
      tunDevice: value['tunDevice'] as String? ?? 'ClashXY',
      launchAtStartup: value['launchAtStartup'] as bool? ?? false,
      autoConnect: value['autoConnect'] as bool? ?? false,
      protocol: value['protocol'] as String? ?? 'automatic',
      tunEnabled: value['tunEnabled'] as bool? ?? true,
      ipv6Enabled: value['ipv6Enabled'] as bool? ?? false,
      logsEnabled: value['logsEnabled'] as bool? ?? true,
      localeCode: value['localeCode'] as String? ?? 'system',
      allowLan: value['allowLan'] as bool? ?? false,
      tunStack: value['tunStack'] as String? ?? 'mixed',
      tunMtu: value['tunMtu'] as int? ?? 9000,
      tunStrictRoute: value['tunStrictRoute'] as bool? ?? true,
      tunAutoRoute: value['tunAutoRoute'] as bool? ?? true,
      tunAutoDetectInterface: value['tunAutoDetectInterface'] as bool? ?? true,
      dnsOverrideEnabled: value['dnsOverrideEnabled'] as bool? ?? false,
      dnsEnabled: value['dnsEnabled'] as bool? ?? true,
      dnsMode: value['dnsMode'] as String? ?? 'fake-ip',
      dnsListenPort: value['dnsListenPort'] as int? ?? 1053,
      dnsNameserver:
          value['dnsNameserver'] as String? ?? 'https://1.1.1.1/dns-query',
      snifferOverrideEnabled: value['snifferOverrideEnabled'] as bool? ?? false,
      snifferEnabled: value['snifferEnabled'] as bool? ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final value = jsonEncode(<String, Object?>{
      'controllerPort': settings.controllerPort,
      'mixedPort': settings.mixedPort,
      'tunDevice': settings.tunDevice,
      'launchAtStartup': settings.launchAtStartup,
      'autoConnect': settings.autoConnect,
      'protocol': settings.protocol,
      'tunEnabled': settings.tunEnabled,
      'ipv6Enabled': settings.ipv6Enabled,
      'logsEnabled': settings.logsEnabled,
      'localeCode': settings.localeCode,
      'allowLan': settings.allowLan,
      'tunStack': settings.tunStack,
      'tunMtu': settings.tunMtu,
      'tunStrictRoute': settings.tunStrictRoute,
      'tunAutoRoute': settings.tunAutoRoute,
      'tunAutoDetectInterface': settings.tunAutoDetectInterface,
      'dnsOverrideEnabled': settings.dnsOverrideEnabled,
      'dnsEnabled': settings.dnsEnabled,
      'dnsMode': settings.dnsMode,
      'dnsListenPort': settings.dnsListenPort,
      'dnsNameserver': settings.dnsNameserver,
      'snifferOverrideEnabled': settings.snifferOverrideEnabled,
      'snifferEnabled': settings.snifferEnabled,
    });
    await _database
        .into(_database.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: _key, value: value),
        );
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clashxy/core/storage/app_database.dart';
import 'package:clashxy/core/storage/settings_store.dart';
import 'package:clashxy/models/app_settings.dart';

void main() {
  test('language preference round-trips without a schema migration', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SettingsStore(database);

    expect((await store.load()).localeCode, 'system');

    await store.save(
      const AppSettings(
        localeCode: 'en',
        mixedPort: 7891,
        allowLan: true,
        tunStack: 'system',
        tunMtu: 1500,
        dnsOverrideEnabled: true,
        dnsListenPort: 1054,
        dnsNameserver: 'https://dns.example/dns-query',
        snifferOverrideEnabled: true,
      ),
    );

    final loaded = await store.load();
    expect(loaded.localeCode, 'en');
    expect(loaded.mixedPort, 7891);
    expect(loaded.allowLan, isTrue);
    expect(loaded.tunStack, 'system');
    expect(loaded.tunMtu, 1500);
    expect(loaded.dnsOverrideEnabled, isTrue);
    expect(loaded.dnsListenPort, 1054);
    expect(loaded.dnsNameserver, 'https://dns.example/dns-query');
    expect(loaded.snifferOverrideEnabled, isTrue);
  });
}

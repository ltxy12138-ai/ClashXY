import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clashxy/core/storage/app_database.dart';
import 'package:clashxy/core/storage/panel_store.dart';
import 'package:clashxy/models/panel_models.dart';

void main() {
  test('panel token metadata round-trips and can be detached safely', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = PanelStore(database);
    final account = PanelAccount(
      id: 'panel-a',
      name: 'Panel A',
      baseUrl: Uri.parse('https://panel.example/app/'),
      username: 'admin',
      createdAt: DateTime.utc(2026, 8, 24),
      tokenId: 'token-7',
    );

    await store.save(account, tokenRef: 'panel.panel-a.token');

    expect(await store.tokenRef(account.id), 'panel.panel-a.token');
    final saved = (await store.list()).single;
    expect(saved.tokenId, 'token-7');
    expect(saved.username, 'admin');

    await store.detach(account.id);

    expect(await store.tokenRef(account.id), isNull);
    final detached = (await store.list()).single;
    expect(detached.tokenId, isNull);
    expect(detached.baseUrl, account.baseUrl);
  });
}

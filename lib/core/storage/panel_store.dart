import 'package:drift/drift.dart';

import '../../models/panel_models.dart';
import 'app_database.dart';

class PanelStore {
  const PanelStore(this._database);

  final AppDatabase _database;

  Future<void> save(PanelAccount account, {required String tokenRef}) async {
    await _database
        .into(_database.panels)
        .insertOnConflictUpdate(
          PanelsCompanion.insert(
            id: account.id,
            name: account.name,
            baseUrl: account.baseUrl.toString(),
            username: account.username,
            tokenRef: Value<String?>(tokenRef),
            tokenId: Value<String?>(account.tokenId),
            createdAt: account.createdAt,
          ),
        );
  }

  Future<List<PanelAccount>> list() async {
    final rows = await (_database.select(
      _database.panels,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
    return rows
        .map(
          (row) => PanelAccount(
            id: row.id,
            name: row.name,
            baseUrl: Uri.parse(row.baseUrl),
            username: row.username,
            createdAt: row.createdAt,
            tokenId: row.tokenId,
          ),
        )
        .toList(growable: false);
  }

  Future<String?> tokenRef(String panelId) async {
    final row = await (_database.select(
      _database.panels,
    )..where((panel) => panel.id.equals(panelId))).getSingleOrNull();
    return row?.tokenRef;
  }

  Future<void> detach(String panelId) async {
    await (_database.update(
      _database.panels,
    )..where((panel) => panel.id.equals(panelId))).write(
      const PanelsCompanion(
        tokenRef: Value<String?>(null),
        tokenId: Value<String?>(null),
      ),
    );
  }
}

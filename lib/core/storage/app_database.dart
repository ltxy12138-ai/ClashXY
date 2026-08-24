import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Panels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get username => text()();
  TextColumn get tokenRef => text().nullable()();
  TextColumn get tokenId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get panelId => text().references(Panels, #id)();
  IntColumn get remoteClientId => integer()();
  TextColumn get displayName => text()();
  TextColumn get protocolSummary => text()();
  TextColumn get secureRef => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StandaloneProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get origin => text()();
  TextColumn get secureRef => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [Panels, Profiles, StandaloneProfiles, Devices, Settings],
)
class AppDatabase extends _$AppDatabase {
  // Retain the legacy filename so existing installations keep their profiles
  // and settings after the public product rename to ClashXY.
  AppDatabase() : super(driftDatabase(name: 'mymihomo'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(standaloneProfiles);
      }
      if (from < 3) {
        await migrator.addColumn(panels, panels.tokenId);
      }
    },
  );
}

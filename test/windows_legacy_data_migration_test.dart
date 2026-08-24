import 'dart:io';

import 'package:clashxy/platform/windows/windows_legacy_data_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clashxy-migration-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'copies the newest legacy secure-storage file without deleting it',
    () async {
      final current = Directory(p.join(root.path, 'ClashXY'));
      final oldOriginal = Directory(
        p.join(root.path, 'app.mymihomo', 'mymihomo'),
      );
      final oldInterim = Directory(p.join(root.path, 'MyTunnel'));
      await oldOriginal.create(recursive: true);
      await oldInterim.create(recursive: true);
      final first = File(
        p.join(
          oldOriginal.path,
          WindowsLegacyDataMigration.secureStorageFileName,
        ),
      );
      final newest = File(
        p.join(
          oldInterim.path,
          WindowsLegacyDataMigration.secureStorageFileName,
        ),
      );
      await first.writeAsString('original');
      await newest.writeAsString('interim');
      await first.setLastModified(DateTime.utc(2026, 1, 1));
      await newest.setLastModified(DateTime.utc(2026, 2, 1));

      final migrated = await const WindowsLegacyDataMigration().migrate(
        currentDirectory: current,
        legacyDirectories: <Directory>[oldOriginal, oldInterim],
      );

      expect(migrated, isTrue);
      expect(
        await File(
          p.join(
            current.path,
            WindowsLegacyDataMigration.secureStorageFileName,
          ),
        ).readAsString(),
        'interim',
      );
      expect(await newest.readAsString(), 'interim');
    },
  );

  test('never overwrites current secure storage', () async {
    final current = Directory(p.join(root.path, 'ClashXY'));
    final legacy = Directory(p.join(root.path, 'MyTunnel'));
    await current.create(recursive: true);
    await legacy.create(recursive: true);
    final currentFile = File(
      p.join(current.path, WindowsLegacyDataMigration.secureStorageFileName),
    );
    final legacyFile = File(
      p.join(legacy.path, WindowsLegacyDataMigration.secureStorageFileName),
    );
    await currentFile.writeAsString('current');
    await legacyFile.writeAsString('legacy');

    final migrated = await const WindowsLegacyDataMigration().migrate(
      currentDirectory: current,
      legacyDirectories: <Directory>[legacy],
    );

    expect(migrated, isFalse);
    expect(await currentFile.readAsString(), 'current');
  });
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies secure storage created before the ClashXY rename into the current
/// Windows application-support directory.
///
/// The source is deliberately retained so that migration is recoverable. The
/// current file is never overwritten.
class WindowsLegacyDataMigration {
  const WindowsLegacyDataMigration();

  static const secureStorageFileName = 'flutter_secure_storage.dat';

  Future<bool> migrate({
    required Directory currentDirectory,
    required Iterable<Directory> legacyDirectories,
  }) async {
    final target = File(p.join(currentDirectory.path, secureStorageFileName));
    if (await target.exists()) return false;

    final candidates = <({File file, DateTime modified})>[];
    for (final directory in legacyDirectories) {
      if (p.equals(directory.path, currentDirectory.path)) continue;
      final file = File(p.join(directory.path, secureStorageFileName));
      if (!await file.exists()) continue;
      candidates.add((file: file, modified: await file.lastModified()));
    }
    if (candidates.isEmpty) return false;
    candidates.sort((a, b) => b.modified.compareTo(a.modified));

    await currentDirectory.create(recursive: true);
    if (await target.exists()) return false;
    final temporary = File(
      '${target.path}.migration-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await candidates.first.file.copy(temporary.path);
      if (await target.exists()) return false;
      await temporary.rename(target.path);
      return true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

Future<void> migrateLegacyWindowsData() async {
  if (!Platform.isWindows) return;
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.trim().isEmpty) return;
  final current = await getApplicationSupportDirectory();
  await const WindowsLegacyDataMigration().migrate(
    currentDirectory: current,
    legacyDirectories: <Directory>[
      Directory(p.join(appData, 'app.mymihomo', 'mymihomo')),
      Directory(p.join(appData, 'MyTunnel')),
    ],
  );
}

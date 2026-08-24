import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clashxy/core/mihomo/config_manager.dart';
import 'package:clashxy/core/mihomo/mihomo_config_builder.dart';
import 'package:clashxy/models/app_settings.dart';
import 'package:clashxy/models/profile_models.dart';
import 'package:clashxy/platform/windows/windows_runtime_file_security.dart';

void main() {
  test('runtime config is hardened, written atomically, and removable', () async {
    final support = await Directory.systemTemp.createTemp('clashxy-config-');
    addTearDown(() => support.delete(recursive: true));
    final security = _RecordingSecurity();
    final manager = ConfigManager(
      supportDirectory: support,
      builder: MihomoConfigBuilder(),
      security: security,
    );
    await manager.runtimeDirectory.create(recursive: true);
    final stale = File(
      '${manager.runtimeDirectory.path}${Platform.pathSeparator}config-dead.tmp',
    );
    await stale.writeAsString('secret');

    final handle = await manager.write(_profile, const AppSettings());

    expect(await stale.exists(), isFalse);
    expect(await handle.file.exists(), isTrue);
    expect(await handle.file.readAsString(), contains('external-controller'));
    expect(security.directories, contains(manager.runtimeDirectory.path));
    expect(security.files.last, handle.file.path);
    expect(
      manager.runtimeDirectory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.tmp'),
      ),
      isEmpty,
    );

    await manager.clear(handle);
    expect(await handle.file.exists(), isFalse);
  });

  test('Windows runtime security removes inherited ACL entries', () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('clashxy-acl-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}config.yaml');
    await file.writeAsString('secret');
    const security = WindowsRuntimeFileSecurity();

    await security.hardenDirectory(directory);
    await security.hardenFile(file);

    final directoryAcl = await Process.run('icacls.exe', <String>[
      directory.path,
    ], runInShell: false);
    final fileAcl = await Process.run('icacls.exe', <String>[
      file.path,
    ], runInShell: false);
    expect(directoryAcl.exitCode, 0);
    expect(fileAcl.exitCode, 0);
    expect('${directoryAcl.stdout}', isNot(contains('(I)')));
    expect('${fileAcl.stdout}', isNot(contains('(I)')));
  });
}

class _RecordingSecurity implements RuntimeFileSecurity {
  final List<String> directories = <String>[];
  final List<String> files = <String>[];

  @override
  Future<void> hardenDirectory(Directory directory) async {
    directories.add(directory.path);
  }

  @override
  Future<void> hardenFile(File file) async {
    files.add(file.path);
  }
}

final ConnectionProfile _profile = ConnectionProfile(
  id: 'profile-1',
  panelId: 'primary',
  remoteClientId: 1,
  displayName: 'Test',
  proxies: const <ProxyProfile>[
    ProxyProfile(
      name: 'Edge',
      protocol: ProxyProtocol.vlessReality,
      server: 'edge.example.test',
      port: 443,
      authentication: '550e8400-e29b-41d4-a716-446655440000',
      options: <String, String>{
        'security': 'reality',
        'pbk': 'public-key',
        'sid': 'a1b2c3d4',
        'sni': 'cdn.example.test',
      },
    ),
  ],
  createdAt: DateTime.utc(2026),
);

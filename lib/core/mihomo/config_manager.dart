import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../models/app_settings.dart';
import '../../models/profile_models.dart';
import 'mihomo_config_builder.dart';
import '../../platform/windows/windows_runtime_file_security.dart';

class RuntimeConfigHandle {
  const RuntimeConfigHandle({required this.file, required this.secret});

  final File file;
  final String secret;
}

class ConfigManager {
  const ConfigManager({
    required this.supportDirectory,
    required this.builder,
    this.security = const WindowsRuntimeFileSecurity(),
  });

  final Directory supportDirectory;
  final MihomoConfigBuilder builder;
  final RuntimeFileSecurity security;

  Directory get runtimeDirectory =>
      Directory('${supportDirectory.path}${Platform.pathSeparator}runtime');

  Future<RuntimeConfigHandle> write(
    ConnectionProfile profile,
    AppSettings settings,
  ) async {
    final runtime = runtimeDirectory;
    await runtime.create(recursive: true);
    await security.hardenDirectory(runtime);
    await clearStale();
    final config = builder.build(profile, settings);
    final file = File('${runtime.path}${Platform.pathSeparator}config.yaml');
    final nonce = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final temporary = File(
      '${runtime.path}${Platform.pathSeparator}config-$nonce.tmp',
    );
    try {
      await temporary.writeAsString(jsonEncode(config.document), flush: true);
      await security.hardenFile(temporary);
      await temporary.rename(file.path);
      await security.hardenFile(file);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return RuntimeConfigHandle(file: file, secret: config.secret);
  }

  Future<void> clearStale() async {
    final runtime = runtimeDirectory;
    if (!await runtime.exists()) return;
    final candidates = runtime.list().where(
      (entity) =>
          entity is File &&
          (entity.path.endsWith('${Platform.pathSeparator}config.yaml') ||
              RegExp(r'config-[0-9a-f]+\.tmp$').hasMatch(entity.path)),
    );
    await for (final entity in candidates) {
      await entity.delete();
    }
  }

  Future<void> clear(RuntimeConfigHandle? handle) async {
    if (handle != null && await handle.file.exists()) {
      await handle.file.delete();
    }
  }
}

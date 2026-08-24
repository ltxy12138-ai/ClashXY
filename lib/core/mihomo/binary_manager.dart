import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/errors/app_exception.dart';

abstract interface class MihomoBinarySource {
  Future<Uint8List> load();
}

class BinaryManager {
  const BinaryManager({
    required this.supportDirectory,
    required this.source,
    required this.expectedSha256,
  });

  final Directory supportDirectory;
  final MihomoBinarySource source;
  final String expectedSha256;

  String get currentExecutablePath =>
      '${supportDirectory.path}${Platform.pathSeparator}core'
      '${Platform.pathSeparator}current.exe';

  Future<File> ensureInstalled() async {
    final coreDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}core',
    );
    await coreDirectory.create(recursive: true);
    final current = File(currentExecutablePath);
    if (await current.exists() && await _valid(current)) return current;

    final bytes = await source.load();
    final digest = sha256.convert(bytes).toString();
    if (digest.toLowerCase() != expectedSha256.toLowerCase()) {
      throw const MihomoException(
        'Bundled Mihomo core failed SHA-256 verification.',
      );
    }

    final previous = File(
      '${coreDirectory.path}${Platform.pathSeparator}previous.exe',
    );
    if (await current.exists()) {
      await current.copy(previous.path);
    }
    final staged = File(
      '${coreDirectory.path}${Platform.pathSeparator}current.staged.exe',
    );
    await staged.writeAsBytes(bytes, flush: true);
    if (await current.exists()) await current.delete();
    await staged.rename(current.path);
    return current;
  }

  Future<bool> _valid(File file) async {
    final digest = sha256.convert(await file.readAsBytes()).toString();
    return digest.toLowerCase() == expectedSha256.toLowerCase();
  }
}

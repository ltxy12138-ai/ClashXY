import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/errors/app_exception.dart';

abstract interface class MihomoBinarySource {
  Future<Uint8List> load();
}

typedef MihomoVersionProbe = Future<String> Function(File executable);

class InstalledMihomoCore {
  const InstalledMihomoCore({
    required this.executable,
    required this.version,
    required this.sha256,
  });

  final File executable;
  final String version;
  final String sha256;
}

class BinaryManager {
  BinaryManager({
    required this.supportDirectory,
    required this.source,
    required this.expectedSha256,
    required this.bundledVersion,
    MihomoVersionProbe? versionProbe,
  }) : versionProbe = versionProbe ?? _probeVersion;

  final Directory supportDirectory;
  final MihomoBinarySource source;
  final String expectedSha256;
  final String bundledVersion;
  final MihomoVersionProbe versionProbe;

  Directory get coreDirectory =>
      Directory('${supportDirectory.path}${Platform.pathSeparator}core');

  String get currentExecutablePath =>
      '${coreDirectory.path}${Platform.pathSeparator}current.exe';

  File get _currentFile => File(currentExecutablePath);

  File get _previousFile =>
      File('${coreDirectory.path}${Platform.pathSeparator}previous.exe');

  File get _stagedFile =>
      File('${coreDirectory.path}${Platform.pathSeparator}current.staged.exe');

  File get _currentMetadata =>
      File('${coreDirectory.path}${Platform.pathSeparator}installed.json');

  File get _previousMetadata =>
      File('${coreDirectory.path}${Platform.pathSeparator}previous.json');

  File get _stagedMetadata =>
      File('${coreDirectory.path}${Platform.pathSeparator}staged.json');

  File get _backupFile =>
      File('${coreDirectory.path}${Platform.pathSeparator}previous.staged.exe');

  File get _backupMetadata => File(
    '${coreDirectory.path}${Platform.pathSeparator}previous.staged.json',
  );

  Future<File> ensureInstalled() async => (await inspect()).executable;

  Future<InstalledMihomoCore> inspect() async {
    await coreDirectory.create(recursive: true);
    await _recoverPromotedStaging();
    final installed = await _validInstallation(_currentFile, _currentMetadata);
    if (installed != null) {
      await _clearStaging();
      return installed;
    }

    if (await _currentFile.exists()) {
      final currentHash = await _fileSha256(_currentFile);
      if (_sameDigest(currentHash, expectedSha256)) {
        final bundled = InstalledMihomoCore(
          executable: _currentFile,
          version: _normalizeVersion(bundledVersion),
          sha256: currentHash,
        );
        await _writeMetadata(_currentMetadata, bundled);
        await _clearStaging();
        return bundled;
      }
    }
    final previous = await _validInstallation(_previousFile, _previousMetadata);
    if (previous != null) {
      await _deleteIfExists(_currentFile);
      await _deleteIfExists(_currentMetadata);
      await _previousFile.copy(_currentFile.path);
      final restored = InstalledMihomoCore(
        executable: _currentFile,
        version: previous.version,
        sha256: previous.sha256,
      );
      await _writeMetadata(_currentMetadata, restored);
      await _clearStaging();
      return restored;
    }

    return _installBundled();
  }

  Future<bool> canRollback({InstalledMihomoCore? installed}) async {
    final current = installed ?? await inspect();
    final previous = await _validInstallation(_previousFile, _previousMetadata);
    return previous != null && previous.sha256 != current.sha256;
  }

  Future<InstalledMihomoCore> installUpdate({
    required Uint8List executableBytes,
    required String version,
  }) async {
    final normalizedVersion = _normalizeVersion(version);
    if (executableBytes.isEmpty || executableBytes.length > _maxCoreBytes) {
      throw const MihomoException(
        'Downloaded Mihomo core has an invalid size.',
      );
    }
    final current = await inspect();
    await _clearStaging();
    final stagedHash = sha256.convert(executableBytes).toString();
    var switchStarted = false;
    try {
      await _stagedFile.writeAsBytes(executableBytes, flush: true);
      if (!_sameDigest(await _fileSha256(_stagedFile), stagedHash)) {
        throw const MihomoException(
          'Downloaded Mihomo core failed staged-file verification.',
        );
      }
      final staged = InstalledMihomoCore(
        executable: _stagedFile,
        version: normalizedVersion,
        sha256: stagedHash,
      );
      await _writeMetadata(_stagedMetadata, staged);
      final probedVersion = _normalizeVersion(
        await versionProbe(_stagedFile).timeout(_probeGuardTimeout),
      );
      if (probedVersion != normalizedVersion) {
        throw const MihomoException(
          'Downloaded Mihomo core reported an unexpected version.',
        );
      }

      await _currentFile.copy(_backupFile.path);
      await _writeMetadata(
        _backupMetadata,
        InstalledMihomoCore(
          executable: _backupFile,
          version: current.version,
          sha256: current.sha256,
        ),
      );
      if (await _validInstallation(_backupFile, _backupMetadata) == null) {
        throw const MihomoException(
          'The installed Mihomo core could not be backed up safely.',
        );
      }
      await _deleteIfExists(_previousFile);
      await _deleteIfExists(_previousMetadata);
      await _backupFile.rename(_previousFile.path);
      await _backupMetadata.rename(_previousMetadata.path);
      switchStarted = true;
      await _deleteIfExists(_currentMetadata);
      await _currentFile.delete();
      await _stagedFile.rename(_currentFile.path);
      final installed = InstalledMihomoCore(
        executable: _currentFile,
        version: normalizedVersion,
        sha256: stagedHash,
      );
      await _writeMetadata(_currentMetadata, installed);
      await _deleteIfExists(_stagedMetadata);
      return installed;
    } catch (error) {
      if (switchStarted) {
        await _restorePrevious();
      }
      await _clearStaging();
      if (error is MihomoException) rethrow;
      throw MihomoException(
        'Mihomo core update failed; the previous core was restored.',
        cause: error,
      );
    }
  }

  Future<InstalledMihomoCore> rollback() async {
    final current = await inspect();
    final previous = await _validInstallation(_previousFile, _previousMetadata);
    if (previous == null || previous.sha256 == current.sha256) {
      throw const MihomoException(
        'No verified previous Mihomo core is available.',
      );
    }
    final bytes = await _previousFile.readAsBytes();
    return installUpdate(executableBytes: bytes, version: previous.version);
  }

  Future<InstalledMihomoCore> _installBundled() async {
    final bytes = await source.load();
    final digest = sha256.convert(bytes).toString();
    if (!_sameDigest(digest, expectedSha256)) {
      throw const MihomoException(
        'Bundled Mihomo core failed SHA-256 verification.',
      );
    }
    await _clearStaging();
    await _stagedFile.writeAsBytes(bytes, flush: true);
    if (!_sameDigest(await _fileSha256(_stagedFile), digest)) {
      await _clearStaging();
      throw const MihomoException(
        'Bundled Mihomo core failed staged-file verification.',
      );
    }
    final installed = InstalledMihomoCore(
      executable: _currentFile,
      version: _normalizeVersion(bundledVersion),
      sha256: digest,
    );
    await _writeMetadata(
      _stagedMetadata,
      InstalledMihomoCore(
        executable: _stagedFile,
        version: installed.version,
        sha256: installed.sha256,
      ),
    );
    await _deleteIfExists(_currentFile);
    await _deleteIfExists(_currentMetadata);
    await _stagedFile.rename(_currentFile.path);
    await _writeMetadata(_currentMetadata, installed);
    await _deleteIfExists(_stagedMetadata);
    return installed;
  }

  Future<void> _recoverPromotedStaging() async {
    if (!await _currentFile.exists() ||
        await _currentMetadata.exists() ||
        await _stagedFile.exists() ||
        !await _stagedMetadata.exists()) {
      return;
    }
    final promoted = await _validInstallation(_currentFile, _stagedMetadata);
    if (promoted == null) return;
    await _writeMetadata(
      _currentMetadata,
      InstalledMihomoCore(
        executable: _currentFile,
        version: promoted.version,
        sha256: promoted.sha256,
      ),
    );
    await _deleteIfExists(_stagedMetadata);
  }

  Future<void> _restorePrevious() async {
    final previous = await _validInstallation(_previousFile, _previousMetadata);
    await _deleteIfExists(_currentFile);
    await _deleteIfExists(_currentMetadata);
    if (previous != null) {
      await _previousFile.copy(_currentFile.path);
      await _writeMetadata(
        _currentMetadata,
        InstalledMihomoCore(
          executable: _currentFile,
          version: previous.version,
          sha256: previous.sha256,
        ),
      );
    }
  }

  Future<InstalledMihomoCore?> _validInstallation(
    File executable,
    File metadataFile,
  ) async {
    if (!await executable.exists() || !await metadataFile.exists()) return null;
    try {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final version = _normalizeVersion(decoded['version'] as String);
      final expected = (decoded['sha256'] as String).toLowerCase();
      if (!_sha256Pattern.hasMatch(expected)) return null;
      final actual = await _fileSha256(executable);
      if (!_sameDigest(actual, expected)) return null;
      return InstalledMihomoCore(
        executable: executable,
        version: version,
        sha256: actual,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMetadata(
    File target,
    InstalledMihomoCore installed,
  ) async {
    final temporary = File('${target.path}.tmp');
    await _deleteIfExists(temporary);
    await temporary.writeAsString(
      jsonEncode(<String, String>{
        'version': installed.version,
        'sha256': installed.sha256,
      }),
      flush: true,
    );
    await _deleteIfExists(target);
    await temporary.rename(target.path);
  }

  Future<void> _clearStaging() async {
    await _deleteIfExists(_stagedFile);
    await _deleteIfExists(_stagedMetadata);
    await _deleteIfExists(File('${_stagedMetadata.path}.tmp'));
    await _deleteIfExists(_backupFile);
    await _deleteIfExists(_backupMetadata);
    await _deleteIfExists(File('${_backupMetadata.path}.tmp'));
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  static Future<String> _fileSha256(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  static bool _sameDigest(String left, String right) =>
      left.toLowerCase() == right.toLowerCase();

  static String _normalizeVersion(String value) {
    final match = _versionPattern.firstMatch(value.trim());
    if (match == null) {
      throw const MihomoException('Mihomo core version is invalid.');
    }
    return '${match[1]}.${match[2]}.${match[3]}';
  }

  static Future<String> _probeVersion(File executable) async {
    final process = await Process.start(executable.path, const <String>[
      '-v',
    ], runInShell: false);
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(_probeTimeout);
    } on TimeoutException {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
      throw const MihomoException(
        'Downloaded Mihomo core version check timed out.',
      );
    }
    if (exitCode != 0) {
      throw const MihomoException('Downloaded Mihomo core could not start.');
    }
    final output = '${await stdout}\n${await stderr}';
    final match = _reportedVersionPattern.firstMatch(output);
    if (match == null) {
      throw const MihomoException(
        'Downloaded file is not a supported Windows Mihomo core.',
      );
    }
    return match[1]!;
  }

  static final RegExp _versionPattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');
  static final RegExp _reportedVersionPattern = RegExp(
    r'Mihomo Meta v(\d+\.\d+\.\d+) windows amd64\b',
    caseSensitive: false,
  );
  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static const int _maxCoreBytes = 128 * 1024 * 1024;
  static const Duration _probeTimeout = Duration(seconds: 10);
  static const Duration _probeGuardTimeout = Duration(seconds: 13);
}

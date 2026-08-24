import 'dart:io';

import '../../core/errors/app_exception.dart';

abstract interface class RuntimeFileSecurity {
  Future<void> hardenDirectory(Directory directory);

  Future<void> hardenFile(File file);
}

class WindowsRuntimeFileSecurity implements RuntimeFileSecurity {
  const WindowsRuntimeFileSecurity();

  static const _systemSid = 'S-1-5-18';
  static const _administratorsSid = 'S-1-5-32-544';

  @override
  Future<void> hardenDirectory(Directory directory) async {
    final userSid = await _currentUserSid();
    await _apply(directory.path, <String>[
      '*$userSid:(OI)(CI)F',
      '*$_systemSid:(OI)(CI)F',
      '*$_administratorsSid:(OI)(CI)F',
    ]);
  }

  @override
  Future<void> hardenFile(File file) async {
    final userSid = await _currentUserSid();
    await _apply(file.path, <String>[
      '*$userSid:F',
      '*$_systemSid:F',
      '*$_administratorsSid:F',
    ]);
  }

  Future<String> _currentUserSid() async {
    if (!Platform.isWindows) {
      throw const AppException(
        'Windows runtime ACL hardening is unavailable on this platform.',
      );
    }
    final result = await Process.run('whoami.exe', const <String>[
      '/user',
      '/fo',
      'csv',
      '/nh',
    ], runInShell: false);
    final output = '${result.stdout} ${result.stderr}';
    final sid = RegExp(r'S-1-(?:\d+-)+\d+').firstMatch(output)?.group(0);
    if (result.exitCode != 0 || sid == null) {
      throw const AppException(
        'Could not resolve the current Windows user SID.',
      );
    }
    return sid;
  }

  Future<void> _apply(String path, List<String> grants) async {
    final result = await Process.run('icacls.exe', <String>[
      path,
      '/inheritance:r',
      '/grant:r',
      ...grants,
      '/q',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw AppException(
        'Could not restrict access to the Mihomo runtime configuration.',
        cause: '${result.stdout}\n${result.stderr}',
      );
    }
  }
}

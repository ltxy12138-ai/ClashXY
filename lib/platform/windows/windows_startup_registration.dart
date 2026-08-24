import 'dart:io';

abstract interface class StartupRegistration {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class WindowsStartupRegistration implements StartupRegistration {
  WindowsStartupRegistration({ProcessRunner? runner})
    : _runner = runner ?? _runProcess;

  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'ClashXY';
  static const _legacyValueNames = <String>['MyTunnel', 'MyMihomo'];

  final ProcessRunner _runner;

  String get command => '"${Platform.resolvedExecutable}" --startup';

  @override
  Future<bool> isEnabled() async {
    final current = await _query(_valueName);
    if (current != null) {
      return current.toLowerCase().contains(command.toLowerCase());
    }
    for (final legacyName in _legacyValueNames) {
      if (await _query(legacyName) == null) continue;
      await _writeCurrent();
      await _deleteLegacyValues();
      return true;
    }
    return false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _writeCurrent();
    } else {
      await _deleteValue(_valueName);
    }
    await _deleteLegacyValues();
  }

  Future<String?> _query(String valueName) async {
    final result = await _runner('reg.exe', <String>[
      'query',
      _runKey,
      '/v',
      valueName,
    ]);
    return result.exitCode == 0 ? '${result.stdout}' : null;
  }

  Future<void> _writeCurrent() async {
    final arguments = <String>[
      'add',
      _runKey,
      '/v',
      _valueName,
      '/t',
      'REG_SZ',
      '/d',
      command,
      '/f',
    ];
    final result = await _runner('reg.exe', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'reg.exe',
        arguments,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
  }

  Future<void> _deleteLegacyValues() async {
    for (final valueName in _legacyValueNames) {
      await _deleteValue(valueName);
    }
  }

  Future<void> _deleteValue(String valueName) async {
    // Deleting an already absent value is the desired end state.
    await _runner('reg.exe', <String>[
      'delete',
      _runKey,
      '/v',
      valueName,
      '/f',
    ]);
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) => Process.run(executable, arguments, runInShell: false);
}

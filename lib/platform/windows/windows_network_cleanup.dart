import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../core/errors/app_exception.dart';

enum WindowsNetworkCleanupOutcome { unchanged, cleaned }

class WindowsPowerShellResult {
  const WindowsPowerShellResult({required this.exitCode, required this.stdout});

  final int exitCode;
  final String stdout;
}

typedef WindowsPowerShellRunner = Future<WindowsPowerShellResult> Function(
  String script,
);

class WindowsNetworkCleanup {
  WindowsNetworkCleanup({WindowsPowerShellRunner? runner})
    : _runner = runner ?? _runPowerShell;

  final WindowsPowerShellRunner _runner;

  static final RegExp safeDeviceName = RegExp(r'^[A-Za-z0-9 _.-]{1,64}$');

  Future<WindowsNetworkCleanupOutcome> cleanup({
    required String deviceName,
    required String coreExecutablePath,
  }) async {
    final script = buildScript(
      deviceName: deviceName,
      coreExecutablePath: coreExecutablePath,
    );
    WindowsPowerShellResult result;
    try {
      result = await _runner(script).timeout(const Duration(seconds: 20));
    } catch (error) {
      throw MihomoException(_failureMessage, cause: error);
    }
    if (result.exitCode != 0) throw const MihomoException(_failureMessage);
    final output = result.stdout
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .lastOrNull;
    return switch (output) {
      'CLEANED' => WindowsNetworkCleanupOutcome.cleaned,
      'NOT_FOUND' => WindowsNetworkCleanupOutcome.unchanged,
      _ => throw const MihomoException(_failureMessage),
    };
  }

  static String buildScript({
    required String deviceName,
    required String coreExecutablePath,
  }) {
    if (!safeDeviceName.hasMatch(deviceName)) {
      throw const MihomoException(
        'TUN device name contains unsupported characters.',
      );
    }
    if (!path.isAbsolute(coreExecutablePath)) {
      throw const MihomoException('Mihomo core path must be absolute.');
    }
    final escapedDevice = deviceName.replaceAll("'", "''");
    final escapedCore = path
        .normalize(coreExecutablePath)
        .replaceAll("'", "''");
    return _scriptTemplate
        .replaceAll('__DEVICE_NAME__', escapedDevice)
        .replaceAll('__CORE_PATH__', escapedCore);
  }

  static Future<WindowsPowerShellResult> _runPowerShell(String script) async {
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ], runInShell: false);
    return WindowsPowerShellResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
    );
  }

  static const String _failureMessage =
      'Windows 无法清理 ClashXY 的旧 TUN/DNS 状态，请重启系统后重试。';

  static const String _scriptTemplate = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$changed = $false
$corePath = [System.IO.Path]::GetFullPath('__CORE_PATH__')

try {
  $ownedProcesses = @(
    Get-CimInstance Win32_Process -Filter "Name = 'current.exe'" -ErrorAction SilentlyContinue |
      Where-Object {
        $_.ExecutablePath -and
        ([System.IO.Path]::GetFullPath($_.ExecutablePath) -ieq $corePath)
      }
  )
  foreach ($ownedProcess in $ownedProcesses) {
    $termination = Invoke-CimMethod -InputObject $ownedProcess -MethodName Terminate -ErrorAction Stop
    if ($termination.ReturnValue -ne 0) { throw 'Owned Mihomo termination failed.' }
    $changed = $true
  }
  if ($ownedProcesses.Count -gt 0) { Start-Sleep -Milliseconds 300 }

  $adapter = Get-NetAdapter -IncludeHidden -Name '__DEVICE_NAME__' -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceDescription -eq 'Meta Tunnel' } |
    Select-Object -First 1
  if ($null -ne $adapter) {
    $routes = @(
      Get-NetRoute -InterfaceIndex $adapter.ifIndex -PolicyStore ActiveStore -ErrorAction SilentlyContinue
    )
    if ($routes.Count -gt 0) {
      $routes | Remove-NetRoute -Confirm:$false -ErrorAction Stop
    }
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction Stop
    if ($adapter.Status -ne 'Disabled') {
      Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
    }
    $changed = $true
  }

  if ($changed) {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Output 'CLEANED'
  } else {
    Write-Output 'NOT_FOUND'
  }
  exit 0
} catch {
  exit 1
}
''';
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

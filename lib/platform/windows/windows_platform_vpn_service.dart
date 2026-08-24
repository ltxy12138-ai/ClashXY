import 'dart:convert';
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../platform_vpn_service.dart';

class WindowsPlatformVpnService implements PlatformVpnService {
  const WindowsPlatformVpnService();

  @override
  Future<bool> isAdministrator() async {
    if (!Platform.isWindows) return false;
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent();$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
    ], runInShell: false);
    return result.exitCode == 0 && result.stdout.toString().trim() == 'True';
  }

  @override
  Future<bool> adapterExists(String deviceName) async {
    if (!_safeName.hasMatch(deviceName)) {
      throw const MihomoException(
        'TUN device name contains unsupported characters.',
      );
    }
    final escaped = deviceName.replaceAll("'", "''");
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "[bool](Get-NetAdapter -Name '$escaped' -ErrorAction SilentlyContinue)",
    ], runInShell: false);
    return result.exitCode == 0 && result.stdout.toString().trim() == 'True';
  }

  @override
  Future<List<String>> activeMihomoTunAdapters() async {
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -eq 'Meta Tunnel' } | Select-Object -ExpandProperty Name",
    ], runInShell: false);
    if (result.exitCode != 0) return const <String>[];
    return const LineSplitter()
        .convert(result.stdout.toString())
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> waitForAdapter(
    String deviceName, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await adapterExists(deviceName)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return false;
  }

  @override
  Future<bool> hasInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static final RegExp _safeName = RegExp(r'^[A-Za-z0-9 _.-]{1,64}$');
}

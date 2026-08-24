import 'package:clashxy/core/errors/app_exception.dart';
import 'package:clashxy/platform/windows/windows_network_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

const _corePath =
    r'C:\Users\Test User\AppData\Roaming\ClashXY\core\current.exe';

void main() {
  test('builds an ownership-scoped Windows cleanup script', () {
    final script = WindowsNetworkCleanup.buildScript(
      deviceName: 'ClashXY',
      coreExecutablePath: _corePath,
    );

    expect(script, contains("Name = 'current.exe'"));
    expect(script, contains(r"-ieq $corePath"));
    expect(script, contains(r"Get-NetAdapter -IncludeHidden -Name 'ClashXY'"));
    expect(script, contains(r"$_.InterfaceDescription -eq 'Meta Tunnel'"));
    expect(script, contains('Get-NetRoute -InterfaceIndex'));
    expect(script, contains('-PolicyStore ActiveStore'));
    expect(script, contains('Remove-NetRoute -Confirm:\$false'));
    expect(script, contains('-ResetServerAddresses'));
    expect(script, contains('Disable-NetAdapter -Name \$adapter.Name'));
    expect(script, contains('Clear-DnsClientCache'));
    expect(script, isNot(contains('Stop-Process -Name')));
  });

  test('rejects an unsafe TUN device name before running PowerShell', () {
    expect(
      () => WindowsNetworkCleanup.buildScript(
        deviceName: "ClashXY'; Remove-Item C:\\*; #",
        coreExecutablePath: _corePath,
      ),
      throwsA(isA<MihomoException>()),
    );
  });

  test('rejects a relative core executable path', () {
    expect(
      () => WindowsNetworkCleanup.buildScript(
        deviceName: 'ClashXY',
        coreExecutablePath: r'core\current.exe',
      ),
      throwsA(isA<MihomoException>()),
    );
  });

  test('reports when stale state was cleaned', () async {
    final cleanup = WindowsNetworkCleanup(
      runner: (_) async =>
          const WindowsPowerShellResult(exitCode: 0, stdout: 'CLEANED\r\n'),
    );

    expect(
      await cleanup.cleanup(
        deviceName: 'ClashXY',
        coreExecutablePath: _corePath,
      ),
      WindowsNetworkCleanupOutcome.cleaned,
    );
  });

  test('reports when no stale state exists', () async {
    final cleanup = WindowsNetworkCleanup(
      runner: (_) async => const WindowsPowerShellResult(
        exitCode: 0,
        stdout: 'diagnostic\nNOT_FOUND\n',
      ),
    );

    expect(
      await cleanup.cleanup(
        deviceName: 'ClashXY',
        coreExecutablePath: _corePath,
      ),
      WindowsNetworkCleanupOutcome.unchanged,
    );
  });

  test('returns a safe error without exposing PowerShell output', () async {
    const secretOutput = 'failure subscription-token=do-not-expose';
    final cleanup = WindowsNetworkCleanup(
      runner: (_) async =>
          const WindowsPowerShellResult(exitCode: 1, stdout: secretOutput),
    );

    await expectLater(
      cleanup.cleanup(deviceName: 'ClashXY', coreExecutablePath: _corePath),
      throwsA(
        isA<MihomoException>().having(
          (error) => error.toString(),
          'safe message',
          isNot(contains(secretOutput)),
        ),
      ),
    );
  });
}

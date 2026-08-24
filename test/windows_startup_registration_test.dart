import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clashxy/platform/windows/windows_startup_registration.dart';

void main() {
  test(
    'startup registration reads and writes the current executable',
    () async {
      final calls = <List<String>>[];
      late WindowsStartupRegistration registration;
      registration = WindowsStartupRegistration(
        runner: (executable, arguments) async {
          calls.add(<String>[executable, ...arguments]);
          if (arguments.first == 'query') {
            return ProcessResult(
              1,
              0,
              'ClashXY    REG_SZ    ${registration.command}',
              '',
            );
          }
          return ProcessResult(1, 0, '', '');
        },
      );

      expect(await registration.isEnabled(), isTrue);
      await registration.setEnabled(true);
      await registration.setEnabled(false);

      expect(
        calls[0],
        containsAllInOrder(<String>['reg.exe', 'query', '/v', 'ClashXY']),
      );
      expect(
        calls[1],
        containsAllInOrder(<String>[
          'reg.exe',
          'add',
          '/v',
          'ClashXY',
          '/d',
          registration.command,
          '/f',
        ]),
      );
      expect(calls.where((call) => call.contains('MyTunnel')), isNotEmpty);
      expect(calls.where((call) => call.contains('MyMihomo')), isNotEmpty);
    },
  );

  test('migrates a legacy startup value to ClashXY', () async {
    final calls = <List<String>>[];
    final registration = WindowsStartupRegistration(
      runner: (executable, arguments) async {
        calls.add(<String>[executable, ...arguments]);
        if (arguments.first == 'query') {
          final valueName = arguments[3];
          if (valueName == 'MyTunnel') {
            return ProcessResult(
              1,
              0,
              'MyTunnel REG_SZ "C:\\old\\MyTunnel.exe" --startup',
              '',
            );
          }
          return ProcessResult(1, 1, '', 'missing');
        }
        return ProcessResult(1, 0, '', '');
      },
    );

    expect(await registration.isEnabled(), isTrue);
    expect(
      calls,
      contains(
        containsAllInOrder(<String>[
          'reg.exe',
          'add',
          '/v',
          'ClashXY',
          '/d',
          registration.command,
        ]),
      ),
    );
    expect(
      calls,
      contains(
        containsAllInOrder(<String>['reg.exe', 'delete', '/v', 'MyTunnel']),
      ),
    );
  });

  test(
    'missing startup value is disabled and deletion is idempotent',
    () async {
      final registration = WindowsStartupRegistration(
        runner: (executable, arguments) async =>
            ProcessResult(1, 1, '', 'missing'),
      );

      expect(await registration.isEnabled(), isFalse);
      await expectLater(registration.setEnabled(false), completes);
      await expectLater(
        registration.setEnabled(true),
        throwsA(isA<ProcessException>()),
      );
    },
  );
}

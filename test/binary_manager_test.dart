import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clashxy/core/errors/app_exception.dart';
import 'package:clashxy/core/mihomo/binary_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory support;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('clashxy-binary-test-');
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  test('installs the verified bundled core and writes metadata', () async {
    final bundle = _coreBytes('1.0.0');
    final manager = _manager(support, bundle: bundle);

    final installed = await manager.inspect();

    expect(installed.version, '1.0.0');
    expect(await installed.executable.readAsBytes(), bundle);
    expect(
      await File(
        '${manager.coreDirectory.path}${Platform.pathSeparator}installed.json',
      ).exists(),
      isTrue,
    );
  });

  test('keeps a verified downloaded core across manager recreation', () async {
    final bundle = _coreBytes('1.0.0');
    final manager = _manager(support, bundle: bundle);
    await manager.installUpdate(
      executableBytes: _coreBytes('2.0.0'),
      version: '2.0.0',
    );
    final recreatedSource = _MemoryBinarySource(bundle);
    final recreated = _manager(
      support,
      bundle: bundle,
      source: recreatedSource,
    );

    final installed = await recreated.inspect();

    expect(installed.version, '2.0.0');
    expect(recreatedSource.loads, 0);
    expect(await recreated.canRollback(), isTrue);
  });

  test('rejects a staged core whose reported version does not match', () async {
    final bundle = _coreBytes('1.0.0');
    final manager = BinaryManager(
      supportDirectory: support,
      source: _MemoryBinarySource(bundle),
      expectedSha256: sha256.convert(bundle).toString(),
      bundledVersion: '1.0.0',
      versionProbe: (_) async => '9.9.9',
    );
    await manager.inspect();

    await expectLater(
      manager.installUpdate(
        executableBytes: _coreBytes('2.0.0'),
        version: '2.0.0',
      ),
      throwsA(isA<MihomoException>()),
    );

    expect((await manager.inspect()).version, '1.0.0');
    expect(await manager.canRollback(), isFalse);
  });

  test(
    'rollback restores only an older core and cannot switch forward again',
    () async {
      final bundle = _coreBytes('1.0.0');
      final manager = _manager(support, bundle: bundle);
      await manager.installUpdate(
        executableBytes: _coreBytes('2.0.0'),
        version: '2.0.0',
      );

      final rolledBack = await manager.rollback();

      expect(rolledBack.version, '1.0.0');
      expect(await manager.canRollback(), isFalse);
      await expectLater(manager.rollback(), throwsA(isA<MihomoException>()));
    },
  );

  test(
    'restores the verified previous core after an interrupted switch',
    () async {
      final bundle = _coreBytes('1.0.0');
      final manager = _manager(support, bundle: bundle);
      await manager.installUpdate(
        executableBytes: _coreBytes('2.0.0'),
        version: '2.0.0',
      );
      await File(manager.currentExecutablePath).delete();
      await File(
        '${manager.coreDirectory.path}${Platform.pathSeparator}installed.json',
      ).delete();

      final restored = await manager.inspect();

      expect(restored.version, '1.0.0');
      expect(await restored.executable.readAsBytes(), bundle);
    },
  );

  test('does not run a bundled core with the wrong digest', () async {
    final bundle = _coreBytes('1.0.0');
    final manager = BinaryManager(
      supportDirectory: support,
      source: _MemoryBinarySource(bundle),
      expectedSha256: List<String>.filled(64, '0').join(),
      bundledVersion: '1.0.0',
      versionProbe: _versionFromBytes,
    );

    await expectLater(manager.inspect(), throwsA(isA<MihomoException>()));
    expect(await File(manager.currentExecutablePath).exists(), isFalse);
  });
}

BinaryManager _manager(
  Directory support, {
  required Uint8List bundle,
  _MemoryBinarySource? source,
}) => BinaryManager(
  supportDirectory: support,
  source: source ?? _MemoryBinarySource(bundle),
  expectedSha256: sha256.convert(bundle).toString(),
  bundledVersion: '1.0.0',
  versionProbe: _versionFromBytes,
);

Uint8List _coreBytes(String version) =>
    Uint8List.fromList(utf8.encode('fake-mihomo:$version'));

Future<String> _versionFromBytes(File executable) async =>
    utf8.decode(await executable.readAsBytes()).split(':').last;

class _MemoryBinarySource implements MihomoBinarySource {
  _MemoryBinarySource(this.bytes);

  final Uint8List bytes;
  int loads = 0;

  @override
  Future<Uint8List> load() async {
    loads++;
    return bytes;
  }
}

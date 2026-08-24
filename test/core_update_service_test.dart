import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:clashxy/core/errors/app_exception.dart';
import 'package:clashxy/core/mihomo/binary_manager.dart';
import 'package:clashxy/core/mihomo/core_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory support;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('clashxy-update-test-');
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  test('downloads, verifies, extracts and switches to a newer core', () async {
    final executable = _coreBytes('2.0.0');
    final archive = _zip(<String, Uint8List>{
      'mihomo-windows-amd64-compatible.exe': executable,
    });
    final release = _release('2.0.0', archive);
    final source = _ReleaseSource(release: release, archive: archive);
    final binary = _manager(support);
    final service = MihomoCoreUpdateService(
      binary: binary,
      releaseSource: source,
    );
    final stages = <MihomoCoreApplyStage>[];

    final check = await service.check();
    final installed = await service.install(
      check.latest,
      onProgress: stages.add,
    );

    expect(check.updateAvailable, isTrue);
    expect(installed.version, '2.0.0');
    expect(stages, <MihomoCoreApplyStage>[
      MihomoCoreApplyStage.downloading,
      MihomoCoreApplyStage.installing,
    ]);
    expect(source.downloads, 1);
    expect(await binary.canRollback(), isTrue);
  });

  test('rejects an archive whose official digest does not match', () async {
    final archive = _zip(<String, Uint8List>{
      'mihomo-windows-amd64-compatible.exe': _coreBytes('2.0.0'),
    });
    final valid = _release('2.0.0', archive);
    final release = MihomoCoreRelease(
      version: valid.version,
      assetName: valid.assetName,
      downloadUri: valid.downloadUri,
      archiveSha256: List<String>.filled(64, '0').join(),
      archiveSize: valid.archiveSize,
    );
    final binary = _manager(support);
    final service = MihomoCoreUpdateService(
      binary: binary,
      releaseSource: _ReleaseSource(release: release, archive: archive),
    );

    await expectLater(
      service.install(release),
      throwsA(isA<MihomoException>()),
    );

    expect((await binary.inspect()).version, '1.0.0');
    expect(await binary.canRollback(), isFalse);
  });

  test('rejects nested or ambiguous executables in a verified archive', () {
    const decoder = ZipMihomoArchiveDecoder();
    final nested = _zip(<String, Uint8List>{
      'nested/mihomo-windows-amd64-compatible.exe': _coreBytes('2.0.0'),
    });
    final ambiguous = _zip(<String, Uint8List>{
      'mihomo-windows-amd64-compatible.exe': _coreBytes('2.0.0'),
      'mihomo-windows-amd64-compatible-v2.0.0.exe': _coreBytes('2.0.0'),
    });

    expect(
      () => decoder.extractExecutable(nested),
      throwsA(isA<MihomoException>()),
    );
    expect(
      () => decoder.extractExecutable(ambiguous),
      throwsA(isA<MihomoException>()),
    );
  });

  test('compares stable semantic versions without lexical mistakes', () {
    expect(MihomoCoreUpdateService.compareVersions('v1.20.0', '1.9.9'), 1);
    expect(MihomoCoreUpdateService.compareVersions('1.19.30', '1.19.30'), 0);
    expect(MihomoCoreUpdateService.compareVersions('1.18.9', '1.19.0'), -1);
    expect(
      () => MihomoCoreUpdateService.compareVersions('latest', '1.0.0'),
      throwsA(isA<MihomoException>()),
    );
  });
}

BinaryManager _manager(Directory support) {
  final bundle = _coreBytes('1.0.0');
  return BinaryManager(
    supportDirectory: support,
    source: _BinarySource(bundle),
    expectedSha256: sha256.convert(bundle).toString(),
    bundledVersion: '1.0.0',
    versionProbe: (file) async =>
        utf8.decode(await file.readAsBytes()).split(':').last,
  );
}

MihomoCoreRelease _release(String version, Uint8List archive) =>
    MihomoCoreRelease(
      version: version,
      assetName: 'mihomo-windows-amd64-compatible-v$version.zip',
      downloadUri: Uri.parse(
        'https://github.com/MetaCubeX/mihomo/releases/download/'
        'v$version/mihomo-windows-amd64-compatible-v$version.zip',
      ),
      archiveSha256: sha256.convert(archive).toString(),
      archiveSize: archive.length,
    );

Uint8List _zip(Map<String, Uint8List> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List _coreBytes(String version) =>
    Uint8List.fromList(utf8.encode('fake-mihomo:$version'));

class _BinarySource implements MihomoBinarySource {
  const _BinarySource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> load() async => bytes;
}

class _ReleaseSource implements MihomoReleaseSource {
  _ReleaseSource({required this.release, required this.archive});

  final MihomoCoreRelease release;
  final Uint8List archive;
  int downloads = 0;

  @override
  Future<MihomoCoreRelease> latest() async => release;

  @override
  Future<Uint8List> download(MihomoCoreRelease release) async {
    downloads++;
    return archive;
  }

  @override
  void dispose() {}
}

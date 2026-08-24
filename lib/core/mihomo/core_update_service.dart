import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../core/errors/app_exception.dart';
import 'binary_manager.dart';

class MihomoCoreRelease {
  const MihomoCoreRelease({
    required this.version,
    required this.assetName,
    required this.downloadUri,
    required this.archiveSha256,
    required this.archiveSize,
  });

  final String version;
  final String assetName;
  final Uri downloadUri;
  final String archiveSha256;
  final int archiveSize;
}

abstract interface class MihomoReleaseSource {
  Future<MihomoCoreRelease> latest();

  Future<Uint8List> download(MihomoCoreRelease release);

  void dispose();
}

abstract interface class MihomoArchiveDecoder {
  Uint8List extractExecutable(Uint8List archiveBytes);
}

class ZipMihomoArchiveDecoder implements MihomoArchiveDecoder {
  const ZipMihomoArchiveDecoder();

  @override
  Uint8List extractExecutable(Uint8List archiveBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
      final executables = archive.files.where(
        (file) =>
            file.isFile &&
            !file.name.contains('/') &&
            !file.name.contains(r'\') &&
            _executableName.hasMatch(file.name),
      );
      if (executables.length != 1) {
        throw const MihomoException(
          'Mihomo release archive does not contain one supported executable.',
        );
      }
      final executable = executables.single;
      if (executable.size <= 0 || executable.size > _maxExecutableBytes) {
        throw const MihomoException(
          'Mihomo release executable has an invalid size.',
        );
      }
      return executable.content;
    } on MihomoException {
      rethrow;
    } catch (error) {
      throw MihomoException(
        'Mihomo release archive could not be verified or decoded.',
        cause: error,
      );
    }
  }

  static final RegExp _executableName = RegExp(
    r'^mihomo-windows-amd64-compatible(?:-v\d+\.\d+\.\d+)?\.exe$',
    caseSensitive: false,
  );
  static const int _maxExecutableBytes = 128 * 1024 * 1024;
}

class MihomoCoreUpdateCheck {
  const MihomoCoreUpdateCheck({
    required this.installed,
    required this.latest,
    required this.updateAvailable,
    required this.canRollback,
  });

  final InstalledMihomoCore installed;
  final MihomoCoreRelease latest;
  final bool updateAvailable;
  final bool canRollback;
}

enum MihomoCoreApplyStage { downloading, installing }

typedef MihomoCoreUpdateProgress = void Function(MihomoCoreApplyStage stage);

class MihomoCoreUpdateService {
  const MihomoCoreUpdateService({
    required this.binary,
    required this.releaseSource,
    this.archiveDecoder = const ZipMihomoArchiveDecoder(),
  });

  final BinaryManager binary;
  final MihomoReleaseSource releaseSource;
  final MihomoArchiveDecoder archiveDecoder;

  Future<MihomoCoreUpdateCheck> check() async {
    final installed = await binary.inspect();
    final latest = await releaseSource.latest();
    return MihomoCoreUpdateCheck(
      installed: installed,
      latest: latest,
      updateAvailable: compareVersions(latest.version, installed.version) > 0,
      canRollback: await binary.canRollback(installed: installed),
    );
  }

  Future<InstalledMihomoCore> install(
    MihomoCoreRelease release, {
    MihomoCoreUpdateProgress? onProgress,
  }) async {
    final installed = await binary.inspect();
    if (compareVersions(release.version, installed.version) <= 0) {
      throw const MihomoException(
        'The selected Mihomo release is not newer than the installed core.',
      );
    }
    onProgress?.call(MihomoCoreApplyStage.downloading);
    final archiveBytes = await releaseSource.download(release);
    if (archiveBytes.length != release.archiveSize ||
        archiveBytes.isEmpty ||
        archiveBytes.length > _maxArchiveBytes) {
      throw const MihomoException(
        'Downloaded Mihomo release has an unexpected size.',
      );
    }
    final archiveDigest = sha256.convert(archiveBytes).toString();
    if (archiveDigest.toLowerCase() != release.archiveSha256.toLowerCase()) {
      throw const MihomoException(
        'Downloaded Mihomo release failed SHA-256 verification.',
      );
    }
    final executable = archiveDecoder.extractExecutable(archiveBytes);
    onProgress?.call(MihomoCoreApplyStage.installing);
    return binary.installUpdate(
      executableBytes: executable,
      version: release.version,
    );
  }

  Future<InstalledMihomoCore> rollback() => binary.rollback();

  static int compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);
    for (var index = 0; index < leftParts.length; index++) {
      final comparison = leftParts[index].compareTo(rightParts[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static List<int> _parseVersion(String version) {
    final match = _versionPattern.firstMatch(version.trim());
    if (match == null) {
      throw const MihomoException('Mihomo release version is invalid.');
    }
    return <int>[
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    ];
  }

  static final RegExp _versionPattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');
  static const int _maxArchiveBytes = 64 * 1024 * 1024;
}

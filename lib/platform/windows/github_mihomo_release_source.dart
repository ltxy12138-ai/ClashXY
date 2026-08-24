import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/mihomo/core_update_service.dart';

class GitHubMihomoReleaseSource implements MihomoReleaseSource {
  GitHubMihomoReleaseSource({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  @override
  Future<MihomoCoreRelease> latest() async {
    final bytes = await _downloadBytes(
      _latestReleaseUri,
      maxBytes: _maxMetadataBytes,
      accept: 'application/vnd.github+json',
    );
    try {
      return parseReleasePayload(jsonDecode(utf8.decode(bytes)));
    } on MihomoException {
      rethrow;
    } catch (error) {
      throw MihomoException(
        'Mihomo release metadata is invalid.',
        cause: error,
      );
    }
  }

  @override
  Future<Uint8List> download(MihomoCoreRelease release) {
    _validateAssetUri(
      release.downloadUri,
      version: release.version,
      assetName: release.assetName,
    );
    if (release.archiveSize <= 0 || release.archiveSize > _maxArchiveBytes) {
      throw const MihomoException('Mihomo release asset size is invalid.');
    }
    return _downloadBytes(
      release.downloadUri,
      maxBytes: _maxArchiveBytes,
      accept: 'application/octet-stream',
    );
  }

  static MihomoCoreRelease parseReleasePayload(Object? payload) {
    if (payload is! Map<String, dynamic> ||
        payload['draft'] != false ||
        payload['prerelease'] != false) {
      throw const MihomoException(
        'GitHub did not return a stable Mihomo release.',
      );
    }
    final tag = payload['tag_name'];
    if (tag is! String || !_versionPattern.hasMatch(tag)) {
      throw const MihomoException('Mihomo release tag is invalid.');
    }
    final version = tag.substring(1);
    final assetName = 'mihomo-windows-amd64-compatible-v$version.zip';
    final assets = payload['assets'];
    if (assets is! List) {
      throw const MihomoException('Mihomo release assets are missing.');
    }
    final matches = assets.whereType<Map<String, dynamic>>().where(
      (asset) => asset['name'] == assetName,
    );
    if (matches.length != 1) {
      throw const MihomoException(
        'The stable Mihomo release has no unique compatible Windows asset.',
      );
    }
    final asset = matches.single;
    if (asset['content_type'] != 'application/zip') {
      throw const MihomoException('Mihomo Windows release is not a ZIP asset.');
    }
    final digest = asset['digest'];
    final digestMatch = digest is String
        ? _digestPattern.firstMatch(digest)
        : null;
    if (digestMatch == null) {
      throw const MihomoException(
        'Mihomo Windows release has no trusted SHA-256 digest.',
      );
    }
    final size = asset['size'];
    if (size is! int || size <= 0 || size > _maxArchiveBytes) {
      throw const MihomoException('Mihomo Windows release size is invalid.');
    }
    final download = asset['browser_download_url'];
    final uri = download is String ? Uri.tryParse(download) : null;
    if (uri == null) {
      throw const MihomoException('Mihomo Windows release URL is invalid.');
    }
    _validateAssetUri(uri, version: version, assetName: assetName);
    return MihomoCoreRelease(
      version: version,
      assetName: assetName,
      downloadUri: uri,
      archiveSha256: digestMatch[1]!.toLowerCase(),
      archiveSize: size,
    );
  }

  Future<Uint8List> _downloadBytes(
    Uri initialUri, {
    required int maxBytes,
    required String accept,
  }) async {
    var currentUri = initialUri;
    try {
      for (var redirect = 0; redirect <= _maxRedirects; redirect++) {
        _validateRequestUri(currentUri);
        final request = http.Request('GET', currentUri)
          ..followRedirects = false
          ..headers.addAll(<String, String>{
            'Accept': accept,
            'User-Agent': 'ClashXY-Core-Updater',
            'X-GitHub-Api-Version': '2022-11-28',
          });
        final response = await _client.send(request).timeout(timeout);
        if (_redirectStatuses.contains(response.statusCode)) {
          final location = response.headers['location'];
          await response.stream.drain<void>();
          if (location == null || redirect == _maxRedirects) {
            throw const MihomoException(
              'Mihomo download redirected unexpectedly.',
            );
          }
          currentUri = currentUri.resolve(location);
          continue;
        }
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw const MihomoException('Mihomo download request failed.');
        }
        final contentLength = response.contentLength;
        if (contentLength != null && contentLength > maxBytes) {
          await response.stream.drain<void>();
          throw const MihomoException('Mihomo download is too large.');
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(timeout)) {
          builder.add(chunk);
          if (builder.length > maxBytes) {
            throw const MihomoException('Mihomo download is too large.');
          }
        }
        return builder.takeBytes();
      }
    } on MihomoException {
      rethrow;
    } catch (error) {
      throw MihomoException('Mihomo download failed.', cause: error);
    }
    throw const MihomoException('Mihomo download redirected unexpectedly.');
  }

  static void _validateRequestUri(Uri uri) {
    final trustedHost =
        uri.host == 'api.github.com' ||
        uri.host == 'github.com' ||
        uri.host.endsWith('.githubusercontent.com');
    if (uri.scheme != 'https' || !trustedHost || uri.hasFragment) {
      throw const MihomoException(
        'Mihomo update request left the trusted HTTPS origin set.',
      );
    }
  }

  static void _validateAssetUri(
    Uri uri, {
    required String version,
    required String assetName,
  }) {
    final expectedPath =
        '/MetaCubeX/mihomo/releases/download/v$version/$assetName';
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.path != expectedPath ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const MihomoException(
        'Mihomo release asset is outside the official HTTPS repository.',
      );
    }
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }

  static final Uri _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/MetaCubeX/mihomo/releases/latest',
  );
  static final RegExp _versionPattern = RegExp(r'^v\d+\.\d+\.\d+$');
  static final RegExp _digestPattern = RegExp(r'^sha256:([0-9a-fA-F]{64})$');
  static const Set<int> _redirectStatuses = <int>{301, 302, 303, 307, 308};
  static const int _maxRedirects = 5;
  static const int _maxMetadataBytes = 2 * 1024 * 1024;
  static const int _maxArchiveBytes = 64 * 1024 * 1024;
}

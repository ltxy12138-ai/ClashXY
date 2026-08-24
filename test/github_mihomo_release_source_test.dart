import 'dart:async';
import 'dart:convert';

import 'package:clashxy/core/errors/app_exception.dart';
import 'package:clashxy/platform/windows/github_mihomo_release_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses the unique official compatible Windows asset', () {
    final release = GitHubMihomoReleaseSource.parseReleasePayload(_payload());

    expect(release.version, '1.19.30');
    expect(release.assetName, 'mihomo-windows-amd64-compatible-v1.19.30.zip');
    expect(release.archiveSha256, List<String>.filled(64, 'a').join());
    expect(release.archiveSize, 18529108);
  });

  test('rejects prereleases and assets without an official digest', () {
    final prerelease = _payload()..['prerelease'] = true;
    final noDigest = _payload();
    (noDigest['assets'] as List).single['digest'] = null;

    expect(
      () => GitHubMihomoReleaseSource.parseReleasePayload(prerelease),
      throwsA(isA<MihomoException>()),
    );
    expect(
      () => GitHubMihomoReleaseSource.parseReleasePayload(noDigest),
      throwsA(isA<MihomoException>()),
    );
  });

  test('rejects a release asset outside the official repository', () {
    final payload = _payload();
    (payload['assets'] as List).single['browser_download_url'] =
        'https://example.test/mihomo.zip';

    expect(
      () => GitHubMihomoReleaseSource.parseReleasePayload(payload),
      throwsA(isA<MihomoException>()),
    );
  });

  test('requests official release metadata with bounded API headers', () async {
    late http.Request observed;
    final source = GitHubMihomoReleaseSource(
      client: MockClient((request) async {
        observed = request;
        return http.Response(jsonEncode(_payload()), 200);
      }),
    );

    final release = await source.latest();

    expect(observed.url.host, 'api.github.com');
    expect(observed.headers['User-Agent'], 'ClashXY-Core-Updater');
    expect(release.version, '1.19.30');
    source.dispose();
  });

  test('refuses redirects that leave trusted HTTPS GitHub hosts', () async {
    final source = GitHubMihomoReleaseSource(
      client: MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: <String, String>{'location': 'http://example.test/core.zip'},
        ),
      ),
    );

    await expectLater(source.latest(), throwsA(isA<MihomoException>()));
    source.dispose();
  });

  test(
    'enforces an absolute deadline for a continuously active body',
    () async {
      final source = GitHubMihomoReleaseSource(
        client: _SlowStreamingClient(),
        timeout: const Duration(milliseconds: 100),
        totalTimeout: const Duration(milliseconds: 45),
      );
      final stopwatch = Stopwatch()..start();

      await expectLater(source.latest(), throwsA(isA<MihomoException>()));

      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      source.dispose();
    },
  );
}

class _SlowStreamingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.periodic(
        const Duration(milliseconds: 10),
        (_) => const <int>[32],
      ),
      200,
    );
  }
}

Map<String, dynamic> _payload() => <String, dynamic>{
  'tag_name': 'v1.19.30',
  'draft': false,
  'prerelease': false,
  'assets': <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'mihomo-windows-amd64-compatible-v1.19.30.zip',
      'content_type': 'application/zip',
      'digest': 'sha256:${List<String>.filled(64, 'a').join()}',
      'size': 18529108,
      'browser_download_url':
          'https://github.com/MetaCubeX/mihomo/releases/download/'
          'v1.19.30/mihomo-windows-amd64-compatible-v1.19.30.zip',
    },
  ],
};

# Public release checklist

## Release decisions

- [x] Public product and repository name: `ClashXY`.
- [x] Source license: `GPL-3.0-only`; copyright notice: `Copyright (C) 2026
  ClashXY contributors`.

## Repository hygiene

- [x] Ignore `.tooling/`, `dist/`, local databases, runtime YAML, temporary
  configuration, signing certificates, and environment files.
- [x] Document local data, network requests, security boundaries, and third-party
  software.
- [ ] Initialize Git only after reviewing the final staged file list.
- [ ] Run a secret scan over staged files and commit history.
- [x] Scan the publishable source tree for common secret patterns, personal
  Windows paths, local databases, and private key material (2026-08-24). The
  only high-entropy match is an explicit unit-test fixture.
- [ ] Confirm no AppData, Documents database, exported YAML, lab results, or
  release ZIP is staged.

## Verification

- [x] `flutter gen-l10n`
- [x] `flutter analyze`
- [x] `flutter test` (37 tests)
- [x] `flutter build windows --release`
- [x] Verify the packaged Mihomo executable SHA-256.
- [x] Verify `ClashXY.exe` contains the `requireAdministrator` manifest.
- [x] Verify the release ZIP contains `THIRD_PARTY_NOTICES.md`, the Mihomo GPL
  license, and the Flutter `NOTICES.Z` bundle.
- [ ] Install and smoke-test on a clean Windows 10/11 x64 machine.

## Release publication

- [ ] Publish source for the tagged application revision.
- [ ] Keep the exact Mihomo corresponding-source link next to every binary
  download.
- [ ] Publish SHA-256 checksums for the release ZIP and bundled core.
- [ ] Enable GitHub private vulnerability reporting.

## Latest verified local artifact

- File: `dist/ClashXY-Windows-x64-1.4.0-build9.zip`
- SHA-256: `A0D438418AE629732B5A0FAD3C7CFB0C54E0E86E8E183AB90DAE3DCD8812183F`
- Bundled Mihomo SHA-256:
  `CF894375DBC00AB6708C1314AC35BBD29059F4C37F315353AACA7F1A9C566DE6`

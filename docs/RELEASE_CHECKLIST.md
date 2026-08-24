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
- [x] Initialize Git only after reviewing the final staged file list.
- [x] Run a secret scan over staged files and commit history.
- [x] Scan the publishable source tree for common secret patterns, personal
  Windows paths, local databases, and private key material (2026-08-24). The
  only high-entropy match is an explicit unit-test fixture.
- [x] Confirm no AppData, Documents database, exported YAML, lab results, or
  release ZIP is staged.

## Verification

- [x] `flutter gen-l10n`
- [x] `flutter analyze`
- [x] `flutter test` (73 tests)
- [x] `flutter build windows --release`
- [x] GitHub Windows CI (analysis, 73 tests, and Release build).
- [x] Run the manual Windows release-candidate workflow on `main`; GitHub run
  [32709049780](https://github.com/ltxy12138-ai/ClashXY/actions/runs/32709049780)
  produced the candidate from commit `70ba5e7` and both binary attestations
  verify against `ltxy12138-ai/ClashXY`.
- [x] Verify the packaged Mihomo executable SHA-256.
- [x] Verify `ClashXY.exe` contains the `requireAdministrator` manifest.
- [x] Verify the release ZIP contains `THIRD_PARTY_NOTICES.md`, the Mihomo GPL
  license, and the Flutter `NOTICES.Z` bundle.
- [x] Build the bilingual Inno Setup installer and verify an isolated
  `1.9.0+14` to `1.9.1+15` upgrade preserves existing application data.
- [x] Run the isolated 2S-UI/Reality/Mihomo/TUN/HTTP lifecycle E2E three
  consecutive times without changing a pre-existing Mihomo adapter.
- [ ] Sign the installer with a trusted code-signing certificate. No suitable
  certificate is installed on the current release machine.
- [ ] Install and smoke-test on a clean Windows 10/11 x64 machine.

## Release publication

- [ ] Publish source for the tagged application revision.
- [ ] Keep the exact Mihomo corresponding-source link next to every binary
  download.
- [ ] Publish SHA-256 checksums for the release ZIP and bundled core.
- [x] Enable GitHub private vulnerability reporting (2026-08-24).

## Latest verified release candidate

- Portable: `dist/ClashXY-Windows-x64-1.9.1-build15.zip`
- Portable SHA-256:
  `69C614DDBAAC3E10A142119789321CEA67A5DA07135FDC9449B6B103EB83E27B`
- Installer: `dist/ClashXY-Setup-x64-1.9.1-build15.exe`
- Installer SHA-256:
  `56FA63C76EE912CF1782C4FC53A93DB2FD5B5EBE323383D81D88F3C3CC590C96`
- Bundled Mihomo SHA-256:
  `CF894375DBC00AB6708C1314AC35BBD29059F4C37F315353AACA7F1A9C566DE6`
- The installer is currently unsigned and is a release candidate, not the final
  public download.
- The private Draft Release points at commit `70ba5e7` and contains the attested
  CI artifacts plus `SHA256SUMS-1.9.1-build15.txt`.

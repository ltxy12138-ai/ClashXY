# ClashXY 1.9.1 release candidate

ClashXY is a Windows Mihomo client with general Clash subscription/YAML support
and optional 2S-UI account and device management.

## Highlights

- Chinese and English UI with generated locale discovery.
- HTTPS subscriptions, local YAML, custom YAML, profile switching, proxy groups,
  rules, connections, logs, providers, and delay testing.
- Optional 2S-UI login, dedicated API Token provisioning, managed Client/device
  creation, traffic display, pause, token rotation, detach, and deletion.
- Windows TUN lifecycle recovery for network changes, sleep/resume, Mihomo crash,
  restart, and auto-connect.
- Serialized Core lifecycle operations and verified official Mihomo update,
  rollback, digest, platform, version, and download-deadline checks.
- Native single instance, system tray, close-to-tray, and startup registration.
- Per-machine x64 installer with Simplified Chinese/English setup UI and preserved
  application data during upgrades.

## Release artifacts

- `ClashXY-Windows-x64-1.9.1-build15.zip`
- `ClashXY-Setup-x64-1.9.1-build15.exe`
- `SHA256SUMS-1.9.1-build15.txt`

The bundled unmodified Mihomo core is v1.19.30 Windows x64 compatible:

- SHA-256: `cf894375dbc00ab6708c1314ac35bbd29059f4c37f315353aaca7f1a9c566de6`
- Release and corresponding source: <https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.30>
- License: GPL-3.0; the binary bundle contains the full license and third-party
  notices.

## Verification

- Flutter analysis: no issues.
- Flutter tests: 73 passed.
- Windows Release build and administrator manifest: verified.
- Isolated 2S-UI/Reality/Mihomo/TUN/HTTP lifecycle E2E: three consecutive passes.
- Installer migration: `1.9.0+14` to `1.9.1+15`; existing application data
  hashes unchanged; uninstall cleanup verified.
- GitHub/Sigstore provenance: both binaries verify against the public repository,
  main-branch release workflow, and tagged source commit.

## Publication gates

This candidate must not be promoted to the final public release until the
installer is signed with a trusted code-signing certificate and the documented
clean Windows 10/11 lifecycle smoke test is complete.

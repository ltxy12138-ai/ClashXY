# ClashXY

A Windows desktop client for Mihomo / Clash profiles with optional 2S-UI
device management. The app is built with Flutter and runs a separately
packaged, checksum-verified Mihomo core.

ClashXY is an independent project and is not affiliated with MetaCubeX, Clash,
or 2S-UI.

## Current features

- HTTPS subscription import, local YAML import, and custom YAML profiles
- Chinese, English, and system-language selection through generated Flutter ARB
  files; adding another complete ARB automatically adds it to the language menu
- subscription refresh intervals and an advanced YAML editor for all profile
  keys
- Mihomo TUN connection with proxy groups, node selection, and delay tests
- rule/global/direct modes, active connections, rules, and redacted core logs
- proxy- and rule-provider status/update, quota information, and concurrent
  delay tests
- structured LAN, local port, TUN stack/route/MTU, DNS, IPv6, and sniffer
  settings with a runtime safety overlay
- optional HTTPS 2S-UI login with 2FA, dedicated API token, device provisioning,
  remote client status/deletion, local account disconnect, and authenticated
  token revocation
- Windows system tray, close-to-tray, single-instance activation, hidden startup,
  and real per-user startup registration
- Windows DPAPI-backed secure storage for tokens and complete proxy profiles
- checksum verification for the bundled Mihomo core, plus official stable Core
  update checks with staged switching and one-version rollback

## Privacy and security

Administrator passwords are used only during 2S-UI authentication and are never
stored. API tokens and complete proxy profiles are kept in Windows secure
storage. Non-secret panel metadata includes the API token ID so the token can
be revoked after administrator reauthentication. The runtime Mihomo YAML is
written into an ACL-restricted directory
and deleted as soon as the core becomes ready.

Read [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before distributing a build.
Managed-device identity and future subscription authentication are documented
in [docs/DEVICE_IDENTITY.md](docs/DEVICE_IDENTITY.md).

## Requirements

- Windows 10 or Windows 11 x64
- administrator access when Windows TUN is enabled
- a valid Clash / Mihomo subscription or YAML profile, or an optional reachable
  2S-UI v1.7.1 panel over HTTPS

## Run a release build

The executable and its adjacent dependencies are produced under:

```text
build\windows\x64\runner\Release\
```

Run `ClashXY.exe` and keep the entire Release directory together. Windows
shows a UAC prompt because TUN configuration requires elevation.

## Development

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build windows --release
```

To add a language, add `lib/l10n/app_<locale>.arb` with a localized
`languageName` and all keys from `app_en.arb`, then rebuild. Generated supported
locales populate the language menu automatically.

Use `tools/package_windows.ps1` to create a release ZIP containing the
application and required third-party notices.

## License and copyright

ClashXY is licensed under the GNU General Public License version 3 only
(`GPL-3.0-only`). Copyright (C) 2026 ClashXY contributors. Individual
contributors retain copyright in their contributions. See [LICENSE](LICENSE),
[NOTICE.md](NOTICE.md), and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Bug reports and contributions are welcome through the public
[GitHub repository](https://github.com/ltxy12138-ai/ClashXY).

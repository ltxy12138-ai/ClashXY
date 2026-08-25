# ClashXY

[English](README.md) | [简体中文](README.zh-CN.md)

[![Windows CI](https://github.com/ltxy12138-ai/ClashXY/actions/workflows/windows-ci.yml/badge.svg?branch=main)](https://github.com/ltxy12138-ai/ClashXY/actions/workflows/windows-ci.yml)
[![Release](https://img.shields.io/github/v/release/ltxy12138-ai/ClashXY?include_prereleases&label=release)](https://github.com/ltxy12138-ai/ClashXY/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0--only-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-0078D4?logo=windows)](https://github.com/ltxy12138-ai/ClashXY/releases)

**A multilingual Windows Mihomo / Clash client with subscription and YAML
profiles, TUN networking, and optional 2S-UI device management.**

ClashXY is designed first as a general-purpose Clash desktop client. You can
use a normal HTTPS subscription, import a local YAML file, or create a custom
YAML profile without connecting to 2S-UI. The 2S-UI integration is an optional
management layer for users who operate their own panel.

ClashXY is an independent project and is not affiliated with MetaCubeX, Clash,
or 2S-UI.

> [!WARNING]
> The current `v1.9.1` prerelease is unsigned and intended for testing. Windows
> may show an unknown-publisher warning. Download it only from the official
> [GitHub Releases page](https://github.com/ltxy12138-ai/ClashXY/releases) and
> verify the published SHA-256 checksums before running it.

## Highlights

### Profiles and subscriptions

- Import and refresh HTTPS Clash / Mihomo subscriptions.
- Import local `.yaml` or `.yml` files and create custom YAML profiles.
- Keep multiple profiles, switch between them, configure refresh intervals,
  and edit advanced YAML keys.
- Preserve proxy groups, providers, rules, DNS, hosts, and sniffer settings
  while applying a local runtime security overlay.

### Mihomo control plane

- Start and supervise the checksum-verified Mihomo Core with Windows TUN.
- Use Rule, Global, and Direct modes; select nodes and test proxy delay.
- Inspect proxy and rule providers, active connections, traffic, rules, and
  redacted Core logs.
- Recover from network changes, sleep/resume, and unexpected Core exits.
- Check official stable Mihomo updates, stage verified replacements, and roll
  back one version.

### Windows desktop experience

- Chinese, English, and system-language selection with extensible Flutter ARB
  localization.
- System tray, close-to-tray, single-instance activation, automatic connection,
  and per-user startup registration.
- Structured LAN, port, TUN, DNS, IPv6, MTU, route, and sniffer settings.
- Installer upgrade migration and a portable ZIP distribution.

### Optional 2S-UI integration

- Connect to a user-supplied 2S-UI v1.7.1 panel over HTTPS with password and
  optional 2FA authentication.
- Create a dedicated API token and managed device Client, then generate a local
  profile without making 2S-UI a startup dependency.
- View device status and traffic; disconnect the panel locally, delete a
  managed device, or revoke the dedicated token with explicit user actions.

## Download

Windows 10 or Windows 11 x64 is required. Administrator access is required for
the current application manifest and TUN lifecycle.

Download the installer, portable archive, and matching checksum file from
[GitHub Releases](https://github.com/ltxy12138-ai/ClashXY/releases). The
installer is the normal choice; use the portable ZIP when you want to keep the
application directory together and manage shortcuts yourself.

Verify a downloaded file in PowerShell:

```powershell
Get-FileHash .\ClashXY-Setup-x64-1.9.1-build15.exe -Algorithm SHA256
Get-Content .\SHA256SUMS-1.9.1-build15.txt
```

The two values must match exactly. GitHub provenance is an additional supply
chain signal, but it does not replace Authenticode verification.

## Quick start

1. Install ClashXY or extract the complete portable archive.
2. Open **Profiles** and add an HTTPS subscription, import a YAML file, or paste
   a custom YAML configuration.
3. Select the saved profile and choose **Connect** on the Home page.
4. Open **Proxies** to select nodes or test delay, and **Connections** to inspect
   live traffic, rules, connections, and logs.
5. Optionally open **2S-UI** to connect your own HTTPS panel and provision a
   managed device profile.

Do not run ClashXY alongside another TUN-based Clash client unless you are
deliberately testing coexistence. Competing TUN routes, DNS settings, and local
ports can prevent either application from becoming ready.

## Privacy and security

ClashXY has no analytics, advertising, telemetry, or project-operated cloud
service. Subscription URLs, complete proxy profiles, proxy credentials, and
2S-UI API tokens are stored with Windows DPAPI-backed secure storage.
Administrator passwords are held in memory only for the requested 2S-UI
operation and are not persisted. Runtime YAML is written to an ACL-restricted
directory and removed after Mihomo becomes ready.

The app still connects to endpoints explicitly supplied by the user or defined
by an imported profile, and to GitHub when the user requests a Mihomo Core
update. Imported profiles and elevated network software are security-sensitive;
only use configurations and builds from sources you trust.

Read the full policies before distributing or diagnosing a build:

- [Privacy policy](PRIVACY.md)
- [Security policy and vulnerability reporting](SECURITY.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Device identity boundaries](docs/DEVICE_IDENTITY.md)

## Code signing policy

ClashXY has applied to the SignPath Foundation program. The program requires
this acknowledgement:

> Free code signing provided by SignPath.io, certificate by SignPath Foundation

This acknowledgement describes the intended signing provider; it does not mean
that the application has been approved or that an unsigned prerelease is
signed. Trust a release as signed only when its Authenticode signatures pass the
documented [code-signing policy](docs/CODE_SIGNING_POLICY.md). A trusted,
timestamped publisher and clean Windows 10/11 lifecycle evidence remain stable
release gates.

## Development

The CI reference environment uses Flutter `3.47.1` on Windows. Install Flutter,
Visual Studio with the Desktop development with C++ workload, and a compatible
Windows SDK, then run:

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build windows --release
```

The unpackaged Release directory is generated at:

```text
build\windows\x64\runner\Release\
```

To add a language, create `lib/l10n/app_<locale>.arb` with a localized
`languageName` and every key from `app_en.arb`, then regenerate localization.
Complete ARB files automatically appear in the language menu.

Useful project documentation:

- [Architecture](docs/ARCHITECTURE.md)
- [Project plan](docs/PROJECT_PLAN.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Windows clean-machine E2E](docs/WINDOWS_E2E.md)
- [Contributing guide](CONTRIBUTING.md)

## Project status

The Windows client is in public prerelease. Core Clash functionality and the
optional 2S-UI integration are implemented; trusted code signing and final
clean-machine Windows 10/11 validation are still required before a stable
release. Android is a planned later phase and is not currently supported.

Bug reports and contributions are welcome through [GitHub Issues](https://github.com/ltxy12138-ai/ClashXY/issues).
Do not include subscription URLs, credentials, tokens, exported YAML, or
unredacted logs in public reports.

## License and acknowledgements

ClashXY is licensed under `GPL-3.0-only`. Copyright (C) 2026 ClashXY
contributors; individual contributors retain copyright in their contributions.
See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

Release bundles include an unmodified, separately executed Mihomo Core under
GPL-3.0. 2S-UI is not bundled. Exact upstream versions, source links, hashes,
and license notices are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

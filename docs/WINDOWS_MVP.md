# ClashXY Windows release baseline

## Build baseline

- Flutter 3.47.1 stable
- Dart 3.13.1
- Visual Studio Community 2026 18.0.2
- Windows SDK 10.0.26100.0
- Mihomo v1.19.30 Windows x64
- Mihomo SHA-256: `cf894375dbc00ab6708c1314ac35bbd29059f4c37f315353aaca7f1a9c566de6`

## Security model

- The production app accepts HTTPS 2S-UI panel URLs only.
- The administrator password is used only for the login and API Token provisioning flow.
- The password is never written to Drift, files, or ordinary logs.
- API Tokens and complete proxy profiles are stored through Windows secure storage.
- Drift stores only non-secret metadata and secure-storage references.
- A panel API token ID is stored as non-secret metadata so an authenticated
  account-management action can revoke the dedicated token.
- The bundled Mihomo core is verified with SHA-256 before installation.
- Runtime config contains secrets, is created only for a connection, and is deleted on stop.
- Mihomo and application logs pass through `SecretRedactor`.
- The Windows executable requests administrator permission through its embedded manifest because TUN requires elevation.

## Implemented flows

### General Clash profiles

1. Add an HTTPS subscription, import local YAML, or paste custom YAML.
2. Store the complete profile through Windows secure storage.
3. Optionally configure refresh intervals or edit advanced YAML.
4. Apply structured port/LAN/TUN/DNS/sniffer settings and the runtime security
   overlay.
5. Connect, switch proxy groups/modes, test delays, inspect providers/rules/
   connections/logs, and disconnect from the tray or app.

### Optional 2S-UI management

1. Test an HTTPS panel URL.
2. Sign in with username, password, and optional 2FA.
3. Create and verify a device API Token.
4. Store the Token securely and discard the administrator session.
5. Select VLESS Reality and/or Hysteria2 inbounds.
6. Create a remote Client with generated credentials.
7. Read server-generated links with `sync=true`, validate them, and save the secure local Profile.
8. Verify and install the bundled Mihomo core.
9. Generate a structured runtime config and start Mihomo with Windows TUN.
10. Show connection state, traffic, proxy delay, server state, and devices.
11. Stop the connection and remove both the remote Client and local secure Profile when deleting this device.
12. Disconnect an account locally while preserving VPN profiles, or
    reauthenticate and revoke the app's dedicated token before disconnecting.

If remote creation succeeds but local validation or persistence fails, the provisioning state machine attempts to delete the remote Client automatically.

## Verification

The delivery was validated with:

```powershell
flutter analyze
flutter test
flutter build windows --release
```

Results:

- `flutter analyze`: no issues
- `flutter test`: 73 tests passed
- Windows Release: built successfully
- Release manifest: `requireAdministrator`
- Packaged Mihomo SHA-256: matches the verified upstream core
- Bilingual Inno Setup installer: built successfully
- Upgrade migration: `1.9.0+14` to `1.9.1+15`, application data preserved
- Isolated panel/Reality/Mihomo/TUN/HTTP E2E: three consecutive passes
- Main-branch CI release candidate: checksums and GitHub/Sigstore provenance
  verified for both Windows binaries

## Remaining release work

The Windows stabilization implementation now includes network-change and
sleep/resume recovery, bounded Mihomo crash restart, ownership-scoped TUN/DNS
cleanup, and verified core update/rollback. The remaining release work is:

- full P6-010 clean-machine and lifecycle E2E evidence
- trusted code signing for the application, installer, and generated uninstaller
- clean Windows 10/11 lifecycle smoke test
- final release publication, checksums, and corresponding-source links

Provider-neutral Authenticode verification and redacted lifecycle evidence
collection are implemented. The exact release order and manual test procedure
are documented in `CODE_SIGNING_POLICY.md` and `WINDOWS_E2E.md`; actual trusted
signing and the two clean-machine runs remain external release gates.

System tray, close-to-tray, native single instance, hidden startup and real HKCU
startup registration are implemented. The public product name and GPL license
are settled, and upgrade verification is complete; signing and clean-machine
smoke testing are still required.

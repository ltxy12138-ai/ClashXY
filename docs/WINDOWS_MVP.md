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
- `flutter test`: 34 tests passed
- Windows Release: built successfully
- Release manifest: `requireAdministrator`
- Packaged Mihomo SHA-256: matches the verified upstream core

## Remaining stabilization work

The MVP does not claim the following stabilization tasks:

- network-change and sleep/resume recovery
- Mihomo crash restart policy
- abnormal TUN/DNS cleanup
- core download/update/rollback UI
- signed installer and upgrade migration

System tray, close-to-tray, native single instance, hidden startup and real HKCU
startup registration are implemented. A final public release still requires a
product-name decision, source-code license, signing, and clean-machine smoke
test.

# P6-010 clean Windows lifecycle evidence

P6-010 is the final human lifecycle gate for a Windows release. It complements
the automated Flutter, installer, 2S-UI, Mihomo, TUN, and provenance tests; it
does not replace them.

## Test matrix

Run the checklist separately on clean Windows 10 x64 and Windows 11 x64
machines. Both runs must use the exact same final, trusted, timestamp-signed
installer. A VM is acceptable when it supports real suspend/resume and network
switching; Windows Sandbox alone is not sufficient for those lifecycle checks.

Use test subscriptions and YAML that contain no production credentials. Do not
put subscription URLs, panel credentials, API tokens, UUIDs, proxy secrets,
user names, IP addresses, or exported runtime YAML in evidence notes or public
issues. The evidence tool redacts common accidental values, but that is only a
last line of defense.

## Start a run

Open an elevated PowerShell session from a checkout of the exact release
commit. Keep the evidence directory outside the application-data directory so
it survives restart and uninstall.

```powershell
$evidenceRoot = 'C:\ClashXY-Evidence\win11'

.\tools\windows_lifecycle_evidence.ps1 `
  -Action Start `
  -EvidenceDirectory $evidenceRoot `
  -InstallerPath 'C:\Release\ClashXY-Setup-x64-1.9.1-build15.exe' `
  -ExpectedVersion '1.9.1+15' `
  -ExpectedPublisherPattern '<approved subject regex>'
```

`Start` refuses an unsigned, untrusted, or non-timestamped installer. The
explicit `-AllowUnsignedCandidate` switch is only for rehearsal and marks the
entire run ineligible for a release.

## Record checkpoints

After each manual action, record its result. `Record` only captures redacted
system facts; it never sleeps, restarts, switches a network, launches the app,
or changes VPN state.

```powershell
.\tools\windows_lifecycle_evidence.ps1 `
  -Action Record `
  -EvidenceDirectory $evidenceRoot `
  -Checkpoint clean-machine-baseline `
  -Result Pass
```

Perform and record these checkpoints in order:

| Checkpoint | Manual action and expected result |
| --- | --- |
| `clean-machine-baseline` | Confirm no prior ClashXY install, process, or TUN remains. |
| `install` | Install the final package; confirm the registered version and publisher. |
| `first-launch` | Launch successfully and complete first-run setup. |
| `subscription-import` | Add a test HTTPS subscription without exposing its URL. |
| `subscription-connect` | Connect; Mihomo and the ClashXY TUN become healthy. |
| `node-switch` | Switch to another node and retain connectivity. |
| `internet-access` | Reach an independent HTTPS test site through the active profile. |
| `subscription-update` | Refresh the subscription successfully. |
| `yaml-import` | Import a separate test YAML profile. |
| `profile-switch` | Switch to that profile and reconnect successfully. |
| `app-before-restart` | Record while connected, immediately before quitting the app. |
| `app-restart-restore` | Reopen ClashXY and confirm profile/connection recovery. |
| `sleep-before` | Record while connected, immediately before Windows sleep. |
| `sleep-resume` | Sleep, wake, wait for recovery, and confirm internet access. |
| `network-before-switch` | Record immediately before changing or disconnecting the active network. |
| `network-switch-recovery` | Switch/disconnect/reconnect and confirm automatic recovery. |
| `system-before-restart` | Enable auto-connect and record immediately before Windows restart. |
| `system-restart-autoconnect` | Restart Windows, reopen PowerShell, and confirm automatic connection and internet access. |
| `disconnect-cleanup` | Disconnect; Mihomo and the owned TUN must be gone. |
| `uninstall-cleanup` | Quit and uninstall; installation, processes, and owned TUN must be gone. |

Optional 2S-UI checkpoints are `two-sui-login`, `two-sui-device-create`,
`two-sui-connect`, and `two-sui-device-delete`. The isolated automated 2S-UI
Lab remains the authoritative protocol/lifecycle test.

Use `-Result Fail` or `-Result Blocked` truthfully when a step does not pass.
Rerunning the same checkpoint replaces its earlier record. View progress with:

```powershell
.\tools\windows_lifecycle_evidence.ps1 `
  -Action Status `
  -EvidenceDirectory $evidenceRoot
```

## Finish and validate

`Finish` checks every required result plus observable invariants: signed
installed executable/uninstaller, running Mihomo and Up TUN at connected
checkpoints, a new application process after app restart, a Windows resume
event, a network transition, a later boot time after system restart, and clean
disconnect/uninstall state.

```powershell
.\tools\windows_lifecycle_evidence.ps1 `
  -Action Finish `
  -EvidenceDirectory $evidenceRoot
```

It writes `state.json`, `report.md`, and `evidence.sha256`. After completing both
operating systems, verify the pair from a trusted checkout:

```powershell
.\tools\verify_windows_lifecycle_evidence.ps1 `
  -EvidenceDirectory @(
    'C:\ClashXY-Evidence\win10',
    'C:\ClashXY-Evidence\win11'
  ) `
  -ExpectedInstallerSHA256 '<final installer SHA-256>' `
  -ExpectedVersion '1.9.1+15' `
  -ExpectedSourceCommit '<final 40-character main commit>' `
  -ExpectedPublisherPattern '<approved subject regex>'
```

Only the redacted Markdown report, manifest, and a minimal pass summary belong
in the release issue. Review them manually before upload. Keep raw screenshots
private unless all credentials, subscription identifiers, user paths, IP
addresses, and account details have been removed.

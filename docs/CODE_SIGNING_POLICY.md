# ClashXY Windows code-signing policy

## Release requirement

Every stable Windows release must use a trusted Authenticode code-signing
identity and an RFC 3161-compatible trusted timestamp. An unsigned prerelease
candidate may be published only for testing or signing-provider evaluation,
must carry a prominent unsigned warning, and must not be promoted to a stable
release. GitHub artifact attestations prove which repository workflow produced
an artifact; they do not replace the Windows Authenticode trust decision. Both
controls are required for stable releases.

The following first-party files must have a valid signature from the same
publisher:

- `ClashXY.exe` in the portable archive and installed application
- `ClashXY-Setup-x64-<version>-build<build>.exe`
- the Inno Setup-generated `unins000.exe`

The signer certificate must contain the Code Signing enhanced key usage OID
`1.3.6.1.5.5.7.3.3`. The publisher subject is frozen for a release and checked
with an explicit regular expression.

Do not re-sign Mihomo, Flutter DLLs, Windows runtime libraries, or any other
bundled upstream binary with the ClashXY publisher identity. They retain their
own provenance and are covered by the corresponding-source, license, checksum,
and release-attestation controls.

## Custody and approval

- Signing keys and provider credentials stay outside the repository, build
  artifacts, caches, logs, and issue comments.
- Prefer a hardware-backed or managed signing service with MFA and an audit
  trail. Do not export a production private key into a repository secret when
  the provider supports keyless or remote signing.
- A repository maintainer must manually approve every public-release signing
  request and confirm the exact `main` commit, version, and workflow run.
- Provider access is least-privilege and is revoked promptly when a maintainer
  or signing integration no longer needs it.
- Compromise or unexplained signing activity blocks release publication and is
  handled through the process in `SECURITY.md`.

This policy is provider-neutral. SignPath Foundation and Azure Artifact Signing
are both compatible choices once their external identity-validation and project
approval requirements have been completed. Provider approval must never be
claimed before it is actually granted.

## SignPath Foundation application

ClashXY is applying to the SignPath Foundation program. No artifact may be
described as SignPath-signed until the application is approved and the release
passes the verification gates below. If accepted, signed release and download
pages will include the required acknowledgement:

> Free code signing provided by SignPath.io, certificate by SignPath Foundation

## Team roles

- Authors and committers: [Leetxy](https://github.com/Leetxy)
- Reviewers: [Leetxy](https://github.com/Leetxy)
- Signing approvers: [Leetxy](https://github.com/Leetxy)

Changes proposed by other contributors require review by the listed reviewer.
Every signing request requires a separate manual decision by the signing
approver. These assignments must be updated before repository or signing access
is delegated to another maintainer.

## Privacy policy

The project privacy policy is published in [PRIVACY.md](../PRIVACY.md).
ClashXY does not transfer information to project-operated networked systems.
Network requests occur only when requested by the user or required by an
imported profile, user-supplied service, or user-initiated Core update.

## Required build order

The portable archive must contain the same signed `ClashXY.exe` that the
installer deploys. Therefore a signed release uses this order:

1. Check out the exact reviewed `main` commit and build the Windows Release
   directory.
2. Verify version, manifest, bundled Core hash, tests, and analysis.
3. Build the installer with `-SignToolCommand`; Inno Setup signs the first-party
   application before packaging and signs the installer and generated
   uninstaller.
4. Package the portable ZIP from the now-signed Release directory with
   `-RequireValidSignature`.
5. Run signed install/upgrade/uninstall verification with
   `-RequireValidSignature`.
6. Generate checksums, GitHub attestations, and P6-010 evidence for these exact
   bytes.

The command supplied to Inno Setup must use its literal `$f` file placeholder.
The provider-specific command is intentionally not stored in this repository.

```powershell
.\tools\build_windows_installer.ps1 `
  -SkipBuild `
  -Iscc 'C:\path\to\ISCC.exe' `
  -SignToolCommand '<provider command containing literal $f>' `
  -ExpectedPublisherPattern '<approved subject regex>'

.\tools\package_windows.ps1 `
  -SkipBuild `
  -RequireValidSignature `
  -ExpectedPublisherPattern '<approved subject regex>'

.\tools\test_windows_installer_upgrade.ps1 `
  -InstallOnly `
  -RequireValidSignature `
  -ExpectedPublisherPattern '<approved subject regex>'
```

## Verification and evidence

`verify_windows_signatures.ps1` requires a valid Windows trust chain, Code
Signing EKU, trusted timestamp, and successful Windows SDK `signtool /pa /all`
verification. `-SkipSignTool` exists only for diagnostics and clean-machine
evidence collection; it does not replace the strict release gate.

```powershell
.\tools\verify_windows_signatures.ps1 `
  -Path @(
    '.\build\windows\x64\runner\Release\ClashXY.exe',
    '.\dist\ClashXY-Setup-x64-1.9.1-build15.exe'
  ) `
  -ExpectedPublisherPattern '<approved subject regex>'

gh attestation verify '.\dist\ClashXY-Windows-x64-VERSION.zip' `
  --repo Leetxy/ClashXY
```

The installed `ClashXY.exe` and generated uninstaller are checked by the
installer lifecycle test and again in each P6-010 evidence run.

### Historical repository identity

The `v1.9.1` prerelease attestations were issued before the GitHub account was
renamed from `ltxy12138-ai` to `Leetxy`. GitHub preserves those attestations
under their original repository identity. Verify each historical artifact
separately:

```powershell
gh attestation verify `
  .\dist\ClashXY-Windows-x64-1.9.1-build15.zip `
  --repo ltxy12138-ai/ClashXY

gh attestation verify `
  .\dist\ClashXY-Setup-x64-1.9.1-build15.exe `
  --repo ltxy12138-ai/ClashXY
```

This exception records immutable historical provenance; source, support, and
future attestation links use `Leetxy/ClashXY`.

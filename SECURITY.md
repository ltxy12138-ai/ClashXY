# Security policy

## Supported versions

The project is currently pre-release. Only the newest source revision and newest
published build, once releases begin, receive security fixes.

## Reporting a vulnerability

Do not include subscription URLs, proxy credentials, panel passwords, API
tokens, exported YAML, or unredacted logs in a public issue. Use GitHub private
vulnerability reporting when it is enabled for the repository. If no private
channel is available, open a public issue containing only a request for a
private contact channel.

Include the affected version, Windows version, reproduction steps, expected
impact, and redacted evidence. Allow reasonable time for investigation before
public disclosure.

## Security boundaries

- 2S-UI and subscription endpoints must use HTTPS.
- The 2S-UI administrator password is not persisted.
- API tokens and complete profiles use Windows DPAPI-backed secure storage.
- Runtime configuration is ACL-restricted and deleted after Mihomo loads it.
- The bundled Mihomo binary is checked against a pinned SHA-256 before use.
- Core updates accept only the official stable MetaCubeX/mihomo Windows x64
  compatible asset over HTTPS with the GitHub Release SHA-256 digest. The
  executable is staged, rehashed, version-probed, and retains a verified
  rollback copy before switching.
- The controller binds to loopback and uses a randomly generated secret.
- Logs pass through secret redaction.
- Exported profiles are explicitly treated as sensitive.

The application runs elevated when TUN is enabled. A malicious imported profile,
core binary, dependency, or remote provider can therefore have serious impact.
Only import configurations and install builds from sources you trust.

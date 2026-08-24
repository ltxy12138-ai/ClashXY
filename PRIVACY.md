# Privacy

ClashXY is a local Windows network client. It does not include analytics,
advertising, telemetry, or a project-operated cloud service.

## Data stored on this computer

The app stores data in these Windows locations:

- `%APPDATA%\ClashXY\flutter_secure_storage.dat` — DPAPI-encrypted
  subscription URLs, complete proxy profiles, proxy credentials, and 2S-UI API
  tokens.
- `%USERPROFILE%\Documents\mymihomo.sqlite` — profile names, panel URL and
  username, API token ID, device identifiers, timestamps, settings, and secure-storage
  reference keys. Administrator passwords and complete proxy configurations are
  not stored in this database.
- `%APPDATA%\ClashXY\runtime\` — ACL-restricted Mihomo runtime
  data. The generated plaintext `config.yaml` exists only while the core starts
  and is deleted once Mihomo is ready. Stale configuration files are removed on
  the next app startup.
- `%APPDATA%\ClashXY\core\` — the active Mihomo executable, one verified
  rollback executable, and non-secret version/SHA-256 metadata.

The database keeps its pre-release filename for upgrade compatibility. On the
first ClashXY launch, if the current secure-storage file does not yet exist,
the app copies the newest legacy file from `%APPDATA%\MyTunnel\` or
`%APPDATA%\app.mymihomo\mymihomo\`. The old file is not deleted and an existing
ClashXY secure-storage file is never overwritten.

The 2S-UI administrator password is held in memory only for login, dedicated
API-token creation, or a user-requested token revocation. It is cleared from the
UI after the operation and is never intentionally written to disk or logs.

## Network requests

Depending on the features used, the app connects directly to:

- subscription URLs supplied by the user;
- proxy servers and remote providers defined by imported profiles;
- the user-supplied 2S-UI panel;
- GeoIP, GeoSite, or rule-provider URLs requested by the imported Mihomo
  configuration.
- `api.github.com` and GitHub release asset hosts when the user checks for or
  installs a Mihomo Core update.

No profile, credential, traffic record, or panel data is sent to a service
operated by this project.

## Logs and exports

Application and Mihomo output passes through secret redaction before it is
retained by the UI. Technical output can still contain hostnames and connection
metadata. Exported YAML can contain credentials and must be treated as a secret.

## Deletion

Deleting a standalone profile removes its local metadata and encrypted profile;
it does not modify the subscription provider. Deleting a managed 2S-UI device
while its source panel is connected also deletes the corresponding remote
client and disconnects the current VPN. If the source panel is detached, only
the local profile is deleted. There is no undo.

Disconnecting a panel locally removes its token from Windows secure storage but
does not remove the remote API token or remote clients. “Revoke token and
disconnect” asks for the administrator password/2FA for that request, deletes
the dedicated token remotely, and then removes the local token. Existing VPN
profiles remain usable in either case.

Uninstalling the application may not remove the AppData secure-storage file or
the Documents database. Users who want a complete local reset should first
delete profiles and disconnect panel accounts in the app, then remove the paths
listed above.

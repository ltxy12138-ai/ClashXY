# ClashXY device identity and subscription authentication

## Design rule

ClashXY treats the following values as separate concepts:

| Field | Purpose | User visibility |
| --- | --- | --- |
| `display_name` | Mutable label such as “上海办公电脑” | Shown and editable |
| `client_id` | Stable machine identity managed by ClashXY | Visible in details |
| `subscription_token` | Opaque credential for fetching a subscription | Hidden by default |
| `two_sui_client_name` | Compatibility mapping to the backing 2S-UI Client | Diagnostic only |

A machine identifier must never double as a subscription credential.

## Current Windows client

- ClashXY creates a stable identity in the form
  `clashxy-<machine>-<12 lowercase hex>` and stores it in Windows secure
  storage.
- Identities created by pre-release `MyTunnel` and `MyMihomo` builds remain
  valid after upgrade.
- 2S-UI v1.7.1 compatibility currently maps this identity to
  `Client.name`. Protocol UUIDs and passwords are generated independently.
- When provisioning a 2S-UI device, the user chooses a mutable display name.
  ClashXY shows that label separately while continuing to use the stable
  machine identity for `Client.name`.
- The Windows client does not operate a public subscription endpoint and does
  not store an independent subscription token.

## Target managed-service model

The future server-side management layer should own records equivalent to:

```text
Client
  id
  display_name
  client_id
  managed_by = ClashXY
  two_sui_client_name
  platform
  last_seen_at

SubscriptionCredential
  client_id
  token_hash
  enabled
  created_at
  rotated_at
  last_used_at
```

Only a token hash should be stored server-side. A newly generated plaintext
token is shown once and used in a URL such as `/s/<opaque-token>`. Token
rotation must not delete or recreate the Client, so traffic history, device
binding, and permissions remain intact.

This model requires a server-side subscription gateway or a compatible 2S-UI
extension. It cannot be implemented securely by changing only the ClashXY
desktop client. Until that service exists, ClashXY keeps the machine-level
Client naming scheme for 2S-UI compatibility and does not present it as a
subscription-security boundary.

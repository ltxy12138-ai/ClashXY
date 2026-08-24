# VLESS Reality 参数提取

> Task：P0-010
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证依据：2S-UI v1.7.1 官方源码 + 完整 mock

## 1. 实现

```text
tools/clashxy_lab/extract_vless_reality.ps1
tools/clashxy_lab/profile_vless_inspect.ps1
```

脱敏 CLI：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\tools\clashxy_lab\clashxy_lab.ps1 profile inspect-vless `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token `
  -InboundId 1 `
  -ClientId 2
```

## 2. 字段来源

| 模型字段 | 2S-UI 来源 |
| --- | --- |
| Inbound ID/tag | Inbound |
| Client ID/name | Client |
| UUID | `client.config.vless.uuid` |
| flow | `client.config.vless.flow` |
| 默认 server/port | `inbound.out_json.server/server_port` |
| transport | `inbound.out_json.transport` |
| TLS/Reality 客户端配置 | `inbound.out_json.tls` |
| 自定义 endpoint | `inbound.addrs[]` |
| endpoint TLS 覆盖 | `inbound.addrs[].tls` |

`out_json` 是官方 `FillOutJson` 生成的客户端视图：它合并 TLS 客户端配置，并剥离服务端私钥、key path 与 ACME 字段。不能从 TLS server 配置直接取 Reality `private_key`。

## 3. 结构化模型

内部模型类型：

```text
ClashXY.VlessRealityConnection
├── Protocol / InboundId / InboundTag
├── ClientId / ClientName
├── Uuid: SecureString
├── Flow
├── Transport
│   ├── Type
│   ├── Path
│   ├── Host / Headers
│   ├── ServiceName
│   └── Early Data
└── Endpoints[]
    ├── Server / Port / Remark
    ├── ServerName / ALPN / Insecure
    ├── Fingerprint
    └── RealityPublicKey / RealityShortId
```

支持官方链接生成器使用的 transport：TCP（缺省）、HTTP、WS、gRPC、HTTPUpgrade。

当 `addrs` 非空时，每个地址生成一个 endpoint，并按官方浅合并规则用 `addr.tls` 覆盖基础 TLS。

## 4. 校验

提取器拒绝：

- 非 VLESS Inbound。
- Client 未绑定目标 Inbound。
- 缺失 `config.vless.uuid`。
- 非 Reality endpoint。
- 缺失 server、合法端口或 Reality 公钥。
- 无可用 endpoint。

UUID 转为 `SecureString` 后清除明文变量。CLI 只输出 `UuidPresent` 和 Reality 字段存在性，不输出 UUID、公钥值或任何原始对象。

## 5. 测试

Fixture 覆盖：

- WS + Early Data。
- 两个 endpoint。
- 基础 Reality/SNI/fingerprint。
- 地址级 Reality/SNI/fingerprint 覆盖。
- Client–Inbound 绑定失败。
- 原始 `out_json` 中的私钥陷阱和无关密码。
- SecureString UUID 与脱敏 CLI。

结果：

```text
PASS: VLESS Reality extraction, endpoint overrides, binding guard, SecureString UUID, and redacted summary
```

官方临时实例当前没有 VLESS Reality Inbound。完整真实协议对象会让 UUID/密码进入上游 `changes` 审计表，因此本任务未在没有额外授权时写入该对象，也未把 mock 结果表述为真实联网验证。

P0-010 结构化模型验收通过。

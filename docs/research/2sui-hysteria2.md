# Hysteria2 参数提取

> Task：P0-011
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证依据：2S-UI v1.7.1 官方源码 + 完整 mock

## 1. 实现

~~~text
tools/clashxy_lab/extract_hysteria2.ps1
tools/clashxy_lab/profile_hysteria2_inspect.ps1
~~~

脱敏 CLI：

~~~powershell
$token = Read-Host 'API Token' -AsSecureString
.\tools\clashxy_lab\clashxy_lab.ps1 profile inspect-hysteria2 -BaseUrl https://panel.example.com/app/ -ApiToken $token -InboundId 1 -ClientId 2
~~~

## 2. 官方源码依据

核对版本：

~~~text
2S-UI v1.7.1
tag commit: eb2d01440708d0896136cc8d169f19c683b3350c
~~~

关键实现：

| 官方文件 | 已确认行为 |
| --- | --- |
| frontend/src/types/clients.ts | Client 凭据位于 config.hysteria2.password |
| frontend/src/types/inbounds.ts | Hysteria2 Inbound 包含上下行带宽、salamander obfs 等字段 |
| util/outJson.go | 生成客户端视图；服务端 down_mbps → 客户端 up_mbps，服务端 up_mbps → 客户端 down_mbps |
| util/genLink.go | 读取 Client 密码、endpoint、端口范围、obfs、TLS/SNI/ALPN 和 fast open |
| util/outJson.go / service/tls.go | 客户端 TLS pin 使用 certificate_public_key_sha256[] |

inbound.out_json 已经是客户端视角，因此提取器不再二次交换 up_mbps 与 down_mbps。

## 3. 字段来源

| 模型字段 | 2S-UI 来源 |
| --- | --- |
| Inbound ID/tag | Inbound |
| Client ID/name | Client |
| Hysteria2 password | client.config.hysteria2.password |
| 客户端上传/下载 Mbps | inbound.out_json.up_mbps/down_mbps |
| salamander obfs | inbound.out_json.obfs |
| 端口范围 | inbound.out_json.server_ports[] |
| TCP fast open | Inbound tcp_fast_open |
| 默认 server/port | inbound.out_json.server/server_port |
| TLS/SNI/ALPN/uTLS | inbound.out_json.tls |
| 自定义 endpoint | inbound.addrs[] |
| endpoint TLS 覆盖 | inbound.addrs[].tls |
| SPKI pins | TLS certificate_public_key_sha256[] |

当 addrs 非空时，每个地址生成一个 endpoint，并按官方链接生成器的浅合并规则，用 addr.tls 的顶层字段覆盖基础 TLS。

## 4. pin 语义

结构化模型保存：

~~~text
certificate_public_key_sha256[]
~~~

这是 sing-box/2S-UI 客户端 TLS 配置使用的 Base64 SHA-256 SPKI hash。

2S-UI 分享链接中的 pinSHA256 由服务端证书重新计算为十六进制证书指纹。两者格式与用途不同，P0-011 不做错误互转；分享链接兼容逻辑不属于本任务。

## 5. 结构化模型

内部模型类型：

~~~text
ClashXY.Hysteria2Connection
├── Protocol / InboundId / InboundTag
├── ClientId / ClientName
├── Password: SecureString
├── ClientUpMbps / ClientDownMbps
├── ServerPorts[]
├── TcpFastOpen
├── ObfsType
├── ObfsPassword: SecureString
└── Endpoints[]
    ├── Server / Port / Remark
    ├── Security = tls
    ├── ServerName / ALPN / Insecure
    ├── Fingerprint
    └── CertificatePublicKeySha256Pins[]
~~~

CLI 只输出密码存在性、pin 数量和其他非机密结构字段，不输出密码、obfs 密码或 pin 值。

## 6. 校验

提取器拒绝：

- 非 Hysteria2 Inbound。
- Client 未绑定目标 Inbound。
- 缺失 config.hysteria2.password。
- 缺失 TLS。
- Hysteria2 + Reality。
- 非 salamander obfs。
- obfs 已启用但缺失密码。
- 缺失 server、合法端口或可用 endpoint。
- 负数带宽。

Client 密码和 obfs 密码转为 SecureString 后清除明文变量。原始 Client links、描述和 TLS 服务端 key 不进入模型。

## 7. 测试

Fixture 覆盖：

- 客户端视角的上下行带宽方向。
- 两个 endpoint。
- 基础 TLS/SNI/ALPN/uTLS/SPKI pin。
- 地址级 TLS/SNI/uTLS/SPKI pin 覆盖。
- 两段 server port 范围。
- salamander obfs。
- TCP fast open。
- Client–Inbound 绑定失败。
- Hysteria2 + Reality 拒绝。
- Client 密码和 obfs 密码的 SecureString 保存。
- 服务端 TLS 私钥、Client link/描述陷阱与 CLI 泄漏黑名单。

结果：

~~~text
PASS: Hysteria2 extraction, bandwidth direction, endpoint overrides, pin counts, guards, SecureString passwords, and redacted summary
~~~

官方临时实例当前没有 Hysteria2 Inbound。完整真实协议对象会让 UUID/密码进入上游 changes 审计表，因此本任务未写入含凭据的真实对象，也未把 mock 结果表述为真实联网验证。

P0-011 结构化模型验收通过。

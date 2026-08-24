# VLESS Reality → Mihomo ProxyProfile

> Task：P0-012
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证依据：2S-UI v1.7.1 官方源码样例 + Mihomo 官方文档 + 完整 mock

## 1. 实现

~~~text
tools/clashxy_lab/map_vless_reality_profile.ps1
~~~

输入：

~~~text
ClashXY.VlessRealityConnection
~~~

输出：

~~~text
ClashXY.ProxyProfile
├── Protocol
├── SourceInboundId / SourceClientId / SourceEndpointIndex
├── SensitiveFieldNames[]
└── Fields
~~~

本任务只生成结构化 ProxyProfile，不拼接 YAML。ConnectionProfile 与 YAML AST/序列化属于 P0-014。

## 2. Mihomo 官方依据

本次核对：

- [Mihomo VLESS 官方配置](https://wiki.metacubex.one/en/config/proxies/vless/)
- [Mihomo TLS 官方配置](https://wiki.metacubex.one/en/config/proxies/tls/)
- [Mihomo Transport 官方配置](https://wiki.metacubex.one/en/config/proxies/transport/)

官方 VLESS 配置确认了 uuid、flow、tls、servername、client-fingerprint、reality-opts、network 等键。官方 Transport 配置确认了 ws-opts、http-opts、grpc-opts，以及 HTTPUpgrade 应表达为 WebSocket 的 v2ray-http-upgrade 选项。

## 3. 核心字段映射

| 连接模型 | Mihomo Fields |
| --- | --- |
| Profile name | name |
| Protocol | type = vless |
| Endpoint server/port | server / port |
| UUID SecureString | uuid |
| flow | flow |
| TLS enabled | tls = true |
| SNI | servername |
| ALPN | alpn |
| skip verify | skip-cert-verify |
| uTLS fingerprint | client-fingerprint |
| Reality public key | reality-opts.public-key |
| Reality short ID | reality-opts.short-id |
| transport | network + protocol opts |
| VLESS encryption default | encryption = 空字符串 |
| UDP | udp = true |

uuid 在 Fields 中仍为 SecureString。P0-014 的序列化边界负责短暂解包，业务层和日志不得提前转成明文。

## 4. Transport 映射

| 2S-UI transport | Mihomo |
| --- | --- |
| tcp / 缺省 | network = tcp |
| ws | network = ws + ws-opts |
| http | network = http + http-opts |
| grpc | network = grpc + grpc-opts |
| httpupgrade | network = ws + ws-opts.v2ray-http-upgrade = true |

WS 映射 path、headers、max-early-data、early-data-header-name。

HTTP 映射 method、path 和 headers；2S-UI 的 host 列表补入 Host header。

gRPC 映射 service_name → grpc-service-name。

2S-UI 的 quic transport 不在 Mihomo VLESS 官方支持列表中，Mapper 明确拒绝，不生成看似合法但不可运行的配置。

## 5. 校验

Mapper 拒绝：

- 非 VLESS connection。
- UUID 不是 SecureString。
- endpoint 索引越界。
- 非法 server/port。
- 缺失 Reality servername。
- 缺失 Reality public key。
- endpoint security 不是 Reality。
- Mihomo VLESS 不支持的 transport。

Profile name 缺省时由 Client name、Inbound tag 与 endpoint 序号生成，并限制为 80 个字符；调用方也可显式指定。

## 6. 单元测试

真实主样例来自 P0-010 的 2S-UI v1.7.1 风格 fixture：

- WS + Early Data。
- Reality public key / short ID。
- SNI / ALPN / client fingerprint。
- 两个 endpoint 与地址级 TLS 覆盖。
- SecureString UUID。

派生分支覆盖：

- TCP。
- HTTP method/path/Host。
- gRPC service name。
- HTTPUpgrade → WS upgrade。
- QUIC 拒绝。
- endpoint index 选择。
- ProxyProfile JSON 不包含 UUID 明文。

结果：

~~~text
PASS: VLESS Reality to Mihomo ProxyProfile mapping, endpoint selection, supported transports, unsupported transport guard, and UUID redaction
~~~

P0-012 结构化 Mapper 验收通过。实际 Mihomo 配置解析与进程启动分别在 P0-014、P0-015 验收。

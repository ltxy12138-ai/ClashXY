# Hysteria2 → Mihomo ProxyProfile

> Task：P0-013
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证依据：2S-UI v1.7.1 官方源码样例 + Mihomo 官方文档 + 完整 mock

## 1. 实现

~~~text
tools/clashxy_lab/map_hysteria2_profile.ps1
~~~

输入 ClashXY.Hysteria2Connection，输出 ClashXY.ProxyProfile。本任务不生成 YAML。

## 2. Mihomo 官方依据

本次核对：

- [Mihomo Hysteria2 官方配置](https://wiki.metacubex.one/en/config/proxies/hysteria2/)
- [Mihomo TLS 官方配置](https://wiki.metacubex.one/en/config/proxies/tls/)
- [Mihomo 通用 Proxy 字段](https://wiki.metacubex.one/en/config/proxies/)

官方 Hysteria2 配置确认了 ports、hop-interval、password、up/down、obfs、obfs-password、sni、skip-cert-verify、fingerprint 与 alpn 等键。

## 3. 核心字段映射

| 连接模型 | Mihomo Fields |
| --- | --- |
| Profile name | name |
| Protocol | type = hysteria2 |
| Endpoint server/port | server / port |
| Password SecureString | password |
| ClientUpMbps | up = N Mbps |
| ClientDownMbps | down = N Mbps |
| ServerPorts[] | ports |
| ObfsType | obfs |
| ObfsPassword SecureString | obfs-password |
| SNI | sni |
| ALPN | alpn |
| TLS verify mode | skip-cert-verify |

password 和 obfs-password 在 Fields 中仍为 SecureString，由 P0-014 的序列化边界短暂解包。

## 4. 端口范围

2S-UI v1.7.1 导入 Hysteria2 分享链接时，会把 mport 范围中的连字符转换为内部冒号：

~~~text
20000-20100 → 20000:20100
~~~

Mihomo ports 使用连字符区间和逗号列表，因此 Mapper 转回：

~~~text
["20000:20100", "30000"] → "20000-20100,30000"
~~~

每个端口必须在 1～65535，范围起点不得大于终点。非法格式和降序范围直接拒绝。

2S-UI v1.7.1 的该连接模型没有 hop interval 来源，Mapper 不发明值，Mihomo 使用自身默认值。

## 5. TLS pin 安全边界

2S-UI 客户端字段 certificate_public_key_sha256[] 是 Base64 SPKI hash。

Mihomo Hysteria2 的 fingerprint 是整张证书的 SHA-256 fingerprint。官方 TLS 文档明确说明它不是公钥 fingerprint。两者不能直接转换。

默认行为：

~~~text
存在 2S-UI SPKI pin
→ Mapper 拒绝
~~~

显式高级开关：

~~~powershell
-AllowInsecurePinnedCertificate
~~~

会改为 skip-cert-verify = true，并在 ProxyProfile 中记录：

- TlsPinMode = explicit-insecure-pin-downgrade
- SecurityWarnings 包含安全降级说明

如果 2S-UI 源 endpoint 已经设置 insecure，Mapper保留该设置，并记录 SPKI pin 未被 Mihomo 表达。

2S-UI TLS 中的 utls.fingerprint 也不是 Mihomo Hysteria2 的证书 fingerprint。Mapper不写 fingerprint，并在 IgnoredSourceFields 中记录 utls.fingerprint。

## 6. 校验

Mapper 拒绝：

- 非 Hysteria2 connection。
- password 不是 SecureString。
- endpoint 索引越界。
- 非法 server/port。
- endpoint 不是标准 TLS。
- 未显式处理的 SPKI pin。
- 非 salamander 的 2S-UI obfs。
- obfs 启用但密码不是 SecureString。
- 非法端口和降序端口范围。

## 7. 单元测试

真实主样例来自 P0-011 的 2S-UI v1.7.1 风格 fixture：

- 两个 endpoint。
- 客户端视角 200 Mbps up / 100 Mbps down。
- 两段端口范围。
- salamander obfs。
- SNI / ALPN。
- 两个 SecureString 密码。
- 基础与地址级 SPKI pin。
- uTLS fingerprint 与 TLS 私钥陷阱。

测试覆盖：

- 默认 pin 阻断。
- 显式 pin 安全降级与 warning。
- 源端 insecure 模式。
- 无 pin 的 CA 验证模式。
- 端口范围转换和降序拒绝。
- password / obfs-password 不泄漏。
- SPKI pin、TLS 私钥不进入 Profile。
- uTLS fingerprint 不误映射为整证书 fingerprint。

结果：

~~~text
PASS: Hysteria2 to Mihomo ProxyProfile mapping, port ranges, bandwidth, SecureString credentials, pin downgrade guard, and fingerprint separation
~~~

P0-013 结构化 Mapper 验收通过。实际 Mihomo 配置解析与进程启动分别在 P0-014、P0-015 验收。

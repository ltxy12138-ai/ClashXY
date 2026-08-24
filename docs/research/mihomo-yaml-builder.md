# Mihomo YAML Builder

> Task：P0-014
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证依据：结构化 AST + 独立 Serializer + 临时文件集成测试

## 1. 实现分层

~~~text
ProxyProfile[]
    ↓
build_mihomo_config.ps1
    ↓
ClashXY.ConnectionProfile / Map AST
    ↓
convert_to_yaml.ps1
    ↓
YAML text
    ↓
write_mihomo_config.ps1
    ↓
UTF-8 no-BOM config file
~~~

业务 Mapper 和 Config Builder 不拼 YAML。convert_to_yaml.ps1 是唯一 YAML 语法层。

## 2. 最小配置 AST

Builder 生成：

~~~text
mixed-port
allow-lan = false
mode = rule
log-level = info
ipv6 = true
external-controller = 127.0.0.1:<port>
secret = SecureString
proxies[]
proxy-groups[]
rules = MATCH,<group>
~~~

external-controller 固定绑定 loopback。mixed port 与 controller port 不得相同。

proxy-groups 使用 select 类型，包含全部 ProxyProfile name。所有 name 必须唯一。

## 3. Secret 边界

ConnectionProfile AST 中以下值保持 SecureString：

- Controller secret。
- VLESS uuid。
- Hysteria2 password。
- Hysteria2 obfs-password。

只有 YAML Serializer 会在内存中短暂解包。Writer 把 YAML 直接写入目标文件并清除局部字符串引用，返回值只包含：

- Path。
- ByteLength。
- SHA-256。
- ProxyCount。
- Written 状态。

返回摘要不包含 YAML、Controller secret 或协议凭据。

如果调用方不提供 Controller secret，Builder 使用系统 CSPRNG 生成 32 字节随机值并转换为 SecureString。显式 Secret 最少 16 个字符。

## 4. Serializer

通用 YAML Serializer 支持：

- 有序 dictionary。
- sequence。
- null。
- bool。
- 整数与浮点数。
- string。
- SecureString。

所有字符串使用 YAML 单引号样式；单引号按两个单引号转义。控制字符和多行字符串直接拒绝，避免隐式类型、换行注入和复杂 block scalar。

映射键只有满足安全标识符规则时才使用 plain style，否则同样安全引用。

## 5. 原子写入

Writer：

1. 在目标目录创建随机临时文件。
2. 以 UTF-8 无 BOM 写入。
3. 成功后原子替换目标。
4. finally 清理临时文件。
5. 计算最终文件 SHA-256。

输出路径仅允许 .yaml 或 .yml。

## 6. 测试

测试使用一个 VLESS Reality ProxyProfile 与一个 Hysteria2 ProxyProfile，覆盖：

- ConnectionProfile 最小 AST。
- loopback Controller 与 allow-lan=false。
- 两个代理进入 select group。
- MATCH rule。
- UUID、两个 HY2 密码和 Controller Secret 的 SecureString 边界。
- YAML 单引号转义。
- UTF-8 无 BOM。
- 原子临时文件清理。
- 写入 hash 与安全摘要。
- 重复代理名称阻断。
- 自动随机 Controller Secret。
- ConnectionProfile JSON 与 Writer 摘要不泄漏 Secret。

结果：

~~~text
PASS: structured Mihomo config AST, generic YAML serialization, SecureString boundary, atomic UTF-8 write, duplicate guard, and redacted summary
~~~

P0-014 Builder 验收通过。YAML 将在 P0-015 使用官方 Mihomo 自身的配置检查再次验证，并用于 Windows start/stop。

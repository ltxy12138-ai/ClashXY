# ClashXY Lab

`clashxy_lab` 是 Phase 0 的 Windows 技术验证工具。它用于逐步验证：

```text
2S-UI 登录
→ 创建测试 Client
→ 生成 Mihomo Profile
→ 启动 Mihomo 与 TUN
→ 联网检测
→ 清理测试 Client
```

当前已完成 P0-001～P0-018：面板验证、Client 生命周期、协议提取/映射、结构化 Mihomo YAML Builder、Windows 核心启停、Controller 健康检查、隔离 TUN 生命周期与完整 E2E 回滚。

## 运行

在 PowerShell 7 或更高版本（命令名 `pwsh`）中执行。Windows PowerShell 5.1 不受支持：

```powershell
pwsh --version
pwsh
cd C:\path\to\ClashXY\tools\clashxy_lab
.\clashxy_lab.ps1 help
.\clashxy_lab.ps1 version
```

如果本机执行策略阻止脚本，可以仅为本次进程使用：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\clashxy_lab.ps1 help
```

## 安全约束

- 不把管理员密码、API Token、完整 UUID、HY2 密码或私钥写入日志。
- 不在未验证真实 2S-UI API Schema 前实现写操作。
- 测试创建的远程对象必须可追踪、可清理。
- 每个后续命令按 `docs/TASKS.md` 的顺序单独实现和验收。
## P0-002 API 探测

默认只允许 HTTPS：

```powershell
.\clashxy_lab.ps1 panel-test -BaseUrl https://panel.example.com/app/
```

需要验证登录时，只在命令中提供用户名，脚本会安全提示输入密码和 2FA code：

```powershell
.\clashxy_lab.ps1 panel-test `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin
```

本地 HTTP 测试必须明确加上 `-AllowInsecureHttp`。探测结果只输出结构摘要和 Cookie 属性，不输出响应对象或任何凭据值。

运行无外部依赖的本地 mock 测试：

```powershell
.\tests\probe_2sui_test.ps1
```
## P0-003 登录实验

无 2FA 和启用 2FA 的面板使用同一命令：

```powershell
.\clashxy_lab.ps1 panel login `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin
```

密码始终通过安全提示输入。只有服务端返回 `obj.twoFa=true` 时才会继续提示 TOTP code。成功输出包含脱敏的 Session Cookie 属性，并在输出前主动 logout；失败输出包含业务错误摘要且不会包含密码或验证码。

自动化测试可显式传入 `SecureString`：

```powershell
$password = Read-Host 'Panel password' -AsSecureString
$code = Read-Host 'Two-factor code' -AsSecureString
.\clashxy_lab.ps1 panel login `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin `
  -Password $password `
  -TwoFactorCode $code
```
## P0-004 API Token 实验

该命令创建一天期测试 Token、验证 API v2 后立即删除：

```powershell
.\clashxy_lab.ps1 panel token-test `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin `
  -TokenExpiryDays 1
```

输出只包含 Token 长度、API v2 状态和清理结果，不包含 Token value。创建后的任何失败都会进入 `finally` 清理并 logout。

## P0-005 Inbound 查询

使用 API Token 查询 Inbound：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\clashxy_lab.ps1 panel inbounds `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token
```

省略 `-ApiToken` 时会进入无回显安全提示。输出采用字段白名单，仅包含 ID、类型、标签、监听地址/端口、TLS/节点 ID 与用户数量；不会输出用户值、`out_json` 或其他协议配置。

## P0-006 Client 查询

使用 API Token 查询 Client：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\clashxy_lab.ps1 panel clients `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token
```

输出采用字段白名单，包含 Client ID、name、启用状态、Inbound ID 和安全的数字统计；不会输出 `config`、`links`、描述或备注。

## P0-008 创建测试 Client

使用 API Token 创建带安全前缀的测试 Client：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\clashxy_lab.ps1 device create `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token `
  -DeviceName 'windows-pc' `
  -InboundIds 1,2
```

默认在内存中生成与官方前端同构的全协议凭据，输出只包含 Client ID、名称、Inbound ID 和创建状态。名称固定以 `clashxy-lab-` 开头。`-SafeSchemaOnly` 仅用于不写入协议凭据的临时 Schema 验收，不得用于可连接的正式设备。

## P0-009 删除测试 Client

按 ID 删除测试 Client，并可校验期望名称：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\clashxy_lab.ps1 device delete `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token `
  -ClientId 123 `
  -ExpectedClientName 'clashxy-lab-windows-pc-12ab34cd'
```

命令只允许删除名称以 `clashxy-lab-` 开头的 Client。删除前按 ID 查询，删除后再次查询确认不存在。

## P0-010 VLESS Reality 参数提取

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\clashxy_lab.ps1 profile inspect-vless `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token `
  -InboundId 1 `
  -ClientId 2
```

内部模型保留完整 endpoint/transport/Reality 参数，UUID 使用 `SecureString`。CLI 只输出脱敏摘要。

## P0-011 Hysteria2 参数提取

~~~powershell
$token = Read-Host 'API Token' -AsSecureString
.\clashxy_lab.ps1 profile inspect-hysteria2 -BaseUrl https://panel.example.com/app/ -ApiToken $token -InboundId 1 -ClientId 2
~~~

内部模型保留客户端视角的上下行带宽、端口范围、salamander obfs、TLS/SNI/ALPN/uTLS、证书 SPKI pin 与多个 endpoint。Client 密码和 obfs 密码使用 SecureString。

CLI 只输出密码存在性、pin 数量和非机密结构摘要。字段依据与安全边界见 docs/research/2sui-hysteria2.md。

## P0-012 VLESS → Mihomo ProxyProfile

map_vless_reality_profile.ps1 将 P0-010 的连接模型按 endpoint 转为结构化 ClashXY.ProxyProfile。支持 TCP、WS、HTTP、gRPC，并把 2S-UI HTTPUpgrade 转为 Mihomo WS upgrade 选项。

Fields 使用 Mihomo 官方键名，但 uuid 仍保留为 SecureString；本任务不生成 YAML。字段表、transport 映射和测试证据见 docs/research/mihomo-vless-profile.md。

## P0-013 Hysteria2 → Mihomo ProxyProfile

map_hysteria2_profile.ps1 映射 password、客户端视角带宽、端口跳跃、salamander obfs、SNI/ALPN 与 TLS 验证模式。password 和 obfs-password 保持为 SecureString。

2S-UI SPKI pin 不能映射为 Mihomo 整证书 fingerprint，默认阻断；只有显式 AllowInsecurePinnedCertificate 才降级为 skip-cert-verify 并写入安全 warning。详细说明见 docs/research/mihomo-hysteria2-profile.md。


## P0-014 Mihomo YAML Builder

build_mihomo_config.ps1 只构造 ConnectionProfile/Map AST，convert_to_yaml.ps1 是唯一 YAML 语法层，write_mihomo_config.ps1 以 UTF-8 无 BOM 原子写入并返回脱敏 hash 摘要。

UUID、HY2 密码与 Controller Secret 在 AST 中保持为 SecureString，只在写文件边界短暂解包。结构与测试证据见 docs/research/mihomo-yaml-builder.md。


## P0-015 Mihomo Windows 启动

启动前需准备官方 Mihomo Windows 核心、由 P0-014 写出的配置和独立运行目录：

~~~powershell
.\clashxy_lab.ps1 mihomo start -CorePath C:\path\mihomo.exe -ConfigPath C:\path\config.yaml -RuntimeDirectory C:\path\runtime
~~~

停止同一实例：

~~~powershell
.\clashxy_lab.ps1 mihomo stop -RuntimeDirectory C:\path\runtime
~~~

也可用 -StatePath 指定状态文件，但它必须位于 RuntimeDirectory 内。启动会先执行官方核心配置校验，再以隐藏窗口运行；停止会校验 PID、核心路径和启动时间，拒绝停止身份不匹配的进程。CLI 和状态文件不包含连接凭据。

使用官方核心运行独立验收：

~~~powershell
.\tests\mihomo_process_test.ps1 -CorePath C:\path\mihomo.exe
~~~

验证版本、哈希、安全边界和测试证据见 docs/research/mihomo-windows-process.md。

## P0-016 Controller 健康检查

启动 Mihomo 后，使用同一个 Controller Secret 检查官方 /version 接口：

~~~powershell
$secret = Read-Host 'Mihomo Controller Secret' -AsSecureString
.\clashxy_lab.ps1 status -ControllerUri http://127.0.0.1:9090 -ControllerSecret $secret
~~~

省略 -ControllerSecret 时 CLI 会无回显提示。明文 HTTP 只允许 loopback；结果不包含 Secret。接口依据与测试证据见 docs/research/mihomo-controller-status.md。

使用官方核心运行独立验收：

~~~powershell
.\tests\controller_status_test.ps1 -CorePath C:\path\mihomo.exe
~~~

## P0-017 Windows TUN 验证

TUN 默认不进入配置，必须由 Builder 显式 EnableTun。Windows 创建网卡需要管理员令牌；TunAutoRoute 与 TunStrictRoute 默认关闭。

核心启动后可双重检查 Controller 和 Windows 网卡：

~~~powershell
$secret = Read-Host 'Mihomo Controller Secret' -AsSecureString
.\clashxy_lab.ps1 tun status -ControllerUri http://127.0.0.1:9090 -ControllerSecret $secret -TunDeviceName ClashXY
~~~

隔离生命周期验收会创建随机名测试网卡、选择未占用的 198.19.x.x/30、不安装全局路由，并在停止后确认网卡消失：

~~~powershell
.\tests\tun_test.ps1 -CorePath C:\path\mihomo.exe
~~~

v1.19.30 的顶层 TUN IPv4 地址实际由 dns.fake-ip-range 派生，不能依赖被核心忽略的 tun.inet4-address。权限、源码依据、冲突处理和验收证据见 docs/research/mihomo-windows-tun.md。

## P0-018 完整 E2E Lab

一次命令执行登录、短期 Token、Inbound 读取、测试 Client 创建、VLESS Reality Profile、Mihomo/TUN 启动、HTTP 连通检测以及完整回滚：

~~~powershell
.\clashxy_lab.ps1 e2e run `
  -CorePath C:\path\mihomo.exe `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin `
  -InboundId 1 `
  -ConnectivityUri https://example.com/ `
  -RuntimeDirectory C:\path\e2e-runtime
~~~

密码会无回显提示；启用 2FA 的自动化场景可传入 SecureString `-TwoFactorCode`。TUN 名称和未占用的 `198.19.x.x/30` 默认自动分配，且不安装全局路由。结果只输出阶段状态、状态码、版本和安全标识。

独立验收使用已验证 2S-UI Schema 的动态 mock，以及两套官方 Mihomo 分别充当 VLESS Reality 服务端和客户端：

~~~powershell
.\tests\e2e_lab_test.ps1 -CorePath C:\path\mihomo.exe
~~~

该命令会在目标面板真实创建并删除短期 Token 与测试 Client。2S-UI v1.7.1 的审计变更记录可能保留完整 Client 保存对象；只能针对专用测试 Inbound 运行，并应先确认审计保留策略。隔离拓扑、官方版本、回滚顺序和验收证据见 `docs/research/e2e-lab.md`。

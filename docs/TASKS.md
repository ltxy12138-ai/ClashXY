# ClashXY Tasks

> 2026-08-24 状态补充：通用配置、多语言、Clash 高级设置、Provider 管理、
> Windows 托盘/单实例/开机启动、发布加固和 2S-UI 账户管理已实现。
> 历史任务明细保留用于追溯。

> Codex 每次只执行一个 Task。
> 未经明确要求，不得提前实现后续 Task。

---

# P0 — Windows 技术验证

## P0-001 建立研究目录

**状态：✅ 已完成（2026-08-21）**

**目标**

创建：

```text
tools/clashxy_lab/
docs/research/
```

**要求**

- 不创建 Flutter UI
- 不实现正式业务
- 添加 README

**验收**

目录清晰，项目可运行最小 CLI。

---

## P0-002 2S-UI API 基础探测

**状态：✅ 已完成（2026-08-21）**

**目标**

验证当前目标 2S-UI 的：

- base path
- login endpoint
- cookie/session
- 2FA
- API v2 base path

**输出**

```text
docs/research/2sui-api.md
```

**禁止**

不要猜接口。

**验收**

文档记录真实请求/响应结构，Secret 必须脱敏。

---

## P0-003 登录实验

**状态：✅ 已完成（2026-08-21）**

**目标**

在 Lab 中实现：

```text
panel login
```

支持：

- username
- password
- optional 2FA

**验收**

成功和失败均有明确输出。

---

## P0-004 API Token 实验

**状态：✅ 已完成（2026-08-21）**

**目标**

验证登录后创建 API Token。

**要求**

- Token 不写普通日志
- 支持测试后删除

**验收**

API v2 请求可使用 Token 成功鉴权。

---

## P0-005 Inbound 查询

**状态：✅ 已完成（2026-08-21）**

**目标**

实现：

```text
panel inbounds
```

**验收**

输出结构化的 Inbound 摘要。

---

## P0-006 Client 查询

**状态：✅ 已完成（2026-08-21）**

**目标**

实现：

```text
panel clients
```

**验收**

输出 Client ID / name / inbound 等非敏感摘要。

---

## P0-007 Client 创建 Schema 验证

**状态：✅ 已完成（2026-08-21）**

**目标**

确认 2S-UI 创建 Client 的真实 JSON Schema。

**要求**

优先参考：

- 浏览器 Network 请求
- 2S-UI 源码
- 实际测试

**输出**

更新：

```text
docs/research/2sui-api.md
```

---

## P0-008 创建测试 Client

**状态：✅ 已完成（2026-08-21）**

**目标**

实现：

```text
device create
```

**要求**

Client 名称带：

```text
clashxy-lab-
```

**验收**

2S-UI 面板中出现对应 Client。

---

## P0-009 删除测试 Client

**状态：✅ 已完成（2026-08-21）**

**目标**

实现：

```text
device delete
```

**验收**

删除后 2S-UI 中不存在该 Client。

---

## P0-010 VLESS Reality 参数提取

**状态：✅ 已完成（2026-08-21）**

**目标**

从 Inbound + Client 得到完整连接参数。

**输出**

结构化模型，不生成 YAML。

---

## P0-011 Hysteria2 参数提取

**状态：✅ 已完成（2026-08-21）**

同 P0-010。

---

## P0-012 VLESS → Mihomo Profile

**状态：✅ 已完成（2026-08-21）**

**目标**

实现结构化转换。

**验收**

单元测试覆盖真实测试样例。

---

## P0-013 HY2 → Mihomo Profile

**状态：✅ 已完成（2026-08-21）**

同 P0-012。

---

## P0-014 Mihomo YAML Builder

**状态：✅ 已完成（2026-08-21）**

**目标**

从 Profile 生成最小可运行配置。

**禁止**

业务层直接拼 YAML。

---

## P0-015 Mihomo Windows 启动

**状态：✅ 已完成（2026-08-21）**

**目标**

CLI 启动 / 停止 Mihomo。

**验收**

```text
mihomo start
mihomo stop
```

均成功。

---

## P0-016 Controller 健康检查

**状态：✅ 已完成（2026-08-21）**

**目标**

验证 Mihomo External Controller。

实现：

```text
status
```

---

## P0-017 Windows TUN 验证

**状态：✅ 已完成（2026-08-21）**

**目标**

成功启用 TUN。

**输出**

记录权限和系统要求。

---

## P0-018 完整 E2E Lab

**状态：✅ 已完成（2026-08-21）**

**目标**

一次命令完成：

```text
登录
创建 Client
生成 Profile
启动 Mihomo
启动 TUN
HTTP 连通测试
停止
删除 Client
```

**验收**

完整成功。

**里程碑**

Phase 0 完成。

---

# P1 — Flutter Windows 骨架

## P1-001 创建 Flutter Windows 项目

**状态：✅ 已完成（2026-08-21）**

**要求**

只启用 Windows。

**验收**

```bash
flutter analyze
flutter test
```

通过。

---

## P1-002 建立目录结构

**状态：✅ 已完成（2026-08-21）**

按 `ARCHITECTURE.md` 建立：

```text
app/
core/
features/
platform/
models/
```

不实现业务。

---

## P1-003 Riverpod 基础

**状态：✅ 已完成（2026-08-21）**

建立 Provider 容器和依赖注入入口。

---

## P1-004 Router

**状态：✅ 已完成（2026-08-21）**

页面：

- Home
- Servers
- Devices
- Settings

使用假数据。

---

## P1-005 Logger

**状态：✅ 已完成（2026-08-21）**

建立 AppLogger + SecretRedactor。

---

## P1-006 SecureStorage 接口

**状态：✅ 已完成（2026-08-21）**

只定义接口和 Windows 实现。

---

## P1-007 Drift 数据库

**状态：✅ 已完成（2026-08-21）**

建立最小 Schema：

- panels
- devices
- profiles
- settings

不保存 Secret。

---

# P2 — 2S-UI Connector

## P2-001 PanelConnector 接口

**状态：✅ 已完成（2026-08-21）**

定义完整接口及业务模型。

---

## P2-002 TwoSUI HTTP Client

**状态：✅ 已完成（2026-08-21）**

实现：

- base URL
- timeout
- cookie
- Token Header
- error handling

---

## P2-003 登录

**状态：✅ 已完成（2026-08-21）**

支持：

- username
- password
- 2FA

---

## P2-004 Token Provision

**状态：✅ 已完成（2026-08-21）**

登录成功后：

```text
创建 Device API Token
保存 Secure Storage
清除管理员密码
```

---

## P2-005 Inbounds

**状态：✅ 已完成（2026-08-21）**

实现并添加 Mapper + Tests。

---

## P2-006 Clients

**状态：✅ 已完成（2026-08-21）**

实现并添加 Mapper + Tests。

---

## P2-007 Create Client

**状态：✅ 已完成（2026-08-21）**

实现创建。

---

## P2-008 Update Client

**状态：✅ 已完成（2026-08-21）**

实现编辑 / 禁用。

---

## P2-009 Delete Client

**状态：✅ 已完成（2026-08-21）**

实现删除。

---

## P2-010 Stats / Status / Online

**状态：✅ 已完成（2026-08-21）**

实现：

- server status
- traffic
- online clients

---

# P3 — Provisioning

## P3-001 DeviceIdentityService

**状态：✅ 已完成（2026-08-21）**

生成稳定 Device ID。

---

## P3-002 CredentialGenerator

**状态：✅ 已完成（2026-08-21）**

支持：

- VLESS
- HY2

---

## P3-003 InboundSelector

**状态：✅ 已完成（2026-08-21）**

策略：

```text
Auto
VLESS Reality
Hysteria2
```

---

## P3-004 Provisioning State

**状态：✅ 已完成（2026-08-21）**

定义 sealed state。

---

## P3-005 RemoteClientProvisioner

**状态：✅ 已完成（2026-08-21）**

封装创建 / 删除远程 Client。

---

## P3-006 ProxyProfileFactory

**状态：✅ 已完成（2026-08-21）**

从 2S-UI 数据生成业务 Profile。

---

## P3-007 ProfileValidator

**状态：✅ 已完成（2026-08-21）**

本地校验：

- 必填字段
- URL / host
- port
- TLS / Reality 参数

---

## P3-008 RollbackCoordinator

**状态：✅ 已完成（2026-08-21）**

远程成功、本地失败时自动清理。

---

## P3-009 完整 ProvisioningService

**状态：✅ 已完成（2026-08-21）**

完整状态机。

---

# P4 — Mihomo Windows

## P4-001 MihomoEngine 接口

**状态：✅ 已完成（2026-08-21）**

定义统一接口。

---

## P4-002 BinaryManager

**状态：✅ 已完成（2026-08-21）**

管理：

```text
core/current
core/previous
```

---

## P4-003 ConfigManager

**状态：✅ 已完成（2026-08-21）**

写入临时运行配置。

---

## P4-004 ProcessManager

**状态：✅ 已完成（2026-08-21）**

实现：

- start
- stop
- restart
- exit watch

---

## P4-005 ControllerClient

**状态：✅ 已完成（2026-08-21）**

实现：

- status
- proxies
- traffic
- delay

---

## P4-006 WindowsPlatformVpnService

**状态：✅ 已完成（2026-08-21）**

负责 Windows TUN 生命周期。

---

## P4-007 HealthChecker

**状态：✅ 已完成（2026-08-21）**

综合：

- process
- controller
- tun
- proxy
- connectivity

---

## P4-008 ConnectionSupervisor

**状态：✅ 已完成（2026-08-21）**

实现核心连接状态机。

---

# P5 — Windows MVP UI

## P5-001 首次设置向导

**状态：✅ 已完成（2026-08-21）**

输入：

- Panel URL
- Username
- Password
- 2FA

---

## P5-002 面板连接测试

**状态：✅ 已完成（2026-08-21）**

登录前可检测：

- URL
- HTTPS
- reachable

---

## P5-003 创建设备向导

**状态：✅ 已完成（2026-08-21）**

按钮：

```text
为本机创建并连接
```

---

## P5-004 首页连接按钮

**状态：✅ 已完成（2026-08-21）**

状态：

- disconnected
- connecting
- connected
- reconnecting
- error

---

## P5-005 实时流量

**状态：✅ 已完成（2026-08-21）**

显示：

- upload rate
- download rate

---

## P5-006 延迟

**状态：✅ 已完成（2026-08-21）**

显示当前节点真实代理延迟。

---

## P5-007 Devices 页面

**状态：✅ 已完成（2026-08-21）**

显示：

- 当前设备
- 远程设备
- online
- traffic

---

## P5-008 删除设备

**状态：✅ 已完成（2026-08-21）**

当前设备删除时：

- 停止连接
- 删除远程 Client
- 删除本地 Profile

---

## P5-009 Settings

**状态：✅ 已完成（2026-08-21）**

支持：

- auto start
- auto connect
- protocol
- TUN
- IPv6
- logs

---

# P6 — Windows 稳定化

## P6-001 系统托盘

**状态：✅ 已完成（2026-08-24）**

支持：

- 连接
- 断开
- 打开窗口
- 退出

窗口关闭时隐藏到托盘；托盘菜单随语言和连接状态更新，支持连接、断开、显示窗口
和执行受控退出。

---

## P6-002 单实例

**状态：✅ 已完成（2026-08-24）**

防止重复启动。

Windows Runner 使用产品级和旧产品名兼容互斥体阻止重复实例，避免多个进程同时
争用代理端口、TUN 和运行时文件。

---

## P6-003 开机启动

**状态：✅ 已完成（2026-08-24）**

实现并可关闭。

使用当前用户启动注册项并传入 `--startup`；开机启动时窗口保持隐藏，用户可以在
设置页随时启用或关闭。

---

## P6-004 自动连接

**状态：✅ 已完成（2026-08-24）**

系统启动后恢复。

---

## P6-005 网络变化监听

**状态：✅ 已完成（2026-08-24）**

支持 Wi-Fi / Ethernet 切换。

实现三秒网络快照轮询、断网等待、恢复后的延迟健康检查，并只在 Mihomo、
Controller、TUN、代理数据面或外网连通性未恢复时重连当前配置。

---

## P6-006 睡眠恢复

**状态：✅ 已完成（2026-08-24）**

处理 suspend/resume。

Windows Runner 监听系统电源广播；挂起时冻结网络恢复调度并保留活动配置，
唤醒后等待网络栈恢复，再检查 Mihomo、Controller、TUN、代理和外网连通性。
健康状态不重启，异常状态才重连当前配置。

---

## P6-007 Mihomo 崩溃恢复

**状态：✅ 已完成（2026-08-24）**

自动拉起并限制重试频率。

`ConnectionSupervisor` 在 Mihomo 意外退出后保留当前配置，按 1、2、4、8、
16 秒进行最多五次自动恢复；连续稳定运行两分钟后重置重试预算。手动断开会
取消待执行的恢复，达到上限后进入明确错误状态，避免无限崩溃循环。

---

## P6-008 TUN / DNS 清理

**状态：✅ 已完成（2026-08-24）**

异常退出后可恢复系统网络。

应用启动及 Mihomo 意外退出后的自动恢复都会执行所有权限定清理：只终止安装在
ClashXY 应用数据目录下、完整路径精确匹配的 `core/current.exe`，只处理当前配置
名称且接口描述为 `Meta Tunnel` 的 TUN；删除该接口在 `ActiveStore` 中的路由、
重置其 DNS、禁用残留适配器并刷新 DNS 缓存。不会按通用进程名或适配器类型清理
其他 Clash/Mihomo 客户端。

---

## P6-009 Core Update

**状态：✅ 已完成（2026-08-24）**

支持：

- download
- verify
- switch
- rollback

设置页可检查 `MetaCubeX/mihomo` 官方最新稳定版。更新器只选择唯一的 Windows
x64 compatible ZIP，只接受 HTTPS GitHub 来源和 Release API 提供的 SHA-256；
下载大小受限，校验通过后才在内存中提取单一根目录 EXE。新 Core 先写入暂存文件、
核对落盘哈希并执行 `-v` 验证平台及版本，再保存当前 Core 作为经过校验的
`previous` 后切换。中断切换会在下次启动恢复 `previous`，设置页也支持手动回滚；
安装或回滚前必须断开 VPN。连接、设置引擎重建、安装和回滚共用生命周期门，避免
替换正在运行的 Core；回滚只允许切换到更旧版本。GitHub 请求同时受空闲超时和五
分钟绝对截止时间约束。

---

## P6-010 Windows E2E

**状态：🚧 进行中（2026-08-24）**

自动化已完成：

```text
1.9.0+14 新装 → 1.9.1+15 覆盖升级 → 卸载
登录 → 短期 Token → Client 创建 → Reality 配置
官方 Mihomo 服务端/客户端 → TUN → 代理 HTTP
停止 → Client/Token 回滚删除 → 隔离网络清理
```

上述完整 Lab 在存在其他 Mihomo TUN 的机器上连续通过三次，且基线适配器未被
修改；安装器升级前后现有应用数据文件哈希一致。网络连通性探测增加了有总时限的
短重试，消除 Core/TUN 刚就绪时的偶发 502 竞态。

发布前仍需在干净 Windows 10/11 x64 环境人工覆盖：

```text
安装后首次启动、订阅/YAML 导入、切换节点、访问互联网、更新订阅
睡眠 → 唤醒、网络切换、应用/系统重启、自动连接、断开并清理
```

已增加发布门禁工具：最终安装包必须通过可信 Authenticode、代码签名 EKU、时间戳、
发布者与 Windows SDK `signtool` 校验；安装后的主程序和卸载器也必须有效签名。
P6-010 证据工具仅记录人工检查点与脱敏系统事实，不会自动触发睡眠、重启或切网，
并要求 Windows 10/11 两次验收使用完全相同的最终安装包哈希。操作说明见
`docs/CODE_SIGNING_POLICY.md` 与 `docs/WINDOWS_E2E.md`。

**里程碑**

Windows v1.0。

---

# P7 — Android 技术验证

## P7-001 Android Build

启用 Android 平台。

---

## P7-002 VpnService Skeleton

建立最小 VpnService。

---

## P7-003 TUN FD

成功创建 TUN。

---

## P7-004 Mihomo Native Bridge

让 Mihomo 使用 TUN FD。

---

## P7-005 Android Connectivity Test

使用已有 Profile 完成真实联网。

**里程碑**

Android 技术验证通过。

---

# P8 — Android MVP

## P8-001 AndroidPlatformVpnService

实现 Platform 接口。

---

## P8-002 Foreground Service

确保连接期间长期运行。

---

## P8-003 NetworkCallback

网络变化恢复。

---

## P8-004 Battery Optimization

提供检测与用户提示。

---

## P8-005 复用登录

直接复用 TwoSUIConnector。

---

## P8-006 复用 Provisioning

当前手机创建 Client。

---

## P8-007 Android Home

连接 / 断开 / 延迟 / 流量。

---

## P8-008 Android E2E

```text
安装
登录
创建 Client
连接
网络切换
断开
删除 Client
```

完成后进入 Android 后续稳定化。
---

# P9 — 托管订阅服务（未来服务端）

> 本阶段不是 Windows 客户端功能，只有在确定部署独立服务端后启动。

## P9-001 设备与订阅凭证领域模型

分离 `display_name`、`client_id`、`two_sui_client_name` 和
`subscription_token`；服务端只保存 Token Hash。

---

## P9-002 订阅认证网关

使用不可预测的独立 Token 提供订阅，不把机器 ID 暴露为订阅凭证。

---

## P9-003 Token 轮换、暂停与撤销

轮换订阅 Token 时保留 Client、流量历史、设备绑定和节点权限。

---

## P9-004 2S-UI 映射与托管状态

维护内部 Client 映射、最后在线时间、流量、权限和托管状态；支持解除托管
而不误删非 ClashXY 资源。

详细约束见 `docs/DEVICE_IDENTITY.md`。

---

# P5A — 通用 Clash 产品重构

> 本阶段修订旧 MVP 的产品定位：通用 Mihomo / Clash 客户端为主，2S-UI 为可选集成。

## P5A-001 Profile Source 模型

**状态：✅ 已完成（2026-08-21）**

支持来源：

- subscription
- localFile
- custom
- twoSui

旧 2S-UI Profile 无需迁移即可继续解码。

---

## P5A-002 HTTPS 订阅

**状态：✅ 已完成（2026-08-21）**

实现：

- HTTPS 限制
- 超时
- 10 MB 上限
- Clash User-Agent
- YAML 解析
- 手动更新订阅

订阅 URL 和完整配置仅保存到 Secure Storage。

---

## P5A-003 本地与自定义 YAML

**状态：✅ 已完成（2026-08-21）**

支持文件选择器导入 `.yaml` / `.yml`，以及应用内粘贴完整 YAML。

---

## P5A-004 配置安全覆盖层

**状态：✅ 已完成（2026-08-21）**

保留代理、提供器、代理组和规则，同时强制：

- loopback Controller
- 随机 Secret
- `allow-lan: false`
- loopback DNS
- 应用控制 TUN
- 移除 External UI / Controller 外部入口

---

## P5A-005 安全持久化与数据库 v2

**状态：✅ 已完成（2026-08-21）**

新增 standalone_profiles 元数据表；敏感内容使用 Windows Secure Storage。

---

## P5A-006 无面板启动

**状态：✅ 已完成（2026-08-21）**

没有 2S-UI 或面板 Token 失效时，通用配置仍可加载和连接。

---

## P5A-007 中文界面

**状态：✅ 已完成（2026-08-21）**

首次设置、首页、配置、设备、设置、状态与错误提示改为中文。

---

## P5A-008 配置管理

**状态：✅ 已完成（2026-08-21）**

支持添加、更新、连接和删除多来源配置；2S-UI 管理显示为可选区域。

---

## P5A-009 完整 Controller 数据面

**状态：✅ 已完成（2026-08-21）**

实现：

- 代理组与节点选择
- Rule / Global / Direct 模式
- 规则查看
- 活动连接查看
- 单连接 / 全连接关闭
- 实时流量
- 实时核心日志

---

## P5A-010 配置编辑与覆盖

**状态：✅ 已完成（2026-08-21）**

支持：

- 重命名配置
- 修改订阅 URL
- 查看更新时间
- 订阅更新策略
- 配置复制和导出（导出前明确 Secret 风险）

---

## P5A-011 代理组体验完善

**状态：✅ 已完成（2026-08-21）**

支持：

- 组内节点批量延迟测试
- 延迟排序
- 节点搜索
- 当前活动配置标识
- Provider 更新状态与流量信息

---

## P5A-012 规则与连接体验完善

**状态：✅ 已完成（2026-08-21）**

支持：

- 规则搜索与过滤
- 活动连接自动刷新
- 域名 / 链路 / 流量过滤
- 日志级别和搜索
- 日志显式导出与二次脱敏

---

## P5A-013 通用配置 Windows E2E

**状态：🚧 并入 P6-010（2026-08-24）**

完成：

```text
全新安装
添加 HTTPS 订阅
连接
切换节点
访问互联网
更新订阅
导入 YAML
切换配置
重启应用
恢复配置
断开并清理
```

**里程碑**

通用 Clash Windows MVP 完成后进入 P6 稳定化。

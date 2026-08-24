# ClashXY Architecture

> 本文定义代码边界、依赖方向和长期架构约束。
> 产品主线：通用 Mihomo / Clash 客户端；2S-UI 为可选集成。

---

## 1. 架构目标

1. Windows 先行，Android 后续复用业务层。
2. 配置来源可扩展、可独立测试。
3. 2S-UI 不得成为应用启动或 VPN 连接的前置依赖。
4. Mihomo Core 可升级和回滚。
5. Platform、Core、Application、UI 保持单向依赖。
6. 敏感数据不可进入普通数据库或日志。
7. 外部导入配置必须经过运行时安全覆盖层。

---

## 2. 依赖方向

```text
UI
 ↓
Application / Runtime Controller
 ↓
Core Services and Interfaces
 ↓
Storage / HTTP / Mihomo / Platform Adapters
```

禁止：

```text
Core → Flutter Widget
Core → Riverpod
Core → Windows UI
Profile Source → 直接启动子进程
2S-UI Connector → 控制通用订阅生命周期
MihomoEngine → 读取页面状态
```

---

## 3. Profile Source

配置来源是应用的一等抽象：

```text
ProfileSource
├── SubscriptionProfileSource
├── LocalFileProfileSource
├── CustomProfileSource
└── TwoSuiProfileSource
```

统一输出：

```text
ConnectionProfile
├── id / displayName / origin
├── rawConfig（完整 Clash 配置，可选）
├── proxies（结构化 2S-UI 生成配置，可选）
├── subscriptionUrl（仅订阅来源）
└── createdAt
```

来源规则：

- Subscription：HTTPS 下载并解析 YAML，可更新。
- LocalFile：读取一次并保存快照，不依赖原文件长期存在。
- Custom：应用内输入并解析 YAML。
- TwoSui：通过 Provisioning 生成结构化代理配置。

新增来源不得修改 MihomoEngine；只需产出 `ConnectionProfile`。

---

## 4. 配置构建

```text
ConnectionProfile
      ↓
MihomoConfigBuilder
      ├─ structured 2S-UI config
      └─ imported full config
      ↓
Runtime Security Overlay
      ↓
temporary runtime YAML
```

导入配置使用深拷贝，不能修改安全存储中的原始配置。

安全覆盖层必须控制：

- Controller 仅监听 loopback
- Controller Secret 由应用随机生成
- 默认 `allow-lan: false`
- TUN 生命周期和设备名
- DNS 监听仅本机
- 移除 External UI、Controller TLS/CORS 等外部入口

业务层禁止用字符串拼接 YAML。

---

## 5. Mihomo Runtime

```text
ConnectionSupervisor
├── BinaryManager
├── ConfigManager
├── ProcessManager
├── PlatformVpnService
├── HealthChecker
└── ControllerClient
```

Core 更新链路保持同样的依赖方向：`MihomoCoreUpdateService` 负责版本比较、归档
校验和事务编排，Windows GitHub Release Adapter 负责受限 HTTPS 下载，
`BinaryManager` 负责暂存、版本探测、切换、启动恢复和单版本回滚。更新器不得直接
覆盖正在运行的 Core，也不得在缺少官方 SHA-256 时降级为仅信任 HTTPS。

ControllerClient 提供：

- status / configs
- proxies / proxy groups / node selection
- delay
- traffic stream
- rules
- active connections / close
- mode switch
- core log stream

页面不得直接访问本地 Controller。

---

## 6. 2S-UI 可选集成

```text
TwoSUIHttpClient
      ↓
PanelConnector
      ↓
ProvisioningService
├── DeviceIdentityService
├── CredentialGenerator
├── InboundSelector
├── RemoteClientProvisioner
├── ProfileFactory
├── ProfileValidator
└── RollbackCoordinator
```

2S-UI 登录失败、Token 缺失或面板离线时：

- 已保存的订阅、本地和自定义配置仍可加载与连接。
- 仅禁用面板管理和 2S-UI Provisioning。
- 不得把应用强制退回首次设置页。

管理员密码不能保存；远程 Client 创建成功而本地保存失败时必须回滚远程 Client。
账户断开只删除本机 Token，不删除现有 Profile 或远程 Client；用户选择“撤销并
断开”时，必须重新验证管理员身份，使用持久化的非敏感 Token ID 删除远程 Token。
来自已断开面板的 Profile 只能执行本地删除，禁止借用当前其他面板连接删除同号
Remote Client。

---

## 7. Storage

### Secure Storage

保存：

- 完整 `ConnectionProfile`
- 订阅 URL 和其中的 Token
- 代理凭据
- 2S-UI API Token
- 设备身份 Secret

### Drift / SQLite

只保存：

- 配置 ID、名称、来源和 SecureRef
- Panel URL、名称、用户名、TokenRef 和用于撤销的 Token ID
- Remote Client ID
- 用户设置与非敏感缓存

数据库 schema 只允许向前迁移；旧 2S-UI Profiles 表保留，通用配置使用独立表，避免破坏已有外键。

---

## 8. 日志与错误

- AppLogger 的所有文本必须经过 SecretRedactor。
- 禁止记录响应体、原始 YAML、订阅 URL、代理 URI 或 Authorization Header。
- Mihomo 实时日志只在内存中显示，默认最多保留有限条目，不自动持久化。
- UI 显示可操作的中文错误；底层异常保留 cause 供测试和受控诊断使用。

---

## 9. 平台边界

```text
PlatformVpnService
├── WindowsPlatformVpnService
└── AndroidPlatformVpnService（后续）
```

Windows 实现负责管理员权限、TUN 适配器、进程恢复和系统网络清理。Android 实现负责 VpnService、TUN FD、Foreground Service 和网络回调。Core 不得引用 Win32 或 Android API。

---

## 10. 测试边界

单元测试至少覆盖：

- YAML 解析和大小/协议限制
- ProfileCodec 向后兼容
- 导入配置安全覆盖层
- Controller DTO 解析和写操作
- 2S-UI DTO / Provisioning / 回滚
- Secret 脱敏

集成/E2E 分开覆盖：

1. 通用订阅或 YAML → Mihomo → TUN → 联网。
2. 2S-UI 登录 → 创建设备 → Mihomo → 联网 → 删除设备。
3. 异常退出、睡眠、网络切换和 Core 崩溃恢复。

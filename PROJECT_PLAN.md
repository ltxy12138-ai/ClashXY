# ClashXY 项目计划

> **已弃用：** 本文件保留为早期设计记录，其中“非通用客户端”等内容已失效。
> 当前计划以 `docs/PROJECT_PLAN.md` 为准。

> 版本：v1.0
> 当前目标平台：Windows → Android
> 暂不支持：Linux / macOS / iOS
> 核心技术：Flutter + Mihomo + 2S-UI
> 开发方式：Codex 分阶段、小任务、可验收推进

---

## 1. 项目定位

ClashXY 不是一个通用机场客户端，也不是 ClashMi 的简单换皮。

项目目标是：

> 做一个面向私人 VPS / 私人代理节点的客户端，把 2S-UI 的用户管理能力与 Mihomo 的客户端代理能力整合起来，实现“登录面板 → 为本机创建用户 → 自动生成配置 → 一键连接”。

普通用户最终不需要接触：

- UUID
- Reality public key
- shortId
- SNI
- 订阅地址
- YAML
- Inbound / Outbound
- SSH
- VPS 命令行

这些内容只允许出现在高级设置或调试日志中。

---

## 2. 当前范围

### 第一阶段：Windows

Windows 是主开发平台，也是整个技术链路的验证平台。

必须做到：

- Windows 10 / 11 x64
- Flutter Desktop
- 2S-UI 登录
- 2FA 登录支持
- API Token 获取与安全存储
- Inbound 查询
- Client 查询
- 一键为本机创建 Client
- 一键删除 / 禁用 Client
- VLESS Reality
- Hysteria2
- Mihomo 配置生成
- Mihomo 启停
- TUN
- 一键连接 / 断开
- 延迟测试
- 实时流量
- 开机启动
- 自动连接
- 网络变化自动重连
- 系统托盘
- 日志
- 配置恢复
- Mihomo 崩溃恢复

### 第二阶段：Android

Android 必须建立在 Windows 业务层稳定之后。

Android 主要新增：

- Android VpnService
- TUN File Descriptor
- Mihomo Native Bridge
- Foreground Service
- Android 生命周期
- 电池优化适配
- 网络切换恢复

必须复用：

- 2S-UI Connector
- DTO
- Provisioning
- Profile
- 设备模型
- 核心状态机
- 页面
- 配置生成逻辑

### 暂不开发

以下内容不进入当前任务列表：

- iOS
- macOS
- Linux
- 机场订阅市场
- 多机场
- 规则市场
- 插件系统
- 云同步
- 复杂账号体系
- 复杂 YAML 编辑器
- VMess
- Trojan
- Shadowsocks
- 完整 2S-UI 管理后台

---

## 3. 核心用户体验

### 首次使用

```text
安装 ClashXY
    ↓
输入 2S-UI 地址
    ↓
输入用户名 / 密码 / 2FA
    ↓
验证面板
    ↓
创建本机 API Token
    ↓
删除内存中的管理员密码
    ↓
发现可用 Inbound
    ↓
为本机创建 Client
    ↓
生成 Mihomo Profile
    ↓
启动 Mihomo + TUN
    ↓
联网检测
    ↓
连接成功
```

### 日常使用

```text
打开 ClashXY
    ↓
[连接]
```

或者：

```text
开机
  ↓
ClashXY 自动启动
  ↓
自动连接
```

---

## 4. 核心架构

```text
┌──────────────────────────────┐
│          Flutter UI          │
│ Home / Server / Device / Set │
└──────────────┬───────────────┘
               │
       Application Layer
               │
 ┌─────────────┴─────────────┐
 │                           │
 ▼                           ▼
Panel Layer              Proxy Layer
2SUIConnector            MihomoEngine
 │                           │
 ▼                           ▼
2S-UI API                Platform VPN
 │                           │
 ▼                           ▼
Sing-box VPS              Windows TUN
```

核心原则：

1. UI 不直接请求 2S-UI。
2. UI 不直接操作 Mihomo 子进程。
3. Core 不依赖 Windows 专属实现。
4. Platform 层不能反向污染 Core。
5. 所有敏感信息通过 Secure Storage。
6. Mihomo YAML 由结构化对象生成。
7. 所有核心流程必须可测试。
8. 所有远程写操作必须考虑回滚。

---

## 5. Phase 0：Windows 技术验证

这一阶段不做正式 UI。

目标：

> 使用最小 CLI / Lab 工具证明“2S-UI → 创建 Client → 生成 Mihomo 配置 → TUN → 联网”整条链路成立。

建议项目：

```text
tools/clashxy_lab/
```

功能：

```text
panel test
panel login
panel token-create
panel inbounds
panel clients

device create
device delete

profile build
mihomo start
mihomo stop
status
```

### 必须验证

- 2S-UI 实际 API base path
- 登录请求格式
- 2FA 请求格式
- Session/Cookie 行为
- API Token 创建流程
- API v2 Token Header 行为
- Client Create JSON Schema
- Client Delete JSON Schema
- Inbound 数据 Schema
- 单 Client 连接信息如何获取
- VLESS Reality 参数
- Hysteria2 参数
- Mihomo 对应配置格式
- Windows TUN 权限需求

### Phase 0 验收标准

以下流程能够完整跑通：

```text
全新测试用户
  ↓
登录 2S-UI
  ↓
创建 API Token
  ↓
读取 Inbounds
  ↓
创建测试 Client
  ↓
生成 Mihomo Profile
  ↓
启动 Mihomo
  ↓
启用 TUN
  ↓
HTTP 联网成功
  ↓
停止 Mihomo
  ↓
删除测试 Client
```

如果 Phase 0 未完成，禁止进入正式 UI 开发。

---

## 6. Phase 1：Flutter Windows 工程骨架

目标：

建立长期可维护的工程结构。

### 页面

第一版只保留：

- Home
- Servers
- Devices
- Settings

### 基础能力

- Router
- Theme
- Riverpod
- Logger
- HTTP Client
- SQLite / Drift
- Secure Storage
- Error Mapper
- App Bootstrap

### 验收标准

```bash
flutter analyze
flutter test
```

必须通过。

---

## 7. Phase 2：2S-UI Connector

实现：

```text
PanelConnector
└── TwoSUIConnector
```

功能：

- 登录
- 2FA
- 登出
- API Token
- Inbounds
- Clients
- Status
- Stats
- Online Clients
- Client Create
- Client Update
- Client Delete

### 安全原则

管理员密码只允许存在于：

```text
LoginForm
  ↓
HTTP Request
  ↓
Token Provision
  ↓
立即清除
```

禁止：

- 写入 SQLite
- 写日志
- 写配置文件
- 写 crash report
- 放进剪贴板

---

## 8. Phase 3：Provisioning

核心服务：

```text
ProvisioningService
```

职责：

```text
检测面板
  ↓
读取 Inbound
  ↓
选择协议
  ↓
生成设备身份
  ↓
生成远程 Client
  ↓
获取连接参数
  ↓
生成 Mihomo Profile
  ↓
测试配置
  ↓
写入本地
```

### 必须实现状态机

```text
idle
checkingPanel
loadingInbounds
generatingCredential
creatingRemoteClient
fetchingConfiguration
buildingProfile
testingProfile
savingProfile
ready
failed
rollingBack
```

### 回滚

若出现：

```text
远程 Client 创建成功
本地 Profile 失败
```

必须自动删除远程 Client。

---

## 9. Phase 4：Mihomo Windows

第一版采用 Mihomo 独立进程方案。

```text
Flutter
  ↓
MihomoEngine
  ↓
mihomo.exe
  ↓
External Controller
```

### 必须实现

- CoreManager
- ProcessManager
- ConfigManager
- ControllerClient
- TunManager
- TrafficMonitor
- DelayTester
- HealthChecker

### 连接成功条件

不能只判断进程存在。

必须同时满足：

```text
Mihomo Running
+
TUN Active
+
Controller Available
+
Proxy Available
+
HTTP Connectivity Test Success
```

---

## 10. Phase 5：Windows MVP

功能：

- 首次登录
- 一键创建本机设备
- 自动生成 Profile
- 一键连接
- 一键断开
- 延迟显示
- 上下行速率
- 累计流量
- 设备删除
- 系统托盘
- 开机启动
- 自动连接

### MVP 用户流程

用户只需要输入：

```text
2S-UI URL
用户名
密码
2FA（如有）
```

随后：

```text
[为本机创建并连接]
```

即可联网。

---

## 11. Phase 6：Windows 稳定化

Windows 必须先稳定到“长期自用”再进入 Android。

重点处理：

- Mihomo 崩溃自动拉起
- Wi-Fi / 有线切换
- 网络断开恢复
- 电脑休眠恢复
- Windows 重启恢复
- DNS 恢复
- TUN 失败恢复
- 异常退出恢复
- 配置损坏恢复
- 核心版本回滚
- 单实例
- 托盘控制
- 卸载前清理

### 必测场景

#### 场景 A

```text
连接
↓
任务管理器杀掉 ClashXY
```

系统网络不能损坏。

#### 场景 B

```text
连接
↓
睡眠
↓
唤醒
```

必须自动恢复。

#### 场景 C

```text
Wi-Fi A
↓
Wi-Fi B
```

必须自动重新建立连接。

#### 场景 D

```text
Mihomo 进程异常退出
```

必须进入自动恢复状态机。

---

## 12. Windows v1.0 验收标准

必须稳定完成：

```text
新装
登录
建用户
连接
断开
重启电脑
自动连接
睡眠恢复
网络切换
Mihomo 崩溃恢复
删除设备
重新创建设备
```

Windows v1.0 之前，不启动 Android 正式开发。

---

## 13. Phase 7：Android 技术验证

Android 第一阶段只证明 VPN 技术链路。

目标：

```text
已有本地 Mihomo Profile
   ↓
Android VpnService
   ↓
TUN FD
   ↓
Mihomo Native Bridge
   ↓
联网
```

暂时不做完整 UI。

---

## 14. Phase 8：Android MVP

Android 复用 Windows 已有业务层。

新增：

```text
AndroidPlatformVpnService
AndroidMihomoBridge
ForegroundService
NetworkObserver
BatteryOptimizationHandler
```

Android MVP：

```text
登录 2S-UI
↓
为当前手机创建 Client
↓
生成 Profile
↓
连接
↓
断开
```

---

## 15. 协议范围

当前只实现：

### VLESS Reality

必须支持：

- UUID
- server
- port
- network
- TLS
- Reality
- serverName
- publicKey
- shortId
- fingerprint

### Hysteria2

必须支持：

- server
- port
- password
- TLS
- SNI
- skip-cert-verify（高级设置）
- obfs（若服务端实际使用）

其他协议后续再加。

---

## 16. 数据模型

核心模型：

```text
PanelAccount
Server
Inbound
RemoteClient
LocalDevice
ProxyProfile
ConnectionProfile
TrafficRecord
```

### PanelAccount

不能保存管理员密码。

```json
{
  "id": "panel-001",
  "name": "My VPS",
  "baseUrl": "https://panel.example.com/",
  "panelType": "2s-ui",
  "tokenRef": "secure://panel-001"
}
```

### LocalDevice

```json
{
  "id": "uuid",
  "displayName": "Richard-PC",
  "platform": "windows",
  "remoteClientId": "client-id",
  "profileId": "profile-id"
}
```

---

## 17. 安全要求

### Secret 必须脱敏

包括：

- API Token
- 密码
- UUID
- Hysteria2 password
- Reality private key
- 订阅 secret

日志输出：

```text
Token: abcd****wxyz
```

而不是完整值。

### HTTPS

默认拒绝普通 HTTP。

开发模式可临时允许：

```text
allowInsecurePanelHttp = true
```

正式版本默认关闭。

---

## 18. Mihomo 更新策略

App 和 Mihomo Core 分离更新。

目录：

```text
core/
├── current/
├── previous/
└── metadata.json
```

更新步骤：

```text
下载
↓
校验
↓
保存 previous
↓
切换 current
↓
启动测试
↓
失败则回滚
```

禁止无条件追最新版本。

---

## 19. 测试策略

### Unit Test

覆盖：

- DTO
- API Parser
- Config Builder
- VLESS Mapping
- HY2 Mapping
- Provisioning State Machine
- Error Mapper
- Profile Serialization

### Mock Test

必须提供：

```text
Fake2SUI
FakeMihomoController
FakePlatformVpnService
```

### Integration Test

真实 VPS：

```text
登录
建 Client
连接
产生流量
查询统计
删除 Client
```

### E2E

```text
全新安装
↓
登录
↓
创建 Client
↓
连接
↓
访问互联网
↓
断开
↓
删除 Client
↓
再次连接必须失败
```

---

## 20. 当前项目主线

```text
Phase 0 Windows CLI 技术验证
        ↓
Phase 1 Flutter Windows 骨架
        ↓
Phase 2 2S-UI Connector
        ↓
Phase 3 Provisioning
        ↓
Phase 4 Mihomo Windows
        ↓
Phase 5 Windows MVP
        ↓
Phase 6 Windows 稳定化
        ↓
Windows v1.0
        ↓
Phase 7 Android VPN 技术验证
        ↓
Phase 8 Android MVP
```

这是当前唯一主线。

任何额外需求必须判断：

> 是否影响 Windows v1.0？

如果不影响，优先放入 Backlog。

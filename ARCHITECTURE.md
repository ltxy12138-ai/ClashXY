# ClashXY Architecture

> **已弃用：** 当前架构规范以 `docs/ARCHITECTURE.md` 为准；本文件仅保留
> 早期设计记录。

> 本文定义 ClashXY 的代码边界、依赖方向和长期架构约束。
> Codex 在修改代码前必须阅读本文。

---

## 1. 架构目标

项目必须同时满足：

1. Windows 先行。
2. Android 后续可复用绝大多数业务逻辑。
3. 2S-UI 可替换。
4. Mihomo 可替换或升级。
5. Platform 逻辑与 Core 解耦。
6. 业务逻辑可测试。
7. 敏感数据不可泄漏。
8. 不依赖 ClashMi 私有组件。

---

## 2. 推荐目录

```text
lib/
├── app/
│   ├── bootstrap/
│   ├── router/
│   └── theme/
│
├── core/
│   ├── panel/
│   │   ├── panel_connector.dart
│   │   └── two_s_ui/
│   │
│   ├── mihomo/
│   │   ├── mihomo_engine.dart
│   │   ├── controller/
│   │   ├── config/
│   │   └── models/
│   │
│   ├── provisioning/
│   ├── connection/
│   ├── storage/
│   ├── security/
│   ├── networking/
│   └── errors/
│
├── features/
│   ├── home/
│   ├── servers/
│   ├── devices/
│   └── settings/
│
├── platform/
│   ├── platform_vpn_service.dart
│   ├── platform_secure_storage.dart
│   └── windows/
│
└── models/
```

Android 阶段新增：

```text
platform/
└── android/
```

而不是修改 Core 来适配 Android。

---

## 3. 依赖方向

合法：

```text
UI
 ↓
Application / Feature
 ↓
Core Interfaces
 ↓
Adapters
 ↓
Platform / HTTP / Mihomo
```

禁止：

```text
Core → Windows UI
Core → Win32
Core → Android VpnService
PanelConnector → Widget
MihomoEngine → Riverpod Widget
```

---

## 4. Panel 抽象

```dart
abstract class PanelConnector {
  Future<PanelSession> login(LoginRequest request);
  Future<void> logout();

  Future<List<Inbound>> getInbounds();
  Future<List<RemoteClient>> getClients();

  Future<RemoteClient> createClient(
    CreateClientRequest request,
  );

  Future<RemoteClient> updateClient(
    UpdateClientRequest request,
  );

  Future<void> deleteClient(String id);

  Future<ServerStatus> getStatus();
  Future<TrafficStats> getTraffic();
  Future<List<OnlineClient>> getOnlineClients();
}
```

当前实现：

```text
TwoSUIConnector
```

未来可能：

```text
XUIConnector
MarzbanConnector
CustomPanelConnector
```

因此 UI 禁止依赖 `TwoSUIConnector` 具体类型。

---

## 5. 2S-UI Adapter 分层

```text
TwoSUIConnector
├── TwoSUIHttpClient
├── TwoSUIAuthService
├── TwoSUITokenService
├── TwoSUIInboundRepository
├── TwoSUIClientRepository
├── TwoSUIStatsRepository
├── DTO
└── Mapper
```

### 规则

DTO 只描述 2S-UI 数据。

业务层模型使用：

```text
Inbound
RemoteClient
TrafficStats
```

禁止 Feature 层直接使用：

```text
TwoSUIInboundDto
TwoSUIClientDto
```

---

## 6. Provisioning 架构

```text
ProvisioningService
├── DeviceIdentityService
├── CredentialGenerator
├── InboundSelector
├── RemoteClientProvisioner
├── ProxyProfileFactory
├── ProfileValidator
└── RollbackCoordinator
```

ProvisioningService 不负责 UI。

输入：

```text
ProvisionDeviceRequest
```

输出：

```text
ProvisionDeviceResult
```

进度通过：

```text
Stream<ProvisioningState>
```

暴露。

---

## 7. Provisioning 状态机

```text
Idle
CheckingPanel
LoadingInbounds
SelectingInbound
GeneratingCredential
CreatingRemoteClient
FetchingConnectionInfo
BuildingProfile
TestingProfile
SavingProfile
Ready
RollingBack
Failed
```

状态必须是显式模型。

禁止：

```dart
String status = "loading";
```

推荐：

```dart
sealed class ProvisioningState {}
```

---

## 8. Mihomo 抽象

```dart
abstract class MihomoEngine {
  Future<void> initialize();

  Future<void> start(ConnectionProfile profile);

  Future<void> stop();

  Future<void> restart();

  Future<MihomoStatus> getStatus();

  Future<DelayResult> testDelay();

  Stream<TrafficSample> trafficStream();

  Stream<MihomoLogEntry> logStream();
}
```

Windows 实现可以使用子进程。

Android 实现可以使用 Native Bridge。

上层不得感知差异。

---

## 9. Platform VPN 抽象

```dart
abstract class PlatformVpnService {
  Future<void> prepare();
  Future<void> start(VpnStartRequest request);
  Future<void> stop();
  Future<PlatformVpnStatus> getStatus();
  Stream<PlatformNetworkEvent> networkEvents();
}
```

### Windows

```text
WindowsPlatformVpnService
```

负责：

- TUN
- 权限
- 网络变化监听
- 恢复
- 清理

### Android

```text
AndroidPlatformVpnService
```

负责：

- VpnService
- TUN FD
- Foreground Service
- NetworkCallback

---

## 10. ConnectionSupervisor

长期运行不能依靠页面逻辑。

需要：

```text
ConnectionSupervisor
```

状态：

```text
Disconnected
Connecting
Connected
WaitingForNetwork
Reconnecting
Stopping
Error
```

监听：

- Platform 网络变化
- Mihomo 进程状态
- TUN 状态
- App 生命周期
- 用户连接意图

---

## 11. Mihomo Profile

禁止直接在业务逻辑中拼接 YAML。

结构：

```text
ConnectionProfile
├── ProxyProfile
├── DnsProfile
├── TunProfile
├── RuleProfile
└── ControllerProfile
```

最后：

```text
ConnectionProfile
      ↓
MihomoConfigBuilder
      ↓
Map / YAML AST
      ↓
YAML
```

---

## 12. 协议 Mapper

```text
TwoSUIProxyMapper
├── VlessRealityMapper
└── Hysteria2Mapper
```

输入：

```text
Inbound
RemoteClient
TLS
Transport
```

输出：

```text
ProxyProfile
```

每个 Mapper 必须有独立单元测试。

---

## 13. Secure Storage

统一接口：

```dart
abstract class SecureStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}
```

Windows：

```text
WindowsSecureStorage
```

Android：

```text
AndroidSecureStorage
```

业务层不允许知道：

```text
DPAPI
Credential Manager
Keystore
```

---

## 14. SQLite / Drift

SQLite 只保存非 Secret：

允许：

- Panel URL
- Panel Name
- Device ID
- Remote Client ID
- Profile metadata
- User preferences
- 缓存统计

禁止：

- Admin password
- API Token 明文
- Hysteria2 password 明文（若可用 SecureRef）
- Private Key

Secret 用引用：

```text
secure://panel/token/001
```

---

## 15. 日志

统一：

```text
AppLogger
```

必须支持：

```text
debug
info
warning
error
```

任何 Secret 必须经过：

```text
SecretRedactor
```

禁止：

```dart
logger.info(response.body);
```

除非 DTO 已确认不包含敏感内容。

---

## 16. 错误体系

统一业务异常：

```text
PanelAuthException
PanelUnavailableException
PanelApiException
ProvisioningException
MihomoStartException
MihomoConfigException
TunException
NetworkUnavailableException
SecureStorageException
```

UI 通过：

```text
ErrorMapper
```

映射成人类可读信息。

---

## 17. Windows Mihomo 进程

建议：

```text
CoreManager
├── BinaryManager
├── ProcessManager
├── ConfigFileManager
├── ControllerClient
└── CoreHealthChecker
```

BinaryManager：

```text
core/current/mihomo.exe
core/previous/mihomo.exe
```

ProcessManager 不负责 UI。

---

## 18. 健康检查

Connected 必须是综合状态：

```text
processRunning
&& controllerReachable
&& tunActive
&& proxyReachable
&& connectivityCheckOk
```

任一失败都不能显示“已连接”。

---

## 19. Android 迁移原则

Windows 开发阶段禁止做 Android 专用实现，但必须保证：

```text
PanelConnector
Provisioning
Profile Builder
Device Model
Connection State
Repositories
```

均不依赖 Windows API。

Android 开发时只新增：

```text
AndroidPlatformVpnService
AndroidMihomoBridge
AndroidForegroundService
```

---

## 20. 禁止事项

Codex 不得：

- 把 HTTP 请求直接写在 Widget 中
- 把 Windows TUN 逻辑放进 `core/`
- 在多个文件重复实现 2S-UI 请求
- 长期保存管理员密码
- 日志输出完整 Token
- 用字符串拼接复杂 YAML
- 用静态全局变量维护连接状态
- 在任务未要求时重构整个项目
- 顺手实现后续平台功能
- 引入大型依赖而不解释理由
- 复制 ClashMi 私有/不可用依赖

---

## 21. 设计决策原则

发生不确定性时优先：

1. 可测试
2. 可替换
3. 少依赖
4. 明确状态
5. 安全
6. 简单
7. 再考虑性能

不要为了“未来可能需要”过度设计。

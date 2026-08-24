# CODEX_GUIDE

> 这是 Codex 在 ClashXY 仓库中的强制工作约束。

---

## 1. 每次开始任务

开始任何代码修改前，依次阅读：

1. `docs/PROJECT_PLAN.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TASKS.md`
4. 当前用户指定的 Task

如果仓库状态与文档冲突：

> 先报告冲突，不要自行重构整个项目。

---

## 2. 一次只做一个 Task

禁止：

- 顺手实现下一个 Task
- 顺手增加新页面
- 顺手加新协议
- 顺手支持 Linux/macOS/iOS
- 顺手做大范围重构

除非当前 Task 明确需要。

---

## 3. 修改前先检查

必须先检查：

```text
git status
相关目录
现有接口
现有测试
```

避免重复实现。

---

## 4. 架构约束

### Core

禁止依赖：

- Windows UI
- Win32 实现
- Android VpnService
- Widget
- BuildContext

### Features

只能通过 Core Service / Repository 工作。

### Platform

负责操作系统专属实现。

### Panel

必须经过：

```text
PanelConnector
```

不能在 Widget 直接 HTTP。

---

## 5. 敏感信息规则

永远禁止日志输出：

- Admin Password
- API Token
- 完整 UUID
- HY2 Password
- Private Key
- Subscription Secret

所有 Secret 通过：

```text
SecretRedactor
```

处理。

---

## 6. 管理员密码

管理员密码：

```text
只允许用于首次登录
```

成功创建 API Token 后：

- 清除 Controller
- 清除 State
- 不写数据库
- 不写配置
- 不写日志

---

## 7. YAML

禁止：

```dart
final yaml = "proxies:\n - name: $name...";
```

复杂 Mihomo 配置必须经过：

```text
Domain Model
↓
Config Builder
↓
Serializer
```

---

## 8. 状态管理

禁止用：

```dart
bool isConnecting;
bool reconnecting;
bool failed;
```

表达复杂连接生命周期。

必须使用显式状态：

```text
Disconnected
Connecting
Connected
Reconnecting
Error
```

Provisioning 同理。

---

## 9. 错误处理

禁止把底层错误直接显示给用户：

```text
SocketException
ProcessException
HandshakeException
```

底层抛业务异常。

UI 使用：

```text
ErrorMapper
```

转换。

---

## 10. 测试

每个核心模块必须写测试。

至少包括：

```text
正常路径
失败路径
边界条件
```

特别是：

- 2S-UI Mapper
- VLESS Reality
- HY2
- Config Builder
- Provisioning Rollback
- Connection State

---

## 11. Task 完成前

运行：

```bash
dart format .
flutter analyze
flutter test
```

如果当前阶段有 integration test：

```bash
flutter test integration_test
```

如果失败：

> 不得声明 Task 完成。

---

## 12. Task 完成输出格式

每次完成任务必须报告：

```text
Task:
完成内容:
修改文件:
新增测试:
执行命令:
测试结果:
已知限制:
下一 Task 建议:
```

不要只说：

```text
已完成
```

---

## 13. 不允许隐藏失败

如果遇到：

- API Schema 不确定
- 2S-UI 版本差异
- Windows 权限问题
- Mihomo 行为不确定
- 测试环境缺失

必须明确指出。

禁止：

- 猜接口
- 伪造测试成功
- 用 TODO 假装完成核心功能

---

## 14. 依赖管理

增加依赖前必须说明：

```text
为什么需要
替代方案
是否跨平台
维护状态
```

禁止仅为了几行代码加入重量级库。

---

## 15. 文件修改范围

如果 Task 给出允许修改范围：

> 不要修改范围外文件。

确有必要时：

1. 先说明原因
2. 做最小修改

---

## 16. Windows 优先

当前阶段 Windows 优先。

禁止提前实现：

```text
Linux
macOS
iOS
```

Android 只有在 Windows v1.0 后进入正式阶段。

---

## 17. ClashMi 参考原则

可以参考：

- 信息架构
- UX
- Flutter 工程思路
- Mihomo 使用方式

不要依赖：

- `libclash-vpn-service`
- `board-service`
- 未公开私有模块

不要直接大面积复制 ClashMi 源码。

---

## 18. 2S-UI 规则

任何写操作必须基于真实 API Schema。

优先级：

```text
实际请求
>
2S-UI 源码
>
现有测试
>
猜测
```

禁止猜 Client JSON。

---

## 19. Provisioning 写操作

远程创建 Client 后，本地流程失败：

> 必须考虑 rollback。

禁止留下不可追踪的垃圾 Client。

---

## 20. ConnectionSupervisor

长期连接相关行为统一进入：

```text
ConnectionSupervisor
```

禁止在：

- HomePage
- Tray
- SettingsPage

各自实现重连逻辑。

---

## 21. 最小改动原则

一个 Task 只解决一个问题。

优先：

```text
可读
可测试
简单
```

不要为了“以后可能会用”创建复杂抽象。

---

## 22. 当前总目标

所有开发决策优先服务：

> Windows v1.0 可以稳定长期自用。

如果某项工作与这一目标无直接关系：

> 放入 Backlog，不要现在实现。

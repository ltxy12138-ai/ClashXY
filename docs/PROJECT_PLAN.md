# ClashXY 项目计划

> 正式产品名：`ClashXY`。

> 版本：v1.1（产品定位修订）
> 当前目标平台：Windows → Android
> 核心技术：Flutter + Mihomo；2S-UI 为可选集成
> 修订日期：2026-08-21

---

## 1. 产品定位

ClashXY 的主产品是一个完整、通用的 Mihomo / Clash 客户端。

用户不需要连接 2S-UI，也可以通过下列来源使用 VPN：

- HTTPS 订阅链接
- 本地 Clash / Mihomo YAML
- 应用内粘贴的自定义 YAML
- 2S-UI 为当前设备生成的配置

2S-UI 是附加管理能力，用于登录面板、创建设备客户端、查看服务器状态和管理远程客户端。它不是应用启动、导入订阅或连接 VPN 的前置条件。

旧版文档中“不是通用机场客户端”“隐藏订阅地址/YAML”“首次使用必须登录 2S-UI”等描述全部由本版本取代。

---

## 2. 产品原则

1. 通用 Clash 功能优先，面板集成可选。
2. 中文为默认界面语言。
3. 配置来源平等，不把某一种来源硬编码为主流程。
4. 兼容完整 Clash / Mihomo 配置，尽量保留代理、代理提供器、代理组、规则和 DNS 行为。
5. 应用始终接管安全边界：控制器仅监听本机、密钥随机生成、默认不允许局域网访问。
6. 订阅地址、完整 YAML、代理凭据和 2S-UI Token 只进入系统安全存储。
7. SQLite 只保存非敏感元数据。
8. 2S-UI 管理员密码只在登录和创建 API Token 时短暂存在于内存。
9. 不干扰用户已有的 Clash/Mihomo 应用、进程或网络适配器。
10. 核心流程必须可测试、可恢复、可回滚。

---

## 3. Windows 功能范围

### 通用配置

- 添加、更新、删除 HTTPS 订阅
- 导入本地 `.yaml` / `.yml`
- 粘贴自定义 YAML
- 多配置并存和切换
- 完整配置的安全持久化
- 旧 2S-UI 配置无损迁移

### Clash / Mihomo 运行能力

- Mihomo 独立进程和 Windows TUN
- 连接、断开、自动连接
- Rule / Global / Direct 模式
- 代理组和节点选择
- 节点延迟测试
- 实时上下行速率
- 活动连接查看、单条关闭、全部关闭
- 规则查看
- 实时核心日志
- DNS、IPv6、端口和 TUN 设置

### 可选 2S-UI 管理

- HTTPS 面板连接测试
- 用户名、密码、2FA 登录
- 独立 API Token 创建和安全存储
- Inbound、Client、在线状态和流量查询
- 为本机创建/删除 Client
- VLESS Reality、Hysteria2 配置生成
- 远程写入失败时回滚

设备显示名、稳定机器 ID、2S-UI Client 映射和未来的订阅 Token 必须保持
独立；详细边界见 [DEVICE_IDENTITY.md](DEVICE_IDENTITY.md)。独立订阅 Token
属于后续服务端订阅认证层，不由 Windows 客户端伪造实现。

### Windows 稳定化

- 系统托盘
- 单实例
- 开机启动
- 网络变化自动重连
- 睡眠/唤醒恢复
- Mihomo 崩溃恢复和退避
- 异常退出后的 TUN / DNS 清理
- Core 更新、校验和回滚
- Windows 安装包和升级迁移

---

## 4. 首次使用体验

```text
打开 ClashXY
    ↓
选择配置来源
    ├─ 添加订阅
    ├─ 导入本地 YAML
    ├─ 自定义 YAML
    └─ 连接 2S-UI（可选）
    ↓
保存到安全存储
    ↓
选择配置并连接
    ↓
选择代理组 / 节点
```

已有 2S-UI 的用户仍可使用：

```text
连接 2S-UI
    ↓
创建本机 API Token
    ↓
选择 Inbound 并创建设备 Client
    ↓
生成配置并连接
```

---

## 5. 核心架构

```text
Flutter UI
  │
  ├─ Profile Sources
  │    ├─ Subscription
  │    ├─ Local YAML
  │    ├─ Custom YAML
  │    └─ 2S-UI Provisioning
  │
  ├─ Secure Profile Store
  │
  └─ Mihomo Runtime
       ├─ Config Safety Overlay
       ├─ Process / TUN
       └─ External Controller
            ├─ Proxies / Delay
            ├─ Rules
            ├─ Connections
            ├─ Traffic
            └─ Logs
```

2S-UI Connector 与其他 Profile Source 同级，不得反向成为 Mihomo Runtime 的依赖。

---

## 6. 配置安全覆盖层

导入的 Clash / Mihomo 配置允许保留：

- `proxies`
- `proxy-providers`
- `proxy-groups`
- `rules` / `rule-providers`
- DNS 策略
- hosts、sniffer 和其他 Mihomo 能力

运行时必须覆盖或移除：

- `external-controller`：固定为 `127.0.0.1`
- `secret`：每次运行随机生成
- `allow-lan`：默认 `false`
- `bind-address`：固定为 `127.0.0.1`
- `external-ui*`、Controller TLS/CORS 等外部暴露入口
- TUN 启用、设备名、自动路由和严格路由：由应用设置控制
- DNS 监听地址：仅本机

订阅正式版只接受 HTTPS，默认上限 10 MB，并设置请求超时。

---

## 7. 阶段路线

### P0-P5：原始 2S-UI MVP

已完成并保留为可选集成能力。

### P5A：通用 Clash 产品重构

目标：移除 2S-UI 前置依赖，建立通用配置来源、中文界面和完整 Mihomo 控制面。

### P6：Windows 稳定化

已完成多语言、托盘、关闭到托盘、单实例、开机启动注册、发布脚本、运行配置
ACL 加固、Clash 高级配置和 2S-UI 账户断开/令牌撤销。网络变化与睡眠/唤醒
恢复、Mihomo 崩溃恢复与有限退避、所有权限定的异常 TUN/DNS 网络清理，以及
官方稳定版 Core 下载、SHA-256 校验、安全切换和回滚已完成。Windows 安装器、
升级迁移和发布候选自动化也已完成；可信代码签名与干净 Windows 10/11 生命周期
证据仍是正式发布门禁。

### P7-P8：Android

复用 Profile Source、Secure Store、配置安全覆盖层和 Controller 业务模型；平台层替换为 Android VpnService / Native Bridge。

---

## 8. Windows 发布验收

至少覆盖：

```text
全新安装
添加订阅
导入 YAML
连接 / 断开
切换节点和模式
查看规则、连接和日志
更新订阅
重启后恢复配置
网络切换和睡眠恢复
Mihomo 崩溃恢复
可选连接 2S-UI
创建、连接并删除 2S-UI 设备
卸载前安全清理
```

任何订阅 Secret、代理凭据、管理员密码、API Token 或运行时 Controller Secret 都不能进入普通日志、SQLite 或发布产物中的明文诊断文件。

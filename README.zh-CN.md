# ClashXY

[English](README.md) | [简体中文](README.zh-CN.md)

[![Windows CI](https://github.com/ltxy12138-ai/ClashXY/actions/workflows/windows-ci.yml/badge.svg?branch=main)](https://github.com/ltxy12138-ai/ClashXY/actions/workflows/windows-ci.yml)
[![Release](https://img.shields.io/github/v/release/ltxy12138-ai/ClashXY?include_prereleases&label=release)](https://github.com/ltxy12138-ai/ClashXY/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0--only-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-0078D4?logo=windows)](https://github.com/ltxy12138-ai/ClashXY/releases)

**支持订阅与 YAML、Windows TUN、多语言界面，并可选管理 2S-UI 设备的
Mihomo / Clash 桌面客户端。**

ClashXY 首先是一款通用 Clash 客户端。即使不连接 2S-UI，用户也可以直接添加
HTTPS 订阅、导入本地 YAML 或创建自定义 YAML 配置。2S-UI 是为自建面板用户提供的
可选管理层，不是应用启动和 VPN 连接的前置条件。

ClashXY 是独立项目，与 MetaCubeX、Clash 或 2S-UI 均无隶属关系。

> [!WARNING]
> 当前 `v1.9.1` 是用于测试的未签名预发布版，Windows 可能提示未知发布者。请只从
> [GitHub Releases](https://github.com/ltxy12138-ai/ClashXY/releases) 下载，
> 并在运行前核对发布页提供的 SHA-256 校验值。

## 主要功能

### 配置与订阅

- 添加和更新 HTTPS Clash / Mihomo 订阅。
- 导入本地 `.yaml` / `.yml` 文件，或在应用内创建自定义 YAML。
- 多配置保存与切换、定时更新、重命名、复制、导出和高级 YAML 编辑。
- 保留代理组、Provider、规则、DNS、hosts、sniffer 等完整配置，并叠加本机安全约束。

### Mihomo 控制能力

- 启动并监管经过哈希校验的 Mihomo Core 和 Windows TUN。
- 支持 Rule、Global、Direct 模式，节点选择和代理延迟测试。
- 查看 Provider、活动连接、实时流量、规则和经过脱敏的 Core 日志。
- 支持网络变化、睡眠唤醒和 Core 异常退出后的受控恢复。
- 检查 Mihomo 官方稳定版更新，校验后切换，并保留一个可回滚版本。

### Windows 桌面体验

- 中文、英文和跟随系统语言；新增完整 ARB 文件即可扩展语言。
- 系统托盘、关闭到托盘、单实例、自动连接和当前用户开机启动。
- 提供局域网、端口、TUN、DNS、IPv6、MTU、路由和 Sniffer 设置。
- 提供安装器升级迁移和便携 ZIP 两种分发方式。

### 可选 2S-UI 集成

- 通过 HTTPS 登录用户自己的 2S-UI v1.7.1 面板，支持密码和可选 2FA。
- 创建独立 API Token 和托管设备 Client，再生成本地连接配置。
- 查看设备状态和流量，并通过明确操作仅断开本地面板、删除托管设备或撤销专用 Token。

## 下载

当前支持 Windows 10 / 11 x64。现有应用清单和 TUN 生命周期需要管理员权限。

请从 [GitHub Releases](https://github.com/ltxy12138-ai/ClashXY/releases)
下载安装包、便携 ZIP 和对应校验文件。一般用户建议使用安装包；希望自行管理目录与
快捷方式时可以使用便携版。

在 PowerShell 中校验下载文件：

```powershell
Get-FileHash .\ClashXY-Setup-x64-1.9.1-build15.exe -Algorithm SHA256
Get-Content .\SHA256SUMS-1.9.1-build15.txt
```

两处数值必须完全一致。GitHub 构建溯源可以提供额外供应链证据，但不能替代
Windows Authenticode 签名校验。

## 快速上手

1. 安装 ClashXY，或者完整解压便携版 ZIP。
2. 打开“配置”，添加 HTTPS 订阅、导入 YAML 文件或粘贴自定义 YAML。
3. 选择保存的配置，在首页点击“连接”。
4. 在“代理”页选择节点或测试延迟，在“连接”页查看流量、规则、连接和日志。
5. 如果你运营自己的面板，可以在“2S-UI”页连接面板并为本机创建设备配置。

除非正在进行共存测试，否则不要同时运行多款使用 TUN 的 Clash 客户端。它们可能
争用 TUN 路由、DNS 和本地端口，导致任一应用无法就绪。

## 隐私与安全

ClashXY 不包含分析、广告和遥测，也没有项目方运营的云服务。订阅 URL、完整代理
配置、代理凭据和 2S-UI API Token 使用 Windows DPAPI 安全存储。管理员密码只在
用户请求的 2S-UI 操作期间保留于内存，不会持久化。运行时 YAML 写入 ACL 受限目录，
并在 Mihomo 就绪后删除。

应用仍会连接用户明确提供的服务、导入配置中定义的端点，以及用户主动检查 Core
更新时使用的 GitHub。导入配置和管理员权限网络软件具有安全风险，请只使用可信来源。

- [隐私政策](PRIVACY.md)
- [安全政策与漏洞报告](SECURITY.md)
- [第三方声明](THIRD_PARTY_NOTICES.md)
- [设备身份边界](docs/DEVICE_IDENTITY.md)

## Code signing policy

ClashXY 已提交 SignPath Foundation 开源签名申请。该计划要求保留以下声明：

> Free code signing provided by SignPath.io, certificate by SignPath Foundation

这段声明表示预期使用的签名服务，不代表申请已获批准，也不代表当前未签名预发布版
已经签名。只有 Authenticode 通过[代码签名政策](docs/CODE_SIGNING_POLICY.md)中的
完整校验时，才应将版本视为已签名。可信时间戳发布者和干净 Windows 10/11 生命周期
证据仍是正式版门禁。

## 开发

CI 参考环境使用 Windows 和 Flutter `3.47.1`。请安装 Flutter、带“使用 C++ 的桌面
开发”工作负载的 Visual Studio，以及兼容的 Windows SDK，然后运行：

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build windows --release
```

未打包的 Release 目录位于：

```text
build\windows\x64\runner\Release\
```

新增语言时，创建 `lib/l10n/app_<locale>.arb`，提供本地化 `languageName` 和
`app_en.arb` 的全部键，然后重新生成本地化代码。完整 ARB 会自动出现在语言菜单中。

相关文档：

- [架构说明](docs/ARCHITECTURE.md)
- [项目计划](docs/PROJECT_PLAN.md)
- [发布检查清单](docs/RELEASE_CHECKLIST.md)
- [Windows 干净环境 E2E](docs/WINDOWS_E2E.md)
- [贡献指南](CONTRIBUTING.md)

## 项目状态

Windows 客户端当前处于公开预发布阶段。通用 Clash 功能和可选 2S-UI 集成已经实现；
正式发布前仍需完成可信代码签名与干净 Windows 10/11 最终验证。Android 属于后续
规划，目前尚不支持。

欢迎通过 [GitHub Issues](https://github.com/ltxy12138-ai/ClashXY/issues)
提交问题和建议。公开报告中请勿包含订阅 URL、凭据、Token、导出 YAML 或未脱敏日志。

## 许可证与致谢

ClashXY 使用 `GPL-3.0-only` 许可证。Copyright (C) 2026 ClashXY contributors；
每位贡献者保留其贡献内容的版权。详见 [LICENSE](LICENSE) 与 [NOTICE.md](NOTICE.md)。

发布包包含未修改、独立运行的 Mihomo Core，其许可证为 GPL-3.0；2S-UI 不随应用
分发。准确的上游版本、源代码链接、哈希和许可证声明见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

# Mihomo Windows 进程控制

## 结论

P0-015 已在 Windows 上完成真实核心验收。Lab CLI 支持：

~~~text
mihomo start
mihomo stop
~~~

启动前必须通过 Mihomo 自身的配置测试；启动后状态文件记录 PID、核心绝对路径与进程启动时间，停止时三者必须一致，避免 PID 复用或被篡改状态导致误杀其他进程。

## 验证基线

- Mihomo：v1.19.30 windows amd64，官方 GitHub Release
- Release 日期：2026-08-16
- ZIP：mihomo-windows-amd64-v1-v1.19.30.zip
- ZIP SHA-256：8b81fe2c5cd04ca6deb61eec6075150b44cc5ad13ab867750642e2422f7c1278
- EXE SHA-256：cf894375dbc00ab6708c1314ac35bbd29059f4c37f315353aaca7f1a9c566de6
- 核心版本输出：Mihomo Meta v1.19.30 windows amd64 with go1.26.6

v1 构建作为兼容性基线；MVP 不把临时测试核心复制进仓库。

## 启动流程

mihomo_start.ps1 执行以下检查：

1. 仅允许 Windows .exe 核心、存在的 .yaml/.yml 配置。
2. RuntimeDirectory 使用绝对路径；StatePath 必须位于其中且使用 .json。
3. 若已有状态文件，验证 PID、核心路径和 StartTimeUtcTicks；同一实例返回 AlreadyRunning，身份不一致则拒绝覆盖。
4. 执行核心的 -t -f CONFIG -d RUNTIME，失败时不启动。
5. 通过 Start-Process 以隐藏窗口启动，stdout/stderr 分别重定向到运行目录。
6. 等待早期退出窗口，随后原子写入无凭据状态文件。
7. 状态写入或身份验证失败时立即停止刚启动的进程。

## 停止流程

mihomo_stop.ps1 只读取运行目录内的状态文件。停止前重新验证：

- PID 仍存在；
- 实际 executable path 与 CorePath 完全一致；
- 实际进程 UTC 启动 ticks 与状态一致。

任一身份检查失败都拒绝调用 Stop-Process。成功退出后才删除状态文件；进程已不存在时只清理对应的 stale state。

## Secret 边界

状态和 CLI JSON 不包含 Controller Secret、VLESS UUID、Hysteria2 password 或完整配置内容。测试还检查 Mihomo stdout/stderr，不允许 fixture secret 出现在可观察输出中。

配置文件本身必须包含连接凭据，因此只应写入受限运行目录；本阶段尚未实现 Windows ACL 加固和安全存储，它们属于正式 ProcessManager/ConfigManager 工作。

## 验收证据

使用 tests/mihomo_process_test.ps1 和已校验官方核心执行：

~~~text
PASS: official Mihomo config validation, hidden Windows start, PID identity state, redacted logs, and stop
~~~

测试覆盖：

- 同一份结构化 Builder 输出被官方核心解析成功；
- CLI start 返回新 PID，进程与状态文件存在；
- CLI/state/core logs 无 fixture secret；
- CLI stop 返回相同 PID；
- 进程退出、状态文件删除、临时目录清理。

P0-001 至 P0-014 的 probe_2sui_test.ps1 全量回归同时通过。

# P0-018 完整 E2E Lab

## 结论

2026-08-21 在 Windows 上完成一次可重复、可回滚的完整链路：

```text
2S-UI 登录
→ 创建一天期 API Token 并验证
→ 读取 VLESS Reality Inbound
→ 创建带随机 UUID 的测试 Client
→ 解析并映射 ProxyProfile
→ 生成 Mihomo YAML
→ 启动官方 Mihomo 客户端与独立 TUN
→ Controller 与 Windows 网卡双重检查
→ 经 mixed 端口、VLESS Reality 服务端完成 HTTP 请求
→ 停止客户端
→ 删除 Client、Token、Session 与凭据配置
```

验收结果为 PASS，失败路径与成功路径都进入同一套 finally 回滚。

## 验证环境

- Windows PowerShell 7.6.4。
- 2S-UI v1.7.1，tag 对应 commit `eb2d01440708d0896136cc8d169f19c683b3350c`。
- Mihomo Meta v1.19.30，Windows amd64，官方压缩包 SHA-256：
  `8b81fe2c5cd04ca6deb61eec6075150b44cc5ad13ab867750642e2422f7c1278`。
- Mihomo 可执行文件 SHA-256：
  `cf894375dbc00ab6708c1314ac35bbd29059f4c37f315353aaca7f1a9c566de6`。

## 隔离拓扑

测试使用已按 2S-UI v1.7.1 源码和真实响应结构校验的动态本地模拟面板。另起两套官方 Mihomo：

1. 服务端监听 loopback VLESS Reality，使用单次随机 UUID、Reality keypair 与 short-id。
2. 客户端使用 E2E 生成的 ProxyProfile，启用唯一名称的 Windows TUN。
3. HTTP 目标由模拟面板提供；服务端 hosts 规则将测试域名定向到 loopback。
4. 客户端通过 mixed 端口发出请求，数据实际经过 VLESS Reality 服务端后到达目标。

TUN 使用未占用的 `198.19.0.0/16` 内随机 /30，`auto-route=false`、`strict-route=false`，因此不接管系统默认路由。测试前后校验已有 `Mihomo` 网卡的名称和 ifIndex 不变。

## 真实 2S-UI 的安全边界

官方 v1.7.1 的 Client 创建会把完整保存对象写入审计变更记录 `changes.obj`。删除 Client 不等于删除该审计副本。因此：

- 已授权的官方临时实例用于登录、Token、Inbound/Client Schema 与安全写入验证。
- 不在该实例中创建含真实随机凭据的可连接 Client。
- 完整凭据 E2E 改用与官方 Schema 对齐的本地模拟面板。
- 真实服务端和客户端数据面仍由官方 Mihomo 完成，不以 mock 代替代理链路。

这避免为测试目的在 2S-UI 数据库中留下 UUID、私钥或其他完整 Client 配置。

## 回滚与脱敏

`e2e_lab.ps1` 维护每个阶段的完成标志。finally 按以下顺序处理：

1. 停止并校验当前 Mihomo 进程身份。
2. 删除名称以 `clashxy-lab-` 开头且 ID 匹配的 Client。
3. 删除短期 Token。
4. logout Session。
5. 删除包含连接凭据的 YAML。

输出只包含阶段布尔值、版本、状态码、Client ID/安全名称、TUN 名称与完成时间；Token、密码、TOTP、完整 UUID、Reality 私钥和 Controller Secret 不进入结果或日志。

## 复现

以管理员 PowerShell 运行：

```powershell
.\tools\clashxy_lab\tests\e2e_lab_test.ps1 -CorePath C:\path\mihomo.exe
```

预期输出：

```text
PASS: login, short-lived Token, Client create, Reality Profile, official Mihomo server/client, TUN active, proxied HTTP, stop, Client/Token rollback, and redaction
```

面向受控目标面板的一次命令入口：

```powershell
.\tools\clashxy_lab\clashxy_lab.ps1 e2e run `
  -CorePath C:\path\mihomo.exe `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin `
  -InboundId 1 `
  -ConnectivityUri https://example.com/ `
  -RuntimeDirectory C:\path\e2e-runtime
```

该命令会创建并删除远程 Client 与 Token。运行前应确认目标面板的审计保留策略，并使用专用测试 Inbound。

# 2S-UI Client 查询实验

> Task：P0-006
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证版本：2S-UI v1.7.1
> 官方源码提交：`eb2d01440708d0896136cc8d169f19c683b3350c`

## 1. 实现

CLI：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\tools\clashxy_lab\clashxy_lab.ps1 panel clients `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token
```

实现文件：

```text
tools/clashxy_lab/panel_clients.ps1
tools/clashxy_lab/clashxy_lab.ps1
```

## 2. API Schema

请求：

```http
GET <panel-base>/apiv2/clients
Token: <redacted>
```

成功 envelope：

```json
{
  "success": true,
  "msg": "",
  "obj": {
    "clients": [],
    "clientsSeq": 1
  }
}
```

不带 `id` 的列表请求由 `ClientService.GetAll()` 处理。官方 v1.7.1 的列表投影包含：

```text
id, enable, name, desc, group, remark, inbounds,
up, down, volume, expiry, created_at, online_at, limit_ip
```

源码明确排除了 `config` 和 `links`，因为它们包含协议凭据和订阅 URI。CLI 仍会再次白名单投影，不依赖服务端永远保持该约束。

## 3. 输出白名单

| 输出字段 | 来源/语义 |
| --- | --- |
| `Id` | Client ID |
| `Name` | Client name |
| `Enabled` | 启用状态 |
| `Group` | Client group |
| `InboundIds` | 绑定的 Inbound ID |
| `InboundCount` | 绑定数量 |
| `UpBytes` / `DownBytes` | 当前流量计数 |
| `QuotaBytes` | 流量额度 |
| `ExpiryUnix` | 到期时间 |
| `LimitIp` | 并发 IP 限制 |

顶层另含 `SnapshotSequence`、HTTP 状态、总数和查询时间。

以下内容不输出：

- `config` 及 UUID、密码、认证串
- `links` 及订阅 URI
- `desc`、`remark`
- API Token

## 4. 自动化测试

Mock 返回一个绑定两个 Inbound 的 Client，并故意附带 `config`、`links`、描述和备注密钥。测试确认安全字段正确，所有敏感字段名和值均未进入 CLI JSON。

结果：

```text
PASS: panel clients structural summary and credential-field redaction
PASS: panel inbounds structural summary and sensitive-field redaction
PASS: panel token create, API v2 auth, delete, cleanup, and redaction
PASS: panel login no-2FA, 2FA, failure, logout, and redaction
PASS: 2S-UI probe flow and secret redaction
```

## 5. 官方 v1.7.1 实测

| 项目 | 结果 |
| --- | --- |
| API v2 HTTP 状态 | 200 |
| `clientsSeq` | 存在 |
| 当前 Client 数 | 0（干净临时实例，P0-006 不提前创建 Client） |
| 临时 Token 删除 | 成功 |
| Session logout | 成功 |
| API 二次查询 | 匹配 Token 0 |
| SQLite 只读复核 | Client 0，实验 Token 0 |

非空字段映射由官方模型、官方列表投影和含敏感数据的 mock 共同验证。真实 Client 创建留给下一任务 P0-007 单独验证。

## 6. 结论

`panel clients` 已满足 P0-006：能使用 API Token 查询官方 2S-UI v1.7.1，并输出 Client ID、name、Inbound 等非敏感结构化摘要。

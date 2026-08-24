# 2S-UI Inbound 查询实验

> Task：P0-005
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证版本：2S-UI v1.7.1
> 官方源码提交：`eb2d01440708d0896136cc8d169f19c683b3350c`

## 1. 实现

CLI：

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\tools\clashxy_lab\clashxy_lab.ps1 panel inbounds `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token
```

实现文件：

```text
tools/clashxy_lab/panel_inbounds.ps1
tools/clashxy_lab/clashxy_lab.ps1
```

API Token 省略时由无回显提示读取。普通 HTTP 默认拒绝，仅本机开发实验可显式使用 `-AllowInsecureHttp`。

## 2. API Schema

请求：

```http
GET <panel-base>/apiv2/inbounds
Token: <redacted>
```

成功响应保持 2S-UI 通用 envelope：

```json
{
  "success": true,
  "msg": "",
  "obj": {
    "inbounds": []
  }
}
```

官方源码调用链：

```text
api/apiV2Handler.go
  → ApiService.LoadPartialData(..., ["inbounds"])
  → InboundService.Get(id)
  → obj.inbounds
```

源码与实测确认，单个原始 Inbound 可能包含：

- `id`、`type`、`tag`、`tls_id`
- 可选 `node_id`
- `listen`、`listen_port` 等协议选项
- `users`
- `addrs`、`out_json`

其中 `users`、`addrs`、`out_json` 和其他动态协议字段不能原样进入普通日志。

## 3. 输出白名单

CLI 不返回原始对象，只重新构造以下摘要：

| 输出字段 | 来源/语义 |
| --- | --- |
| `Id` | Inbound ID |
| `Type` | 协议类型 |
| `Tag` | Inbound 标签 |
| `Listen` | 监听地址 |
| `Port` | `listen_port` |
| `TlsId` | TLS 配置引用 ID |
| `NodeId` | 可选节点 ID |
| `UserCount` | `users` 数量，不含用户值 |

同时输出请求时间、规范化 Base URL、HTTP 状态与总数。Token 明文只在请求期间短暂存在于内存中，最终输出不含 Token。

## 4. 自动化测试

本地 mock 返回一个包含用户值和 `out_json` 密钥的 VLESS Inbound。测试确认：

- 安全摘要字段和值正确。
- `UserCount=1`，但用户值不出现。
- `users`、`out_json` 和密钥值不出现。
- API Token 不出现。
- P0-002～P0-004 回归继续通过。

结果：

```text
PASS: panel inbounds structural summary and sensitive-field redaction
PASS: panel token create, API v2 auth, delete, cleanup, and redaction
PASS: panel login no-2FA, 2FA, failure, logout, and redaction
PASS: 2S-UI probe flow and secret redaction
```

## 5. 官方 v1.7.1 实测

使用已校验的官方 Windows 包启动本机临时实例：

| 项目 | 结果 |
| --- | --- |
| Release 包 SHA256 | `772245D87A9D3C83F4EE83FB6BEE9A09839A49531E2A81D3C47ADEB4D670E414` |
| 临时 Inbound | 唯一标签的 `direct`，仅监听 `127.0.0.1` 随机空闲端口 |
| API v2 HTTP 状态 | 200 |
| 摘要匹配 | 类型、监听地址、端口、用户数量均正确 |
| 临时 Inbound 删除 | 成功 |
| 临时 Token 删除 | 成功 |
| Session logout | 成功 |
| API 二次查询 | 匹配 Inbound 0，匹配 Token 0 |
| SQLite 只读复核 | 实验 Inbound 0，实验 Token 0 |

## 6. 结论

`panel inbounds` 已满足 P0-005：可使用 API Token 查询真实 2S-UI v1.7.1，并只输出结构化、脱敏的 Inbound 摘要。

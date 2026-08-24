# 2S-UI API Token 实验

> Task：P0-004
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证版本：2S-UI v1.7.1

## 1. 实现

CLI：

```powershell
.\tools\clashxy_lab\clashxy_lab.ps1 panel token-test `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin `
  -TokenExpiryDays 1
```

实现文件：

```text
tools/clashxy_lab/panel_token_test.ps1
tools/clashxy_lab/probe_2sui.ps1
tools/clashxy_lab/clashxy_lab.ps1
```

## 2. 实验流程

```text
Session 登录
  ↓
POST api/addToken
  ↓
只在内存中接收一次明文 Token
  ↓
GET api/tokens，通过唯一 desc 查找 Token ID
  ↓
GET apiv2/status，Header: Token
  ↓
POST api/deleteToken
  ↓
GET api/tokens，确认无残留
  ↓
GET api/logout
```

每次实验使用唯一描述：

```text
clashxy-lab-<UTC timestamp>-<random suffix>
```

即使 API v2 验证失败，`finally` 清理流程仍会尝试查找并删除 Token，然后 logout。

## 3. API Schema 实测

### 创建

```http
POST <panel-base>/api/addToken
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
```

form：

| 字段 | 实测语义 |
| --- | --- |
| `desc` | Token 描述 |
| `expiry` | 从当前时间起计算的有效天数 |

成功 envelope 的 `obj` 是新 Token 明文，只返回一次。

### 列表

```http
GET <panel-base>/api/tokens
```

列表包含 `id`、`desc`、`expiry`，Token 字段显示为 `****`。

### API v2

```http
GET <panel-base>/apiv2/status?r=sys
Token: <redacted>
```

### 删除

```http
POST <panel-base>/api/deleteToken
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
```

form：

```text
id=<token-id>
```

## 4. 自动化测试

结果：

```text
PASS: panel token create, API v2 auth, delete, cleanup, and redaction
PASS: panel login no-2FA, 2FA, failure, logout, and redaction
PASS: 2S-UI probe flow and secret redaction
```

Mock 测试确认：

- 创建响应可用于 API v2。
- Token value 不出现在 CLI 输出。
- 删除后列表中不存在唯一描述。
- Session 最终 logout。

## 5. 官方 v1.7.1 实测

脱敏结果：

| 项目 | 结果 |
| --- | --- |
| Token 创建 | 成功 |
| Token 长度 | 32 |
| API v2 HTTP 状态 | 200 |
| API v2 envelope | `success=true` |
| status 对象字段 | `sys` |
| Token 删除 | 成功 |
| 删除后二次查询 | 无残留 |
| logout | 成功 |
| SQLite `tokens` 行数 | 0 |

## 6. 安全结论

- Token value 不写文件、不写普通日志、不进入最终 JSON。
- 输出只记录长度、API 结果和清理状态。
- 管理员密码继续通过 `SecureString` 输入。
- 创建成功后的任意失败路径都会进入清理。
- 正式客户端必须把需要长期保留的 Device Token 写入 Secure Storage；Phase 0 测试 Token 必须删除。

P0-004 验收通过。

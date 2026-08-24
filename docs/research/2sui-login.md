# 2S-UI 登录实验

> Task：P0-003
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证版本：2S-UI v1.7.1

## 1. 实现

CLI：

```powershell
.\tools\clashxy_lab\clashxy_lab.ps1 panel login `
  -BaseUrl https://panel.example.com/app/ `
  -Username admin
```

实现文件：

```text
tools/clashxy_lab/panel_login.ps1
tools/clashxy_lab/probe_2sui.ps1
tools/clashxy_lab/clashxy_lab.ps1
```

`panel login` 复用 P0-002 的请求、Cookie jar 和脱敏流程，没有重复实现 HTTP 登录。

## 2. 行为

登录请求：

```http
POST <panel-base>/api/login
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
```

流程：

```text
提交 user + pass + 空 code
  ├─ success=true → 登录成功
  └─ obj.twoFa=true
       ↓
     安全读取 TOTP code
       ↓
     再次提交同一 endpoint
```

成功后：

- 捕获 Session Cookie 的非敏感属性。
- 不输出 Cookie value。
- 调用 `GET api/logout` 清除 Session。
- 输出 `Success`、`TwoFactorRequired`、`TwoFactorUsed` 和 `LogoutSuccess`。

失败时：

- 返回清晰的业务失败摘要。
- CLI 以错误结束。
- 不输出密码或 TOTP code。

## 3. 自动化测试

本地 mock 覆盖：

- 无 2FA 成功
- 2FA 提示与成功
- 错误密码
- Session Cookie 元数据
- logout
- CLI 参数转发
- Secret 泄漏检查

结果：

```text
PASS: panel login no-2FA, 2FA, failure, logout, and redaction
PASS: 2S-UI probe flow and secret redaction
```

PowerShell 脚本通过语法解析，Node mock 通过 `node --check`。

## 4. 官方 v1.7.1 实测

验证环境：

```text
http://127.0.0.1:2095/app/
官方 Windows 临时实例
仅开发测试显式允许 HTTP
```

结果：

| 场景 | 结果 |
| --- | --- |
| 无 2FA | HTTP 200，`Success=true` |
| 开启 2FA，首次提交 | `TwoFactorRequired=true` |
| 正确 TOTP code | `Success=true`、`TwoFactorUsed=true` |
| 错误密码 | 明确失败，输入未出现在错误输出 |
| Session Cookie | 捕获名称与属性，不捕获 value |
| logout | `LogoutSuccess=true`，Cookie jar 清空 |

2FA 启用时使用过的 TOTP 窗口不能复用；下一个 30 秒窗口登录成功，符合防重放实现。

## 5. 安全结论

- 管理员密码和 TOTP 使用 `SecureString` 接收。
- 明文只在构造单次 form request 时短暂存在于进程内存。
- 项目文件、日志和输出中未保存密码、TOTP Secret、TOTP code 或 Cookie value。
- 普通 HTTP 默认被拒绝；正式使用必须采用 HTTPS。
- 登录实验结束后主动 logout。

P0-003 验收通过。

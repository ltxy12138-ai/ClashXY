# 2S-UI API 探测记录

> Task：P0-002
> 状态：✅ 已完成（官方 v1.7.1 Windows 临时实例实测通过）
> 研究日期：2026-08-21
> Secret：本文不得记录真实密码、Token、完整 UUID 或私钥

## 1. 验证对象

| 项目 | 值 |
| --- | --- |
| 官方仓库 | https://github.com/shenaba/2s-ui |
| 稳定版本 | `v1.7.1` |
| 发布时间 | 2026-08-20T08:06:53Z |
| Tag commit | `eb2d01440708d0896136cc8d169f19c683b3350c` |
| Windows 资产 | `s-ui-windows-amd64.zip` |
| GitHub asset SHA-256 | `772245d87a9d3c83f4ee83fb6bee9a09839a49531e2a81d3c47adeb4d670e414` |
| 本地下载 SHA-256 | 与 GitHub asset digest 一致 |

说明：该版本附带的 `SHA256SUMS` 只列出 Linux 资产，没有 Windows 资产行。Windows 包改用 GitHub Releases API 返回的资产 `digest` 校验。此上游发布缺口需要保留记录。

证据优先级：

```text
目标实例真实请求
>
v1.7.1 官方源码
>
官方 Wiki
>
推测
```

本文已包含目标实例真实请求、v1.7.1 官方源码和本地 mock 三层证据。

## 2. Base path

官方默认面板地址：

```text
http://<host>:2095/app/
```

源码中所有路由都基于可配置的 Web Path 注册：

```text
<panel-base>/api/
<panel-base>/apiv2/
<panel-base>/login
```

因此客户端不能硬编码 `/app/`。输入地址需要规范化为：

```text
scheme://host[:port]/<configured-web-path>/
```

v1.7.1 本地真实实例验证：

- [x] 开发实例协议：HTTP（仅通过显式 `-AllowInsecureHttp` 使用）
- [x] 地址：`127.0.0.1:2095`
- [x] Web Path：`/app/`
- [x] `GET /app` 返回 307，Location 为 `/app/`
- [x] 未登录的 `GET /app/` 返回 307，Location 为 `/app/login`
- [x] 错误 path 返回 404

生产环境仍默认要求 HTTPS；本地 HTTP 结果不改变客户端安全策略。

## 3. Frontend 登录 API

### 3.1 Endpoint

```http
POST <panel-base>/api/login
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
```

表单字段：

| 字段 | 含义 | 必填 |
| --- | --- | --- |
| `user` | 管理员用户名 | 是 |
| `pass` | 管理员密码 | 是 |
| `code` | TOTP 六位验证码 | 仅开启 2FA 时 |

登录请求不是 JSON。管理员密码只用于该请求，不得写入配置、数据库或日志。

### 3.2 通用响应 envelope

源码定义所有普通 JSON 结果为：

```json
{
  "success": true,
  "msg": "",
  "obj": null
}
```

业务失败通常仍使用 HTTP 200，并通过 `success=false` 表达，因此调用方必须同时检查 HTTP 层与 envelope。

### 3.3 2FA 流程

第一次提交正确用户名和密码但不带 `code` 时，源码返回：

```json
{
  "success": false,
  "msg": "",
  "obj": {
    "twoFa": true
  }
}
```

随后在同一个 `POST api/login` 请求中补充 `code`。错误 2FA code 会记入登录失败限制；同一个成功 code 不能并发重复提交。

v1.7.1 真实实例验证：

- [x] 无 2FA 登录成功并返回 Session Cookie
- [x] 开启 2FA 后首次登录返回 `obj.twoFa=true`
- [x] 下一个 TOTP 时间窗口中的正确 code 登录成功
- [x] 错误密码和重复使用的 2FA code 返回业务失败
- [x] 登录响应为 HTTP 200、`application/json; charset=utf-8`

启用 2FA 时使用过的 TOTP 时间窗口不能立即复用于登录；进入下一个 30 秒窗口后验证成功。连续失败锁定的完整时序留给 P0-003 失败路径测试。

## 4. Session / Cookie

官方源码确认：

- Cookie session 名称为 `s-ui`。
- Session 使用服务端 Secret 签名的 Cookie store。
- Cookie Path 设为 `/`。
- 登录成功后写入用户名及凭据指纹。
- 修改用户名或密码后，旧 session 的凭据指纹失效。
- `GET <panel-base>/api/logout` 清空 session，并使用 `MaxAge=-1` 删除 Cookie。
- 配置的 session max age 大于 0 时，源码按“分钟 × 60”写入 Cookie MaxAge；否则为会话 Cookie。
- 当前源码显式设置 `Secure=false`。

v1.7.1 本地真实响应：

```http
Set-Cookie: s-ui=<redacted>; Path=/
```

实际 Header 未包含 `Secure`、`HttpOnly` 或 `SameSite`。因此 ClashXY 必须默认拒绝普通 HTTP 面板，并且绝不记录 Session Cookie value。

客户端必须使用独立 Cookie jar，不得把 session Cookie 写入普通日志。

## 5. API v2

Base path：

```text
<panel-base>/apiv2/
```

鉴权 Header：

```http
Token: <redacted>
```

源码确认 Token 为空、未知或过期时返回 envelope：

```json
{
  "success": false,
  "msg": "invalid token",
  "obj": null
}
```

主要只读 endpoint：

```text
GET apiv2/load
GET apiv2/inbounds
GET apiv2/clients
GET apiv2/status
GET apiv2/stats
GET apiv2/onlines
```

Token 管理仍走已登录的 frontend session：

```text
GET  api/tokens
POST api/addToken
POST api/deleteToken
```

`api/addToken` 使用 form 字段：

| 字段 | 语义 |
| --- | --- |
| `desc` | Token 描述 |
| `expiry` | 有效天数；`0` 表示不过期 |

新增 Token 只在创建响应中返回明文；之后的 `api/tokens` 列表会将 Token 显示为 `****`。调用方必须立即放入 Secure Storage，再清除内存中的管理员密码。

## 6. 实测计划

使用一次性测试管理员和独立 Cookie jar，按顺序捕获脱敏摘要：

```text
GET  <panel-base>/login
POST <panel-base>/api/login
POST <panel-base>/api/login + code（若需要）
GET  <panel-base>/api/tokens
POST <panel-base>/api/addToken
GET  <panel-base>/apiv2/status
POST <panel-base>/api/deleteToken
GET  <panel-base>/api/logout
```

记录要求：

- URL 只保留 scheme、host、port、Web Path。
- 密码永不落盘。
- Token 只记录首尾各四位或固定 `<redacted>`。
- Cookie value 只记录长度和属性，不记录内容。
- 响应对象中可能出现 Secret 的字段必须递归脱敏。

## 7. 探测工具与本地验证

已实现：

```text
tools/clashxy_lab/probe_2sui.ps1
tools/clashxy_lab/tests/mock-2sui-server.mjs
tools/clashxy_lab/tests/probe_2sui_test.ps1
```

CLI 入口：

```powershell
.\clashxy_lab.ps1 panel-test -BaseUrl https://panel.example.com/app/
```

安全行为：

- 默认拒绝普通 HTTP，必须显式使用 `-AllowInsecureHttp`。
- 密码、2FA code 和 API Token 使用 `SecureString` 传入。
- 不输出响应 `obj` 的值，只输出类型和字段名。
- 不输出 Cookie value，只输出名称、属性和 value 长度。
- 完成 session 探测后主动调用 logout。
- 输出文本经过输入 Secret 替换和通用 Secret 模式脱敏。

2026-08-21 本地 mock 验证结果：

```text
PASS: 2S-UI probe flow and secret redaction
PASS: plain HTTP rejected without explicit opt-in
```

Mock 覆盖登录页、无 Token 的 API v2、2FA 提示、2FA 登录、Session Cookie、Token 列表、Token Header 鉴权和 logout。该测试只证明探测工具行为正确，不能替代目标 2S-UI 实例的真实验证。

## 8. v1.7.1 真实实例结论

2026-08-21 在已校验 GitHub asset digest 的官方 Windows 临时实例上完成：

- Base path、重定向和错误 path 行为已确认。
- 无 2FA 与启用 2FA 的登录流程均已确认。
- Session Cookie 名称、Path、属性和 logout 清理已确认。
- frontend API 与 API v2 的 HTTP 200 envelope 行为已确认。
- 无 Token 的 API v2 返回 `success=false`、`msg="invalid token"`、`obj=null`。
- 所有捕获均脱敏，未把密码、TOTP Secret、code、Cookie value 或 Token 写入项目。

P0-002 验收通过；API Token 的创建、使用和删除已在 P0-004 单独完成。

## 9. P0-007 Client 创建 Schema 验证

### 9.1 保存请求

官方前端统一使用：

```http
POST <panel-base>/api/save
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
```

form 字段：

| 字段 | Client 创建值 |
| --- | --- |
| `object` | `clients` |
| `action` | `new` |
| `data` | Client JSON 字符串 |
| `initUsers` | Client 创建时为空；该字段主要供 Inbound 初始化用户使用 |

官方前端创建 payload：

| JSON 字段 | 类型 | 语义 |
| --- | --- | --- |
| `enable` | boolean | 是否启用 |
| `name` | string | Client 唯一名称；实验对象使用 `clashxy-lab-` 前缀 |
| `config` | object | 各协议的客户端凭据配置 |
| `inbounds` | number[] | 绑定的 Inbound ID |
| `links` | object[] | 外部/订阅链接；新建通常为空 |
| `volume` | integer | 字节额度，0 为不限 |
| `expiry` | integer | Unix 秒，0 为不过期 |
| `desc` | string | 描述 |
| `group` | string | 分组 |
| `limitIp` | integer | 并发 IP 限制，0 为不限 |
| `delayStart` | boolean | 是否延迟起算 |
| `autoReset` | boolean | 是否周期重置 |
| `resetDays` | integer | 重置周期天数 |
| `nextReset` | integer | 下次重置 Unix 秒，初始可为 0 |

新建页面默认 `autoReset=true`、`resetDays=30`。前端在普通保存时主动省略 `up`、`down`、`totalUp`、`totalDown`；这些计数由服务端维护，只有明确执行流量重置时才随请求发送。

Go 服务端还会返回/保存：

```text
id, up, down, totalUp, totalDown,
createdAt, onlineAt, remark
```

其中 `id` 和 `createdAt` 在创建时由服务端分配。

### 9.2 config 协议结构

官方前端 `randomConfigs(name)` 生成以下结构：

| key | 身份字段 | 凭据/选项字段 |
| --- | --- | --- |
| `mixed`、`socks`、`http` | `username` | `password` |
| `shadowsocks`、`shadowsocks16`、`shadowtls` | `name` | `password` |
| `vmess` | `name` | `uuid`、`alterId` |
| `vless` | `name` | `uuid`、`flow` |
| `anytls`、`trojan`、`hysteria2` | `name` | `password` |
| `naive` | `username` | `password` |
| `hysteria` | `name` | `auth_str` |
| `tuic` | `name` | `uuid`、`password` |

服务端 `setConfigIdentity` 会把每个配置中的 `name` 或 `username` 统一改为 Client name。正式实现仍应在发送前生成正确身份与随机凭据，不依赖服务端修正。

### 9.3 创建响应与读取

成功创建返回通用 envelope，`obj` 包含：

```text
clients
clientsSeq
```

`clients` 是安全列表投影，不含 `config` 和 `links`。需要读取完整单条 Client 时使用已登录 session：

```http
GET <panel-base>/api/clients?id=<client-id>
```

该响应的 `obj.clients[0]` 包含完整模型。调用方不得把该对象直接写入日志。

### 9.4 删除 Schema

```http
POST <panel-base>/api/save
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
```

form：

```text
object=clients
action=del
data=<JSON number: client ID>
initUsers=
```

删除的 `data` 是 JSON 数字 ID，不是 Client name，也不是对象。

### 9.5 官方 v1.7.1 安全实测

为避免官方审计表留存协议凭据，实际创建使用：

```json
{
  "config": {},
  "inbounds": [],
  "links": []
}
```

其余字段与官方前端 payload 一致。完整协议 `config` 结构由同一版本前端源码确认。

实测结果：

| 项目 | 结果 |
| --- | --- |
| `object/action/data/initUsers` form | 成功 |
| Client 创建 | 成功 |
| ID 分配 | 成功 |
| `createdAt` 分配 | 成功 |
| 保存响应 | `clients`、`clientsSeq` |
| 完整单条读取 | 字段和类型与 Go 模型一致 |
| Inbound 绑定 | 0 |
| `action=del` + JSON 数字 ID | 成功 |
| 删除后二次查询 | Client 不存在 |
| SQLite 只读复核 | 匹配 Client 0 |
| logout | 成功 |

高风险的“完整随机密码/UUID实测”在执行前被安全审查拒绝，因此没有产生 Client 或审计记录；随后采用上述无凭据方案完成验证。

### 9.6 审计与 Secret 结论

`ConfigService.Save` 会把原始 `data` 写入 `changes.obj`。因此完整 Client 创建 payload 中的 UUID、密码和认证串会进入 2S-UI 数据库审计表：

- 不得把 `api/save data` 写入 ClashXY 普通日志。
- 完整 Client 响应必须按敏感对象处理。
- 调试输出只记录字段名、类型和对象 ID。
- 删除 Client 不会删除官方 `changes` 审计记录。
- 本次安全实测只留下两条无凭据的 `clients new/del` 审计记录。

P0-007 Schema 验证通过。

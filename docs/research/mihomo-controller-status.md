# Mihomo Controller 健康检查

## 结论

P0-016 已实现顶层 CLI 命令：

~~~text
status
~~~

它对 Mihomo External Controller 执行经过 Bearer 鉴权的 GET /version，并只返回健康状态、HTTP 状态码、Meta 标志、核心版本和检查时间。

## 官方接口依据

Mihomo 官方 API 文档规定：

- External Controller 是 RESTful API；
- 配置项 secret 是 API access key；
- 常规 HTTP 请求使用 Authorization: Bearer SECRET；
- GET /version 返回 meta 与 version。

参考：

- https://wiki.metacubex.one/en/api/
- https://wiki.metacubex.one/en/config/general/

## URI 安全边界

controller_status.ps1 接受绝对 http/https URI，并拒绝：

- 非 HTTP(S) scheme；
- URI user info、query 或 fragment；
- 非根路径；
- 指向非 loopback host 的明文 HTTP。

因此 Phase 0 的默认形态是 http://127.0.0.1:PORT。远程 Controller 必须使用 HTTPS；本任务不实现证书 pin 或远程 Controller 管理。

## Secret 边界

Controller Secret 参数类型为 SecureString。CLI 未提供时使用无回显提示。脚本只在构造 Authorization header 的短暂边界转为明文，并在 finally 清空 header 引用；返回对象、错误消息和状态文件均不包含 Secret。

健康检查不从 YAML 反向解析 Secret，也不把 Secret 写入 P0-015 的进程状态文件。

## 返回结构

成功返回字段：

- SchemaVersion
- Healthy
- StatusCode
- ControllerUri
- Meta
- Version
- CheckedAtUtc

非 200 响应仅报告状态码；无效 JSON 或缺少 meta/version 会失败关闭。

## 验收证据

tests/controller_status_test.ps1 使用已校验的官方 Mihomo v1.19.30 Windows 核心执行：

~~~text
PASS: authenticated Mihomo /version health, wrong-secret rejection, loopback HTTP guard, redaction, and cleanup
~~~

覆盖：

- 正确 Secret 获得 HTTP 200 和非空版本；
- 错误 Secret 获得 HTTP 401；
- 远程明文 HTTP 在网络请求前被拒绝；
- 输出不包含 fixture UUID、正确 Secret 或错误 Secret；
- 测试实例停止并清理。

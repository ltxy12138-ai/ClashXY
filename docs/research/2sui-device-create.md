# 2S-UI 测试 Client 创建实验

> Task：P0-008
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证版本：2S-UI v1.7.1

## 1. 命令

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\tools\clashxy_lab\clashxy_lab.ps1 device create `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token `
  -DeviceName 'windows-pc' `
  -InboundIds 1,2
```

实现文件：

```text
tools/clashxy_lab/device_create.ps1
```

## 2. 行为

- 使用 `POST apiv2/save` 和 API Token，不需要再次保留管理员密码。
- 自动生成 `clashxy-lab-<device>-<8 hex>` 名称。
- 默认在内存生成官方前端同构的 14 类协议配置。
- Client 默认启用、无限额度、不过期、30 天自动重置。
- 输出只含 ID、名称、Inbound ID、创建时间和状态。
- 创建后若响应异常，会按 Client ID（或唯一名称回查 ID）尝试回滚。
- Token、UUID、密码、认证串、完整 `config` 和 `links` 均不进入输出。

`-SafeSchemaOnly` 会发送空 `config`，仅用于临时实例的无凭据 Schema/生命周期验收，不产生可连接设备。

## 3. 自动化测试

Mock 只有在完整协议配置、名称前缀、Inbound 数组和 Link 数组均符合 Schema 时才接受默认创建请求。测试确认：

- 默认模式完整 Schema 创建成功。
- 名称固定使用 `clashxy-lab-` 前缀。
- 创建后能通过 `panel clients` 查询。
- Inbound ID 保持不变。
- schema-only 模式支持空 Inbound 数组。
- 输出不含凭据字段名或值。

结果：

```text
PASS: device create schema-only mode and empty-Inbound Client query
PASS: device create prefix, full-schema request, panel visibility, and secret redaction
```

## 4. 官方 v1.7.1 实测

为避免 `changes.obj` 留存协议凭据，官方临时实例使用 `-SafeSchemaOnly`：

| 项目 | 结果 |
| --- | --- |
| Client 创建 | 成功 |
| ID | 3 |
| 名称 | `clashxy-lab-p0-008-official-7f2c98bc` |
| 前缀 | 正确 |
| Inbound 数量 | 0 |
| `panel clients` 可见 | 是 |
| 临时 Token 删除 | 成功 |
| logout | 成功 |
| Client 生命周期 | 保留至 P0-009 删除验收 |

默认完整凭据模式已由源码和 mock 验证；由于上游审计表会保留原始 payload，本任务没有在官方临时实例写入真实随机凭据。

P0-008 验收通过。

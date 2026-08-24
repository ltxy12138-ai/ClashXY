# 2S-UI 测试 Client 删除实验

> Task：P0-009
> 状态：✅ 已完成
> 验证日期：2026-08-21
> 验证版本：2S-UI v1.7.1

## 1. 命令

```powershell
$token = Read-Host 'API Token' -AsSecureString
.\tools\clashxy_lab\clashxy_lab.ps1 device delete `
  -BaseUrl https://panel.example.com/app/ `
  -ApiToken $token `
  -ClientId 123 `
  -ExpectedClientName 'clashxy-lab-windows-pc-12ab34cd'
```

实现文件：

```text
tools/clashxy_lab/device_delete.ps1
```

## 2. 安全流程

```text
GET apiv2/clients
  ↓
按 ID 找到目标
  ↓
强制校验 name 以 clashxy-lab- 开头
  ↓
可选校验 ExpectedClientName
  ↓
POST apiv2/save
  object=clients
  action=del
  data=<JSON number ID>
  ↓
再次 GET apiv2/clients
  ↓
确认 ID 不存在
```

命令不会删除缺少实验前缀的 Client，也不会按模糊名称删除。

## 3. 自动化测试

结果：

```text
PASS: device delete ID schema, prefix guard, absence verification, and redaction
```

覆盖：

- JSON 数字 ID 删除 Schema。
- 正确期望名称删除。
- 非 `clashxy-lab-` Client 拒删。
- 删除后二次查询。
- 删除两个已创建实验 Client 后，实验前缀数量为 0。
- 输出不含 API Token。

## 4. 官方 v1.7.1 实测

首次删除 P0-008 保留的 ID 3 Client 时，服务端删除成功，但二次查询暴露了空列表占位值的严格模式缺陷。数据库确认该 Client 与 Token 均已清除。修复后增加空值/缺失 `id` 防护并重跑完整回归。

随后重新执行无凭据生命周期：

| 项目 | 结果 |
| --- | --- |
| 临时 Client ID | 4 |
| 名称 | `clashxy-lab-p0-009-retry-409eb113` |
| 创建 | 成功 |
| `device delete` | 成功 |
| 命令二次查询 | 不存在 |
| 临时 Token 删除 | 成功 |
| logout | 成功 |
| SQLite：全部 Client | 0 |
| SQLite：`clashxy-lab-%` Client | 0 |
| SQLite：本次 Token | 0 |

P0-009 验收通过。

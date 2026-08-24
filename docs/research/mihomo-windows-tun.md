# Mihomo Windows TUN 验证

## 结论

P0-017 已在 Windows 管理员令牌下使用官方 Mihomo v1.19.30 完成真实 TUN 生命周期验收：

- 随机名 Meta Tunnel 网卡成功创建并变为 Up；
- Controller /configs 报告 TUN enable；
- 网卡获得隔离的 198.19.x.x/30 地址；
- auto-route 与 strict-route 均关闭；
- 测试网卡不存在默认路由或 0/1、128/1 分流全局路由；
- 停止核心后测试网卡消失；
- 既有第三方 Mihomo 网卡的 ifIndex 保持不变；
- CLI、状态和核心日志不包含 fixture secret。

## Windows 要求

- 必须以管理员权限运行；非提升令牌在测试开始前失败。
- Mihomo 内置 Wintun/Meta Tunnel 支持，不需要 Lab 另行安装驱动。
- Windows 防火墙可能影响 system/mixed stack 的实际代理流量；官方文档建议允许核心通过防火墙。
- strict-route 在 Windows 会添加防火墙规则以抑制多宿主 DNS 泄漏，也可能影响 VirtualBox 等应用，因此 Phase 0 隔离测试不启用。

官方文档：

- https://wiki.metacubex.one/en/config/inbound/tun/
- https://wiki.metacubex.one/en/config/general/

## 默认关闭策略

build_mihomo_config.ps1 的 TUN 默认关闭。只有 EnableTun 才生成 TUN 配置。

可选参数：

- TunStack：system、gvisor 或 mixed，默认 mixed；
- TunDevice：Windows 网卡名；
- TunIPv4Address：必须是 /30 的第一个可用地址；
- TunAutoRoute：默认 false；
- TunStrictRoute：默认 false，且要求 TunAutoRoute。

TunDevice 只允许字母开头以及字母、数字、连字符，最长 31 个字符。

## v1.19.30 IPv4 兼容性发现

实际测试最初与已经运行的第三方 Mihomo TUN 冲突，日志为：

~~~text
configure tun interface: set ipv4 address: The object already exists
~~~

现有网卡占用 Mihomo 默认 198.18.0.1/30。最初尝试写 tun.inet4-address，但官方 v1.19.30 源码显示：

- config.RawTun 中 Inet4Address 字段已被注释；
- parseTun 从 dns.fake-ip-range 读取地址；
- 未设置时回退到 198.18.0.1/16；
- 随后用相同起始地址派生 /30；
- listener 再把派生地址传给 sing-tun。

源码：

- https://github.com/MetaCubeX/mihomo/blob/v1.19.30/config/config.go
- https://github.com/MetaCubeX/mihomo/blob/v1.19.30/listener/sing_tun/server.go

因此 Builder 不输出会被忽略的顶层 tun.inet4-address，而是：

~~~yaml
dns:
  enable: false
  fake-ip-range: 198.19.x.1/30
tun:
  enable: true
  stack: mixed
  device: clashxy-lab-xxxxxxxx
  auto-route: false
  auto-detect-interface: true
  strict-route: false
~~~

隔离测试保持 DNS disabled；fake-ip-range 在这里仅作为 v1.19.30 顶层 TUN 地址来源。正式 DNS/TUN 配置需要在后续 ConfigManager 中统一建模。

## 运行态检查

tun_status.ps1 执行两层验证：

1. 使用 Controller Secret 调用 /version 和 /configs；
2. 使用精确设备名调用 Get-NetAdapter。

只有 Controller 报告 TUN enabled、device 匹配，并且 Windows 网卡唯一且为 Up 才返回 Healthy。Controller 可能省略 false 的布尔字段，因此缺失的 auto-route/strict-route 按 false 处理。

## 隔离地址选择

tests/tun_test.ps1 从 198.19.0.0/16 随机选择一个未被 Windows IPv4 地址或精确 /30 路由占用的网段，使用该网段第一个可用地址。测试不删除、禁用或重配任何既有网卡。

## 验收证据

~~~text
PASS: elevated Windows TUN adapter up, controller config verified, no global route, isolated device cleanup, and redaction
~~~

P0-001 至 P0-016 的 mock、进程和 Controller 回归同时通过。

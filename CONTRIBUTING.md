# Contributing to ClashXY / 参与 ClashXY

Thank you for helping improve ClashXY. Issues, documentation fixes,
translations, tests, and focused code changes are welcome.

感谢你帮助改进 ClashXY。欢迎提交问题、文档修正、翻译、测试和范围明确的代码改动。

## Security and privacy / 安全与隐私

Never put subscription URLs, proxy credentials, 2S-UI passwords or tokens,
exported YAML, private panel addresses, or unredacted logs in an issue, commit,
or pull request. Follow [SECURITY.md](SECURITY.md) for vulnerability reports.

请勿在 Issue、提交或 PR 中放入订阅 URL、代理凭据、2S-UI 密码或 Token、导出的
YAML、私有面板地址或未脱敏日志。漏洞报告请遵循 [SECURITY.md](SECURITY.md)。

## Before opening a pull request / 提交 PR 前

1. Open or reference an issue for behavior changes that need product discussion.
2. Keep each pull request focused on one change.
3. Preserve the architecture boundaries in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
4. Add or update tests for behavior changes.
5. Update both READMEs when user-facing documentation changes.

行为变更请先创建或引用 Issue；每个 PR 只解决一个主题，并遵守架构边界。功能变化
需要同步测试；面向用户的说明需要同时更新英文和中文 README。

## Local verification / 本地验证

The Windows CI reference uses Flutter `3.47.1`:

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build windows --release
```

Do not commit generated release binaries, credentials, runtime YAML, local
databases, or developer-specific paths.

不要提交生成的发布二进制、凭据、运行时 YAML、本地数据库或开发者机器专属路径。

## Localization / 本地化

Add `lib/l10n/app_<locale>.arb` with a localized `languageName` and every key
from `app_en.arb`. Run `flutter gen-l10n`, then check the new locale at normal
and narrow window sizes. Do not edit generated localization files manually.

新增语言时需要提供完整 ARB、运行 `flutter gen-l10n`，并在正常和窄窗口尺寸下检查
界面。不要手工修改生成的本地化文件。

## Pull request checklist / PR 检查清单

- The change contains no secrets or personal data.
- Analysis, tests, and the Windows Release build pass.
- New external behavior has failure handling and user-facing errors.
- Security-sensitive logs remain redacted.
- Documentation and third-party notices are updated when applicable.

By contributing, you agree that your contribution is distributed under the
project's `GPL-3.0-only` license. You retain copyright in your contribution.

提交贡献即表示你同意按项目的 `GPL-3.0-only` 许可证分发该贡献；你仍保留贡献内容
的版权。

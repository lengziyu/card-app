# Card App 协作规范

本仓库的产品、技术、合规与第一版范围约束，以
[`docs/APP_DEVELOPMENT_GUIDELINES.md`](docs/APP_DEVELOPMENT_GUIDELINES.md) 为准。

- 旧 Vue 项目只可作为视觉、内容、交互和资源参考，禁止修改。
- 核心界面使用 Flutter 原生 Widget、绘制和手势实现，不使用 WebView。
- 未经项目所有者确认，不扩展第一版范围，不接入登录、正式 API、支付、广告或推送。
- 提交改动前运行 `dart format`、`flutter analyze` 与 `flutter test`。

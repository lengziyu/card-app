# 公开发布前检查清单

此清单适用于包含 Pro 自动续订订阅与 AI 功能的商店版本。正式构建必须使用统一脚本，确保订阅开关、商品 ID、协议和隐私链接被编译进包内。

## 发布前的 App 版本配置

- 先将新 iOS / Android 包提交到对应商店渠道，确认商店链接可打开；
- 登录 `card.lengziyu.cn/admin` 的“App 版本管理”，分别填写两个平台的最新版本号、构建号和 HTTPS 商店链接；
- 只想提示升级时，不填写“最低支持版本”；需要停止旧版本访问时，再填写最低支持版本与构建号；
- 发布后在旧包打开“设置 → 版本管理”验证提示和商店跳转；不要在商店包尚未可下载前提高最低支持版本。

## 必须完成

1. 将 `android/key.properties.example` 复制为本机的 `android/key.properties`，填写 **上传密钥**信息。该文件已被 Git 忽略，禁止提交 keystore 或密码。
2. 在上线前完成 Supabase Auth、SMTP、邮箱确认、密码重置和 App 深链的基础配置，并用中国大陆及海外网络真机完成注册、验证、登录、重置、退出与删除账号。旧用户迁移不早于上线前 1–2 天，具体顺序见 `SUPABASE_AUTH.md`。
3. 在认证切换窗口的 API 部署环境设置 Supabase 生产凭据和 `SUPABASE_AUTH_ENABLED=true`，并明确设置 `FIREBASE_AUTH_ENABLED=false`、`LEGACY_PASSWORD_AUTH_ENABLED=false`；确认 `GET /api/auth/config` 同时返回 `supabaseEnabled: true`、`firebaseEnabled: false` 与 `legacyPasswordAuth: false`。
4. 将 `docs/legal/` 中的隐私政策、用户协议和账号删除说明替换真实支持邮箱后部署为公开 HTTPS 页面；复制 `config/legal.example.json` 为 `config/legal.local.json`，配置对应链接和支持邮箱，并在商店后台填写同一组信息。App 内游客可从“我的 → 设置”访问这些说明。
5. 确认 `DELETE /api/auth/account` 在生产可用。它会删除 Supabase 账号，以及本服务保存的卡包、收藏、历史、反馈和 Pro 工作区数据；旧 `card_session_*` 和 Firebase ID Token 不得再访问私有接口。应用商店订阅须由用户在商店自行取消。
6. 为 iOS 配置签名、Bundle ID、App Store Connect 条目、隐私清单及截图；为 Android 配置 Play Console 条目、Data safety、商店素材与上传密钥。
7. 在真机离线、弱网、横竖屏、深浅色、动态文字和首次安装场景完成回归测试。
8. 在 App Store Connect 的 Business 页面确认 Paid Apps Agreement 已生效，税务和收款资料无待处理项。
9. 确认月度与年度订阅位于同一订阅组，商品 ID 与 `config/pro.local.json` 完全一致，价格和本地化资料完整，并随本次 App 版本一同提交审核。
10. 用 Sandbox/TestFlight 账号在 iPhone 与 iPad 完成加载价格、购买、恢复购买、取消后的权益刷新；不得仅验证本地测试配置。
11. 在三项 AI 功能中逐一确认：勾选前不会发送数据；页面明确显示发送内容、接收方（百炼或 OpenAI）和用途；公开隐私政策与 App 内说明一致。

## 正式发布开关

- `config/pro.local.json` 中 `ENABLE_PRO_BILLING=true`；禁止用未注入该文件的 Xcode Archive 提交。
- 服务端在商店沙盒验单通过后设置 `PRO_API_ENABLED=true`，并确认 `/api/pro/config` 返回 iOS 商店可用及两个正确商品 ID。
- 未实现的 Google / Apple 第三方登录入口不展示。
- 未完成真实商店验单和隐私流程时不得提交 Pro 版本。

## 本地发布校验

```bash
dart format lib test
flutter analyze
flutter test
tools/build_store_release.sh --check
tools/build_store_release.sh ipa
tools/build_store_release.sh appbundle
```

Android release signing 未配置时构建会明确失败，避免用 debug key 误发布。
不要从 Xcode 直接重新 Archive 一个没有 Dart defines 的包；上传前以脚本产物为准，并核对构建号已递增。

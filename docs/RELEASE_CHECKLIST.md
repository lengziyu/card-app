# 公开发布前检查清单

此清单适用于当前 Flutter App 的免费公开版本。Pro 订阅和账单 AI 仍保持关闭，不能随本次发布一并开放。

## 必须完成

1. 将 `android/key.properties.example` 复制为本机的 `android/key.properties`，填写 **上传密钥**信息。该文件已被 Git 忽略，禁止提交 keystore 或密码。
2. 创建 Supabase Auth 项目，配置 SMTP、邮箱确认、密码重置和 App 深链，并用中国大陆及海外网络真机完成注册、验证、登录、重置、退出与删除账号。
3. 在 API 部署环境设置 Supabase 生产凭据和 `SUPABASE_AUTH_ENABLED=true`；确认 `GET /api/auth/config` 返回 `supabaseEnabled: true`。
4. 部署一个公开可访问的隐私政策、用户协议、联系邮箱和账号删除说明；在商店后台填写对应链接。
5. 确认 `DELETE /api/auth/account` 在生产可用。它会删除 Supabase 账号，以及本服务保存的卡包、收藏、历史、反馈和 Pro 工作区数据。应用商店订阅须由用户在商店自行取消。
6. 为 iOS 配置签名、Bundle ID、App Store Connect 条目、隐私清单及截图；为 Android 配置 Play Console 条目、Data safety、商店素材与上传密钥。
7. 在真机离线、弱网、横竖屏、深浅色、动态文字和首次安装场景完成回归测试。

## 必须保持关闭

- `ENABLE_PRO_BILLING=false`
- `PRO_API_ENABLED=false`
- 未实现的 Google / Apple 第三方登录入口不展示。
- 未接入真实商店验单、通知和隐私流程前，不宣传 Pro、订阅、账单识别或实时提醒可用。

## 本地发布校验

```bash
dart format lib test
flutter analyze
flutter test
flutter build appbundle --release
flutter build ipa --release
```

Android release signing 未配置时构建会明确失败，避免用 debug key 误发布。

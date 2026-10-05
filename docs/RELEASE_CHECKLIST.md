# 公开发布前检查清单

此清单适用于包含 Pro 自动续订订阅、可选永久 Pro 与 AI 功能的商店版本。正式构建必须使用统一脚本，确保购买开关、商品 ID、协议和隐私链接被编译进包内。

## 发布前的 App 版本配置

- 先将新 iOS / Android 包提交到对应商店渠道，确认商店链接可打开；
- 登录 `card.lengziyu.cn/admin` 的“App 版本管理”，分别填写两个平台的最新版本号、构建号和 HTTPS 商店链接；默认保持“强制更新”关闭；
- 只想提示升级时，不填写“最低支持版本”；需要停止旧版本访问时，再填写最低支持版本与构建号；
- 发布后在旧包验证启动可选更新、“设置 → 版本管理”和商店跳转；只有商店包已确认可下载且确有阻断旧版的必要时，才开启强更并设置最低支持版本。详见 `APP_VERSION_UPDATES.md`。

## 必须完成

### 认证阶段记录（2026-08-26）

- 已将生产 Supabase Email OTP 固定为 6 位，并完成自定义模板、实际邮件送达、现有
  Supabase 邮箱账号登录及原卡包/收藏保持验证；旧密码能力、Firebase 和既有会话未关闭。
- 仍需在中国大陆及海外网络分别完成重发、会话恢复、退出和账号删除回归；这些未完成项
  不因本次基础登录通过而视为验收完成。
- 新版默认使用邮箱 OTP，但保留已有账号密码登录和忘记密码，不提供新的密码注册入口。
  发布前须使用 `SUPABASE_AUTH.md` 中按 RedirectTo 分支的 Password Reset 兼容模板，并将
  普通回调和 `mode=password-recovery-otp` 回调都加入 Redirect URLs。在 iOS、Android 真机
  完成六位重置码、重发、设置新密码、取消恢复临时会话及新密码重新登录回归；同时使用旧包
  确认原密码重置链接仍可打开，审核兼容期不得删除模板的旧版本分支。

1. 将 `android/key.properties.example` 复制为本机的 `android/key.properties`，填写 **上传密钥**信息。该文件已被 Git 忽略，禁止提交 keystore 或密码。
2. 在上线前完成 Supabase Auth、自定义 SMTP、邮箱 OTP 模板与限流，并用中国大陆及海外网络真机完成获取验证码、校验、重发、会话恢复、退出与删除账号。确认现有 Supabase 邮箱用户通过 OTP 登录后 `user.id`、卡包、收藏和 Pro 权益不变。旧用户迁移不早于上线前 1–2 天，具体顺序见 `SUPABASE_AUTH.md`。
3. 在 API 部署环境设置 Supabase 生产凭据和 `SUPABASE_AUTH_ENABLED=true`。审核期与首个公开无密码版本必须继续保持 `FIREBASE_AUTH_ENABLED=true`、`LEGACY_PASSWORD_AUTH_ENABLED=true`；确认 `GET /api/auth/config` 同时返回三个开关均为 `true`。关闭旧认证必须另行获得项目所有者确认。
4. 将 `docs/legal/` 中的隐私政策、用户协议和账号删除说明替换真实支持邮箱后部署为公开 HTTPS 页面；复制 `config/legal.example.json` 为 `config/legal.local.json`，配置对应链接和支持邮箱，并在商店后台填写同一组信息。App 内游客可从“我的 → 设置”访问这些说明。
5. 确认 `DELETE /api/auth/account` 在生产可用。它会删除当前身份提供方账号，以及本服务保存的卡包、收藏、浏览历史、历史账单、反馈和 Pro 工作区数据；审核兼容期内其他用户的旧 `card_session_*` 与 Firebase ID Token 必须继续按原规则工作。应用商店订阅须由用户在商店自行取消。
6. 为 iOS 配置签名、Bundle ID、App Store Connect 条目、隐私清单及截图；为 Android 配置 Play Console 条目、Data safety、商店素材与上传密钥。
7. 在真机离线、弱网、横竖屏、深浅色、动态文字和首次安装场景完成回归测试。
8. 在 App Store Connect 的 Business 页面确认 Paid Apps Agreement 已生效，税务和收款资料无待处理项。
9. 确认月度与年度订阅位于同一订阅组。仅当永久 Pro 已完成 Apple Non-Consumable、Google one-time product、双端验单及恢复/退款真机矩阵后，才同时开启服务端 `PRO_LIFETIME_ENABLED` 与新构建 `ENABLE_PRO_LIFETIME`。开启后新客户端必须同时展示月付、年付和永久 Pro；旧月付/年付商品及验单映射不得删除。
10. 用 Sandbox/TestFlight 账号在 iPhone 与 iPad 完成加载价格、购买、恢复购买、取消后的权益刷新；不得仅验证本地测试配置。
11. 在三项 AI 功能中逐一确认：勾选前不会发送数据；页面明确显示发送内容、接收方阿里云百炼和用途；公开隐私政策与 App 内说明一致。
12. 历史账单采用客户端与服务端双重开关；启用前完成专项隐私、账号删除、iOS/Android 真机和审核说明回归，并确认 App 构建的 `ENABLE_BILL_HISTORY` 与服务端 `PRO_BILL_HISTORY_ENABLED` 配置一致。
13. 左边缘滑动返回完成 iOS/Android 真机回归前保持 `ENABLE_EDGE_SWIPE_BACK=false`；重点验证系统手势导航、卡片画布、多指缩放、图片翻页、横向列表、登录取消和嵌套页面返回层级。
14. 小票打印结果完成真机回归前保持 `ENABLE_BILL_RECEIPT_PRINTER=false`；验证真实等待、成功后出纸、失败不出纸、减少动态效果、320px 窄屏、130% 大字体和长字段换行。
15. 如开放卡片评论，确认服务端“开启评论审核”已打开，新评论只进入 `pending`；验证基础过滤、举报后立即隐藏、屏蔽作者、取消屏蔽、作者删除、支持邮箱和后台举报处理。审核关闭时商店客户端必须隐藏发布入口。

## 正式发布开关

- `config/pro.local.json` 中 `ENABLE_PRO_BILLING=true`；禁止用未注入该文件的 Xcode Archive 提交。
- 服务端在商店沙盒验单通过后设置 `PRO_API_ENABLED=true`，并确认 `/api/pro/config` 返回 iOS 商店可用及两个正确商品 ID。
- Google OAuth Client、品牌审核和双端真机测试完成前保持 `ENABLE_GOOGLE_AUTH=false`。
- Apple Provider、entitlement、Manual Identity Linking、authorization code 登记与删除时 Token Revocation 全部完成前保持 `ENABLE_APPLE_AUTH=false`。
- 双端边缘手势专项回归完成前保持 `ENABLE_EDGE_SWIPE_BACK=false`。
- 小票打印结果专项回归完成前保持 `ENABLE_BILL_RECEIPT_PRINTER=false`。
- 审核通过和首个正式版本发布时不提高最低支持版本，不强制旧客户端升级。
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

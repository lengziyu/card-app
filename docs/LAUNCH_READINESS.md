# 上线准备清单

更新时间：2026-08-26

## 已可验证

- `dart format` 与 `flutter analyze` 通过；iOS 可在禁用代码签名时构建 `Runner.app`。
- 发布质量门仍未完成：完整 Flutter 测试需保持全绿；Android Release 需要配置上传密钥后才能构建 AAB，不能使用测试或 debug 签名发布。
- 游客不创建个人卡包、收藏、历史或提交记录；已验证 Supabase 账号的卡片状态、收藏、历史与提交记录通过 HTTPS 接口同步，本机仅作为离线缓存。
- 生产 Supabase 已切换为 6 位 Email OTP 模板；现有 Supabase 邮箱账号已完成实际邮件登录并保持原卡包与收藏。旧密码、Firebase 与既有会话继续保留。
- 公开内容的推送采用“发布 → 待确认 → 人工发送 → 结果留存”流程。
- 邀请码与邀请链接由服务端脱敏，默认不公开；管理端可按文章/卡片分别开启。
- 公开邀请字段仅用于经人工确认的非商业信息；不得包含 Affiliate、CPA、返佣、推广追踪或隐藏跳转。
- Pro 客户端购买、恢复、服务端预检、Apple/Google 验单和权益门控已实现；缺少正式账号或商店密钥时默认关闭，不会发起扣款。
- Pro 端已实现聚焦/钱包模式、2–4 卡对比、费用情景估算与导出、长周期数据、规则关注、离线公开资料和工作区；云同步接口只保存关注项与对比方案。

## 发布前必须由运营完成

1. 如本次开放推送，在部署环境填写 FCM 服务账号变量，并在 Firebase 上传 iOS APNs 密钥、配置 iOS `GoogleService-Info.plist` 与 Android `google-services.json`；如不开放，则隐藏通知开关和相关承诺。详见 `PUSH_NOTIFICATIONS_SETUP.md`。
2. App 内隐私政策、用户协议、联系支持和账号删除说明入口已补齐；将 `docs/legal/` 文案替换真实支持邮箱后部署为公开 HTTPS 页面，并通过 `config/legal.local.json` 把地址和邮箱注入正式包。
3. Flutter Supabase 邮箱 OTP、iOS Apple、双端 Google、显式身份绑定、退出和账号删除客户端代码已实现；Google/Apple 默认关闭，待外部 Provider、Apple Token Revocation 服务端闭环和真机回归完成后才可开启。旧版密码能力和既有会话在兼容窗口内保留，旧 H5 用户迁移及 Firebase/旧密码认证关闭另行安排。详见 `SUPABASE_AUTH.md` 与 `RELEASE_CHECKLIST.md`。
4. 用真实 iPhone 与一台中低端 Android 验证大字体、减少动态效果、深浅主题、冷启动、网络失败与推送点击跳转；当前已检测到 iPhone，Android 真机仍待接入。
5. 提供商店需要的最终图标、启动图、截图、隐私问卷、年龄分级、支持网址和审核说明。
6. 如开放 Pro，按 `PRO_MVP.md` 和服务端 `docs/PRO_SUBSCRIPTIONS.md` 注入正式账号与商店密钥，配置 `PRO_TERMS_URL`、`PRO_PRIVACY_URL`，完成商店通知、会员协议和沙盒真机测试；未完成前同时保持 `ENABLE_PRO_BILLING=false` 与 `PRO_API_ENABLED=false`。
7. 上线“规则变更提醒”前必须部署规则差异检测任务，并用正式账号映射关注项、通过已配置的推送服务定向发送；当前只可宣称“规则关注”，不能宣称实时提醒已上线。

## 发布操作顺序

1. 部署服务端和管理端；先确认 `/api/health`、内容展示设置和推送中心可访问。
2. 在管理端的“内容展示”逐项开启已审核的文章或卡片邀请字段。
3. 用测试设备订阅通知，发布一条测试文章，确认它先进入“待人工确认”，再手动发送。
4. 先走 TestFlight / Android 内测，再提交正式商店审核。

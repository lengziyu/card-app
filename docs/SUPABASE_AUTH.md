# Supabase Auth 接入

更新时间：2026-08-26
状态：Flutter、Node 与大陆网络反向代理已接入。认证基础设施和真机回归现在开始准备；旧 H5
用户迁移与旧认证关闭安排在正式上线前 1–2 天执行，不能提前切换生产流量。

## 1. 目标架构

使用 Supabase 官方托管项目保存统一账号库；生产客户端通过腾讯云现有域名代理
Auth 请求，避免中国大陆网络直接访问 Supabase 不稳定：

```text
Flutter
  └─ https://card.lengziyu.cn/supabase/auth/v1
      └─ Nginx 固定上游代理
          └─ https://<project-ref>.supabase.co/auth/v1
              └─ Supabase Auth + PostgreSQL
                  └─ Supabase access token
                      └─ https://card.lengziyu.cn/api
```

Node 服务端仍直接访问 Supabase 官方项目地址进行令牌校验和账号删除，客户端代理
与服务端上游必须分别配置，避免形成代理回环。不要为国内和海外建立两套用户库。

Firebase Authentication 只在迁移期保留。FCM 推送是独立功能，不参与账号登录；停用 Firebase
Auth 时不得一并撤销仍供 FCM 使用的服务账号，除非推送已迁移到独立凭据。

## 2. Flutter 构建配置

复制 `config/supabase.example.json` 为不提交 Git 的
`config/supabase.local.json`：

```json
{
  "ENABLE_SUPABASE_AUTH": true,
  "SUPABASE_URL": "https://card.lengziyu.cn/supabase",
  "SUPABASE_PUBLISHABLE_KEY": "客户端 publishable key",
  "SUPABASE_EMAIL_REDIRECT_URL": "cn.lengziyu.cardapp://auth-callback",
  "ENABLE_GOOGLE_AUTH": false,
  "GOOGLE_WEB_CLIENT_ID": "",
  "GOOGLE_IOS_CLIENT_ID": "",
  "ENABLE_APPLE_AUTH": false,
  "AUTH_ACCOUNT_PATH": "/api/auth/account",
  "AUTH_APPLE_CREDENTIAL_PATH": "/api/auth/apple-credential"
}
```

运行：

```bash
flutter run --dart-define-from-file=config/supabase.local.json
```

Publishable key 可以进入客户端；`service_role` key 只能进入服务端 Secret。
Supabase 会话由 `flutter_secure_storage` 保存到 iOS Keychain / Android
Keystore，不进入 SharedPreferences、日志或构建产物中的明文配置。

新版 Flutter 默认使用邮箱 OTP，并继续为已有 Supabase 密码账号保留“使用密码登录”和
“忘记密码”入口；不提供新的密码注册入口。兼容窗口内不要关闭 Supabase Email Provider
或清除旧用户密码摘要，已发布旧客户端和既有会话必须继续可用。新客户端通过相同邮箱 OTP
登录后仍取得原 Supabase `user.id`，不得复制账号或迁移业务数据。

## 3. Supabase Auth 配置

- 开启 Email Provider 与 Email OTP；
- 将 Magic Link 邮件模板改为展示 `{{ .Token }}`，不要包含可直接登录的
  `{{ .ConfirmationURL }}`；
- Password Reset / Reset Password 使用兼容模板：当前 Flutter 通过专用 RedirectTo 标记
  取得 `{{ .Token }}` 六位验证码，已发布旧客户端继续取得原 `{{ .ConfirmationURL }}`。
  新客户端用 `verifyOTP(type: recovery)` 建立临时恢复会话，再展示两次新密码输入并更新密码；
  普通已登录会话不得当作密码恢复授权，取消恢复时必须退出临时会话。兼容模板如下：

```html
{{ if eq .RedirectTo "cn.lengziyu.cardapp://auth-callback?mode=password-recovery-otp" }}
<h2>CardFi 密码重置验证码 / Password reset code</h2>
<p>请输入以下 6 位验证码继续重置密码：</p>
<h1 style="letter-spacing: 0.28em;">{{ .Token }}</h1>
<p>Enter the 6-digit code above to continue resetting your password.</p>
<p>验证码仅可使用一次，请勿转发给他人。</p>
{{ else }}
<h2>重置密码 / Reset password</h2>
<p><a href="{{ .ConfirmationURL }}">打开 CardFi 重置密码 / Open CardFi to reset password</a></p>
{{ end }}
```
- 生产项目 `mailer_otp_length` 固定为 6，客户端输入与提示保持 6 位；Supabase 虽支持
  6–10 位，但不得单独调整服务端长度而不同步客户端。审核兼容期不调整现有有效期，因为
  它同时影响注册确认、密码重置、邮箱变更和邀请邮件；同一邮箱保持至少 60 秒内不可重发；
- 使用自定义 SMTP，并配置项目级发送、OTP 和校验限流；
- Site URL 使用 `https://card.lengziyu.cn`；
- Redirect URLs 同时加入 `cn.lengziyu.cardapp://auth-callback` 和
  `cn.lengziyu.cardapp://auth-callback?mode=password-recovery-otp`；
- 配置中文和英文 OTP 邮件模板；
- 生产环境启用 HTTPS，不允许客户端跳过证书校验。

### 3.1 Google

- 在 Google Cloud 分别创建 Web、iOS、Android OAuth Client；
- Web Client ID 配入 Supabase Google Provider，并作为 `GOOGLE_WEB_CLIENT_ID` 注入客户端；
- iOS Client ID 作为 `GOOGLE_IOS_CLIENT_ID` 注入客户端，Android Client 必须使用
  `cn.lengziyu.cardapp` 与正式签名 SHA 指纹；
- iOS 复制 `ios/Flutter/Auth.xcconfig.example` 为不提交 Git 的
  `ios/Flutter/Auth.local.xcconfig`，填写该 iOS Client 的 `REVERSED_CLIENT_ID`；
- 重新下载 Android `google-services.json`，确认其中包含正式签名对应的 OAuth Client；
- 按当前 Supabase Flutter 原生 Google 登录要求配置 nonce 校验选项；
- 完成 OAuth 品牌页、隐私政策域名和测试/生产发布状态；
- 配置全部完成前保持 `ENABLE_GOOGLE_AUTH=false`。

### 3.2 Apple

- Apple Developer App ID `cn.lengziyu.cardapp` 开启 Sign in with Apple capability；
- Supabase Apple Provider 加入该 Bundle ID；
- iOS 使用原生 Authentication Services，不在第一阶段向 Android 展示 Apple 登录；
- 打开 Supabase Manual Identity Linking，使老用户可先用邮箱 OTP 登录，再显式绑定 Apple；
- Apple 一次性 authorization code 必须发送至受保护的
  `POST /api/auth/apple-credential`，由服务端向 Apple 换取并加密保存撤销所需 Token；
- `DELETE /api/auth/account` 删除 Apple 用户前必须调用 Apple Token Revocation，成功或按受控
  降级流程处理后再删除本地身份和业务数据；
- 上述服务端闭环和真机测试完成前保持 `ENABLE_APPLE_AUTH=false`。

## 4. Node 环境变量

```env
SUPABASE_AUTH_ENABLED=true
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_AUTH_TIMEOUT_MS=8000
SUPABASE_PURCHASE_LINK_SECRET=
APPLE_TEAM_ID=
APPLE_KEY_ID=
APPLE_CLIENT_ID=cn.lengziyu.cardapp
APPLE_PRIVATE_KEY=
APPLE_AUTH_ENABLED=false
# 使用 openssl rand -base64 32 生成，只放服务端 Secret。
APPLE_TOKEN_ENCRYPTION_KEY=
APPLE_AUTH_TIMEOUT_MS=8000

# 审核期与首个正式无密码版本继续保留；关闭需另行确认。
FIREBASE_AUTH_ENABLED=true
LEGACY_PASSWORD_AUTH_ENABLED=true
```

中国大陆网络环境下，生产客户端可以把 `SUPABASE_URL` 设置为经过自有
HTTPS 域名反向代理的地址，例如 `https://card.lengziyu.cn/supabase`。
代理只转发 `/supabase/auth/v1/`，服务端令牌校验仍应使用 Supabase 官方
项目地址，避免代理回环。`service_role` 密钥不得放入客户端或 Nginx 配置。

购买关联密钥应独立生成：

```bash
openssl rand -base64 48
```

服务端通过 Supabase Auth `/auth/v1/user` 校验 Token 和邮箱确认状态；删除账号
通过仅服务端持有的 `service_role` key 调用 Admin API。客户端永远不得获得该密钥。

`POST /api/auth/apple-credential` 只接受已验证的 Supabase Bearer Token 和一次性 Apple
authorization code，不接受客户端提供用户 ID。服务端必须校验 code、App ID 与 Apple `sub`
和当前 Supabase Apple identity 一致，再加密保存 refresh/access token。日志不得记录 code、
Apple Token、Supabase Token 或完整邮箱。

`POST /api/auth/client-context` 是新版客户端的可选、非阻断上报接口，只记录 `ios` / `android`
平台、登录方式和 App 版本，不接收设备硬件唯一标识。注册平台仅在 Supabase 身份确认为两小时内
新建且客户端刚完成显式登录时写入一次；最近平台可随以后登录更新。历史用户缺少该字段时显示
“未知/旧版本”，不得按邮箱、商店订阅或最近设备猜测回填注册平台。

## 5. 两阶段上线顺序

### 阶段 A：现在开始至上线前 2 天

1. 创建 Supabase 官方托管项目，配置 SMTP、邮件模板、回调地址、限流和 HTTPS
   反向代理；记录 Project URL、publishable key 与仅服务端可见的 `service_role` key。
2. 部署 Node Supabase 环境变量并确认 `/api/auth/config` 返回
   `supabaseEnabled: true`。此阶段可暂时保留旧 H5 认证，**不得**把这视为认证收口完成。
3. 使用 Supabase 构建参数运行 Flutter；在中国大陆移动网络和海外网络分别验证邮箱 OTP
   注册/登录、重发、Token 刷新、退出、账号删除和邮件送达；同时在 iOS、Android 真机验证
   新版已有账号密码登录、忘记密码六位验证码、验证码重发、两次新密码校验、更新后重新登录，
   以及旧客户端的密码登录、旧密码重置链接与注册确认链接。
4. 验证收藏、卡包、历史、反馈、Pro 和账单接口按 Supabase 用户 ID 隔离；删除账号
   必须同时删除 Supabase 身份和本服务数据。
5. 盘点旧 H5 的活跃用户、旧会话和 Firebase 用户；审核期和首个正式版本只统计并保留，
   不关闭、不强制迁移，也不得仅按相同邮箱自动合并账号。

### 阶段 B：审核期与首个正式版本兼容窗口

1. 备份旧用户与会话数据；只保留受控、加密且有保留期限的备份，不把旧密码摘要导入 Supabase。
2. 在 API 部署环境继续设置 `FIREBASE_AUTH_ENABLED=true` 与
   `LEGACY_PASSWORD_AUTH_ENABLED=true`，旧 `/api/auth/login`、`/api/auth/register`、
   Firebase ID Token 和既有 `card_session_*` 保持原行为。
3. 先部署兼容的 `/api/auth/client-context`，再提交包含平台上报的新客户端；旧客户端不传字段时
   所有认证接口和用户数据保持原样。客户端遇到 404、网络超时或服务端错误时不得让登录失败。
4. 确认 `/api/auth/config` 精确返回 `supabaseEnabled: true`、
   `firebaseEnabled: true`、`legacyPasswordAuth: true`；运行后端
   `npm run audit:auth-providers`，只记录各认证来源及有业务数据用户的数量，不导出邮箱或 Token。
5. 用专用测试账号重新执行两地真机回归，特别检查 `GET`/`DELETE /api/auth/account`、
   重装后的会话恢复和账号删除后的重新注册。
6. 审核期间不提高最低支持版本；首个公开版本使用分阶段发布并观察 OTP 成功率、稳定
   `user.id`、卡包、收藏和 Pro 权益。发现异常时暂停分阶段发布，不关闭旧入口。
7. Firebase Auth 与旧密码入口的关闭移到后续独立版本，必须在存量账号迁移完成并再次获得
   项目所有者确认后执行；FCM 凭据不得随 Firebase Auth 一并误删。

## 6. 托管方式切换

官方托管方案由 Supabase 维护基础设施，但项目仍需负责 SMTP、回调白名单、限流、
日志脱敏和账号数据合规。若以后改为自托管，还要自行负责系统更新、PostgreSQL
备份与恢复演练、TLS 证书、监控告警和安全补丁。

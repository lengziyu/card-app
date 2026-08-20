# Supabase Auth 接入

更新时间：2026-07-23
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
  "AUTH_ACCOUNT_PATH": "/api/auth/account"
}
```

运行：

```bash
flutter run --dart-define-from-file=config/supabase.local.json
```

Publishable key 可以进入客户端；`service_role` key 只能进入服务端 Secret。
Supabase 会话由 `flutter_secure_storage` 保存到 iOS Keychain / Android
Keystore，不进入 SharedPreferences、日志或构建产物中的明文配置。

## 3. Supabase Auth 配置

- 开启 Email + Password；
- 开启 Confirm email；
- Site URL 使用 `https://card.lengziyu.cn`；
- Redirect URLs 加入 `cn.lengziyu.cardapp://auth-callback`；
- 配置 SMTP、中文和英文验证邮件及密码重置模板；
- 设置注册、登录、重发邮件和密码重置限流；
- 生产环境启用 HTTPS，不允许客户端跳过证书校验。

## 4. Node 环境变量

```env
SUPABASE_AUTH_ENABLED=true
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_AUTH_TIMEOUT_MS=8000
SUPABASE_PURCHASE_LINK_SECRET=

# 旧 H5 用户迁移完成后才关闭；上线前 1–2 天的切换窗口必须显式设为 false。
FIREBASE_AUTH_ENABLED=false
LEGACY_PASSWORD_AUTH_ENABLED=false
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

## 5. 两阶段上线顺序

### 阶段 A：现在开始至上线前 2 天

1. 创建 Supabase 官方托管项目，配置 SMTP、邮件模板、回调地址、限流和 HTTPS
   反向代理；记录 Project URL、publishable key 与仅服务端可见的 `service_role` key。
2. 部署 Node Supabase 环境变量并确认 `/api/auth/config` 返回
   `supabaseEnabled: true`。此阶段可暂时保留旧 H5 认证，**不得**把这视为认证收口完成。
3. 使用 Supabase 构建参数运行 Flutter；在中国大陆移动网络和海外网络分别验证注册、
   邮件确认、登录、重置密码、Token 刷新、退出、账号删除和邮件送达。
4. 验证收藏、卡包、历史、反馈、Pro 和账单接口按 Supabase 用户 ID 隔离；删除账号
   必须同时删除 Supabase 身份和本服务数据。
5. 盘点旧 H5 的活跃用户、旧会话和 Firebase 用户，并由项目所有者选择迁移方案：
   迁移 H5 到同一 Supabase 项目、发送密码重置迁移通知，或下线 H5 登录入口。不得按
   相同邮箱自动合并账号。

### 阶段 B：正式上线前 1–2 天的认证切换窗口

1. 冻结旧账号入口和迁移名单，备份旧用户与会话数据；只保留受控、加密且有保留期限的
   备份，不把旧密码摘要导入 Supabase。
2. 在 API 部署环境明确设置 `FIREBASE_AUTH_ENABLED=false` 与
   `LEGACY_PASSWORD_AUTH_ENABLED=false`，并使旧 `/api/auth/login` 与
   `/api/auth/register` 返回 `410 LEGACY_AUTH_DISABLED`。
3. 确认 `/api/auth/config` 精确返回 `supabaseEnabled: true`、
   `firebaseEnabled: false`、`legacyPasswordAuth: false`；无效 Firebase ID Token、旧
   `card_session_*` 与旧登录接口均不得访问任何私有数据。
4. 用专用测试账号重新执行两地真机回归，特别检查 `GET`/`DELETE /api/auth/account`、
   重装后的会话恢复和账号删除后的重新注册。
5. 确认稳定后，移除 Firebase Auth 的部署密钥和旧密码登录入口。若 FCM 推送仍依赖同一
   Google 服务账号，先拆分凭据或确认推送影响，不能直接撤销该账号。
6. 更新隐私政策、账号删除说明和应用商店隐私披露；如切换失败，恢复到已备份的旧入口
   只能作为短时应急措施，必须记录原因和新的关闭时间。

## 6. 托管方式切换

官方托管方案由 Supabase 维护基础设施，但项目仍需负责 SMTP、回调白名单、限流、
日志脱敏和账号数据合规。若以后改为自托管，还要自行负责系统更新、PostgreSQL
备份与恢复演练、TLS 证书、监控告警和安全补丁。

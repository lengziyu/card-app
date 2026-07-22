# Firebase 账号系统接入（迁移兼容）

更新时间：2026-07-21  
状态：2026-07-22 起不再作为生产主认证；仅用于 Supabase 迁移兼容

## 1. 已实现范围

- Flutter 邮箱注册与登录；
- 注册后发送邮箱验证邮件；
- 未验证邮箱不能向自有 API 提供 Bearer Token，也不能使用账号同步或 Pro 私有接口；
- 重发验证邮件、刷新验证状态和密码重置；
- 登录态恢复与退出登录；
- Node 使用 Firebase Admin SDK 校验 ID Token，并可检查撤销状态；
- 第一次访问自有 API 时，用 Firebase UID 建立不含密码摘要的本地账号资料；
- 为 App Store / Google Play 订阅生成稳定、不可逆的 UUID 购买关联 ID；
- Flutter 从 `/api/auth/account` 获取该 UUID，不在客户端推导；
- 缺少客户端或服务端 Firebase 配置时安全关闭，不回退到旧 SHA-256 登录。

本阶段没有开放 Google、Apple 登录，也没有自动迁移旧账号。

## 2. 架构

```text
Flutter
  ├─ Firebase Authentication：注册、登录、验证、重置、刷新 Token
  └─ Authorization: Bearer <Firebase ID Token>
      └─ card.lengziyu.cn
          ├─ Firebase Admin：验签、有效期、撤销状态、邮箱验证
          ├─ Firebase UID：收藏、历史、反馈和同步的数据归属
          └─ HMAC(Firebase UID)：稳定 Pro 购买 UUID
```

Flutter 不调用旧 `/api/auth/register` 和 `/api/auth/login`，也不保存用户密码。Firebase 原生 SDK 负责移动端登录状态；App 自己不得把 ID Token 写入 SharedPreferences、日志或构建参数。

## 3. Firebase Console 配置

1. 创建或选择 Firebase 项目；
2. 添加 iOS App，Bundle ID 使用 `cn.lengziyu.cardapp`；
3. 添加 Android App，Application ID 使用 `cn.lengziyu.cardapp`；
4. Authentication → Sign-in method 中开启 Email/Password；
5. 配置验证邮件和密码重置邮件的发件人、域名、中文模板和回跳地址；
6. 在 Authentication → Settings 中检查授权域名；
7. 创建仅供服务端使用的 Service Account，禁止把 JSON 放入 Flutter 或 Git。

## 4. Flutter 构建配置

复制 `config/firebase.example.json` 为 `config/firebase.local.json`。客户端 Firebase 配置用于标识项目，不是服务账号私钥，但仍通过本地构建文件管理：

```json
{
  "ENABLE_FIREBASE_AUTH": true,
  "FIREBASE_API_KEY": "public-client-api-key",
  "FIREBASE_APP_ID": "platform-app-id",
  "FIREBASE_PROJECT_ID": "firebase-project-id",
  "FIREBASE_MESSAGING_SENDER_ID": "sender-id",
  "FIREBASE_AUTH_DOMAIN": "project.firebaseapp.com",
  "FIREBASE_STORAGE_BUCKET": "project.firebasestorage.app",
  "FIREBASE_IOS_BUNDLE_ID": "cn.lengziyu.cardapp",
  "AUTH_ACCOUNT_PATH": "/api/auth/account"
}
```

运行：

```bash
flutter run --dart-define-from-file=config/firebase.local.json
```

Firebase 为 iOS 与 Android 分配不同的 `FIREBASE_APP_ID`，两端参数不一致时应分别建立
`config/firebase.ios.local.json` 与 `config/firebase.android.local.json`，运行或打包时传入对应文件；
不要把 iOS App ID 用在 Android 构建中，反之亦然。

如果配置不完整，登录页会显示“Firebase 登录尚未配置”，不会提交密码。

## 5. Node 部署配置

把 `.env.auth.example` 中的值放入部署平台 Secret，不提交真实值：

```env
FIREBASE_AUTH_ENABLED=true
FIREBASE_PROJECT_ID=firebase-project-id
FIREBASE_USE_ADC=true
FIREBASE_SERVICE_ACCOUNT_JSON=
FIREBASE_PURCHASE_LINK_SECRET=<至少 32 字节的独立随机密钥>
LEGACY_PASSWORD_AUTH_ENABLED=false
```

两种服务端凭据方式二选一：

- 推荐在 Google 托管环境使用 Application Default Credentials，并设置 `FIREBASE_USE_ADC=true`；
- 其他环境通过 Secret 注入单行 `FIREBASE_SERVICE_ACCOUNT_JSON`。

购买关联密钥可生成：

```bash
openssl rand -base64 48
```

它不能与 `PRO_DATA_ENCRYPTION_KEY`、OpenAI Key 或 Firebase Service Account 共用。

## 6. 新接口

### `GET /api/auth/config`

公开返回 Firebase 邮箱登录和旧密码登录是否启用，不包含任何密钥。

### `GET /api/auth/account`

要求 Firebase Bearer Token。服务端校验邮箱已验证后返回最小账号资料和 `purchaseApplicationUserName`，供 StoreKit/Google Play 订阅绑定。

已有收藏、文章状态、反馈、Pro 权益、Pro 工作区和账单分析接口可以直接接受经过验证的 Firebase ID Token；旧 H5 Token 只在 `LEGACY_PASSWORD_AUTH_ENABLED=true` 时继续有效。

## 7. 上线顺序

1. 在测试 Firebase 项目开启 Email/Password；
2. 配置客户端公开参数和服务端 Service Account；
3. 保持 `LEGACY_PASSWORD_AUTH_ENABLED=true`，完成 Flutter 注册、验证、登录、重置、退出和私有 API 测试；
4. 备份旧用户与会话数据；
5. 决定旧账号迁移方式；
6. H5 也迁移 Firebase 后，设置 `LEGACY_PASSWORD_AUTH_ENABLED=false`；
7. 删除所有旧会话文件和旧密码登录入口；
8. 单独升级管理员认证，移除源码 Seed 密码；
9. 最后开放 Google 与 Apple 登录。

## 8. 旧账号迁移

- 没有正式用户：直接关闭旧认证，不导入旧密码摘要；
- 有已验证邮箱的用户：发送迁移/密码重置邮件，让用户在 Firebase 建立新凭据；
- 只有用户名的用户：必须先验证旧密码，再绑定并验证邮箱；
- 不允许只按相同邮箱自动合并 Firebase 用户和旧用户；
- 切换完成后撤销全部旧会话，旧 `passwordDigest` 进入受控删除流程。

## 9. 尚未完成

- Firebase Console 和生产 Service Account 的外部配置；
- Google Sign-In 与 Sign in with Apple；
- App 内账号删除已实现：设置页确认后调用 `DELETE /api/auth/account`，服务端撤销 Firebase 身份并清理本项目的同步数据。生产环境仍须完成真机验证与公开删除说明；
- 旧 H5 登录迁移；
- 管理员认证迁移；
- 多实例部署前把账号资料和唯一约束迁移到正式数据库。

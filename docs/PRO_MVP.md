# Pro 订阅与权益实现

更新时间：2026-07-21

## 客户端已完成

- 个人中心 Pro 入口、统一金色皇冠标识与会员状态页；
- 月度、年度方案选择，并从 App Store / Google Play 读取本地化标题和价格；
- 商店购买、恢复购买、管理/取消订阅入口；
- 交易只在服务端校验后发放权益，不使用本地布尔值伪造正式会员；
- 支持未开通、等待确认、生效、宽限期、扣款重试、到期、撤销和异常状态；
- App 回到前台后自动刷新服务端权益；
- 聚焦模式、钱包模式使用统一 Pro 门控；权益失效后自动回退到免费堆叠模式；
- 卡片对比支持同时选择 2–4 张卡，并提供差异标记、费用情景估算、CSV 复制导出和方案保存；
- 稳定币数据支持 Pro 长周期区间（90 天与全部历史），免费版保留 7 天和 30 天；
- Pro 工作区已实现规则关注、保存的对比方案、离线公开资料包和透明的卡包资料评分；
- Pro 消费账单分析已提供截图选择、明确的隐私确认、结构化 AI 提取和服务端确定性费率计算；原图不写入账单记录，市场基准损耗在可靠数据源接入前不展示数值；
- AI 选卡与 AI 开卡准备已统一为 Pro 入口；开卡准备客户端已实现引导式条件确认、敏感文本阻断、结构化清单与可追溯来源展示；
- 离线详情可在网络失败时回退使用，但不会缓存邀请码或跳转链接，避免绕过服务端公开开关；
- 工作区云同步接口已预留，只同步关注项与对比方案，离线资料只保存在本机；
- App 启动时先监听未完成交易，再加载账号、服务端和商品状态，避免冷启动漏单；
- 购买前读取 `/api/pro/config`，核对当前平台验单能力与商品 ID，配置不完整时不会发起扣款；
- 账号令牌与购买关联 ID 均通过 Provider 预留，不写入源码、构建参数或普通偏好设置。

默认 `ENABLE_PRO_BILLING=false`，因此未完成商店与服务端配置时只展示安全的接入状态，不会启动真实购买或产生虚假会员。

仅检查已开通 UI 时，可在 Debug 构建加入 `--dart-define=PRO_PREVIEW_UNLOCKED=true`。该开关在 Profile/Release 构建中强制无效，不能代替服务端正式权益。

## 客户端构建配置

复制 `config/pro.example.json` 为本地配置文件，替换为商店后台创建的公开商品 ID，再将 `ENABLE_PRO_BILLING` 改为 `true`：

```bash
flutter run --dart-define-from-file=config/pro.local.json
```

支持的公开构建参数：

| 参数 | 用途 |
| --- | --- |
| `ENABLE_PRO_BILLING` | 是否连接系统应用内购买 |
| `ENABLE_PRO_REFERRALS` | 是否展示邀请奖励入口；App Store 审核包默认保持 `false` |
| `PRO_MONTHLY_PRODUCT_ID` | 月度订阅商品 ID |
| `PRO_YEARLY_PRODUCT_ID` | 年度订阅商品 ID |
| `PRO_CONFIG_PATH` | 服务端公开 Pro 配置与可用性路径 |
| `PRO_VERIFY_PATH` | 服务端交易校验路径 |
| `PRO_ENTITLEMENT_PATH` | 当前账号权益查询路径 |
| `PRO_WORKSPACE_PATH` | Pro 工作区同步路径 |
| `PRO_BILL_ANALYSIS_PATH` | Pro 消费账单分析路径 |
| `PRO_APPLICATION_ASSISTANT_PATH` | Pro AI 开卡准备路径 |
| `PRO_MANAGE_SUBSCRIPTION_URL` | 可选的订阅管理链接；为空时使用 Apple / Google 官方入口 |
| `PRO_TERMS_URL` | 上线前必须配置的会员服务条款 HTTPS 地址 |
| `PRO_PRIVACY_URL` | 上线前必须配置的隐私政策 HTTPS 地址 |
| `SHOW_PRO_DIAGNOSTICS` | 仅内测排障时显示接入状态，正式包保持 `false` |

这些值都不是密钥。App Store Connect API 私钥、Google Play 服务账号 JSON、Webhook 验签密钥和数据库凭据只能保存在服务端密钥管理系统中，禁止放入 Dart、`dart-define`、资源文件或 Git。

## 账号接入预留

App 组合层已预留两个 Provider：

- `ProAccessTokenProvider`：从 iOS Keychain / Android Keystore 读取短期 Bearer Token；
- `ProApplicationUserNameProvider`：返回服务端为账号稳定生成的 UUID，不得使用邮箱、用户名或其他明文个人信息。该 UUID 同时用于 StoreKit 2 `appAccountToken` 与 Google Play obfuscated account ID。

Flutter 已接入 Supabase 邮箱认证：配置完成且邮箱验证通过后，`ProAccessTokenProvider` 返回 Supabase access token，`ProApplicationUserNameProvider` 从服务端 `/api/auth/account` 读取稳定 UUID。缺少 Supabase 服务、服务端凭据或购买关联密钥时仍会安全返回空值，购买与恢复会被拦截。具体配置见 [`SUPABASE_AUTH.md`](SUPABASE_AUTH.md)。

## 已实现的服务端

`card.lengziyu.cn` 已新增隔离的 `/server/pro` 模块与以下接口，未修改 Vue H5 页面或现有 H5 登录行为。除验单与权益接口外，已实现仅限有效 Pro 访问的 `GET/PUT /api/pro/workspace` 与 `POST /api/pro/bill-analysis`。账单 AI 的产品范围、计算口径和隐私边界见 [`PRO_BILL_ANALYSIS.md`](PRO_BILL_ANALYSIS.md)；部署参数、账号 introspection 契约、Apple/Google/OpenAI 密钥配置与单实例存储限制见相邻项目的 `docs/PRO_SUBSCRIPTIONS.md`。

服务端缺少账号、加密密钥或对应商店凭据时，`/api/pro/config` 会安全返回不可用，客户端不会发起购买。旧 H5 会话令牌不能访问 Pro 权益接口。

AI 开卡准备的 Flutter 客户端与接口契约已完成，但 `/api/pro/application-assistant` 服务端尚未在本 Flutter 仓库中实现。正式启用前必须在独立 API 服务完成 Pro 权益复核、项目文章优先检索、发行方官方域名白名单与 `no-store` 响应，详见 [`AI_APPLICATION_ASSISTANT.md`](AI_APPLICATION_ASSISTANT.md)。AI 选卡服务也必须在服务端补上同等的有效 Pro 权益校验。

## 服务端接口契约

所有接口必须使用 HTTPS，并通过 `Authorization: Bearer <access-token>` 识别当前账号。

### 查询权益

`GET /api/pro/entitlement`

```json
{
  "entitlement": {
    "status": "active",
    "plan": "yearly",
    "expiresAt": "2027-07-20T00:00:00Z",
    "autoRenewing": true,
    "accessGranted": true
  }
}
```

`status` 支持 `free`、`pending`、`active`、`grace_period`、`billing_retry`、`expired`、`revoked`、`error`。`accessGranted` 由服务端明确决定；宽限期或扣款重试期间是否继续授权也以该字段为准。

### 校验交易

`POST /api/pro/verify`

```json
{
  "productId": "cn.lengziyu.cardapp.pro.yearly",
  "purchaseId": "store-transaction-id",
  "transactionDate": "1784486400000",
  "source": "app_store",
  "serverVerificationData": "opaque-store-proof"
}
```

响应：

```json
{
  "valid": true,
  "entitlement": {
    "status": "active",
    "plan": "yearly",
    "expiresAt": "2027-07-20T00:00:00Z",
    "autoRenewing": true,
    "accessGranted": true
  }
}
```

服务端必须校验商品 ID、应用标识、交易环境、账号归属、原始交易 ID 与当前订阅状态，并保证交易幂等。不得信任客户端传入的价格、方案或有效期。

### Pro 工作区同步

`GET /api/pro/workspace` 与 `PUT /api/pro/workspace` 只接受安全账号 Bearer Token，并在服务端再次校验有效 Pro 权益。接口保存有上限的卡片关注 ID 和对比方案；不会接收离线详情、图片、邀请码或跳转链接，也不会复用旧 H5 登录状态。

## 当前能力边界

- 规则关注列表与本机保存已完成；实时规则抓取、差异检测和定向推送仍依赖正式内容任务、账号和推送凭据；
- 云同步客户端与服务端接口已完成，但默认没有账号令牌，未接入安全账号前会给出明确提示且不会上传；
- 费用情景估算只计算资料中明确可解析的费用，不估算返现、奖励价值或收益，不构成选卡建议；
- 卡包评分只反映卡片数量、类型/网络/发行方覆盖及 KYC 资料完整度，不代表收益、信用或申请成功率。
- 账单 AI 只提取截图中明确字段，费率由固定公式计算；当前不保存原图、不自动记账，也不把未经确认的识别结果用于公开排行。

## 正式收费前仍需外部完成

1. 在 App Store Connect 和 Google Play Console 创建订阅组、月度/年度商品、价格、审核截图与本地化文案；
2. 完成安全账号服务，并把上述两个 Provider 接到安全存储与账号会话；
3. 部署已实现的验单和权益接口，并安全注入 App Store Server API 与 Google Play Developer API 凭据；
4. 接入 App Store Server Notifications V2 与 Google Play RTDN，处理续费、退款、撤销、宽限期和扣款重试；
5. 准备会员协议、自动续费说明、隐私政策、客服与退款说明；
6. 使用 StoreKit Configuration、TestFlight Sandbox 与 Google Play License Tester 完成真机购买、恢复、跨设备、退款和到期测试。

## 免费能力保护

公开资料、资料来源、更新时间、风险提示、账号删除、隐私设置和基础浏览不得设置 Pro 付费墙。

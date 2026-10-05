# AI 开卡准备

## 产品定位

`/api/pro/application-assistant` 是面向已登录且已验证账号的公开资料检索与申请准备提醒工具。普通版每个自然月 6 次，Pro 每个自然月 20 次；后台按用户赠送的该能力额外次数叠加到当月基础额度。它不代办开卡，不访问或操作第三方账户，不填写或提交申请，不保证开卡、额度或审核结果。

## 请求

```json
{
  "profile": {
    "cardId": "redotpay",
    "residence": "中国大陆",
    "residenceCountryCode": "CN",
    "applicantType": "个人申请",
    "document": "护照",
    "stage": "准备申请",
    "language": "zh-CN",
    "question": "需要准备哪些材料？"
  },
  "aiDataConsent": {
    "granted": true,
    "version": "2026-08-18",
    "provider": "alibaba-cloud-bailian"
  }
}
```

- `cardId` 必须对应公开目录中真实存在且非全球账户的卡片；
- `residenceCountryCode` 使用 ISO 3166-1 alpha-2 代码；`residence` 在服务端迁移期间保留为兼容文本；
- 个人申请时该字段表示长期居住国家或地区；企业申请时表示企业注册国家或地区；不得根据系统语言或 IP 自动推断；
- `document` 只填写材料类型；可多选，多个类型以 `、` 连接（例如 `护照、身份证`），不得填写号码、照片或其他证件内容；
- `question` 最多 500 字，客户端和服务端必须双重过滤敏感内容；
- 必须携带已验证账号的 Bearer Token，并在服务端读取普通版或 Pro 对应的当月额度。
- 发送前必须在 App 内列明本次数据、接收方阿里云百炼和用途，由用户主动勾选；服务端校验当前同意版本和供应商标识后才会占用额度或调用模型。

## 文章优先检索

1. 只检索 `published` 文章；
2. `relatedCardIds` 精确匹配优先；
3. 其次使用 `open-card` 分类、标签、标题、摘要和正文关键词；
4. 只把最相关的 3–5 个片段交给模型；
5. 无精确匹配、内容过期、来源冲突或不覆盖问题时，才允许进入联网补充。

联网只能访问卡片目录中预先核验的发行方官方域名。论坛、社交媒体、聚合推广站和返佣页面不得作为申请资格依据。

## 响应

```json
{
  "assistant": {
    "summary": "...",
    "sourceMode": "project_articles",
    "checklist": [
      { "title": "...", "detail": "...", "sourceIds": ["article-slug"] }
    ],
    "warnings": ["..."],
    "unknowns": ["..."],
    "nextSteps": ["..."],
    "sources": [
      {
        "id": "article-slug",
        "type": "project_article",
        "title": "...",
        "url": "https://...",
        "updatedAt": "2026-07-23T00:00:00.000Z"
      }
    ],
    "disclaimer": "..."
  }
}
```

`sourceMode` 只允许 `project_articles`、`official_web` 或 `mixed`。响应必须设置 `Cache-Control: no-store`，不记录用户问题、检索片段或模型结果正文。

## 服务端模型

开卡准备使用阿里云百炼 OpenAI 兼容接口，并限定为 `qwen3.5-flash` 系列：

```dotenv
BAILIAN_API_KEY=...
BAILIAN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
AI_APPLICATION_ASSISTANT_MODEL=qwen3.5-flash
```

如未单独设置 `AI_APPLICATION_ASSISTANT_*`，服务会复用选卡的百炼密钥和地址。它不会回退到 OpenAI 或其他文本模型。

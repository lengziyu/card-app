# AI 选卡

## 已实现的范围

`/api/ai/card-advisor` 面向已登录并完成邮箱验证的用户，普通版和 Pro 分别受服务端额度限制。用户主动选择所在地、可用证件、主要用途和 KYC 偏好后，服务端将这些条件与公开卡片目录交给阿里云百炼 `qwen3.5-flash` 做信息匹配。服务端必须在每次请求时校验账号、额度及当次数据共享同意，Flutter 的入口门禁不能替代服务端校验。

- 最多展示三张目录内真实存在的卡片；
- 可用证件仅填写类型，可同时选择护照和身份证；多个类型以 `、` 连接，不填写号码或证件内容；
- 仅使用公开的名称、发行方、摘要、公开 KYC 字段和官方来源；
- 不发送卡号、证件号码、密码、助记词或账单图片；
- 发送前明确列明数据、接收方阿里云百炼、用途和处理方式，并要求用户逐次主动勾选；
- 不保存选卡输入与输出；响应使用 `Cache-Control: no-store`；
- 不提供申请代理、审批承诺、投资建议或规避 KYC / 地区规则的建议；
- 费用、可申请地区、KYC 和审核结果始终以发行方官方页面为准。

## 国家与地区参数

Flutter 端先让用户在“中国大陆”和“其他国家或地区”之间选择；后者使用本地可搜索的 ISO 3166-1 国家/地区列表，不读取定位。请求在保留旧版 `residence` 文本的同时提交稳定的两位代码：

```json
{
  "profile": {
    "residence": "Singapore",
    "residenceCountryCode": "SG",
    "document": "护照",
    "useCase": "日常消费",
    "kycPreference": "可接受 KYC",
    "language": "en-US"
  },
  "aiDataConsent": {
    "granted": true,
    "version": "2026-08-18",
    "provider": "alibaba-cloud-bailian"
  }
}
```

- `residenceCountryCode` 是 ISO 3166-1 alpha-2 代码；服务端升级期间允许缺省，但新版客户端必须提交；
- `residence` 为向后兼容文本，不得替代代码做精确资格判断；
- `language` 只控制回答语言，不能用于推断居住地；
- 没有明确公开地区资料时必须返回“资格待确认”，不得让模型猜测可申请资格。

## 服务端配置

在运行 `card-api.service` 的环境文件中配置，密钥不得写入 Flutter、H5 构建产物或 Git：

```dotenv
AI_CARD_ADVISOR_ENABLED=true
BAILIAN_API_KEY=...
BAILIAN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
AI_CARD_ADVISOR_MODEL=qwen3.5-flash
AI_CARD_ADVISOR_TIMEOUT_MS=25000
AI_CARD_ADVISOR_RATE_LIMIT_MAX=12
```

服务端仅接受百炼兼容域名和 `qwen3.5-flash` 系列模型。文本 AI 不再回退到 OpenAI 或其他供应商；账单识图使用独立配置。

`AI_CARD_ADVISOR_RATE_LIMIT_MAX` 是每个来源 IP 在现有 API 限流窗口内可发起的最大请求数，默认窗口为 60 秒。首发建议维持 12，观察实际用量后再调整。

部署 API 代码和环境变量后执行：

```bash
sudo systemctl restart card-api.service
curl -sS https://card.lengziyu.cn/api/auth/config
```

不要通过 curl 直接传真实用户 Token 或 API 密钥；使用 App 的登录态完成端到端测试。

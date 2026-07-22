# AI 选卡

## 已实现的范围

`/api/ai/card-advisor` 仅面向已登录并完成邮箱验证的用户。用户主动选择所在地、可用证件、主要用途和 KYC 偏好后，服务端将这些条件与公开卡片目录交给模型做信息匹配。

- 最多展示三张目录内真实存在的卡片；
- 仅使用公开的名称、发行方、摘要、公开 KYC 字段和官方来源；
- 不发送卡号、证件号码、密码、助记词或账单图片；
- 不保存选卡输入与输出；响应使用 `Cache-Control: no-store`；
- 不提供申请代理、审批承诺、投资建议或规避 KYC / 地区规则的建议；
- 费用、可申请地区、KYC 和审核结果始终以发行方官方页面为准。

## 服务端配置

在运行 `card-api.service` 的环境文件中配置，密钥不得写入 Flutter、H5 构建产物或 Git：

```dotenv
AI_CARD_ADVISOR_ENABLED=true
OPENAI_API_KEY=...          # 复用账单识别使用的服务端密钥即可
AI_CARD_ADVISOR_MODEL=gpt-4o-mini
AI_CARD_ADVISOR_TIMEOUT_MS=25000
AI_CARD_ADVISOR_RATE_LIMIT_MAX=12
```

`AI_CARD_ADVISOR_RATE_LIMIT_MAX` 是每个来源 IP 在现有 API 限流窗口内可发起的最大请求数，默认窗口为 60 秒。首发建议维持 12，观察实际用量后再调整。

部署 API 代码和环境变量后执行：

```bash
sudo systemctl restart card-api.service
curl -sS https://card.lengziyu.cn/api/auth/config
```

不要通过 curl 直接传真实用户 Token 或 API 密钥；使用 App 的登录态完成端到端测试。

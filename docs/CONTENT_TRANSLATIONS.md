# 内容多语言翻译

Flutter 已请求设备的 `locale` 并读取每个公开内容字段的翻译。卡片、全球账户和文章接口必须把经过审核的翻译直接返回；客户端不会把“尚无英文资料”当成内容替代品。

## 支持语言

内容翻译支持 `en`、`ja`、`ko`、`vi`、`ru`、`es`、`fr`、`de`、`pt` 和 `tr`。`zh-HK` / `zh-TW` 使用应用已有的繁体 UI 文案；如需繁体的远端内容，服务端可提供 `translations.zh-Hant`。没有该字段时，客户端才回退到原始中文。

## API 格式

所有公开详情接口应继续接受 `locale=<BCP-47>` 和 `Accept-Language`，并以 `detail` 或 `item` 返回源字段和下列可选结构：

```json
{
  "translations": {
    "ja": {
      "region": "世界中で利用可能",
      "funding": "暗号資産",
      "speed": "申請受付中",
      "tags": ["キャッシュバック"]
    }
  }
}
```

卡片详情的 `benefits[]`、`fees[]`、`kycFact` 和 `chinaKyc` 可各自带 `translations`。例如 `benefits[0].translations.ja.text`、`fees[0].translations.ja.label` 与 `fees[0].translations.ja.value`。文章使用 `item.translations.<locale>`，字段包括 `title`、`summary`、`rawContent`、`bodyHtml`、`tags`、`author` 和 `verifiedLabel`。

服务端可以在读取时根据 `locale` 选出字段，也可以原样返回上述 `translations`；当前 Flutter 两种方式都兼容。旧的 `titleEn`、`regionEn` 等英语字段只作为迁移兼容，新的非英语内容必须写入 `translations`。

## 生成与审核

在同级的 `card.lengziyu.cn` **后端项目受控环境**运行以下命令。脚本位于该项目的 `scripts/generate-content-translation-drafts.mjs`，只读取公开接口并输出草稿，绝不直接写线上数据库：

```sh
OPENAI_API_KEY='…' npm run generate:translation-drafts -- \
  --generate --only solayer --locale en,ja,ko --output /secure/review/solayer.json
```

确认审核流程后，可显式使用 `--all` 扩大到全部公开卡片和文章：

```sh
OPENAI_API_KEY='…' npm run generate:translation-drafts -- \
  --generate --all --kind all --output /secure/review/all-content.json
```

脚本通过 Responses API 的 Structured Outputs 生成固定 JSON 格式，并校验数组长度，避免权益或费用错位。导入端应按卡片 ID / 文章 slug 合并 `patch`，保留原始中文、审核人和审核时间；不应批量覆盖未审核字段。`OPENAI_API_KEY` 只能存在于服务端密钥管理器，不能加入 Flutter、`--dart-define`、日志或仓库。

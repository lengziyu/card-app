# CardFi

CardFi Flutter App

## 发布合规配置

发布包需要通过 Dart define 配置公开合规页面和支持邮箱。复制
`config/legal.example.json` 为被 Git 忽略的 `config/legal.local.json`，填写真实 HTTPS
地址和可联系邮箱；同时复制 `config/pro.example.json` 为
`config/pro.local.json`，配置真实商品 ID、协议和隐私链接。商店包统一使用校验脚本构建，
避免漏传 `ENABLE_PRO_BILLING` 导致审核设备一直显示“等待商店配置”：

```bash
tools/build_store_release.sh --check
tools/build_store_release.sh ipa
tools/build_store_release.sh appbundle
```

脚本必定注入 legal 与 Pro 配置；本机存在 Supabase 和对应平台 Firebase 配置时也会一并注入。

隐私政策、用户协议和账号删除说明的可部署文案位于 `docs/legal/`。App 内的
“我的 → 设置”始终提供对应说明；配置公开地址后，页面会额外显示网页版入口。

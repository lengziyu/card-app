# 内容更新推送接入

App 的通知开关只会在用户主动开启时请求系统权限，并把匿名安装标识与设备 Token 上传到服务端。Android 上传 FCM Token，iOS 上传原生 APNs device token；未授权、离线或关闭系统通知的用户仍可通过应用内消息看到已确认发送的内容。

## Firebase 客户端配置

Android 在 Firebase Console 中创建应用后执行：

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

该命令会生成 Android Firebase 配置。当前实现仅在 Android 初始化 Firebase App；配置缺失时会安全提示“通知服务尚未配置”，不会伪造订阅成功。

## iOS

1. 在 Apple Developer 中为 App ID 开启 Push Notifications，并为开发/生产签名配置对应 provisioning profile。
2. 创建 APNs Auth Key，部署环境仅保存 `.p8`、Key ID、Team ID 与 Bundle ID；不要上传到 Firebase、Flutter 工程或 Git。
3. 服务端对 `platform: ios` 的订阅使用 APNs HTTP/2 API 直连发送；payload 中将跳转地址放在顶层 `route` 字段，例如 `"route": "/cards/example"`。
4. 用真实设备验证授权、前台通知、后台通知和点击后打开资讯/卡片详情。

## Android

1. 将 Firebase 的 `google-services.json` 放到 `android/app/`。
2. 按 Firebase 指引启用 Google Services Gradle Plugin；Android 使用 FCM。
3. Android 13 及以上已在 Manifest 声明 `POST_NOTIFICATIONS`，但仍由设置页开关触发系统授权。

服务端需同时配置 FCM（Android）与 APNs（iOS）发送凭据。FCM 服务账号私钥和 APNs `.p8` 私钥只放部署环境，绝不能放到 Flutter 工程或 Git。

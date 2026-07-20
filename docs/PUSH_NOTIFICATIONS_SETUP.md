# 内容更新推送接入

App 的通知开关只会在用户主动开启时请求系统权限，并把匿名安装标识与 FCM Token 上传到服务端。未授权、离线或关闭系统通知的用户仍可通过应用内消息看到已确认发送的内容。

## Firebase 客户端配置

在 Firebase Console 中创建 iOS 与 Android 应用后执行：

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

该命令会生成 `lib/firebase_options.dart`，并写入 iOS/Android 配置文件。当前实现使用平台默认 Firebase App；配置缺失时会安全提示“通知服务尚未配置”，不会伪造订阅成功。

## iOS

1. 在 Apple Developer 中为 App ID 开启 Push Notifications。
2. 在 Firebase 项目设置上传 APNs Auth Key（`.p8`、Key ID、Team ID）。
3. 用真实设备验证授权、前台通知、后台通知和点击后打开资讯/卡片详情。

## Android

1. 将 Firebase 的 `google-services.json` 放到 `android/app/`。
2. 按 Firebase 指引启用 Google Services Gradle Plugin。
3. Android 13 及以上已在 Manifest 声明 `POST_NOTIFICATIONS`，但仍由设置页开关触发系统授权。

服务端 FCM 服务账号配置见旧管理端仓库的 `docs/PUSH_NOTIFICATIONS.md` 与 `.env.push.example`。服务账号私钥只放部署环境，绝不能放到 Flutter 工程或 Git。

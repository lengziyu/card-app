# 内容更新推送接入

App 首次正常进入首页后会展示一次通知用途说明；只有用户点击“开启通知”后才请求系统权限，并把匿名安装标识与设备 Token 上传到服务端。选择“暂时不要”或关闭说明页不会触发系统授权，也不会在以后启动时反复弹出。Android 上传 FCM Token，iOS 上传原生 APNs device token；未授权、离线或关闭系统通知的用户仍可通过应用内消息看到已确认发送的内容。

公共内容通知不要求登录，游客也可在“我的 → 设置 → 提醒配置”中管理新卡和资讯提醒。反馈进度、贡献审核等账号内容仍只保留在登录后的应用内消息中；账号定向推送和规则变更推送不属于当前实现范围。

App 会分别记录系统通知权限和服务端订阅状态。用户在系统设置中关闭或重新开启权限后，返回 App 时会自动刷新；权限已经被拒绝时，设置页会引导用户前往系统设置，不会伪装成再次弹出系统授权框。

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
3. Android 13 及以上已在 Manifest 声明 `POST_NOTIFICATIONS`，由首次通知说明页或设置页开关触发系统授权。

服务端需同时配置 FCM（Android）与 APNs（iOS）发送凭据。FCM 服务账号私钥和 APNs `.p8` 私钥只放部署环境，绝不能放到 Flutter 工程或 Git。

## 真机验收

1. 全新安装后进入首页，确认只出现一次 CardFi 通知用途说明，系统授权框只在点击“开启通知”后出现。
2. 选择“暂时不要”后重新启动，确认不会重复弹出；设置页仍能手动开启。
3. 拒绝系统权限后再次从设置页开启，确认出现“前往系统设置”，而不是无效地重复请求权限。
4. 在系统设置中关闭或重新开启通知，返回 App 后确认“未设置 / 系统已关闭 / 已关闭 / 已开启”状态准确。
5. 分别用游客和已验证账号订阅，确认两者都能接收新卡与资讯等公共内容。

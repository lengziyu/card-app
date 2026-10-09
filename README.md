# CardFi

CardFi Flutter App

## Windows 本机开发

本项目创建时使用 Flutter **3.44.6 / Dart 3.12.2**，建议先使用相同版本。
Android 最低版本为 Android 8.0（API 26）；编译使用 Android SDK 36、
NDK 28.2.13676358、Gradle 9.1.0 和 AGP 9.0.1。Java 可使用 Android Studio 自带的 JBR。
Windows 可以开发共用 Flutter 代码并构建、调试 Android；iOS 构建和调试需要 Mac 与 Xcode。

本机环境统一放在 `D:\Devs`：Flutter 位于 `D:\Devs\flutter`，Android Studio 位于
`D:\Devs\AndroidStudio`，Android SDK 位于 `D:\Devs\Android\sdk`。
Pub、Gradle 缓存与模拟器文件也放在该目录下。安装后重启 VS Code 和终端，使用户环境变量生效。
`flutter doctor` 中缺少 Visual Studio 的提示只影响 Windows 桌面构建，本移动端项目不需要安装它。
首次构建会为部分插件自动补齐 SDK 34、35，均保存到上述 Android SDK 目录。
当前 Apple 登录插件仍有 Kotlin 迁移提示；保持现有 Flutter 版本和依赖锁文件，
升级 Flutter 前先确认插件兼容性。
项目在 E 盘、Pub 缓存在 D 盘时，Kotlin 增量缓存会出现 `different roots` 错误。
本机已在 `D:\Devs\Gradle\gradle.properties` 设置 `kotlin.incremental=false`；
该设置不影响 Flutter 的 Dart 热重载，但修改 Android Kotlin 代码后需要完整编译对应模块。

安装 Flutter SDK、Android Studio、Android SDK Command-line Tools 和 VS Code 的
Flutter/Dart 插件后，重新打开终端并执行：

```powershell
flutter doctor -v
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

在 Android Studio 的 Device Manager 启动 Android 模拟器，或连接已开启 USB 调试的
Android 手机并在手机上允许调试。执行 `flutter devices` 确认设备后，运行
`flutter run -d <设备ID>`，或在 VS Code 选择该 Android 设备，按 F5 启动
“CardFi · 应用调试”。调试支持断点和热重载。

查看首页堆叠、聚焦效果时，选择“CardFi · 首页效果调试”，再按 F5。
该入口使用现有的 `PRO_PREVIEW_UNLOCKED` 本地预览开关，仅在 Debug 模式生效，
不修改真实账号权益。也可运行
`flutter run -d <设备ID> --dart-define=PRO_PREVIEW_UNLOCKED=true`。

本机已配置模拟器 `CardFi_API_36`，可使用 `flutter emulators --launch CardFi_API_36`
启动，然后执行 `flutter run -d emulator-5554`（设备 ID 以 `flutter devices` 输出为准）。

默认运行使用公开数据，认证和正式购买仍由各自配置开关控制。调试界面无需填写生产密钥；
如需验证账号流程，按 `docs/SUPABASE_AUTH.md` 配置被 Git 忽略的
`config/supabase.local.json`，并运行：

```powershell
flutter run -d <设备ID> --dart-define-from-file=config/supabase.local.json
```

Android Firebase 客户端配置位于 `android/app/google-services.json`；服务端密钥与
发布签名不能代替本机调试配置。Windows 终端中不直接执行下文的 `.sh` 商店发布脚本，
本机调试构建可使用 `flutter build apk --debug`。

## Mac / iOS 调试

使用与上文相同的 Flutter 版本，并安装 Xcode 和 iOS 模拟器运行时。
先打开一次 Xcode 完成首次初始化，再在项目目录执行：

```bash
git pull --ff-only origin main
flutter doctor -v
flutter pub get --enforce-lockfile
open -a Simulator
flutter devices
flutter run -d <iOS设备ID>
```

设备 ID 使用 `flutter devices` 的实际输出。也可以在 VS Code 选择 iOS 模拟器，
使用“CardFi · 应用调试”或“CardFi · 首页效果调试”按 F5 启动。
后者仅在 Debug 模式开放首页 Pro 效果预览。

当前 iOS 工程最低支持 iOS 15，插件使用 Swift Package Manager。
如需在 iPhone 真机运行，打开 `ios/Runner.xcworkspace`，在 Runner 的
Signing & Capabilities 中确认自己的开发团队与签名，再选择已连接的设备调试。

`config/*.local.json` 和 `ios/Flutter/Auth.local.xcconfig` 不随 Git 同步。
普通界面调试可直接运行；验证登录时，在 Mac 上按
[`docs/SUPABASE_AUTH.md`](docs/SUPABASE_AUTH.md) 配置对应文件。
本次改动已在 Windows 完成 Flutter 检查和 Android 调试，iOS 构建与真机效果需在 Mac 验证。

## 发布合规配置

个人卡片与消费账本使用本仓库内的独立服务，默认关闭。功能入口、服务配置、
账号删除接入和验证步骤见 [`docs/PERSONAL_LEDGER.md`](docs/PERSONAL_LEDGER.md)。
开启开发入口时，在原构建参数上增加
`--dart-define-from-file=config/ledger.local.json`；示例位于
`config/ledger.example.json`，该文件只含公开功能开关。

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

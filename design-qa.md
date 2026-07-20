# 首页卡包三模式 Design QA

- Source visual truth:
  - `/var/folders/68/_9pff1g95q7gt2tqc7g3_jfr0000gn/T/codex-clipboard-229bd334-3d95-4f19-9f73-807fce4dd556.jpg`（堆叠）
  - `/var/folders/68/_9pff1g95q7gt2tqc7g3_jfr0000gn/T/codex-clipboard-c6e40f37-91e1-464c-a01d-0aae4fd9e970.png`（钱包）
  - `/Users/lens/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/wxid_ub0g5rrdelyu29_1e0d/msg/video/2026-07/0afaec1fa3054c5dfb1f5a53979a2ec2.mp4`（聚焦）
- Implementation screenshots:
  - `.design-qa/home-wallet-refactor-current/ios-fresh-default.png`（堆叠，fresh install 默认态）
  - `.design-qa/home-wallet-refactor-current/ios-focus-override.png`（聚焦）
  - `.design-qa/home-wallet-refactor-current/ios-wallet-override.png`（钱包）
  - `.design-qa/home-wallet-refactor-current/ios-stack-tilt-3.png`（堆叠，倾斜错位与透明度递减最终校准）
  - `.design-qa/home-wallet-refactor-current/ios-focus-depth-2.png`（聚焦，中段主卡与上下缩放渐隐最终校准）
  - `.design-qa/home-wallet-refactor/android-current-pass-2.png`（Android 回归参考）
- Combined comparison evidence:
  - `.design-qa/home-wallet-refactor/compare-stack-pass-5.png`
  - `.design-qa/home-wallet-refactor/compare-focus-pass-5.png`
  - `.design-qa/home-wallet-refactor/compare-wallet-pass-3.png`
- Viewports: iPhone 17 Pro simulator, 402 × 874 logical pixels, light theme；Android 1080 × 2400 physical pixels, dark theme.
- State: 首页使用真实卡图；堆叠与聚焦默认选中第 3 张卡；钱包默认无选中卡、全部收拢。iOS 当前截图来自重新安装后的当前源码运行态。

## Full-view comparison

三种模式已按最终参考语义区分：堆叠模式在卡组中间完整展示当前卡，前后卡保留可点击卡头；聚焦模式不再复用堆叠几何，当前卡更独立，前后卡以弱化 peek 方式露出并允许竖向拖动切换；钱包模式进入时没有展开第一张卡，第一张卡会被后续卡覆盖，只露顶部。顶部工具栏仅保留模式入口与添加按钮。

参考素材中的银行卡品牌和卡片数量与项目数据不同，不作为缺陷；实现继续使用项目内真实卡图和现有明暗主题背景。聚焦按视频作为沉浸式卡组 surface：进入后隐藏底部导航，底部显示退出按钮，退出返回堆叠主页。卡片比例、顶部裁切、圆角、柔和阴影、覆盖方向和控制层级保持参考意图。

## Focused region comparison

- 堆叠：默认焦点不再是第一张卡；第 3 张卡完整显示，前两张在上方、后续卡在下方。
- 聚焦：默认焦点不再是第一张卡；当前卡完整显示，前后卡降低透明度与层级，拖动过程由同一动画控制器连续插值，松手按距离与速度吸附。
- 钱包：默认 `selectedIndex = -1`，所有卡按固定卡头高度覆盖排列；点击卡头后才展开该卡；长按拖动排序与双指调节露出高度已回归。
- 工具栏：排序和列表快捷按钮已经移除；模式菜单仍提供堆叠、聚焦、钱包三个入口。聚焦 surface 增加底部退出按钮，退出后恢复底部导航。

## Required fidelity surfaces

- Fonts and typography: 沿用项目主题的中文标题层级；“卡包”和模式名称在窄屏、大字体测试中没有裁切或异常换行。
- Spacing and layout rhythm: 卡片采用统一水平边距、1.586 比例和 23px 圆角；头部固定，卡组可从渐隐区域下方连续经过。
- Colors and tokens: 使用项目现有明暗主题、玻璃按钮、选中洗色和柔和阴影；iOS 浅色与 Android 深色均无对比度退化。
- Image quality and asset fidelity: 全部使用项目已有真实卡片图片，`BoxFit.cover`、顶部对齐，没有拉伸、代码绘图或占位银行卡。
- Copy and content: 模式文案仅为“堆叠 / 聚焦 / 钱包”，与当前首页信息架构一致。
- Icons: 使用同一 Material 图标族；最终头部只保留模式与添加两个 44px 操作区，并带语义标签。
- Interaction and accessibility: 模式切换、点击聚焦、聚焦 surface 退出、钱包展开、钱包长按排序、连续竖向拖动、距离/速度吸附、回弹、双指调节、触觉反馈、偏好保存和减少动态效果均有实现或回归覆盖。
- Performance and responsiveness: 单一 `AnimationController` 统一驱动 transform；布局由纯计算器输出；320px 窄屏、大字体、iOS 和 Android 均已检查。

## Comparison history

### Pass 1

- [P1] 堆叠、聚焦和钱包都把第一张卡作为默认完整卡，和最新参考语义冲突。
- [P1] 钱包模式进入后第一张卡完整展开，不是所有卡只露卡头的默认状态。
- [P2] 顶部仍显示排序和列表两个多余快捷按钮。

Fixes:

- 默认选中项改为中间的第 3 张卡；堆叠与聚焦共享中间展开几何。
- 钱包增加未展开状态，布局使用 `selectedIndex = -1`；点击后才进入展开状态。
- 移除排序和列表快捷入口，仅保留模式与添加。

### Pass 2

- Post-fix evidence: `.design-qa/home-wallet-refactor/compare-stack-pass-5.png`, `.design-qa/home-wallet-refactor/compare-focus-pass-5.png`, and `.design-qa/home-wallet-refactor/compare-wallet-pass-3.png`.
- No actionable P0/P1/P2 visual, behavior, accessibility, or responsive differences remain.

### Pass 3

- [P1] 堆叠和聚焦仍共用同一套展开几何，静态截图过于相似。
- [P1] fresh install 或远程首页顺序同步后，默认焦点可能被保留到错误位置，堆叠首屏看起来像钱包末尾卡完整展开。
- [P2] 钱包模式迁移后缺少旧版长按拖拽排序能力。

Fixes:

- 堆叠和聚焦拆成独立几何：堆叠保留中间完整卡与上下卡头；聚焦使用独立主卡、弱化前后卡、轻微横向偏移和透明度。
- 控制器新增“用户是否主动选过卡”标记，未主动选择时同步卡片顺序会重新默认第 3 张，主动选择后才保留用户焦点。
- 钱包模式恢复长按拖拽排序，排序结果回写首页卡片顺序；双指缩放露出高度保留。
- iOS fresh install stack、focus override、wallet override 均已重新截图确认。

### Pass 4

- [P1] 堆叠模式仍然太像直立钱包卡组，缺少参考图 1 里的倾斜、左右错位和逐级透明变化。
- [P1] 聚焦模式仍然太接近堆叠/钱包，未形成参考图 3 的中段主卡与上下景深。
- [P2] 近卡与远卡的绘制层级会让更远的下方卡片压住近处卡片，聚焦底部区域显得灰成一片。

Fixes:

- 堆叠几何增加距离驱动的扇形错位：非选中卡按上下方向、奇偶错位产生左右位移和轻微旋转，并按距离递减 scale、opacity 与阴影。
- 聚焦几何改为 cover-flow 式景深：主卡固定在上下中段，上下相邻卡只露 peek，并按距离逐渐缩小、侧移和淡出。
- 堆叠/聚焦改用距离主卡的 zIndex；越近的卡越靠上，避免远卡压住近卡。
- 钱包 `_walletCollapsed`、`_walletBase`、长按排序和双指 reveal height 逻辑未改动，仅复用已有回归测试确认。
- iOS stack tilt 与 focus depth 均重新截图；最终截图为 `ios-stack-tilt-3.png` 与 `ios-focus-depth-2.png`。

## Verification

- `dart format lib test`: passed, 0 files changed on final pass.
- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 51 tests.
- Primary interactions tested: 打开模式菜单、切换三种模式、堆叠/聚焦几何差异、聚焦竖向拖动、钱包默认收拢、钱包长按排序、点击卡片、双指高度调节、头部固定和模式偏好保存。
- Flutter exceptions: none.
- Remaining P3: 动画手感仍建议在一台 120Hz iPhone 与一台中低端 Android 真机上感知确认；模拟器和组件测试不能替代真机帧率体验。

final result: passed

---

# 卡片画布 Design QA

- Source visual truth:
  - `/var/folders/68/_9pff1g95q7gt2tqc7g3_jfr0000gn/T/codex-clipboard-eafaa969-7de4-4fbe-a03a-29563d7e6d47.jpg`（紧密网格）
  - `/var/folders/68/_9pff1g95q7gt2tqc7g3_jfr0000gn/T/codex-clipboard-71cbac0f-a35a-47df-88ff-c42c69e92fa0.jpg`（松散画廊）
  - `/var/folders/68/_9pff1g95q7gt2tqc7g3_jfr0000gn/T/codex-clipboard-f866f28f-40a8-427c-a7bc-d96117a60d1a.jpg`（绿色背景与背景面板）
  - `/Users/lens/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/wxid_ub0g5rrdelyu29_1e0d/temp/RWTemp/2026-07/be87af6714357e11dc720cd7010ee257/22bf7e140521948c7b8a948e2de1f975.mp4`（拖动、布局切换、背景、自动播放、缩放与复位交互）
- Implementation screenshots:
  - `.design-qa/card-canvas/ios-compact-final.png`
  - `.design-qa/card-canvas/ios-gallery-final.png`
  - `.design-qa/card-canvas/ios-background-panel-final-2.png`
- Combined comparison evidence:
  - `.design-qa/card-canvas/compare-compact-final.png`
  - `.design-qa/card-canvas/compare-gallery-final.png`
  - `.design-qa/card-canvas/compare-background-final-2.png`
- Viewport: iPhone 17 Pro simulator, 402 × 874 logical pixels, light theme.
- State: 生产公开目录卡图；紧密网格、松散画廊和绿色背景面板分别与对应参考状态比较。

## Full-view comparison

紧密模式保留参考图的三列可视密度、铺满屏幕的连续卡片、轻微错位旋转，以及左右悬浮圆形工具；松散模式增大横纵留白，视口同时保留约两至三列卡片和可向任意方向继续拖动的画布感。实现使用当前项目的真实公开卡图，因此具体品牌、数量和顺序与 ArkFlow 素材不同，这属于预期内容差异。

## Focused region comparison

背景设置面板与参考图并排检查了顶部圆角与拖拽条、标题/完成动作、5+3 色板排列、选中色描边、背景图入口和半透明薄荷色玻璃层。该区域文字和控件足够清晰，不需要进一步裁切比较。

## Required fidelity surfaces

- Fonts and typography: 使用项目既有中文字体回退；面板标题、分组标签、完成按钮和自动播放文案的字号、字重与层级接近参考，未出现裁切。
- Spacing and layout rhythm: 卡片保持 1.586 比例与 10px 圆角；紧密模式约三列，松散模式约两至三列；悬浮控制缩至 48px，关闭按钮 54px，左右安全区和底部手势区均保留。
- Colors and visual tokens: 默认暖白画布、七种预设色与自定义 RGB 颜色可实时切换；选中工具使用浅薄荷玻璃而非首轮过强的实心绿色；深色背景自动使用更合适的卡片阴影。
- Image quality and asset fidelity: 所有卡片使用项目现有 `CardArtwork` 与真实本地/远程卡图，保持裁切、清晰度和缓存策略；没有用占位图、手绘 SVG 或文本字符替代卡面。
- Copy and content: 背景、排列、卡片错位、自动播放、速度、开始/停止、缩放和复位文案均为清晰中文；具体卡片内容来自当前公开目录。
- Interaction and accessibility: 已实现单指拖动、双指缩放、按钮缩放/复位、紧密/松散排列、旋转角度开关和滑杆、重新错位、无尽画布、八方向与速度可调自动播放、立即停止、沉浸模式、关闭返回和卡片详情入口。按钮均有语义标签，点击区不少于 44px；系统“减少动态效果”开启时自动播放会降级并给出提示。
- Performance and responsiveness: 画布变换由 `TransformationController` 与单一 `Ticker` 驱动，卡片使用 `RepaintBoundary`；320px 窄屏、大字体和完整组件测试未发现溢出或异常。

## Comparison history

### Pass 1

- [P2] 首轮紧密模式卡片缩放偏小、同屏列数偏多，左侧圆形工具也比参考更大且起点偏低。

Fixes:

- 紧密模式初始缩放从 0.82 调整到 0.94，松散模式从 0.78 调整到 0.88。
- 常规圆形工具由 52px 收紧到 48px，关闭按钮由 58px 收紧到 54px；工具栏与关闭按钮对齐到同一顶部节奏。
- 补齐视频中出现的无尽画布控制，并保持所有按钮可操作。

### Pass 2

- [P2] 背景面板色板首轮为 4×2 排列，圆点偏大；额外隐私说明让面板高于参考，玻璃底色也偏白。

Fixes:

- 色板改为参考图一致的首行 5 个、次行 3 个，色点直径调整为 44px。
- 移除额外说明，把面板材质改为更接近参考的半透明薄荷白，面板顶部位置与参考误差缩小到约 12px。

### Pass 3

- [P2] 错位和无尽画布选中态使用实心绿色，视觉权重高于参考的半透明悬浮按钮。

Fixes:

- 选中态改为浅薄荷玻璃底与绿色图标，保留状态识别但不压过卡片内容。

### Pass 4

- [P2] 320px 窄屏配合 2× 系统字体时，没有真实图片的本地兜底卡片标签发生 11px 纵向溢出。

Fixes:

- 画布中的兜底卡面关闭生成文字标签，只保留项目既有卡片底图；真实本地/远程卡图不受影响。新增窄屏、大字体和减少动态效果回归测试后未再出现溢出。

### Final pass

- Post-fix evidence: `.design-qa/card-canvas/compare-compact-final.png`, `.design-qa/card-canvas/compare-gallery-final.png`, and `.design-qa/card-canvas/compare-background-final-2.png`.
- No actionable P0/P1/P2 visual, interaction, accessibility, or responsive differences remain.

## Verification

- `dart format --output=none --set-exit-if-changed ...`: passed, 0 files changed.
- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 54 tests.
- Primary interactions tested: 市场入口、打开/关闭画布、紧密/松散排列、错位设置、自动播放方向与启动/停止；模拟器同时检查真实远程卡图、卡片密度、悬浮控件和背景面板。
- Flutter exceptions observed during simulator and test runs: none.
- Remaining P3: “上传背景图”仅保留参考视觉，不读取系统相册；如后续确认需要真实上传，需单独评估相册权限与隐私文案。120Hz iPhone 与中低端 Android 的持续自动播放帧率仍建议真机感知确认。

final result: passed

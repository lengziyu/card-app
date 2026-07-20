# Flutter Card Wallet UI 重构任务

## 目标

请重构当前 Flutter Card 项目的首页卡包界面，目标不是简单还原截图，而是实现一个具有 **Apple Wallet / 高级银行卡管理 App** 质感的卡片交互系统。

请先分析当前代码结构，再在现有基础上重构，不要推倒重写整个项目。

---

# 开发流程（必须遵守）

请严格按照下面流程执行，不要直接开始写代码。

## 第一步

阅读整个 Card 页面相关代码。

分析：

- 当前页面结构
- 当前状态管理
- 当前动画实现
- 当前卡片布局方式
- 当前有哪些问题导致效果不好

然后输出分析结果。

---

## 第二步

提出完整重构方案。

包括：

- Widget 拆分
- 动画方案
- 手势方案
- Layout 计算方案
- Controller 设计
- 数据模型设计

确认方案后，再开始修改代码。

---

## 第三步

开始真正修改代码。

不要一次性生成几千行代码。

每完成一个模块：

- 编译
- 修复错误
- 再继续下一步

最后运行：

```bash
flutter analyze
```

修复所有新增问题。

---

# UI目标

整体风格参考：

Apple Wallet

Curve

Monzo

高端银行卡 App

不是 Material Demo。

整体视觉：

- 留白充足
- 动画自然
- 阴影柔和
- 卡片具有空间层级
- 不要有 Flutter 默认组件的感觉

---

# 页面结构

顶部：

左侧：

```
卡包
```

字体：

- 大号
- Bold

右侧：

四个圆形按钮：

- Stack
- Sort
- Menu
- Add

要求：

- 半透明背景
- 柔和阴影
- 点击动画

顶部固定，不滚动。

---

# 卡片

银行卡比例：

```
1.586
```

例如：

```
340 × 214
```

圆角：

```
22~24
```

图片：

```
BoxFit.cover
```

不要拉伸。

不要变形。

图片加载完成前保持占位。

---

# 三种布局

## ① Stack 模式

所有卡片堆叠。

规则：

第一张：

```
scale = 1
opacity = 1
```

第二张：

```
scale = 0.985
```

第三张：

```
scale = 0.97
```

后面的继续递减。

每张卡：

仅露出：

```
50~60 px
```

点击任意卡：

该卡移动到最前面。

其它卡重新排列。

整个过程必须连续动画。

不能闪。

不能突然交换。

---

## ② Focus 模式

当前卡：

位于页面中部。

完整显示。

上一张：

露出一点。

下一张：

露出一点。

上下拖动：

当前卡跟随手指。

拖动超过阈值：

切换上一张或下一张。

否则：

回弹。

动画：

```
easeOutBack
```

但是不要过度弹。

---

## ③ Wallet 模式

模拟真实钱包。

所有卡：

仅露出顶部：

```
80~100 px
```

点击某张：

平滑展开。

其它卡自动重新排列。

整体像真实钱包。

不是 ListView。

---

# 动画

不要大量 AnimatedPositioned。

建立统一动画系统。

使用：

```
AnimationController
```

统一驱动：

- top
- left
- scale
- opacity
- rotation
- shadow

动画：

```dart
Duration(milliseconds:420)
```

Curve：

```dart
Curves.easeOutCubic
```

拖拽结束：

```dart
Curves.easeOutBack
```

---

# Layout

不要写死坐标。

建立：

```
CardLayoutCalculator
```

输入：

```dart
mode
selectedIndex
dragOffset
screenSize
cardSize
itemCount
```

输出：

```dart
CardTransformState
```

包括：

```dart
top
left
scale
opacity
rotation
elevation
zIndex
```

所有布局：

统一计算。

UI：

只负责绘制。

---

# 手势

支持：

点击：

```
onTap
```

拖动：

```
onPanUpdate
```

结束：

```
onPanEnd
```

拖动过程中：

实时更新：

- 当前卡
- 前后卡位置
- scale
- opacity
- shadow

不要等松手以后才动画。

---

# 阈值

建议：

```dart
distanceThreshold = cardHeight * 0.18;
```

```dart
velocityThreshold = 700;
```

根据：

距离

速度

共同决定是否翻页。

---

# 阴影

不是黑色阴影。

要求：

柔和。

低透明。

不同层级：

阴影不同。

卡片越高：

阴影越明显。

---

# 页面背景

```dart
Color(0xFFF6F6F8)
```

不要纯白。

---

# 按钮

顶部按钮：

圆形。

带：

轻微阴影。

点击：

scale 动画。

---

# 性能

要求：

拖拽保持：

```
60 FPS
```

不要：

每次拖动：

setState 整个页面。

不要：

onPanUpdate：

创建大量对象。

建议：

```
ValueNotifier
```

或：

```
ChangeNotifier
```

或：

```
Riverpod
```

统一更新。

---

# Widget拆分

请拆分：

```
lib/

card_wallet_page.dart

card_stack_view.dart

wallet_card_item.dart

card_stack_controller.dart

card_layout_calculator.dart

card_stack_mode.dart

card_transform_state.dart
```

不要把所有代码写进一个 Widget。

---

# 数据结构

```dart
enum CardStackMode {
  stack,
  focus,
  wallet,
}
```

```dart
class CardTransformState {
  final double top;
  final double left;
  final double scale;
  final double opacity;
  final double rotation;
  final double elevation;
  final int zIndex;
}
```

---

# 图片

不要改变图片比例。

使用：

```dart
ClipRRect
```

```dart
BoxFit.cover
```

---

# 验收标准

最终必须满足：

✅ 三种布局切换平滑

✅ 点击任意卡片自动聚焦

✅ 上下拖动实时跟手

✅ 拖动取消自然回弹

✅ 快速滑动翻页

✅ 图片无拉伸

✅ 无闪烁

✅ 无突然换层

✅ 卡片不会超出 SafeArea

✅ iOS、Android 自适应

✅ flutter analyze 无新增错误

---

# 编码要求

不要为了还原截图写大量魔法数字。

不要大量 if/else 控制坐标。

不要直接照着截图写静态页面。

应该建立：

- Card Controller
- Layout Engine
- Transform Model
- Animation System

所有布局都通过统一算法计算。

---

# 最终要求

完成代码后，请输出：

1. 重构了哪些模块
2. 为什么这样设计
3. 动画实现原理
4. Layout 计算方式
5. Controller 工作流程
6. 后续方便扩展哪些功能（例如拖拽排序、多选、分组、搜索等）

目标不是完成一个 Demo，而是实现一个可长期维护、可扩展、接近 iOS 原生体验的 Flutter 卡包组件。
# Design QA — 首页堆叠切换、非当前卡遮罩与聚焦图标

- Source visual truth: `/Users/lens/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/wxid_ub0g5rrdelyu29_1e0d/msg/video/2026-07/0afaec1fa3054c5dfb1f5a53979a2ec2.mp4`
- Source icon reference: `/var/folders/68/_9pff1g95q7gt2tqc7g3_jfr0000gn/T/codex-clipboard-763149f9-17d0-4490-922c-5fbc92fec146.png`
- Implementation screenshot (stack after swipe): `/tmp/card-app-stack-after-swipe.png`
- Implementation screenshot (mode menu): `/tmp/card-app-mode-menu-final.png`
- Implementation motion capture: `/tmp/card-app-stack-motion.mp4`
- Full-view comparison: `/tmp/card-app-stack-comparison.png` (reference left, implementation right)
- Focused icon comparison: `/tmp/card-app-focus-icon-comparison.png` (reference left, implementation right)
- Viewport: iPhone 17 Pro Simulator, 402 × 874 logical pixels, 942 × 2048 capture
- State: light theme, Pro preview enabled; stack and focus modes with the middle card selected

## Full-view comparison evidence

The supplied video and the simulator capture were normalized into one side-by-side image. The implementation retains its native app spacing and card artwork, while matching the requested interaction characteristics: the module anchor stays fixed, the selected card comes forward, and non-selected cards above and below it visibly recede behind a soft white-to-transparent veil. The simulator motion capture confirms that selection changes through one continuous gesture rather than moving the whole home module.

## Focused region comparison evidence

The icon comparison was inspected at readable scale. The closest existing Material symbol, `view_day_outlined`, reproduces the reference's central outlined card with lighter horizontal layers above and below. It stays consistent with the app's existing Material icon system and remains legible at the 18 px menu size and 23 px header size. No custom-drawn or raster approximation was introduced.

## Findings

- No actionable P0, P1 or P2 mismatch remains within the requested scope.
- [P3] The reference focus icon uses rounded overlapping rectangles, while the standard Material symbol uses flatter horizontal layers. This is an acceptable library-level variation and avoids introducing a one-off custom icon language.
- [P3] Card artwork, header actions and navigation differ from the third-party reference by design; this request uses it only for motion, depth treatment and focus-icon shape.

## Required fidelity surfaces

- Fonts and typography: no copy or type-token changes were requested; existing native typography remains aligned, unclipped and readable.
- Spacing and layout rhythm: the home card module stays at the same top anchor before and after swiping. Existing card radius, width, compact reveal spacing and bottom-navigation clearance are preserved.
- Colors and visual tokens: non-current cards use a white veil that fades through the upper 82% of the artwork, with lower opacity in dark mode. Blur, desaturation, lift, shadow and veil strength now derive from animated depth, so they cross-fade together.
- Image quality and asset fidelity: all existing card artwork remains native and sharp. The focus icon comes from Flutter's Material icon library; no placeholder, custom SVG or improvised image asset is used.
- Copy and content: `钱包`, `堆叠`, `聚焦` and Pro crown/selection states remain unchanged.

## Interaction verification

- Opened and closed the home mode menu.
- Switched between focus and stack modes.
- Dragged upward in focus mode and confirmed selection advanced.
- Dragged upward in stack mode and confirmed selection advanced while the module anchor stayed fixed.
- Checked the Flutter debug stream after interaction; no runtime exception was reported.
- Reduced-motion behavior remains handled by the controller and existing media-query path.

## Comparison history

1. Baseline: geometry already animated, but blur, color lift and non-current treatment switched from the boolean selected state, creating a visible jump at selection time. Non-current cards had no white gradient veil, and focus used the visibility icon.
2. First implementation: visual depth was derived from animated scale, the 420 ms settle curve was added, the white veil was introduced, and focus changed to `view_day_outlined`. Simulator review found that the lower card in compact stack mode exposed the veil too late.
3. Final implementation: the white gradient was extended through 82% of the card with a restrained tail, making the veil visible on both upper and lower non-current cards. Post-fix simulator screenshots and motion capture show no actionable P0/P1/P2 issue.

## Implementation checklist

- [x] Smooth the stack/focus selection handoff.
- [x] Animate blur, color lift and white veil from card depth.
- [x] Add white-to-transparent veils to non-current cards above and below.
- [x] Replace the focus icon in the home menu, header and Pro feature list.
- [x] Verify gestures and fixed module position on an iPhone-sized simulator.
- [x] Run static analysis and focused interaction tests.

## Follow-up polish

- The standard Material focus icon can be replaced later if the product adopts a dedicated custom icon set across the whole app.

final result: passed

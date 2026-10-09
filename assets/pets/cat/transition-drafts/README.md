# 提起与放下身体帧

v6 在已认可的 v5 三张身体关键帧之间，用内置 imagegen 补六张姿势。源 RGBA PNG 未做像素修改，完整提示词保存在同名 `.prompt.txt`。原始头部、眼睛、坐姿端点和悬空端点继续复用。

| 顺序 | 素材 | 动作 | 源脖颈锚点 | 等比缩放 |
| --- | --- | --- | --- | --- |
| 0 | `pickup-low-lift-v1.png` | 前爪刚开始离地 | (627,752) | 1.0 |
| 1 | `pickup-early-v2.png` | 刚离地，后腿仍收在两侧 | (627,752) | 1.0 |
| 2 | `pickup-curl-v1.png` | 前肘继续弯曲 | (627,752) | 1.0 |
| 3 | `pickup-rise-v1.png` | 后爪向腹部收起 | (627,675) | 743/747 |
| 4 | `pickup-middle-v2.png` | 半展开，后腿仍弯曲 | (627,650) | 743/742 |
| 5 | `pickup-open-v1.png` | 膝盖打开，脚尖转向下 | (627,650) | 743/745 |
| 6 | `pickup-unfold-v1.png` | 后腿半下垂 | (627,640) | 743/746 |
| 7 | `pickup-extend-v2.png` | 前肘和后膝继续伸展 | (627,640) | 743/746 |
| 8 | `pickup-late-v1.png` | 接近悬空，四肢下垂 | (627,570) | 743/644 |
| 9 | `landing-contact-v1.png` | 着地轻压 | (627,790) | 743/744 |

`pickup-curl-v1` 的原提示词要求较低抬爪，但实际生成的爪位偏高，因此校准后用于刚离地之后；低抬爪单独生成。未采用的伸展候选头宽缩小且身体过长，没有接入。

## 接入与校准

- `scripts/cat_transition_frames.gd` 负责九张提起身体帧、着地帧、等比缩放和源脖颈锚点；`draft-manifest.json` 记录每张图的尺寸、透明像素、可见边界、比例和提示词路径。
- 提起约 0.54 秒：原始坐姿 → 九张身体帧 → 分层悬空；换帧点为 0.185、0.27、0.355、0.445、0.535、0.625、0.71、0.7925。0.11 前与 0.89 后沿用已认可的端点。
- 放下约 0.60 秒：从当前提起进度反放同一序列，再进入着地轻压。重新抓起从当时进度续接；驱动中的动作回调隔离方式保持不变。
- 原始头部和眼睛大小固定，头颈连续移动/旋转。生成图中的头由 shader 隐藏，仅身体参与换帧，无整猫透明交叠或大幅 UV 变形。
- 身体按头宽等比校准，允许悬空姿势自然更高。原始显示比例 0.19，透明窗口 320×320；逐张 GPU 预览检查胸宽、接缝和四肢位置。
- 悬空时仍由 `cat_drag_rig.gd` 的独立惯性弹簧控制身体、四肢和尾巴。

## 预览与验证

v5 历史保留：`previews/cat-pickup-poses-v5.png`、`previews/cat-drag-swing-v5.webp`。

v6：`previews/cat-pickup-poses-v6.png`（全部姿势）、`previews/cat-drag-swing-v6.webp`（实际速度与惯性）、`previews/cat-pickup-release-v6.webp`（提放慢速审阅）、`previews/drag-cat-v6.qa.json`。

用 Godot 实际 GPU 渲染 `--script res://scripts/export_drag_cat_preview.gd -- --version=v6`，再运行 `scripts/preview_drag_cat.py --version v6`。渲染中间文件写入 Git 忽略的 `previews/drag-rendered/`，审阅输出按版本命名。

`tests/drag_rig_test.gd` 覆盖独立惯性、反向缓冲、中途松手和重新抓起，并检查每个新换帧点两侧的中断连续性。`tests/layered_cat_test.gd` 保持眨眼、摸头和动作恢复验证。`export_layered_cat_preview.gd` 配合 `preview_layered_cat.py --version v6` 检查完整待机周期与原始母版的像素一致性。

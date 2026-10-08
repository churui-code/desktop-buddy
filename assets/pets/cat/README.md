# PNG 小猫动作素材

## 当前默认：固定母版分层

所有部位共享 `idle-base-v1.png` 原始母版，在 Godot 中通过蒙版分出身体、头部（含耳朵）、尾巴和眼睛。`layered_cat_layout.tres` 记录原图像素坐标、关节、显示比例和眼睛区域，图层素材不会重新缩放或生成。眼睛复用既有半闭眼、闭眼图的局部区域，手套继续使用独立的 `petting-glove-v1.png`。本次分层没有生成新图。

静态拼装与母版在同尺寸渲染下，可见 RGBA 像素差为零。报告：`previews/layered-cat-v1.qa.json`。摸头预览：`previews/cat-layered-head-pet-v1.webp`。小幅头部倾斜通过关节旋转实现，脖颈背面复用胸口像素填充；更大的动作需要补全隐藏部位。

## 眨眼素材 v1

生成方式：内置 imagegen。基准图是 `idle-base-v1.png`，它作为两次眼睛编辑的共同参考。两次编辑只要求眼睛变化，完整提示词分别保存在 `blink-half-v1.prompt.txt` 和 `blink-closed-v1.prompt.txt`。

| 源文件 | 状态 |
| --- | --- |
| `idle-base-v1.png` | 睁眼待机 |
| `blink-half-v1.png` | 半闭眼 |
| `blink-closed-v1.png` | 闭眼 |

三张源文件均为 1254 × 1254 的 RGBA PNG。可见主体的脚底位置相同，半闭眼和闭眼帧与基准主体的轮廓重合度分别约 99.58% 和 99.70%。原始生成帧在眼睛之外也有少量色差，因此当前眨眼材质会保留基准图的身体，仅混合眼部区域。Godot 渲染的三张审阅帧在眼部之外的像素差为零。

播放资源 `cat_frames.tres` 定义 240ms 的单次眨眼。主场景的行为管理器负责随机触发，动作驱动器执行动画并回传请求编号。原始 PNG 不进行裁切、对齐修正或覆盖。

正常速度预览：`previews/cat-blink-v1.webp`。慢速预览：`previews/cat-blink-slow-v1.webp`。检查报告：`previews/cat-blink-v1.qa.json`。

## 摸头 v2

内置 imagegen 生成独立透明手套 `petting-glove-v1.png` 和轻微右倾的小猫 `head-pet-right-v1.png`；完整提示词保存在各自的 `.prompt.txt` 中。两张均为 1254 × 1254 RGBA PNG，手套保留整幅透明画布，使用节点位置和旋转实现抚摸，无需手套帧动画。

小猫动作使用 `blink-closed-v1.png` 作为闭眼正姿，以及 `head-pet-right-v1.png` 作为闭眼右倾姿势。`cat_frames.tres` 的 `head_pet` 动画循环播放两帧，专用材质平滑混合帧，保留基准图身体并减小歪头幅度。手套独立显示在小猫上层，其移动与小猫帧相位同步。先前的 `head-pet-glove-keyframe-v1.png` 是合并效果草图，当前运行时使用分层素材。

运行时渲染预览：`previews/cat-head-pet-v2.webp`。

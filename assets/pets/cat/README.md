# PNG 小猫动作素材

## 当前默认：固定母版分层

小猫各部位共享 `idle-base-v1.png` 原始母版，在 Godot 中通过蒙版分出身体、头部（含耳朵）、尾巴和眼睛。`layered_cat_layout.tres` 记录原图像素坐标、关节、显示比例和眼睛区域，猫的图层素材不会重新生成。眼睛复用既有半闭眼、闭眼图的局部区域，手套使用独立的 `petting-right-glove-v2.png`。

静态拼装与母版在同尺寸渲染下，可见 RGBA 像素差为零。报告：`previews/layered-cat-v2.qa.json`。摸头预览：`previews/cat-layered-head-pet-v2.webp`。小幅头部倾斜通过关节旋转实现，脖颈背面复用胸口像素填充；更大的动作需要补全隐藏部位。

### 第一人称右手与抚摸调整

内置 imagegen 参考旧手套生成 `petting-right-glove-v2.png`，完整提示词保存在 `petting-right-glove-v2.prompt.txt`。素材为 1254 × 1254 RGBA PNG，表现观看者从右下方伸出的右手，手背朝向观看者，指尖伸向左上方。保留生成的原始画布，使用独立锚点和节点缩放校准接触位置与大小。

手套仍只有一张固定图片。抚摸周期为 1 秒，显示时横向总幅度约 20 像素，向右下压约 3.4 像素；猫头最大倾角约 2.6 度。所有动作参数位于 `layered_cat_layout.tres`，旧手套与 v1 预览保留用于对比。

## 悬空拖动与七层拆分

`drag-scruff-keyframe-v1.png` 是用户确认的被猫妈妈提住后颈的悬空姿势。`cat_drag_layer.gdshader` 从同一张 1254 × 1254 原图分出头、躯干、两条前腿、两条后腿和尾巴；`CatDragRig` 为各层设置独立轴心，沿用源图坐标，素材大小与拼装位置不靠再次生图匹配。

`drag-torso-underlay-v1.png` 由内置 imagegen 参考悬空关键帧生成，移除四肢和尾巴后补全躯干。运行时仅使用其躯干区域，在运动露出关节背面时覆盖接缝，原图头部和四肢保持不变。两张源图均保留透明画布，完整提示词见同名 `.prompt.txt`。

七层拆分图：`previews/cat-drag-parts-v1.png`。动画预览：`previews/cat-drag-swing-v1.webp`。检查报告：`previews/drag-cat-v1.qa.json`。中立拼装与关键帧的可见像素差为零。动画根据拖动速度驱动独立弹簧，保存角速度并用阻尼衰减，支持反向拖动时的滞后和停住后的余摆。此蒙版与背面补全适用于当前有限幅度的正面摆动。

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

## 整图逐帧摸头实验 v2

内置 imagegen 生成独立透明手套 `petting-glove-v1.png` 和轻微右倾的小猫 `head-pet-right-v1.png`；完整提示词保存在各自的 `.prompt.txt` 中。两张均为 1254 × 1254 RGBA PNG，手套保留整幅透明画布，使用节点位置和旋转实现抚摸，无需手套帧动画。

小猫动作使用 `blink-closed-v1.png` 作为闭眼正姿，以及 `head-pet-right-v1.png` 作为闭眼右倾姿势。`cat_frames.tres` 的 `head_pet` 动画循环播放两帧，专用材质平滑混合帧，保留基准图身体并减小歪头幅度。手套独立显示在小猫上层，其移动与小猫帧相位同步。先前的 `head-pet-glove-keyframe-v1.png` 是合并效果草图，当前运行时使用分层素材。

运行时渲染预览：`previews/cat-head-pet-v2.webp`。

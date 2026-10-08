# Desktop Buddy

用 Godot 4 制作的桌面宠物原型。默认使用固定母版的奶油色小猫，运行时分出头部、身体、尾巴和眼睛，通过节点变换制作动画。待机时轻微呼吸和眨眼；点击会跳起，头部长按会出现白手套摸头，按住左键移动可拖动，右键可重置位置或退出。关闭后会记住位置。

## 运行

用 Godot 4.7 打开本目录的 `project.godot`，按 F5 运行主场景。命令行也可以运行：

```sh
/Users/churui/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/churui/Project/desktop-buddy
```

## 行为与动画的分工

`桌面输入 → PetActionManager → action_requested 信号 → PetVisualDriver.execute() → 具体动画方法`

| 文件 | 职责 |
| --- | --- |
| `scripts/desktop_pet.gd` | 透明窗口、输入、拖动、菜单、位置保存 |
| `scripts/pet_pointer_gesture.gd` | 点击、头部长按和拖动的手势判断 |
| `scripts/pet_action_manager.gd` | 行为状态、眨眼调度、动作优先级、事件派发和完成处理 |
| `scripts/pet_actions.gd` | 统一的动作名称 |
| `scripts/pet_visual_driver.gd` | 可替换动画驱动的接口 |
| `scripts/cat_rig_layout.gd` | 母版像素坐标、关节轴心、蒙版与显示比例的配置类型 |
| `assets/pets/cat/layered_cat_layout.tres` | 当前小猫的素材和拼装坐标 |
| `scripts/layered_cat_pet_driver.gd` | 默认分层小猫的关节动画与眼睛表情 |
| `scenes/pets/layered_cat_pet.tscn` | 头部、眼睛、身体、尾巴和独立手套节点 |
| `scripts/layered_svg_pet_driver.gd` | 原 SVG 角色的 AnimationPlayer / Tween 动画 |
| `scenes/pets/layered_svg_pet.tscn` | 原 SVG 角色的图层、素材、窗口尺寸和点击区域 |
| `scripts/sprite_frames_pet_driver.gd` | PNG 逐帧动作，以及待机呼吸和点击补间 |
| `scenes/pets/sprite_cat_pet.tscn` | 可切回的整图逐帧实验角色 |
| `assets/pets/cat/cat_frames.tres` | 睁眼、半闭眼、闭眼的帧顺序与时长 |

SVG 版本的动画改变 Sprite2D 节点的缩放、旋转和位置，SVG 路径本身保持不变。

默认分层角色共用 `idle-base-v1.png` 这张 1254 × 1254 母版。`cat_master_layer.gdshader` 用互补蒙版分出头部、身体和尾巴；眼睛区域由 `cat_eye_layer.gdshader` 单独绘制。所有零件都保留母版尺寸和坐标，无需重新生成比例各异的零件图。头部包含耳朵，眼睛跟随头部；关节与统一显示比例在 `layered_cat_layout.tres` 中配置。静态拼装与同尺寸渲染的母版比较，RGBA 可见像素差为零，报告见 `previews/layered-cat-v2.qa.json`。

眨眼只使用现有半闭眼、闭眼图的局部眼睛像素，过渡持续 240ms。管理器每 2–4.5 秒随机触发一次。呼吸以脚底为轴心，尾巴绕尾根轻摆。摸头以脖颈为轴心将头部连续旋转，最大倾角约 2.6 度，避开整图姿势混合造成的耳缘重影；脖颈背后有一块复用胸口像素的隐藏填充，用于覆盖小幅倾斜露出的接缝。这种填充适用于当前的小幅动作，大角度转头和走路仍需要补全遮挡部位或进一步拆分爪子。

头部按住左键 0.45 秒触发摸头，松开或移出头部恢复待机，释放时不会再触发点击跳跃。移动达到 8 像素优先进入拖动，摸头过程中也可转为拖动；窗口失去焦点会取消当前手势。身体长按不触发摸头。手套使用一张独立上层图片 `petting-right-glove-v2.png`，表现观看者从右下方伸出的右手，手背朝向观看者、指尖朝左上方；用 0.22 秒淡入，每 1 秒完成一次往返，横向总幅度约 20 像素，向右时下降约 3.4 像素并轻微下斜。头部倾斜与手套同相位，松开后用 0.20 秒淡出并恢复睁眼。各部位共用固定素材，动作通过关节变换和表情组合实现。

手套素材的锚点 `glove_source_joint` 和缩放 `glove_scale` 独立配置，因此替换图片后可以在运行时校准大小与接触位置。抚摸周期、幅度、下压、手部及头部角度、出入场位移和时间也统一放在 `layered_cat_layout.tres` 中。

原始 PNG 和提示词保留在 `assets/pets/cat/`。整图逐帧方案仍可通过主场景的 `visual_scene` 切回 `sprite_cat_pet.tscn`；其资源是 `cat_frames.tres`、`blink_region.gdshader` 和 `petting_cat.gdshader`。

管理器使用 Godot 信号连接当前驱动器。它属于这只宠物实例，无需全局单例。自动眨眼仅在待机时触发；摸头会打断点击反馈，拖动会打断点击或摸头；当前点击反馈完成后恢复待机。摸头由明确的开始、结束事件控制，持续期间不被眨眼或点击打断。每次动作有唯一请求编号，旧动画的完成回调不能重置新动作的状态。

## 替换角色或动画方案

如果只是把 SVG 换成同结构的 PNG，替换角色场景中的 Texture 即可。若改成逐帧、骨骼或 Live2D：

1. 新建角色场景，根节点脚本继承 `PetVisualDriver`，所有素材和动画节点放在这个场景内。
2. 实现 `execute(action, request_id, context)`，把统一动作映射到自己的动画执行函数；实现 `stop()` 来停止动画并清理回调。
3. 设置 `preferred_window_size` 和 `interaction_region`。区域使用窗口左上角为原点的坐标；动画过程中若区域改变，派发 `interaction_region_changed` 信号。
   摸头区域可设置 `head_region` 多边形，或重写 `is_head_position(window_position)`。默认驱动使用配置中的 `head_hit_uv` 椭圆、头部蒙版和透明像素，随头部节点变换计算命中；没有头部区域的驱动不触发摸头。
4. 在主场景根节点的 `visual_scene` 属性中选择新角色场景。

| 动作 | 执行约定 |
| --- | --- |
| `idle` | 循环待机，清理被打断的临时动作 |
| `blink` | 眨眼，结束后发出 `action_finished(action, request_id)` |
| `click` | 单击反馈，结束后发出 `action_finished(action, request_id)`；连续点击重启动作 |
| `head_pet_start` | 打断临时动作并持续播放摸头；等待结束事件，不报告有限动作完成 |
| `head_pet_end` | 清理摸头；管理器随后派发 `idle` |
| `drag_start` | 清理临时动作并进入被拖动的姿态 |
| `drag_end` | 恢复姿态；管理器随后派发 `idle` |

`click` 的 context 包含 `local_position`，可供新驱动区分点击了角色的哪个部位。新驱动负责取消旧 Tween、动画或 SDK 回调，管理器负责拒绝过期请求编号。替换动画驱动无需修改窗口控制或行为管理代码。

## 自动检查

运行以下命令验证驱动替换、动作优先级、旧回调隔离，以及实际 SVG 动画的完成和取消：

```sh
/Users/churui/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/churui/Project/desktop-buddy --script res://tests/action_pipeline_test.gd
/Users/churui/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/churui/Project/desktop-buddy --script res://tests/layered_cat_test.gd
```

检查也覆盖 PNG 眨眼和摸头的播放、材质恢复、动作打断，以及长按与点击、拖动、取消的手势冲突。若重新生成图片，可先用 Godot 的 `--script res://scripts/export_cat_preview.gd` 渲染三张审阅帧，再用带 Pillow 和 NumPy 的 Python 运行 `scripts/preview_cat_frames.py` 生成正常速度、慢速的透明 WebP 预览及一致性报告。`previews/.gdignore` 让审阅动画不进入 Godot 游戏资源导入。

默认分层预览由 Godot 运行 `--script res://scripts/export_layered_cat_preview.gd` 渲染，再用带 Pillow 和 NumPy 的 Python 运行 `scripts/preview_layered_cat.py --version v2`，生成 `previews/cat-layered-head-pet-v2.webp` 和静态拼装检查报告，包含淡入、抚摸循环和淡出。旧版 v1 预览保留用于对比。逐帧实验方案的预览脚本是 `export_head_pet_preview.gd` 和 `preview_head_pet.py`。

## 首版验证

先在 macOS 检查透明窗口、鼠标穿透、置顶、拖动、点击和右键退出。导出 Windows 与 Linux 后，需要在对应系统上重新检查这些窗口行为。

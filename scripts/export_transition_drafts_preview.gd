extends SceneTree

const DRAFT_DIR := "res://assets/pets/cat/transition-drafts/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i.ONE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 370)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("e6edf4")
	viewport.add_child(background)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DRAFT_DIR + "draft-manifest.json"))
	var frames: Array = [{"file": "res://assets/pets/cat/idle-base-v1.png", "head_width_estimate": 743, "opaque_bounds": [156, 139], "title": "Original idle"}]
	var titles := ["1. Lift begins", "2. Knees unfold", "3. Nearly hanging", "4. Landing contact"]
	for index in range(manifest.frames.size()):
		var frame: Dictionary = manifest.frames[index].duplicate()
		frame.file = DRAFT_DIR + frame.file
		frame.title = titles[index]
		frames.append(frame)
	for index in range(frames.size()):
		var frame: Dictionary = frames[index]
		var source := Image.load_from_file(ProjectSettings.globalize_path(frame.file))
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(source)
		sprite.centered = false
		# Calibrate by head width, preserving each pose's natural body height.
		var factor := 0.19 * 743.0 / float(frame.head_width_estimate)
		sprite.scale = Vector2.ONE * factor
		sprite.position = Vector2(index * 320 + 160 - source.get_width() * factor / 2.0, 40 - float(frame.opaque_bounds[1]) * factor)
		viewport.add_child(sprite)
		var label := Label.new()
		label.position = Vector2(index * 320 + 16, 320)
		label.text = frame.title
		label.add_theme_color_override("font_color", Color("26384a"))
		viewport.add_child(label)
	var caption := Label.new()
	caption.position = Vector2(16, 345)
	caption.text = "Pose drafts: matched head width, natural body height. Runtime head will reuse the original layer."
	caption.add_theme_color_override("font_color", Color("52677d"))
	viewport.add_child(caption)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://previews/cat-transition-keyframes-v1.png")
	quit()

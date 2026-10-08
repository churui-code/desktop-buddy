extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i.ONE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://assets/pets/cat/cat_frames.tres")
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/blink_region.gdshader")
	material.set_shader_parameter("idle_texture", sprite.sprite_frames.get_frame_texture(&"idle", 0))
	sprite.material = material
	sprite.position = Vector2(160, 160)
	sprite.scale = Vector2.ONE * 320.0 / 1254.0
	viewport.add_child(sprite)
	DirAccess.make_dir_recursive_absolute("res://previews/rendered")
	var captures := [
		{"name": "open", "animation": &"idle", "frame": 0},
		{"name": "half", "animation": &"blink", "frame": 1},
		{"name": "closed", "animation": &"blink", "frame": 2}
	]
	for capture in captures:
		sprite.animation = capture.animation
		sprite.frame = capture.frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var error := image.save_png("res://previews/rendered/%s.png" % capture.name)
		if error != OK:
			push_error("Unable to save preview frame: %s" % capture.name)
			quit(1)
			return
	print("Rendered three blink review frames using the production shader.")
	quit()

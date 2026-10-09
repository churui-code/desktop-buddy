extends SceneTree

const FRAME_DIR := "res://previews/drag-rendered"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i.ONE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var visual := load("res://scenes/pets/layered_cat_pet.tscn").instantiate() as LayeredCatPetDriver
	visual.preferred_window_size = viewport.size
	viewport.add_child(visual)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	visual.stop()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/assembled-rest.png")
	visual._dragging = true
	for step in range(5):
		visual._pickup_progress = float(step) / 4.0
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("%s/pose-%d.png" % [FRAME_DIR, step])
	# Dedicated contact render, then restore the held reference pose.
	visual._dragging = false
	visual._drag_exiting = true
	visual._release_progress = 0.875
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/landing-contact.png")
	visual._drag_exiting = false
	visual._dragging = true
	visual._pickup_progress = 1.0
	# Compare the held endpoint to the existing hanging atlas and original head.
	var held_material := visual.drag_rig.skin.material
	var reference_material := ShaderMaterial.new()
	reference_material.shader = load("res://shaders/cat_drag_skin.gdshader")
	reference_material.set_shader_parameter("regions", PackedVector2Array(CatDragRig.REGIONS))
	reference_material.set_shader_parameter("joints", PackedVector2Array(CatDragRig.JOINTS))
	reference_material.set_shader_parameter("angles", visual.drag_rig.angles)
	reference_material.set_shader_parameter("body_only", true)
	visual.drag_rig.skin.material = reference_material
	visual.drag_rig.skin.texture = visual.drag_rig.texture
	visual.drag_rig.master_tail.hide()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/held-reference.png")
	visual.drag_rig.skin.material = held_material
	visual.drag_rig.skin.texture = visual.layout.master
	visual.drag_rig.master_tail.show()
	visual.stop()
	visual.execute(PetActions.IDLE, 1, {})
	var samples: Array[Dictionary] = []
	for index in range(144):
		if index == 8:
			visual.execute(PetActions.DRAG_START, 2, {})
		if index >= 12 and index < 76:
			# Drag right/left twice, then hold still to show inertial settling.
			var phase := float(index - 12) / 64.0 * TAU * 2.0
			visual.update_drag_motion(Vector2(cos(phase) * 1000.0, 0), 1.0 / 24.0)
		elif index >= 76:
			visual.update_drag_motion(Vector2.ZERO, 1.0 / 24.0)
		if index == 106:
			visual.execute(PetActions.DRAG_END, 3, {})
			visual.execute(PetActions.IDLE, 4, {})
		await create_timer(1.0 / 24.0).timeout
		await RenderingServer.frame_post_draw
		samples.append({"posture": visual.drag_rig.posture, "body_alpha": visual.drag_rig.modulate.a, "head_alpha": visual.body_pivot.modulate.a * visual.head.modulate.a, "same_head_texture": visual.head.texture == visual.layout.master, "painted_frame": visual.transition_frames.frame_index if visual.transition_frames.visible else -1, "uniform_body_scale": is_equal_approx(visual.transition_frames.body.scale.x, visual.transition_frames.body.scale.y), "progress": visual._current_pickup_pose()})
		viewport.get_texture().get_image().save_png("%s/%03d.png" % [FRAME_DIR, index])
	var report := FileAccess.open(FRAME_DIR + "/pose-samples.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(samples))
	visual.stop()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/rest-after-drag.png")
	# An exploded preview shows the seven masks at a shared scale and origin.
	visual.visible = false
	viewport.size = Vector2i(1024, 560)
	for index in range(7):
		var part := CatDragRig.new()
		part.texture = visual.drag_rig.texture
		part.scale = Vector2.ONE * visual.layout.display_scale
		var cell := Vector2(index % 4 * 256, index / 4 * 280)
		part.position = cell + Vector2(128, 128) - (Vector2(627, 627) - part.anchor) * visual.layout.display_scale
		viewport.add_child(part)
		part.skin.visible = false
		for other in range(7):
			part.pivots[other].visible = other == index
		var label := Label.new()
		label.position = cell + Vector2(16, 251)
		label.text = CatDragRig.PART_NAMES[index]
		viewport.add_child(label)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://previews/cat-drag-parts-v5.png")
	print("Rendered split drag pose, directional swing and settling: ", FRAME_DIR)
	quit()

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
	visual._drag_amount = 1.0
	visual._update_pose()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/assembled-rest.png")
	visual.visible = false
	var reference := Sprite2D.new()
	reference.texture = visual.drag_rig.texture
	reference.position = Vector2(viewport.size) / 2.0
	reference.scale = Vector2.ONE * visual.layout.display_scale
	viewport.add_child(reference)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/master-rest.png")
	reference.queue_free()
	visual.visible = true
	visual.stop()
	visual.execute(PetActions.IDLE, 1, {})
	for index in range(120):
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
		viewport.get_texture().get_image().save_png("%s/%03d.png" % [FRAME_DIR, index])
	visual.stop()
	# An exploded preview shows the seven masks at a shared scale and origin.
	visual.visible = false
	viewport.size = Vector2i(1024, 560)
	for index in range(8):
		var part := CatDragRig.new()
		part.texture = visual.drag_rig.texture
		part.scale = Vector2.ONE * visual.layout.display_scale
		var cell := Vector2(index % 4 * 256, index / 4 * 280)
		part.position = cell + Vector2(128, 128) - (Vector2(627, 627) - part.anchor) * visual.layout.display_scale
		viewport.add_child(part)
		for other in range(7):
			part.pivots[other].visible = other == index
		part._underlay.visible = index == 7
		var label := Label.new()
		label.position = cell + Vector2(16, 251)
		label.text = CatDragRig.PART_NAMES[index] if index < 7 else "Hidden torso backing"
		viewport.add_child(label)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://previews/cat-drag-parts-v1.png")
	print("Rendered split drag pose, directional swing and settling: ", FRAME_DIR)
	quit()

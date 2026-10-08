extends SceneTree

const FRAME_DIR := "res://previews/layered-rendered"

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
	visual.stop()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/assembled-rest.png")
	# Render the same original texture at the same transform as the reference.
	visual.visible = false
	var reference := Sprite2D.new()
	reference.texture = visual.layout.master
	reference.position = Vector2(viewport.size) / 2.0
	reference.scale = Vector2.ONE * visual.layout.display_scale
	viewport.add_child(reference)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(FRAME_DIR + "/master-rest.png")
	reference.queue_free()
	visual.visible = true
	visual.execute(PetActions.IDLE, 1, {})
	for index in range(80):
		if index == 6:
			visual.execute(PetActions.HEAD_PET_START, 2, {})
		if index == 64:
			visual.execute(PetActions.HEAD_PET_END, 3, {})
			visual.execute(PetActions.IDLE, 4, {})
		await create_timer(1.0 / 24.0).timeout
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("%s/%03d.png" % [FRAME_DIR, index])
	visual.stop()
	print("Rendered master comparison and layered head petting: ", FRAME_DIR)
	quit()

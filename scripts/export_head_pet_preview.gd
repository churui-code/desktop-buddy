extends SceneTree

const FRAME_SECONDS := 1.0 / 24.0
const FRAME_DIR := "res://previews/head-pet-rendered"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i.ONE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var visual := load("res://scenes/pets/sprite_cat_pet.tscn").instantiate() as SpriteFramesPetDriver
	visual.preferred_window_size = viewport.size
	viewport.add_child(visual)
	visual.execute(PetActions.IDLE, 1, {})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	for index in range(80):
		if index == 6:
			visual.execute(PetActions.HEAD_PET_START, 2, {})
		if index == 64:
			visual.execute(PetActions.HEAD_PET_END, 3, {})
			visual.execute(PetActions.IDLE, 4, {})
		await create_timer(FRAME_SECONDS).timeout
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("%s/%03d.png" % [FRAME_DIR, index])
	visual.stop()
	print("Rendered petting entrance, stroke loop and exit: ", FRAME_DIR)
	quit()

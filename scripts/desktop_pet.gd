extends Node

const SETTINGS_PATH := "user://desktop_pet.cfg"
const MENU_RESET_POSITION := 1
const MENU_QUIT := 2

@export var visual_scene: PackedScene

@onready var action_manager: PetActionManager = $ActionManager
@onready var pet_menu: PopupMenu = $PetMenu

var visual_driver: PetVisualDriver
var window_size := Vector2i(256, 256)
var _gesture := PetPointerGesture.new()
var _press_window := Vector2i.ZERO
var _last_drag_window := Vector2i.ZERO


func _ready() -> void:
	var instance := visual_scene.instantiate()
	if not instance is PetVisualDriver:
		push_error("visual_scene must have a PetVisualDriver root.")
		instance.queue_free()
		return
	visual_driver = instance as PetVisualDriver
	add_child(visual_driver)
	window_size = visual_driver.get_preferred_window_size()
	_setup_window()
	visual_driver.interaction_region_changed.connect(_apply_interaction_region)
	action_manager.bind_driver(visual_driver)
	_gesture.action_requested.connect(action_manager.request_action)
	_gesture.drag_moved.connect(_move_window)
	_gesture.drag_finished.connect(_save_position)
	_setup_menu()
	_restore_position()
	action_manager.start()


func _process(delta: float) -> void:
	if _gesture.state == PetPointerGesture.State.RELEASED:
		return
	var mouse := DisplayServer.mouse_get_position()
	var on_head := _is_pointer_on_head(mouse)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_gesture.finish(mouse, on_head)
		return
	_gesture.update(mouse, delta, on_head)
	if _gesture.state == PetPointerGesture.State.DRAGGING:
		var displacement := get_window().position - _last_drag_window
		visual_driver.update_drag_motion(Vector2(displacement) / maxf(delta, 0.001), delta)
		_last_drag_window = get_window().position


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			_press_window = get_window().position
			_last_drag_window = _press_window
			_gesture.begin(DisplayServer.mouse_get_position(), mouse_event.position, visual_driver.is_head_position(mouse_event.position))
		else:
			var mouse := DisplayServer.mouse_get_position()
			_gesture.finish(mouse, _is_pointer_on_head(mouse))
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		_gesture.cancel()
		pet_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ONE))


func _is_pointer_on_head(mouse: Vector2i) -> bool:
	return visual_driver.is_head_position(_gesture.get_pointer_local_position(mouse))


func _move_window(displacement: Vector2i) -> void:
	var mouse := DisplayServer.mouse_get_position()
	get_window().position = _clamp_position(_press_window + displacement, _screen_for(mouse))


func _setup_window() -> void:
	var window := get_window()
	window.size = window_size
	window.borderless = true
	window.always_on_top = true
	window.transparent = true
	window.transparent_bg = true
	window.unresizable = true
	_apply_interaction_region(visual_driver.get_interaction_region())


func _apply_interaction_region(region: PackedVector2Array) -> void:
	DisplayServer.window_set_mouse_passthrough(region)


func _setup_menu() -> void:
	pet_menu.add_item("Reset position", MENU_RESET_POSITION)
	pet_menu.add_separator()
	pet_menu.add_item("Quit", MENU_QUIT)
	pet_menu.id_pressed.connect(_on_menu_item_pressed)


func _on_menu_item_pressed(id: int) -> void:
	match id:
		MENU_RESET_POSITION:
			get_window().position = _default_position()
			_save_position()
		MENU_QUIT:
			_save_position()
			action_manager.stop()
			get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_gesture.cancel()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_position()
		action_manager.stop()
		get_tree().quit()


func _restore_position() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		var saved_position: Variant = settings.get_value("window", "position", Vector2i.ZERO)
		if saved_position is Vector2i:
			var saved_screen := _screen_for(saved_position + window_size / 2)
			if saved_screen.has_point(saved_position + window_size / 2):
				get_window().position = _clamp_position(saved_position, saved_screen)
				return
	get_window().position = _default_position()


func _save_position() -> void:
	var settings := ConfigFile.new()
	settings.set_value("window", "position", get_window().position)
	settings.save(SETTINGS_PATH)


func _default_position() -> Vector2i:
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	return _clamp_position(screen.end - window_size - Vector2i(24, 16), screen)


func _screen_for(point: Vector2i) -> Rect2i:
	for index in range(DisplayServer.get_screen_count()):
		var screen := DisplayServer.screen_get_usable_rect(index)
		if screen.has_point(point):
			return screen
	return DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())


func _clamp_position(candidate: Vector2i, screen: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(candidate.x, screen.position.x, maxi(screen.position.x, screen.end.x - window_size.x)),
		clampi(candidate.y, screen.position.y, maxi(screen.position.y, screen.end.y - window_size.y))
	)

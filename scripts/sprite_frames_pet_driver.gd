class_name SpriteFramesPetDriver
extends PetVisualDriver

## Ellipse in the idle texture's normalized coordinates, filtered by alpha.
@export var head_pet_region_uv := Rect2(0.22, 0.10, 0.64, 0.50)
@export var petting_material: ShaderMaterial

@onready var art: Node2D = $Art
@onready var sprite: AnimatedSprite2D = $Art/Sprite
@onready var _blink_material: Material = sprite.material
@onready var petting_hand: Node2D = $PettingHand

var _rest_position := Vector2.ZERO
var _breathing_tween: Tween
var _reaction_tween: Tween
var _active_action: StringName = &""
var _active_request_id := 0
var _computed_interaction_region := PackedVector2Array()
var _idle_image: Image
var _petting_tween: Tween
var _petting_amount := 0.0
var _petting_exiting := false
var _hand_rest := Vector2.ZERO


func _ready() -> void:
	position = Vector2(preferred_window_size) / 2.0
	_rest_position = art.position
	_hand_rest = petting_hand.position
	petting_material = petting_material.duplicate() as ShaderMaterial
	sprite.animation_finished.connect(_on_animation_finished)
	_cache_interaction_region()


func _process(_delta: float) -> void:
	if sprite.animation == &"head_pet":
		_update_pet_visual()


func execute(action: StringName, request_id: int, _context: Dictionary) -> void:
	match action:
		PetActions.IDLE:
			_play_idle()
		PetActions.BLINK:
			_play_blink(request_id)
		PetActions.CLICK:
			_play_click(request_id)
		PetActions.HEAD_PET_START:
			_play_head_pet(request_id)
		PetActions.HEAD_PET_END:
			_end_head_pet()
		PetActions.DRAG_START:
			_play_drag_start()
		PetActions.DRAG_END:
			art.modulate = Color.WHITE
			action_finished.emit(action, request_id)


func stop() -> void:
	_cancel_foreground()
	_kill_tween(_breathing_tween)
	_breathing_tween = null
	art.scale = Vector2.ONE
	art.modulate = Color.WHITE


func get_interaction_region() -> PackedVector2Array:
	if not interaction_region.is_empty():
		return interaction_region
	return _computed_interaction_region


func is_head_position(window_position: Vector2) -> bool:
	if not head_region.is_empty():
		return super.is_head_position(window_position)
	var image_size := Vector2(_idle_image.get_size())
	var pixel := sprite.to_local(window_position) + image_size / 2.0
	var uv := pixel / image_size
	if not head_pet_region_uv.has_point(uv):
		return false
	var ellipse := (uv - head_pet_region_uv.get_center()) / (head_pet_region_uv.size / 2.0)
	if ellipse.length_squared() > 1.0:
		return false
	return _idle_image.get_pixelv(Vector2i(pixel)).a >= 0.2


func _play_idle() -> void:
	# The manager resumes idle immediately; let the driver's visual exit finish.
	if _petting_exiting:
		return
	_cancel_foreground()
	art.modulate = Color.WHITE
	sprite.play(&"idle")
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.play()
	else:
		# The Art pivot is at the paws, so breathing keeps the baseline stable.
		_breathing_tween = create_tween().set_loops()
		_breathing_tween.tween_property(art, "scale", Vector2(1.008, 0.985), 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breathing_tween.tween_property(art, "scale", Vector2.ONE, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_blink(request_id: int) -> void:
	if _petting_exiting:
		return
	_cancel_foreground()
	_active_action = PetActions.BLINK
	_active_request_id = request_id
	sprite.play(&"blink")
	sprite.set_frame_and_progress(0, 0.0)


func _play_click(request_id: int) -> void:
	_cancel_foreground()
	_active_action = PetActions.CLICK
	_active_request_id = request_id
	sprite.play(&"idle")
	_reaction_tween = create_tween()
	_reaction_tween.tween_property(art, "position:y", _rest_position.y - 14.0, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(art, "position:y", _rest_position.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_reaction_tween.finished.connect(func() -> void:
		if _active_action == PetActions.CLICK and _active_request_id == request_id:
			_active_action = &""
			_active_request_id = 0
			action_finished.emit(PetActions.CLICK, request_id)
	)


func _play_head_pet(request_id: int) -> void:
	_cancel_foreground()
	_active_action = PetActions.HEAD_PET_START
	_active_request_id = request_id
	sprite.material = petting_material
	art.modulate = Color.WHITE
	sprite.play(&"head_pet")
	sprite.set_frame_and_progress(0, 0.0)
	petting_hand.visible = true
	_update_pet_visual()
	_petting_tween = create_tween()
	_petting_tween.tween_property(self, "_petting_amount", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _end_head_pet() -> void:
	if sprite.animation != &"head_pet":
		return
	_kill_tween(_petting_tween)
	_petting_exiting = true
	_petting_tween = create_tween()
	_petting_tween.tween_property(self, "_petting_amount", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_petting_tween.finished.connect(func() -> void:
		_petting_exiting = false
		_play_idle()
	)


func _update_pet_visual() -> void:
	var progress := smoothstep(0.0, 1.0, sprite.frame_progress)
	var next_frame := (sprite.frame + 1) % sprite.sprite_frames.get_frame_count(&"head_pet")
	petting_material.set_shader_parameter("next_pose_texture", sprite.sprite_frames.get_frame_texture(&"head_pet", next_frame))
	petting_material.set_shader_parameter("frame_blend", progress)
	petting_material.set_shader_parameter("petting_amount", _petting_amount)
	# Two cat frames travel neutral -> right -> neutral. Hand motion uses the
	# same phase, with clockwise/downward motion on the rightward stroke.
	var rightward := progress if sprite.frame == 0 else 1.0 - progress
	petting_hand.position = _hand_rest + Vector2(lerpf(-4.0, 4.0, rightward), rightward * 1.8)
	petting_hand.position += Vector2(18.0, -14.0) * (1.0 - _petting_amount)
	petting_hand.rotation = lerpf(-0.025, 0.045, rightward)
	petting_hand.modulate.a = _petting_amount


func _play_drag_start() -> void:
	_cancel_foreground()
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.pause()
	art.scale = Vector2.ONE
	art.modulate = Color(0.92, 0.92, 0.92, 1.0)


func _on_animation_finished() -> void:
	if sprite.animation == &"blink" and _active_action == PetActions.BLINK:
		var request_id := _active_request_id
		_active_action = &""
		_active_request_id = 0
		sprite.play(&"idle")
		action_finished.emit(PetActions.BLINK, request_id)


func _cancel_foreground() -> void:
	_active_action = &""
	_active_request_id = 0
	_kill_tween(_reaction_tween)
	_reaction_tween = null
	_kill_tween(_petting_tween)
	_petting_tween = null
	_petting_exiting = false
	_petting_amount = 0.0
	petting_hand.visible = false
	petting_hand.position = _hand_rest
	petting_hand.rotation = 0.0
	sprite.stop()
	sprite.material = _blink_material
	sprite.animation = &"idle"
	sprite.frame = 0
	art.position = _rest_position


func _cache_interaction_region() -> void:
	var texture := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	var image := texture.get_image()
	_idle_image = image
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.2)
	var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 6.0)
	var largest := PackedVector2Array()
	var largest_area := 0.0
	for polygon in polygons:
		var area := _polygon_area(polygon)
		if area > largest_area:
			largest_area = area
			largest = polygon
	for point in largest:
		_computed_interaction_region.append(sprite.to_global(point - Vector2(image.get_size()) / 2.0))


func _polygon_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(polygon.size()):
		total += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(total) / 2.0


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

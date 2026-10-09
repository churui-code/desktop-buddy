class_name LayeredCatPetDriver
extends PetVisualDriver

@export var layout: CatRigLayout

@onready var rig: Node2D = $Rig
@onready var body_pivot: Node2D = $Rig/BodyPivot
@onready var tail_pivot: Node2D = $Rig/BodyPivot/TailPivot
@onready var head_pivot: Node2D = $Rig/BodyPivot/HeadPivot
@onready var head: Sprite2D = $Rig/BodyPivot/HeadPivot/Head
@onready var eyes: Sprite2D = $Rig/BodyPivot/HeadPivot/Eyes
@onready var neck_fill: Polygon2D = $Rig/BodyPivot/NeckFill
@onready var petting_hand: Node2D = $Rig/BodyPivot/PettingHand

var _master_image: Image
var _computed_region := PackedVector2Array()
var _eye_material: ShaderMaterial
var _blink_tween: Tween
var _click_tween: Tween
var _pet_tween: Tween
var _pet_amount := 0.0
var _eye_closure := 0.0
var _stroke_time := 0.0
var _idle_time := 0.0
var _pet_exiting := false
var _dragging := false
var _running := false
var _active_action: StringName = &""
var _active_id := 0
var drag_rig: CatDragRig
var transition_frames: CatTransitionFrames
var _drag_tween: Tween
var _drag_amount := 0.0
var _drag_exiting := false
var _release_from_pickup := 1.0
var _pickup_progress := 0.0:
	set(value):
		_pickup_progress = value
		if is_instance_valid(drag_rig):
			_update_pose()
var _release_progress := 1.0:
	set(value):
		_release_progress = value
		if is_instance_valid(drag_rig):
			_update_pose()
var _body_offset_y := 0.0
var _pose_blend_tween: Tween
var _pose_blend_amount := 0.0
var _pose_snapshot := {}


func _ready() -> void:
	position = Vector2(preferred_window_size) / 2.0
	rig.scale = Vector2.ONE * layout.display_scale
	rig.position = -Vector2(layout.master.get_size()) * layout.display_scale / 2.0
	body_pivot.position = layout.body_joint
	head_pivot.position = layout.head_joint - layout.body_joint
	tail_pivot.position = layout.tail_joint - layout.body_joint
	petting_hand.position = layout.glove_joint - layout.body_joint
	_setup_part($Rig/BodyPivot/Body, layout.body_joint, 0)
	_setup_part(head, layout.head_joint, 1)
	_setup_part($Rig/BodyPivot/TailPivot/Tail, layout.tail_joint, 2)
	_setup_eyes()
	var glove := $Rig/BodyPivot/PettingHand/Glove as Sprite2D
	glove.texture = layout.glove
	glove.scale = Vector2.ONE * layout.glove_scale
	glove.position = -layout.glove_source_joint * layout.glove_scale
	_setup_neck_fill()
	_master_image = layout.master.get_image()
	_cache_interaction_region()
	drag_rig = CatDragRig.new()
	drag_rig.texture = preload("res://assets/pets/cat/drag-scruff-keyframe-v1.png")
	drag_rig.seated_master = layout.master
	drag_rig.position = drag_rig.anchor
	rig.add_child(drag_rig)
	drag_rig.set_body_only(true)
	$Rig/BodyPivot/Body.hide()
	$Rig/BodyPivot/TailPivot/Tail.hide()
	head_pivot.z_index = 1
	transition_frames = CatTransitionFrames.new()
	rig.add_child(transition_frames)
	_update_pose()


func _process(delta: float) -> void:
	if not _running:
		return
	if not _dragging:
		_idle_time += delta
		if _pet_amount > 0.0:
			_stroke_time += delta
	if _dragging or _drag_exiting:
		drag_rig.advance(delta)
	_update_pose()


func execute(action: StringName, request_id: int, _context: Dictionary) -> void:
	_running = true
	match action:
		PetActions.IDLE:
			_play_idle()
		PetActions.BLINK:
			if not _pet_exiting and not _drag_exiting:
				_play_blink(request_id)
		PetActions.CLICK:
			_play_click(request_id)
		PetActions.HEAD_PET_START:
			_start_pet(request_id)
		PetActions.HEAD_PET_END:
			_end_pet()
		PetActions.DRAG_START:
			_start_drag()
		PetActions.DRAG_END:
			_end_drag(request_id)
	_update_pose()


func _play_idle() -> void:
	if not _pet_exiting and not _drag_exiting:
		_cancel_foreground()
		body_pivot.modulate = Color.WHITE


func _start_drag() -> void:
	var resume_progress := _current_pickup_pose()
	var retained_angles := drag_rig.angles.duplicate()
	var retained_speeds := drag_rig.angular_speeds.duplicate()
	_cancel_foreground(true)
	_dragging = true
	_pickup_progress = resume_progress
	_release_progress = 0.0
	drag_rig.angles = retained_angles
	drag_rig.angular_speeds = retained_speeds
	_drag_tween = create_tween()
	interaction_region_changed.emit(PackedVector2Array([Vector2.ZERO, Vector2(preferred_window_size.x, 0), Vector2(preferred_window_size), Vector2(0, preferred_window_size.y)]))
	if resume_progress >= 1.0:
		_drag_tween.tween_interval(0.14)
		return
	# Painted key poses run forward; regrab continues from the actual frame.
	_drag_tween.tween_property(self, "_pickup_progress", 1.0, 0.54 * (1.0 - resume_progress)).set_trans(Tween.TRANS_LINEAR)
	# Held pose is advanced by the inertia rig, until an explicit end event.


func _end_drag(request_id: int) -> void:
	_release_from_pickup = _pickup_progress
	_dragging = false
	_drag_exiting = true
	_kill_tween(_drag_tween)
	drag_rig.set_drag_velocity(Vector2.ZERO)
	_drag_tween = create_tween()
	# Reverse the painted poses, then use the dedicated contact frame.
	_drag_tween.tween_property(self, "_release_progress", 0.75, maxf(0.10, 0.42 * _release_from_pickup)).set_trans(Tween.TRANS_LINEAR)
	_drag_tween.tween_property(self, "_release_progress", 1.0, 0.18).set_trans(Tween.TRANS_LINEAR)
	_drag_tween.finished.connect(func() -> void:
		_drag_exiting = false
		_drag_amount = 0.0
		_pickup_progress = 0.0
		drag_rig.reset_motion()
		_update_pose()
		interaction_region_changed.emit(get_interaction_region())
	)
	_idle_time = 0.0
	action_finished.emit(PetActions.DRAG_END, request_id)


func stop() -> void:
	_cancel_foreground()
	_running = false
	_dragging = false
	_idle_time = 0.0
	body_pivot.modulate = Color.WHITE
	_update_pose()
	interaction_region_changed.emit(get_interaction_region())


func update_drag_motion(velocity: Vector2, _delta: float) -> void:
	if _dragging:
		drag_rig.set_drag_velocity(velocity)


func get_interaction_region() -> PackedVector2Array:
	return interaction_region if not interaction_region.is_empty() else _computed_region


func is_head_position(window_position: Vector2) -> bool:
	if _dragging or _drag_exiting:
		return false
	if not head_region.is_empty():
		return super.is_head_position(window_position)
	var pixel := head.to_local(window_position)
	var size := Vector2(_master_image.get_size())
	var uv := pixel / size
	if not layout.head_hit_uv.has_point(uv):
		return false
	var ellipse := (uv - layout.head_hit_uv.get_center()) / (layout.head_hit_uv.size / 2.0)
	return ellipse.length_squared() <= 1.0 and pixel.y < layout.head_cut_y(pixel.x) and _master_image.get_pixelv(Vector2i(pixel)).a >= 0.2


func _setup_part(sprite: Sprite2D, joint: Vector2, layer: int) -> void:
	sprite.texture = layout.master
	sprite.position = -joint
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/cat_master_layer.gdshader")
	material.set_shader_parameter("layer", layer)
	material.set_shader_parameter("head_cut", layout.head_cut)
	material.set_shader_parameter("tail_cut", layout.tail_cut)
	material.set_shader_parameter("left_region", layout.eye_left)
	material.set_shader_parameter("right_region", layout.eye_right)
	sprite.material = material


func _setup_eyes() -> void:
	eyes.texture = layout.master
	eyes.position = -layout.head_joint
	_eye_material = ShaderMaterial.new()
	_eye_material.shader = load("res://shaders/cat_eye_layer.gdshader")
	_eye_material.set_shader_parameter("half_eyes", layout.half_eyes)
	_eye_material.set_shader_parameter("closed_eyes", layout.closed_eyes)
	_eye_material.set_shader_parameter("left_region", layout.eye_left)
	_eye_material.set_shader_parameter("right_region", layout.eye_right)
	eyes.material = _eye_material


func _setup_neck_fill() -> void:
	# Hidden under the head at rest. Reuse existing chest pixels for the small
	# area exposed by a small tilt; this does not redraw the character.
	var points := PackedVector2Array([Vector2(380, 745), Vector2(450, 715), Vector2(627, 710), Vector2(804, 715), Vector2(874, 745), Vector2(850, 795), Vector2(404, 795)])
	var uvs := PackedVector2Array()
	for index in range(points.size()):
		uvs.append(Vector2(450.0 + (points[index].x - 380.0) * 0.72, points[index].y + 90.0))
		points[index] -= layout.body_joint
	neck_fill.polygon = points
	neck_fill.uv = uvs
	neck_fill.texture = layout.master
	neck_fill.visible = false


func _update_pose() -> void:
	var visual_pet_amount := lerpf(_pet_amount, _pose_snapshot.get("pet", 0.0), _pose_blend_amount)
	_drag_amount = _current_pickup_pose()
	var moving := _dragging or _drag_exiting
	var contact_weight := sin(clampf((_release_progress - 0.75) / 0.25, 0.0, 1.0) * PI) if _drag_exiting else 0.0
	# Select an opaque painted body or an endpoint. Never morph UVs between
	# sitting and hanging, and never fit their different heights to one box.
	var painted := moving and ((_drag_amount > 0.11 and _drag_amount < 0.89) or contact_weight > 0.001)
	var held := moving and _drag_amount >= 0.89
	body_pivot.visible = true
	body_pivot.modulate = Color.WHITE
	drag_rig.visible = not painted
	drag_rig.modulate = Color.WHITE
	transition_frames.visible = painted
	var breath := (1.0 - cos(_idle_time * TAU / 2.6)) / 2.0 if _running and not moving else 0.0
	body_pivot.scale = Vector2(1.0 + breath * 0.005, 1.0 - breath * 0.008)
	body_pivot.position = layout.body_joint + Vector2(0, _body_offset_y)
	tail_pivot.rotation = sin(_idle_time * TAU / 3.2) * 0.025 if _running and not _dragging else 0.0
	var rightward := (1.0 - cos(_stroke_time * TAU / layout.stroke_period)) / 2.0
	var head_angle := lerpf(layout.head_angles.x, layout.head_angles.y, rightward) * visual_pet_amount
	if _pose_blend_amount > 0.0:
		body_pivot.position = body_pivot.position.lerp(_pose_snapshot["position"], _pose_blend_amount)
		body_pivot.scale = body_pivot.scale.lerp(_pose_snapshot["scale"], _pose_blend_amount)
	drag_rig.set_posture(1.0 if held else 0.0)
	drag_rig.set_lift_pose(0.0)
	drag_rig.set_idle_tail(tail_pivot.rotation)
	var seated_root := body_pivot.position + body_pivot.scale * (drag_rig.anchor - layout.body_joint)
	drag_rig.position = seated_root
	drag_rig.scale = body_pivot.scale
	drag_rig.rotation = 0.0
	var seated_head := body_pivot.position + body_pivot.scale * (layout.head_joint - layout.body_joint)
	var head_position := seated_head
	var head_scale := body_pivot.scale
	var motion_angle := 0.0
	if moving:
		motion_angle = drag_rig.angles[0] * _drag_amount
		transition_frames.display_pose(_drag_amount, contact_weight, motion_angle)
		head_position = transition_frames.neck_position + Vector2(sin(motion_angle) * 100.0, 0)
		transition_frames.position = head_position
		head_scale = Vector2.ONE
		if held:
			drag_rig.scale = Vector2.ONE * CatTransitionFrames.HELD_SCALE
			drag_rig.rotation = motion_angle
			var neck_offset := CatTransitionFrames.HELD_NECK - drag_rig.anchor
			drag_rig.position = head_position - Transform2D(motion_angle, drag_rig.scale, 0.0, Vector2.ZERO) * neck_offset
	var head_transform := Transform2D(head_angle * (1.0 - _drag_amount) + motion_angle, head_scale, 0.0, head_position)
	if _pose_blend_amount > 0.0:
		head_transform = head_transform.interpolate_with(_pose_snapshot["head_transform"], _pose_blend_amount)
	head_pivot.transform = body_pivot.transform.affine_inverse() * head_transform
	# All facial patches inherit the head's transform, so no frame silhouette
	# blending or double ear outlines occur.
	var closure := maxf(lerpf(_eye_closure, _pose_snapshot.get("eyes", 0.0), _pose_blend_amount), visual_pet_amount)
	_eye_material.set_shader_parameter("closure", closure)
	neck_fill.visible = visual_pet_amount > 0.001
	petting_hand.visible = visual_pet_amount > 0.001
	petting_hand.position = layout.glove_joint - layout.body_joint
	petting_hand.position += Vector2(lerpf(-layout.stroke_span / 2.0, layout.stroke_span / 2.0, rightward), rightward * layout.stroke_drop)
	petting_hand.position += layout.entry_offset * (1.0 - visual_pet_amount)
	petting_hand.rotation = lerpf(layout.hand_angles.x, layout.hand_angles.y, rightward)
	petting_hand.modulate.a = visual_pet_amount


func _current_pickup_pose() -> float:
	if _dragging:
		return _pickup_progress
	if _drag_exiting:
		return _release_from_pickup * (1.0 - clampf(_release_progress / 0.75, 0.0, 1.0))
	return 0.0


func _play_blink(request_id: int) -> void:
	_cancel_foreground(true)
	_active_action = PetActions.BLINK
	_active_id = request_id
	_blink_tween = create_tween()
	_blink_tween.tween_property(self, "_eye_closure", 1.0, 0.08)
	_blink_tween.tween_interval(0.08)
	_blink_tween.tween_property(self, "_eye_closure", 0.0, 0.08)
	_blink_tween.finished.connect(func() -> void:
		if _active_action == PetActions.BLINK and _active_id == request_id:
			_active_action = &""
			_active_id = 0
			action_finished.emit(PetActions.BLINK, request_id)
	)


func _play_click(request_id: int) -> void:
	_cancel_foreground(true)
	_active_action = PetActions.CLICK
	_active_id = request_id
	_click_tween = create_tween()
	_click_tween.tween_property(self, "_body_offset_y", -74.0, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_click_tween.tween_property(self, "_body_offset_y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_click_tween.finished.connect(func() -> void:
		if _active_action == PetActions.CLICK and _active_id == request_id:
			_active_action = &""
			_active_id = 0
			action_finished.emit(PetActions.CLICK, request_id)
	)


func _start_pet(request_id: int) -> void:
	_cancel_foreground(true)
	_active_action = PetActions.HEAD_PET_START
	_active_id = request_id
	_stroke_time = 0.0
	_pet_tween = create_tween()
	_pet_tween.tween_property(self, "_pet_amount", 1.0, layout.enter_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _end_pet() -> void:
	if _active_action != PetActions.HEAD_PET_START:
		return
	_kill_tween(_pet_tween)
	_pet_exiting = true
	_pet_tween = create_tween()
	_pet_tween.tween_property(self, "_pet_amount", 0.0, layout.exit_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pet_tween.finished.connect(func() -> void:
		_pet_exiting = false
		_cancel_foreground()
		_update_pose()
	)


func _cancel_foreground(blend_to_next := false) -> void:
	var snapshot := {"position": body_pivot.position, "scale": body_pivot.scale, "head_transform": body_pivot.transform * head_pivot.transform, "pet": petting_hand.modulate.a if petting_hand.visible else 0.0, "eyes": _eye_material.get_shader_parameter("closure"), "drag": drag_rig.posture if is_instance_valid(drag_rig) else 0.0}
	if snapshot["drag"] > 0.05:
		snapshot["angles"] = drag_rig.angles.duplicate()
		snapshot["speeds"] = drag_rig.angular_speeds.duplicate()
	_kill_tween(_pose_blend_tween)
	_pose_blend_amount = 0.0
	_kill_tween(_drag_tween)
	_drag_tween = null
	_drag_exiting = false
	_drag_amount = 0.0
	_pickup_progress = 0.0
	_release_progress = 1.0
	_dragging = false
	if is_instance_valid(drag_rig):
		drag_rig.reset_motion()
		interaction_region_changed.emit(get_interaction_region())
	_kill_tween(_blink_tween)
	_kill_tween(_click_tween)
	_kill_tween(_pet_tween)
	_blink_tween = null
	_click_tween = null
	_pet_tween = null
	_active_action = &""
	_active_id = 0
	_pet_exiting = false
	_pet_amount = 0.0
	_eye_closure = 0.0
	body_pivot.position = layout.body_joint
	_body_offset_y = 0.0
	if blend_to_next:
		_pose_snapshot = snapshot
		_pose_blend_amount = 1.0
		_pose_blend_tween = create_tween()
		_pose_blend_tween.tween_property(self, "_pose_blend_amount", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if snapshot["drag"] > 0.05:
			drag_rig.angles = snapshot["angles"]
			drag_rig.angular_speeds = snapshot["speeds"]
			drag_rig.advance(0.0)


func _cache_interaction_region() -> void:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(_master_image, 0.2)
	var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, _master_image.get_size()), 6.0)
	var largest := PackedVector2Array()
	var max_area := 0.0
	for polygon in polygons:
		var area := 0.0
		for index in range(polygon.size()):
			area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
		if absf(area) > max_area:
			max_area = absf(area)
			largest = polygon
	# The folded mesh has a slightly different foot/tail outline from the master.
	# Include its seated envelope so visible paws also accept dragging.
	var seated_body := PackedVector2Array([Vector2(300, 800), Vector2(910, 800), Vector2(980, 1080), Vector2(845, 1165), Vector2(435, 1165), Vector2(170, 1075), Vector2(145, 1000), Vector2(200, 930)])
	var merged := Geometry2D.merge_polygons(largest, seated_body)
	if merged.size() == 1:
		largest = merged[0]
	for point in largest:
		_computed_region.append(head.to_global(point))


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

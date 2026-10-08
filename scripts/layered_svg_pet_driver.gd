class_name LayeredSvgPetDriver
extends PetVisualDriver

@onready var body_root: Node2D = $BodyRoot
@onready var tail_pivot: Node2D = $BodyRoot/TailPivot
@onready var eyes: Sprite2D = $BodyRoot/Eyes
@onready var sparkle: Sprite2D = $BodyRoot/Sparkle
@onready var breathing_animation: AnimationPlayer = $BreathingAnimation

var _blink_tween: Tween
var _reaction_tween: Tween
var _sparkle_tween: Tween
var _tail_tween: Tween


func _ready() -> void:
	position = Vector2(preferred_window_size) / 2.0
	_setup_breathing_animation()


func execute(action: StringName, request_id: int, _context: Dictionary) -> void:
	match action:
		PetActions.IDLE:
			_play_idle()
		PetActions.BLINK:
			_play_blink(request_id)
		PetActions.CLICK:
			_play_click(request_id)
		PetActions.DRAG_START:
			_play_drag_start()
		PetActions.DRAG_END:
			body_root.modulate = Color.WHITE
			action_finished.emit(action, request_id)


func stop() -> void:
	_cancel_transient_actions()
	breathing_animation.stop()
	_kill_tween(_tail_tween)
	_tail_tween = null
	body_root.scale = Vector2.ONE
	body_root.modulate = Color.WHITE
	tail_pivot.rotation = 0.0


func _play_idle() -> void:
	_cancel_transient_actions()
	body_root.modulate = Color.WHITE
	breathing_animation.play("breathe")
	if _tail_tween and _tail_tween.is_valid():
		_tail_tween.play()
	else:
		_tail_tween = create_tween().set_loops()
		_tail_tween.tween_property(tail_pivot, "rotation", 0.12, 1.1).set_trans(Tween.TRANS_SINE)
		_tail_tween.tween_property(tail_pivot, "rotation", -0.08, 1.2).set_trans(Tween.TRANS_SINE)
		_tail_tween.tween_property(tail_pivot, "rotation", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _setup_breathing_animation() -> void:
	var animation := Animation.new()
	animation.length = 2.4
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("BodyRoot:scale"))
	animation.track_insert_key(track, 0.0, Vector2.ONE)
	animation.track_insert_key(track, 1.2, Vector2(1.025, 0.975))
	animation.track_insert_key(track, 2.4, Vector2.ONE)
	var library := AnimationLibrary.new()
	library.add_animation("breathe", animation)
	breathing_animation.add_animation_library("", library)


func _play_blink(request_id: int) -> void:
	_kill_tween(_blink_tween)
	eyes.scale = Vector2.ONE
	_blink_tween = create_tween()
	_blink_tween.tween_property(eyes, "scale:y", 0.08, 0.07)
	_blink_tween.tween_property(eyes, "scale:y", 1.0, 0.11)
	_blink_tween.finished.connect(func() -> void:
		action_finished.emit(PetActions.BLINK, request_id)
	)


func _play_click(request_id: int) -> void:
	_cancel_transient_actions()
	_reaction_tween = create_tween()
	_reaction_tween.tween_property(body_root, "position:y", -14.0, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(body_root, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	sparkle.visible = true
	sparkle.scale = Vector2(0.35, 0.35)
	sparkle.modulate = Color(1, 1, 1, 0)
	_sparkle_tween = create_tween().set_parallel(true)
	_sparkle_tween.tween_property(sparkle, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sparkle_tween.tween_property(sparkle, "modulate:a", 1.0, 0.12)
	_sparkle_tween.chain().tween_property(sparkle, "modulate:a", 0.0, 0.23)
	_sparkle_tween.finished.connect(func() -> void:
		sparkle.visible = false
		action_finished.emit(PetActions.CLICK, request_id)
	)


func _play_drag_start() -> void:
	_cancel_transient_actions()
	breathing_animation.pause()
	if _tail_tween and _tail_tween.is_valid():
		_tail_tween.pause()
	body_root.scale = Vector2(0.98, 1.02)
	body_root.modulate = Color(0.92, 0.92, 0.92, 1.0)


func _cancel_transient_actions() -> void:
	_kill_tween(_blink_tween)
	_kill_tween(_reaction_tween)
	_kill_tween(_sparkle_tween)
	_blink_tween = null
	_reaction_tween = null
	_sparkle_tween = null
	eyes.scale = Vector2.ONE
	body_root.position = Vector2.ZERO
	sparkle.visible = false


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

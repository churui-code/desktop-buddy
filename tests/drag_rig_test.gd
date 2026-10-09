extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cat := load("res://scenes/pets/layered_cat_pet.tscn").instantiate() as LayeredCatPetDriver
	root.add_child(cat)
	cat.set_process(false)
	var rig := cat.drag_rig
	_check(rig.pivots.size() == 7, "Head, torso, four limbs and tail have independent joints.")
	for pivot in rig.pivots:
		_check(pivot.get_child(0).texture == rig.texture, "All parts retain the same pose texture and scale.")
	for index in range(30):
		rig.set_drag_velocity(Vector2(1000, 0))
		rig.advance(1.0 / 60.0)
	var before := rig.angles.duplicate()
	_check(before[0] > 0.05 and before[5] > 0.1, "Window velocity drives the body and tail.")
	_check(absf(before[1] - before[4]) > 0.005, "Front and hind legs respond at different rates.")
	rig.set_drag_velocity(Vector2(-1000, 0))
	rig.advance(1.0 / 60.0)
	_check(rig.angles[0] > 0.0 and rig.angles[5] > 0.0, "Direction reversal preserves inertia instead of flipping the pose.")
	for index in range(40):
		rig.set_drag_velocity(Vector2(-1000, 0))
		rig.advance(1.0 / 60.0)
	_check(rig.angles[0] < -0.05 and rig.angles[5] < -0.1, "Sustained reverse movement eventually swings the other way.")
	rig.set_drag_velocity(Vector2.ZERO)
	var stopped_angle := rig.angles[5]
	rig.advance(1.0 / 60.0)
	_check(absf(rig.angles[5]) > 0.05 and rig.angles[5] != stopped_angle, "A stationary pointer retains residual swing.")
	for index in range(240):
		rig.advance(1.0 / 60.0)
	_check(absf(rig.angles[5]) < 0.001, "Damping settles the tail after the pointer stops.")
	for index in range(60):
		rig.set_drag_velocity(Vector2(1e8, 0))
		rig.advance(2.0)
	_check(absf(rig.angles[5]) <= rig.max_tail_angle * 1.35 and is_finite(rig.angles[5]), "Fast movement and frame stalls keep the spring bounded.")
	cat.execute(PetActions.HEAD_PET_START, 1, {})
	cat.execute(PetActions.DRAG_START, 2, {})
	await cat._pose_blend_tween.finished
	cat._pickup_progress = 0.10
	_check(cat.body_pivot.scale.y < 1.0 and cat._drag_amount == 0.0, "Pickup starts with a compression before switching artwork.")
	cat._pickup_progress = 0.40
	_check(cat.body_pivot.position.y < cat.layout.body_joint.y and cat.body_pivot.scale.y > 1.0, "Pickup lifts and stretches the seated body.")
	await cat._drag_tween.finished
	cat._update_pose()
	_check(cat.drag_rig.visible and not cat.body_pivot.visible and not cat.petting_hand.visible, "Dragging swaps to the hanging rig and cancels the glove.")
	cat.execute(PetActions.DRAG_END, 3, {})
	cat.execute(PetActions.IDLE, 4, {})
	_check(cat._drag_exiting, "Manager idle does not interrupt drag release.")
	cat._release_progress = 0.78
	_check(cat.body_pivot.visible and cat.body_pivot.scale.y < 0.95, "Release compresses the landing pose before its rebound.")
	cat._release_progress = 0.30
	var regrab_position := cat.drag_rig.position
	cat.execute(PetActions.DRAG_START, 5, {})
	_check(is_equal_approx(cat._pickup_progress, 1.0) and cat.drag_rig.position.is_equal_approx(regrab_position), "Regrabbing a hanging cat preserves its current pose instead of restarting pickup.")
	await cat._drag_tween.finished
	await create_timer(0.3).timeout
	_check(cat._dragging and is_equal_approx(cat._drag_amount, 1.0), "An old release cannot hide a newly started drag.")
	cat.stop()
	_check(not cat.drag_rig.visible and cat.body_pivot.visible and is_zero_approx(rig.rotation), "Stopping restores idle artwork and clears inertia.")
	cat.free()
	if failures == 0:
		print("PASS: split drag rig, velocity response, independent inertia, reversal, settling, bounds and cancellation.")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

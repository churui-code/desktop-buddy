extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cat := load("res://scenes/pets/layered_cat_pet.tscn").instantiate() as LayeredCatPetDriver
	root.add_child(cat)
	cat.set_process(false)
	var rig := cat.drag_rig
	_check(rig.skin.texture == cat.layout.master and rig.master_tail.texture == cat.layout.master, "Seated limbs and the separate tail retain the original idle atlas.")
	for index in range(60):
		cat._idle_time = float(index) / 10.0
		cat._update_pose()
		_check(rig.posture == 0.0 and rig.master_tail.transform.is_equal_approx(Transform2D(0, -rig.anchor)), "Idle breathing and tail motion cannot activate a compressed hanging pose.")
	cat._idle_time = 0.0
	cat._update_pose()
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
	_check(not cat.transition_frames.visible and rig.posture == 0.0, "Pickup begins at the unchanged seated endpoint.")
	cat._pickup_progress = 0.60
	_check(cat.transition_frames.visible and cat.transition_frames.frame_index == 5 and not rig.visible, "Pickup selects the painted unfolding body instead of deforming seated limbs.")
	await cat._drag_tween.finished
	cat._update_pose()
	_check(cat.drag_rig.visible and cat.body_pivot.visible and not cat.petting_hand.visible, "Dragging retains the body mesh and original head and cancels the glove.")
	_check(cat.head.texture == cat.layout.master, "Pickup retains the original face texture.")
	for index in range(21):
		cat._pickup_progress = float(index) / 20.0
		_check(cat.drag_rig.modulate.a == 1.0 and cat.body_pivot.modulate.a == 1.0, "Every pickup pose stays opaque instead of crossfading.")
		_check(rig.posture == 0.0 or rig.posture == 1.0, "The endpoint mesh never interpolates incompatible sitting and hanging UVs.")
		_check(is_equal_approx(cat.transition_frames.body.scale.x, cat.transition_frames.body.scale.y), "Painted body frames preserve their aspect ratio.")
		_check((cat.body_pivot.transform * cat.head_pivot.transform).get_scale().is_equal_approx(Vector2.ONE), "The original head keeps its size throughout pickup.")
	cat._pickup_progress = 1.0
	cat.execute(PetActions.DRAG_END, 3, {})
	cat.execute(PetActions.IDLE, 4, {})
	_check(cat._drag_exiting, "Manager idle does not interrupt drag release.")
	cat._release_progress = 0.875
	_check(cat.transition_frames.visible and cat.transition_frames.frame_index == CatTransitionFrames.CONTACT_FRAME, "Release uses the painted contact frame instead of scaling the whole cat.")
	cat._release_progress = 0.30
	var regrab_progress := cat._current_pickup_pose()
	var regrab_texture := cat.transition_frames.body.texture
	var regrab_head := cat.body_pivot.transform * cat.head_pivot.transform
	cat.execute(PetActions.DRAG_START, 5, {})
	_check(is_equal_approx(cat._pickup_progress, regrab_progress) and cat.transition_frames.body.texture == regrab_texture and (cat.body_pivot.transform * cat.head_pivot.transform).is_equal_approx(regrab_head), "Regrab resumes the painted pose and preserves the head transform.")
	await cat._drag_tween.finished
	await create_timer(0.3).timeout
	_check(cat._dragging and is_equal_approx(cat._drag_amount, 1.0), "An old release cannot hide a newly started drag.")
	cat.stop()
	_check(cat.drag_rig.visible and cat.body_pivot.visible and is_zero_approx(rig.rotation) and is_zero_approx(rig.posture), "Stopping restores the seated geometry on the same opaque skin and clears inertia.")
	cat.execute(PetActions.DRAG_START, 6, {})
	await cat._pose_blend_tween.finished
	cat._pickup_progress = 0.5
	var interrupted_posture := rig.posture
	var interrupted_body_transform := cat.transition_frames.transform
	var interrupted_texture := cat.transition_frames.body.texture
	var interrupted_head := cat.body_pivot.transform * cat.head_pivot.transform
	cat.execute(PetActions.DRAG_END, 7, {})
	_check(is_equal_approx(rig.posture, interrupted_posture), "Releasing midway starts from the actual pickup pose.")
	_check(cat.transition_frames.transform.is_equal_approx(interrupted_body_transform) and cat.transition_frames.body.texture == interrupted_texture and (cat.body_pivot.transform * cat.head_pivot.transform).is_equal_approx(interrupted_head), "A midway release preserves the painted body and head transforms.")
	for index in range(21):
		cat._release_progress = float(index) / 20.0
		_check(rig.posture <= interrupted_posture and rig.modulate.a == 1.0 and cat.body_pivot.modulate.a == 1.0, "Every release pose folds back without opacity changes or a hanging-pose jump.")
	cat.stop()
	# Release and regrab at every new painted-frame boundary. This exercises
	# both sides of each switch rather than only one middle pose.
	for boundary in CatTransitionFrames.FRAME_BOUNDARIES:
		for offset in [-0.0001, 0.0001]:
			cat.execute(PetActions.DRAG_START, 8, {})
			await cat._pose_blend_tween.finished
			cat._pickup_progress = boundary + offset
			var texture := cat.transition_frames.body.texture
			var transform := cat.transition_frames.transform
			cat.execute(PetActions.DRAG_END, 9, {})
			_check(cat.transition_frames.body.texture == texture and cat.transition_frames.transform.is_equal_approx(transform), "Release preserves both sides of every painted-frame boundary.")
			cat.execute(PetActions.DRAG_START, 10, {})
			_check(cat.transition_frames.body.texture == texture and cat.transition_frames.transform.is_equal_approx(transform), "Regrab preserves both sides of every painted-frame boundary.")
			cat.stop()
	cat.free()
	if failures == 0:
		print("PASS: split drag rig, velocity response, independent inertia, reversal, settling, bounds and cancellation.")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

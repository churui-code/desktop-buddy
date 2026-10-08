extends SceneTree

class RecordingDriver:
	extends PetVisualDriver
	var requests: Array[Dictionary] = []
	var stop_count := 0

	func execute(action: StringName, request_id: int, context: Dictionary) -> void:
		requests.append({"action": action, "id": request_id, "context": context})

	func stop() -> void:
		stop_count += 1

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_pointer_gestures()
	var group := Node.new()
	root.add_child(group)
	var manager := PetActionManager.new()
	manager.blink_min_seconds = 30.0
	manager.blink_max_seconds = 30.0
	group.add_child(manager)
	var first := RecordingDriver.new()
	group.add_child(first)
	manager.bind_driver(first)
	manager.start()
	_check(first.requests.back().action == PetActions.IDLE, "Startup dispatches idle to the driver.")

	manager.request_action(PetActions.CLICK)
	var old_id: int = first.requests.back().id
	manager.request_action(PetActions.CLICK)
	var new_id: int = first.requests.back().id
	first.action_finished.emit(PetActions.CLICK, old_id)
	_check(manager.current_state == PetActionManager.State.REACTING, "A stale completion cannot end a newer reaction.")
	var before_blink := first.requests.size()
	manager.request_action(PetActions.BLINK)
	_check(first.requests.size() == before_blink, "Blink is suppressed during a reaction.")
	first.action_finished.emit(PetActions.CLICK, new_id)
	_check(manager.current_state == PetActionManager.State.IDLE, "The current reaction returns to idle on completion.")
	manager.request_action(PetActions.CLICK)
	var pre_pet_click_id: int = first.requests.back().id
	manager.request_action(PetActions.HEAD_PET_START)
	first.action_finished.emit(PetActions.CLICK, pre_pet_click_id)
	_check(manager.current_state == PetActionManager.State.PETTING, "A stale click cannot end a held petting action.")
	var during_pet := first.requests.size()
	manager.request_action(PetActions.BLINK)
	manager.request_action(PetActions.CLICK)
	manager.request_action(PetActions.HEAD_PET_START)
	_check(first.requests.size() == during_pet, "Petting suppresses blink, click and duplicate starts.")
	manager.request_action(PetActions.HEAD_PET_END)
	_check(manager.current_state == PetActionManager.State.IDLE, "Pet release restores idle.")
	manager.request_action(PetActions.HEAD_PET_START)
	manager.request_action(PetActions.DRAG_START)
	manager.request_action(PetActions.HEAD_PET_END)
	_check(manager.current_state == PetActionManager.State.DRAGGING, "A late pet release cannot interrupt dragging.")
	manager.request_action(PetActions.DRAG_END)

	manager.request_action(PetActions.CLICK)
	var interrupted_id: int = first.requests.back().id
	manager.request_action(PetActions.DRAG_START)
	first.action_finished.emit(PetActions.CLICK, interrupted_id)
	_check(manager.current_state == PetActionManager.State.DRAGGING, "Dragging survives a late reaction callback.")
	var before_click := first.requests.size()
	manager.request_action(PetActions.CLICK)
	_check(first.requests.size() == before_click, "Click cannot interrupt dragging.")
	manager.request_action(PetActions.DRAG_END)
	_check(first.requests.back().action == PetActions.IDLE, "Drag end resumes idle.")

	var second := RecordingDriver.new()
	group.add_child(second)
	manager.bind_driver(second)
	_check(first.stop_count == 1, "Replacing the driver stops the old implementation.")
	_check(second.requests.back().action == PetActions.IDLE, "The replacement receives the current idle action.")
	var first_count := first.requests.size()
	manager.request_action(PetActions.CLICK)
	var second_id: int = second.requests.back().id
	first.action_finished.emit(PetActions.CLICK, second_id)
	_check(manager.current_state == PetActionManager.State.REACTING, "The old driver is disconnected.")
	_check(first.requests.size() == first_count, "Actions reach only the replacement driver.")
	second.action_finished.emit(PetActions.CLICK, second_id)

	var visual := load("res://scenes/pets/layered_svg_pet.tscn").instantiate() as LayeredSvgPetDriver
	group.add_child(visual)
	manager.bind_driver(visual)
	manager.request_action(PetActions.CLICK)
	await create_timer(0.08).timeout
	manager.request_action(PetActions.CLICK)
	await create_timer(0.7).timeout
	_check(manager.current_state == PetActionManager.State.IDLE, "The real driver reports the replacement reaction's completion.")
	_check(visual.body_root.position.is_equal_approx(Vector2.ZERO), "A completed reaction resets the body position.")
	_check(not visual.sparkle.visible, "A completed reaction hides its effect.")

	manager.request_action(PetActions.CLICK)
	await create_timer(0.06).timeout
	manager.request_action(PetActions.DRAG_START)
	await create_timer(0.6).timeout
	_check(manager.current_state == PetActionManager.State.DRAGGING, "The real driver cancels interrupted reaction callbacks.")
	_check(not visual.sparkle.visible, "Dragging clears transient effects.")
	_check(not visual.breathing_animation.is_playing(), "Dragging pauses the idle animation.")
	manager.request_action(PetActions.DRAG_END)
	_check(visual.breathing_animation.is_playing(), "Releasing a drag resumes idle.")
	manager.request_action(PetActions.BLINK)
	await create_timer(0.3).timeout
	_check(visual.eyes.scale.is_equal_approx(Vector2.ONE), "Blink finishes with open eyes.")
	var raster := load("res://scenes/pets/sprite_cat_pet.tscn").instantiate() as SpriteFramesPetDriver
	group.add_child(raster)
	manager.bind_driver(raster)
	_check(raster.get_interaction_region().size() >= 3, "The PNG driver provides a silhouette interaction region.")
	var blink_completions: Array[int] = []
	raster.action_finished.connect(func(action: StringName, request_id: int) -> void:
		if action == PetActions.BLINK:
			blink_completions.append(request_id)
	)
	manager.request_action(PetActions.BLINK)
	_check(raster.sprite.animation == &"blink", "A blink event starts the frame sequence.")
	await create_timer(0.35).timeout
	_check(raster.sprite.animation == &"idle", "The PNG blink returns to the open-eye frame.")
	_check(blink_completions.size() == 1, "A PNG blink reports its completion exactly once.")
	manager.request_action(PetActions.BLINK)
	await create_timer(0.02).timeout
	manager.request_action(PetActions.CLICK)
	await create_timer(0.5).timeout
	_check(blink_completions.size() == 1, "A click cancels the blink completion callback.")
	_check(manager.current_state == PetActionManager.State.IDLE, "The PNG click reaction restores manager idle.")
	manager.request_action(PetActions.CLICK)
	await create_timer(0.04).timeout
	manager.request_action(PetActions.DRAG_START)
	await create_timer(0.5).timeout
	_check(manager.current_state == PetActionManager.State.DRAGGING, "The PNG driver's canceled reaction cannot interrupt dragging.")
	manager.request_action(PetActions.DRAG_END)
	_check(raster.art.position.is_equal_approx(Vector2(0, 101)), "The PNG driver's paw pivot is restored.")
	var eye_material := raster.sprite.material
	var forehead := raster.sprite.to_global(Vector2(0, -300))
	var belly := raster.sprite.to_global(Vector2(0, 330))
	_check(raster.is_head_position(forehead), "The forehead is a head target.")
	_check(not raster.is_head_position(belly), "The body is not a head target.")
	_check(not raster.is_head_position(Vector2.ZERO), "Transparent space is not a head target.")
	var gesture := PetPointerGesture.new()
	gesture.action_requested.connect(manager.request_action)
	gesture.begin(Vector2i(100, 100), forehead, raster.is_head_position(forehead))
	gesture.update(Vector2i(100, 100), 0.5, true)
	_check(manager.current_state == PetActionManager.State.PETTING, "A head hold reaches the manager through the gesture signal.")
	_check(raster.sprite.animation == &"head_pet", "Head petting displays the glove keyframe.")
	_check(raster.sprite.material == raster.petting_material, "Petting uses the smooth full-head material.")
	_check(raster.petting_hand.visible, "The glove is a separate visible upper layer.")
	_check(raster.sprite.sprite_frames.get_frame_count(&"head_pet") == 2, "The cat's petting motion has separate neutral and tilted frames.")
	_check(is_zero_approx(raster._petting_amount), "The petting entrance begins transparent.")
	await create_timer(0.3).timeout
	_check(manager.current_state == PetActionManager.State.PETTING, "The held action does not finish itself.")
	_check(is_equal_approx(raster._petting_amount, 1.0), "The petting entrance reaches full visibility.")
	var hand_pose := raster.petting_hand.position
	await create_timer(0.3).timeout
	_check(not raster.petting_hand.position.is_equal_approx(hand_pose), "The separate glove strokes while the cat's frames play.")
	gesture.finish(Vector2i(100, 100), true)
	_check(manager.current_state == PetActionManager.State.IDLE, "Releasing a head hold restores idle without a click reaction.")
	_check(raster._petting_exiting and raster.petting_hand.visible, "Release starts a visual fade instead of snapping to idle.")
	await create_timer(0.3).timeout
	_check(raster.sprite.animation == &"idle" and raster.sprite.material == eye_material, "Pet release restores the idle frame and blink material.")
	_check(not raster.petting_hand.visible, "The exit hides the glove.")
	manager.request_action(PetActions.CLICK)
	await create_timer(0.04).timeout
	manager.request_action(PetActions.HEAD_PET_START)
	await create_timer(0.5).timeout
	_check(manager.current_state == PetActionManager.State.PETTING, "Petting cancels the real driver's click completion.")
	manager.request_action(PetActions.DRAG_START)
	_check(raster.sprite.animation == &"idle" and raster.sprite.material == eye_material, "Dragging clears the petting frame and restores the eye material.")
	manager.request_action(PetActions.DRAG_END)
	manager.request_action(PetActions.HEAD_PET_START)
	await create_timer(0.1).timeout
	manager.request_action(PetActions.HEAD_PET_END)
	manager.request_action(PetActions.CLICK)
	await create_timer(0.3).timeout
	_check(manager.current_state == PetActionManager.State.REACTING and raster._active_action == PetActions.CLICK, "A canceled petting exit cannot reset a newer click.")
	await create_timer(0.2).timeout
	manager.request_action(PetActions.BLINK)
	await create_timer(0.35).timeout
	_check(blink_completions.size() == 2, "Blinking still finishes normally after petting and dragging.")
	manager.stop()
	group.free()
	if failures == 0:
		print("PASS: gestures, head targeting, petting lifecycle, driver replacement, action priority, cancellation, SVG and PNG integration.")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _check_pointer_gestures() -> void:
	var gesture := PetPointerGesture.new()
	var actions: Array[StringName] = []
	var movements: Array[Vector2i] = []
	gesture.action_requested.connect(func(action: StringName, _context: Dictionary) -> void: actions.append(action))
	gesture.drag_moved.connect(func(displacement: Vector2i) -> void: movements.append(displacement))
	var mouse := Vector2i(100, 100)
	gesture.begin(mouse, Vector2(120, 80), true)
	_check(gesture.get_pointer_local_position(mouse + Vector2i(3, 2)) == Vector2(123, 82), "Head targeting uses the press event's local coordinates plus pointer movement.")
	gesture.update(mouse, 0.2, true)
	gesture.finish(mouse, true)
	_check(actions == [PetActions.CLICK], "A short head press remains a click.")
	actions.clear()
	gesture.begin(mouse, Vector2(120, 80), true)
	gesture.update(mouse, 0.44, true)
	_check(actions.is_empty(), "Petting waits for the hold threshold.")
	gesture.update(mouse, 0.02, true)
	gesture.update(mouse, 1.0, true)
	gesture.finish(mouse, true)
	gesture.finish(mouse, true)
	_check(actions == [PetActions.HEAD_PET_START, PetActions.HEAD_PET_END], "A hold starts once and ends once without a click, including duplicate releases.")
	actions.clear()
	gesture.begin(mouse, Vector2(120, 200), false)
	gesture.update(mouse, 1.0, true)
	gesture.finish(mouse, false)
	_check(actions == [PetActions.CLICK], "A body press cannot become petting by entering the head.")
	actions.clear()
	gesture.begin(mouse, Vector2(120, 80), true)
	gesture.update(mouse + Vector2i(8, 0), 0.5, true)
	gesture.finish(mouse + Vector2i(12, 0), true)
	_check(actions == [PetActions.DRAG_START, PetActions.DRAG_END], "Movement wins over a simultaneous hold threshold.")
	_check(movements.back() == Vector2i(12, 0), "The final pointer movement is included in dragging.")
	actions.clear()
	gesture.begin(mouse, Vector2(120, 80), true)
	gesture.update(mouse, 0.5, true)
	gesture.update(mouse + Vector2i(10, 0), 0.01, true)
	gesture.finish(mouse + Vector2i(10, 0), true)
	_check(actions == [PetActions.HEAD_PET_START, PetActions.HEAD_PET_END, PetActions.DRAG_START, PetActions.DRAG_END], "Petting transitions cleanly to dragging.")
	actions.clear()
	gesture.begin(mouse, Vector2(120, 80), true)
	gesture.update(mouse, 0.5, true)
	gesture.update(mouse, 0.01, false)
	gesture.update(mouse, 1.0, true)
	gesture.finish(mouse, true)
	_check(actions == [PetActions.HEAD_PET_START, PetActions.HEAD_PET_END], "Leaving the head ends petting without restarting or clicking on release.")
	actions.clear()
	gesture.begin(mouse, Vector2(120, 80), true)
	gesture.update(mouse, 0.5, true)
	gesture.cancel()
	gesture.finish(mouse, true)
	_check(actions == [PetActions.HEAD_PET_START, PetActions.HEAD_PET_END] and gesture.state == PetPointerGesture.State.RELEASED, "Focus/menu cancellation ends petting and consumes the release.")

extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager := PetActionManager.new()
	manager.blink_min_seconds = 30.0
	manager.blink_max_seconds = 30.0
	root.add_child(manager)
	var cat := load("res://scenes/pets/layered_cat_pet.tscn").instantiate() as LayeredCatPetDriver
	root.add_child(cat)
	manager.bind_driver(cat)
	manager.start()
	var original_head_texture := cat.head.texture
	_check(cat.head.texture == cat.layout.master, "The head reuses the unchanged master pixels.")
	_check(cat.get_interaction_region().size() >= 3, "The layered rig provides the cat silhouette.")
	_check(cat.is_head_position(cat.head.to_global(Vector2(627, 330))), "The forehead belongs to the head hit region.")
	_check(not cat.is_head_position(cat.head.to_global(Vector2(627, 990))), "The belly is not a head target.")
	var completions: Array[StringName] = []
	cat.action_finished.connect(func(action: StringName, _id: int) -> void: completions.append(action))
	manager.request_action(PetActions.BLINK)
	await create_timer(0.35).timeout
	_check(completions == [PetActions.BLINK] and is_zero_approx(cat._eye_closure), "Blink finishes once and restores open eyes.")
	manager.request_action(PetActions.CLICK)
	await create_timer(0.04).timeout
	manager.request_action(PetActions.HEAD_PET_START)
	await create_timer(0.5).timeout
	_check(manager.current_state == PetActionManager.State.PETTING, "Petting cancels a click's completion.")
	_check(not completions.has(PetActions.CLICK), "An interrupted click cannot emit a completion.")
	_check(cat.petting_hand.visible and cat.neck_fill.visible, "Petting shows the separate glove and hidden neck coverage.")
	_check(cat.head.texture == original_head_texture, "Petting keeps the same head texture.")
	var head_angle := cat.head_pivot.rotation
	var hand_position := cat.petting_hand.position
	await create_timer(0.4).timeout
	_check(not is_equal_approx(head_angle, cat.head_pivot.rotation), "The head tilts around its joint.")
	_check(not hand_position.is_equal_approx(cat.petting_hand.position), "The single glove texture moves independently.")
	_check(absf(cat.head_pivot.rotation) <= 0.0461, "The stronger head tilt remains within about 2.7 degrees.")
	manager.request_action(PetActions.HEAD_PET_END)
	_check(cat._pet_exiting and manager.current_state == PetActionManager.State.IDLE, "The manager resumes idle while the visual fades out.")
	await create_timer(0.3).timeout
	_check(not cat.petting_hand.visible and is_zero_approx(cat.head_pivot.rotation), "Pet release hides the glove and restores the head.")
	manager.request_action(PetActions.HEAD_PET_START)
	await create_timer(0.1).timeout
	manager.request_action(PetActions.HEAD_PET_END)
	manager.request_action(PetActions.CLICK)
	await create_timer(0.3).timeout
	_check(manager.current_state == PetActionManager.State.REACTING, "A canceled fade cannot reset a newer click.")
	await create_timer(0.2).timeout
	_check(manager.current_state == PetActionManager.State.IDLE, "The layered click reports its completion.")
	manager.request_action(PetActions.HEAD_PET_START)
	await create_timer(0.35).timeout
	manager.request_action(PetActions.DRAG_START)
	await create_timer(0.3).timeout
	_check(manager.current_state == PetActionManager.State.DRAGGING and not cat.petting_hand.visible, "Dragging cancels petting and clears the glove.")
	_check(cat.body_pivot.scale == Vector2.ONE and is_zero_approx(cat.head_pivot.rotation), "Dragging restores the rig's neutral joints.")
	manager.request_action(PetActions.DRAG_END)
	manager.request_action(PetActions.BLINK)
	await create_timer(0.35).timeout
	_check(completions.count(PetActions.BLINK) == 2, "Blinking resumes after petting and dragging.")
	manager.stop()
	_check(cat.body_pivot.position == cat.layout.body_joint and cat.body_pivot.scale == Vector2.ONE, "Stopping restores the master coordinate layout.")
	cat.free()
	manager.free()
	if failures == 0:
		print("PASS: master-based layered rig, head targeting, blink, smooth petting, cancellation and drag recovery.")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

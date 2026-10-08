class_name PetPointerGesture
extends RefCounted

## Gesture decisions are independent of the native window and artwork.
signal action_requested(action: StringName, context: Dictionary)
signal drag_moved(displacement: Vector2i)
signal drag_finished

enum State { RELEASED, PRESSED, PETTING, DRAGGING }

var hold_seconds := 0.45
var drag_threshold := 8.0
var state: State = State.RELEASED
var _press_mouse := Vector2i.ZERO
var _press_local := Vector2.ZERO
var _elapsed := 0.0
var _head_eligible := false
var _consumed := false


func begin(mouse: Vector2i, local_position: Vector2, on_head: bool) -> void:
	cancel()
	state = State.PRESSED
	_press_mouse = mouse
	_press_local = local_position
	_elapsed = 0.0
	_head_eligible = on_head
	_consumed = false


func update(mouse: Vector2i, delta: float, on_head: bool) -> void:
	if state == State.RELEASED:
		return
	var displacement := mouse - _press_mouse
	# Movement wins over a hold, including on the threshold-crossing frame.
	if state != State.DRAGGING and displacement.length() >= drag_threshold:
		if state == State.PETTING:
			action_requested.emit(PetActions.HEAD_PET_END, {})
		state = State.DRAGGING
		action_requested.emit(PetActions.DRAG_START, {})
	if state == State.DRAGGING:
		drag_moved.emit(displacement)
		return
	if not on_head:
		_head_eligible = false
		if state == State.PETTING:
			state = State.PRESSED
			action_requested.emit(PetActions.HEAD_PET_END, {})
		return
	_elapsed += delta
	if state == State.PRESSED and _head_eligible and not _consumed and _elapsed >= hold_seconds:
		state = State.PETTING
		_consumed = true
		action_requested.emit(PetActions.HEAD_PET_START, {"local_position": _press_local})


func finish(mouse: Vector2i, on_head: bool) -> void:
	if state == State.RELEASED:
		return
	update(mouse, 0.0, on_head)
	var previous := state
	state = State.RELEASED
	match previous:
		State.DRAGGING:
			action_requested.emit(PetActions.DRAG_END, {})
			drag_finished.emit()
		State.PETTING:
			action_requested.emit(PetActions.HEAD_PET_END, {})
		State.PRESSED:
			if not _consumed:
				action_requested.emit(PetActions.CLICK, {"local_position": _press_local})


func cancel() -> void:
	var previous := state
	state = State.RELEASED
	if previous == State.PETTING:
		action_requested.emit(PetActions.HEAD_PET_END, {})
	elif previous == State.DRAGGING:
		action_requested.emit(PetActions.DRAG_END, {})
		drag_finished.emit()


func get_pointer_local_position(mouse: Vector2i) -> Vector2:
	# Anchor to the event's local position, avoiding desktop/window coordinate
	# offsets across monitors and injected native-window events.
	return _press_local + Vector2(mouse - _press_mouse)

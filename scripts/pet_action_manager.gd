class_name PetActionManager
extends Node

signal action_requested(action: StringName, request_id: int, context: Dictionary)
signal state_changed(state: State)

enum State { IDLE, REACTING, PETTING, DRAGGING }

@export_range(0.5, 30.0, 0.1) var blink_min_seconds := 2.0
@export_range(0.5, 30.0, 0.1) var blink_max_seconds := 4.5

var current_state: State = State.IDLE
var _driver: PetVisualDriver
var _blink_timer: Timer
var _started := false
var _next_request_id := 0
var _active_reaction_id := 0


func _ready() -> void:
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	add_child(_blink_timer)
	_blink_timer.timeout.connect(_on_blink_timeout)


func bind_driver(driver: PetVisualDriver) -> void:
	if is_instance_valid(_driver):
		action_requested.disconnect(_driver.execute)
		_driver.action_finished.disconnect(_on_action_finished)
		_driver.stop()
	_driver = driver
	_active_reaction_id = 0
	_set_state(State.IDLE)
	if is_instance_valid(_driver):
		action_requested.connect(_driver.execute)
		_driver.action_finished.connect(_on_action_finished)
		if _started:
			_dispatch(PetActions.IDLE)


func start() -> void:
	if _started:
		return
	if not is_instance_valid(_driver):
		push_error("Bind a visual driver before starting PetActionManager.")
		return
	_started = true
	request_action(PetActions.IDLE)
	_schedule_blink()


func stop() -> void:
	_started = false
	_active_reaction_id = 0
	_blink_timer.stop()
	if is_instance_valid(_driver):
		_driver.stop()
	_set_state(State.IDLE)


func request_action(action: StringName, context: Dictionary = {}) -> void:
	if not _started or not is_instance_valid(_driver):
		return
	match action:
		PetActions.IDLE:
			_active_reaction_id = 0
			_set_state(State.IDLE)
			_dispatch(action, context)
		PetActions.BLINK:
			if current_state == State.IDLE:
				_dispatch(action, context)
		PetActions.CLICK:
			if current_state in [State.IDLE, State.REACTING]:
				_set_state(State.REACTING)
				_dispatch(action, context)
		PetActions.HEAD_PET_START:
			if current_state in [State.IDLE, State.REACTING]:
				_active_reaction_id = 0
				_set_state(State.PETTING)
				_dispatch(action, context)
		PetActions.HEAD_PET_END:
			if current_state == State.PETTING:
				_set_state(State.IDLE)
				_dispatch(action, context)
				_dispatch(PetActions.IDLE)
		PetActions.DRAG_START:
			_active_reaction_id = 0
			_set_state(State.DRAGGING)
			_dispatch(action, context)
		PetActions.DRAG_END:
			if current_state == State.DRAGGING:
				_set_state(State.IDLE)
				_dispatch(action, context)
				_dispatch(PetActions.IDLE)
		_:
			push_warning("Unknown pet action: %s" % action)


func _dispatch(action: StringName, context: Dictionary = {}) -> void:
	_next_request_id += 1
	if action == PetActions.CLICK:
		# Set before emission: a driver is allowed to finish synchronously.
		_active_reaction_id = _next_request_id
	action_requested.emit(action, _next_request_id, context.duplicate(true))


func _on_action_finished(action: StringName, request_id: int) -> void:
	if action == PetActions.CLICK and current_state == State.REACTING:
		if request_id == _active_reaction_id:
			_active_reaction_id = 0
			_set_state(State.IDLE)
			_dispatch(PetActions.IDLE)


func _on_blink_timeout() -> void:
	request_action(PetActions.BLINK)
	_schedule_blink()


func _schedule_blink() -> void:
	if _started:
		_blink_timer.start(randf_range(blink_min_seconds, maxf(blink_min_seconds, blink_max_seconds)))


func _set_state(state: State) -> void:
	if current_state != state:
		current_state = state
		state_changed.emit(state)

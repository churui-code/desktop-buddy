class_name PetVisualDriver
extends Node2D

## Finite actions report their request ID when finished. A canceled action
## must stop its animation and callbacks; the manager also rejects stale IDs.
signal action_finished(action: StringName, request_id: int)
signal interaction_region_changed(region: PackedVector2Array)

@export var preferred_window_size := Vector2i(256, 256)
## Coordinates are relative to the top-left of the native window.
## An empty polygon accepts clicks across the entire window.
@export var interaction_region := PackedVector2Array()
## Optional head hit polygon in window coordinates. Drivers can override the
## query to account for their animated transforms or texture coordinates.
@export var head_region := PackedVector2Array()


func execute(_action: StringName, _request_id: int, _context: Dictionary) -> void:
	push_error("PetVisualDriver.execute() must be implemented by a visual driver.")


func stop() -> void:
	pass


func get_preferred_window_size() -> Vector2i:
	return preferred_window_size


func get_interaction_region() -> PackedVector2Array:
	return interaction_region


func is_head_position(window_position: Vector2) -> bool:
	return head_region.size() >= 3 and Geometry2D.is_point_in_polygon(window_position, head_region)

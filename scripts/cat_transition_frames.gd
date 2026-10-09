class_name CatTransitionFrames
extends Node2D

## Only painted body pixels switch. The driver moves the unchanged head to
## neck_position, and the held rig owns continuous limb/tail motion.
const TEXTURES := [
	preload("res://assets/pets/cat/transition-drafts/pickup-low-lift-v1.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-early-v2.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-curl-v1.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-rise-v1.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-middle-v2.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-open-v1.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-unfold-v1.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-extend-v2.png"),
	preload("res://assets/pets/cat/transition-drafts/pickup-late-v1.png"),
	preload("res://assets/pets/cat/transition-drafts/landing-contact-v1.png"),
]
const SOURCE_NECKS := [
	Vector2(627, 752), Vector2(627, 752), Vector2(627, 752),
	Vector2(627, 675), Vector2(627, 650), Vector2(627, 650),
	Vector2(627, 640), Vector2(627, 640), Vector2(627, 570), Vector2(627, 790),
]
const UNIFORM_SCALES := [
	1.0, 1.0, 743.0 / 743.0, 743.0 / 747.0, 743.0 / 742.0,
	743.0 / 745.0, 743.0 / 746.0, 743.0 / 746.0, 743.0 / 644.0, 743.0 / 744.0,
]
# Midpoints of adjacent painted poses. The same selection is used in reverse
# and on regrab, so an interruption cannot restart the unfolding sequence.
const FRAME_BOUNDARIES := [0.185, 0.27, 0.355, 0.445, 0.535, 0.625, 0.71, 0.7925]
const CONTACT_FRAME := 9
const POSE_TIMES := [0.11, 0.22, 0.50, 0.78, 1.0]
const NECK_HEIGHTS := [752.0, 732.0, 690.0, 627.0, 627.0]
const HELD_SCALE := 743.0 / 655.0
const HELD_NECK := Vector2(627, 600)

var body: Sprite2D
var frame_index := -1
var neck_position := Vector2(627, 752)
var _material: ShaderMaterial


func _ready() -> void:
	body = Sprite2D.new()
	body.centered = false
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/cat_transition_body.gdshader")
	body.material = _material
	add_child(body)
	hide()


func pose_neck(progress: float) -> Vector2:
	if progress <= POSE_TIMES[0]:
		return Vector2(627, NECK_HEIGHTS[0])
	for index in range(POSE_TIMES.size() - 1):
		if progress <= POSE_TIMES[index + 1]:
			var weight := smoothstep(POSE_TIMES[index], POSE_TIMES[index + 1], progress)
			return Vector2(627, lerpf(NECK_HEIGHTS[index], NECK_HEIGHTS[index + 1], weight))
	return Vector2(627, NECK_HEIGHTS[-1])


func display_pose(progress: float, contact_weight: float, angle: float) -> void:
	neck_position = pose_neck(progress)
	# Nearest painted pose; endpoint meshes are selected by the driver.
	frame_index = 0
	for boundary in FRAME_BOUNDARIES:
		if progress >= boundary:
			frame_index += 1
	if contact_weight > 0.0:
		frame_index = CONTACT_FRAME
		neck_position = Vector2(627, 752 + contact_weight * 74.0)
	body.texture = TEXTURES[frame_index]
	body.position = -SOURCE_NECKS[frame_index]
	body.scale = Vector2.ONE * UNIFORM_SCALES[frame_index]
	# Scale the source origin with the texture, not the frame's height.
	body.position *= UNIFORM_SCALES[frame_index]
	_material.set_shader_parameter("neck_cut", SOURCE_NECKS[frame_index].y - 22.0)
	position = neck_position
	rotation = angle

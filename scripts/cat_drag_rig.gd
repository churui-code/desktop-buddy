class_name CatDragRig
extends Node2D

## Shared full-size pose: separate masks and joints, no resized/generated limbs.
@export var texture: Texture2D
@export var anchor := Vector2(627, 160)
@export var max_body_angle := 0.105
@export var max_limb_angle := 0.20
@export var max_tail_angle := 0.24
@export var speed_for_full_swing := 950.0
@export var spring_frequencies := PackedFloat32Array([10.0, 13.0, 11.5, 9.0, 8.0, 6.5])
@export var damping_ratio := 0.525
@export var input_decay := 7.0

const JOINTS := [Vector2(627, 160), Vector2(475, 655), Vector2(754, 674), Vector2(553, 975), Vector2(750, 989), Vector2(440, 899), Vector2(627, 160)]
const PART_NAMES := ["Torso", "FrontLeft", "FrontRight", "HindLeft", "HindRight", "Tail", "Head"]
const REGIONS := [
	Vector2(410, 615), Vector2(485, 638), Vector2(535, 695), Vector2(579, 759), Vector2(607, 809), Vector2(632, 866), Vector2(626, 899), Vector2(600, 914), Vector2(548, 909), Vector2(504, 890), Vector2(474, 834), Vector2(431, 750),
	Vector2(737, 636), Vector2(808, 657), Vector2(834, 720), Vector2(817, 806), Vector2(804, 864), Vector2(803, 912), Vector2(786, 943), Vector2(740, 950), Vector2(695, 929), Vector2(670, 894), Vector2(681, 789), Vector2(707, 705),
	Vector2(499, 978), Vector2(537, 985), Vector2(580, 987), Vector2(619, 1002), Vector2(638, 1033), Vector2(657, 1076), Vector2(650, 1120), Vector2(616, 1146), Vector2(561, 1157), Vector2(515, 1139), Vector2(498, 1092), Vector2(494, 1031),
	Vector2(697, 981), Vector2(740, 981), Vector2(784, 980), Vector2(805, 1016), Vector2(825, 1068), Vector2(837, 1115), Vector2(807, 1147), Vector2(758, 1159), Vector2(711, 1141), Vector2(685, 1098), Vector2(673, 1048), Vector2(678, 1003),
	Vector2(329, 850), Vector2(401, 843), Vector2(447, 867), Vector2(459, 923), Vector2(470, 989), Vector2(489, 1038), Vector2(507, 1099), Vector2(489, 1189), Vector2(389, 1203), Vector2(327, 1160), Vector2(310, 1033), Vector2(306, 911),
]

var pivots: Array[Node2D] = []
var angles := PackedFloat64Array([0, 0, 0, 0, 0, 0])
var angular_speeds := PackedFloat64Array([0, 0, 0, 0, 0, 0])
var _motion := Vector2.ZERO
var _underlay: Sprite2D


func _ready() -> void:
	pivots.resize(7)
	_underlay = Sprite2D.new()
	_underlay.texture = preload("res://assets/pets/cat/drag-torso-underlay-v1.png")
	_underlay.centered = false
	_underlay.position = -anchor
	var underlay_material := ShaderMaterial.new()
	underlay_material.shader = preload("res://shaders/cat_drag_underlay.gdshader")
	_underlay.material = underlay_material
	_underlay.z_index = -1
	add_child(_underlay)
	# Back layers first; every Sprite retains the same canvas and source origin.
	for index in [5, 3, 4, 0, 1, 2, 6]:
		var pivot := Node2D.new()
		pivot.name = PART_NAMES[index]
		pivot.position = JOINTS[index] - anchor
		add_child(pivot)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = -JOINTS[index]
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/cat_drag_layer.gdshader")
		material.set_shader_parameter("layer", index)
		material.set_shader_parameter("regions", PackedVector2Array(REGIONS))
		sprite.material = material
		pivot.add_child(sprite)
		pivots[index] = pivot
	reset_motion()


func set_drag_velocity(velocity: Vector2) -> void:
	_motion = velocity.limit_length(1800.0)


func advance(delta: float) -> void:
	# Semi-implicit spring steps keep fast reversals and frame stalls bounded.
	var remaining := minf(delta, 0.1)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 120.0)
		var drive := clampf(_motion.x / speed_for_full_swing, -1.0, 1.0)
		for index in range(6):
			var limit := max_body_angle if index == 0 else (max_tail_angle if index == 5 else max_limb_angle)
			var target := drive * limit
			var frequency: float = spring_frequencies[index]
			angular_speeds[index] += ((target - angles[index]) * frequency * frequency - angular_speeds[index] * frequency * 2.0 * damping_ratio) * step
			angles[index] = clampf(angles[index] + angular_speeds[index] * step, -limit * 1.35, limit * 1.35)
		_motion *= exp(-step * input_decay)
		remaining -= step
	rotation = angles[0]
	for index in range(1, 6):
		pivots[index].rotation = angles[index]
	# Head follows the scruff pivot with the torso; keep this neck seam closed.
	pivots[6].rotation = 0.0
	var fur_coverage := 0.0
	for index in range(1, 6):
		fur_coverage = maxf(fur_coverage, absf(angles[index]))
	_underlay.visible = fur_coverage > 0.0002
	_underlay.modulate.a = clampf(fur_coverage / 0.006, 0.0, 1.0)


func reset_motion() -> void:
	_motion = Vector2.ZERO
	rotation = 0.0
	for index in range(6):
		angles[index] = 0.0
		angular_speeds[index] = 0.0
	for pivot in pivots:
		pivot.rotation = 0.0
	_underlay.visible = false

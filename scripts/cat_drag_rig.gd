class_name CatDragRig
extends Node2D

## Shared full-size pose: separate masks and joints, no resized/generated limbs.
@export var texture: Texture2D
@export var seated_master: Texture2D
@export var anchor := Vector2(627, 160)
@export var max_body_angle := 0.20
@export var max_limb_angle := 0.30
@export var max_tail_angle := 0.46
@export var speed_for_full_swing := 550.0
@export var spring_frequencies := PackedFloat32Array([9.0, 12.0, 10.5, 8.0, 7.0, 6.0])
@export var damping_ratio := 0.48
@export var input_decay := 7.0

const JOINTS := [Vector2(627, 160), Vector2(475, 655), Vector2(754, 674), Vector2(530, 942), Vector2(755, 955), Vector2(440, 899), Vector2(627, 160)]
const PART_NAMES := ["Torso", "FrontLeft", "FrontRight", "HindLeft", "HindRight", "Tail", "Head"]
const REGIONS := [
	Vector2(410, 615), Vector2(485, 638), Vector2(535, 695), Vector2(579, 759), Vector2(607, 809), Vector2(632, 866), Vector2(626, 899), Vector2(600, 914), Vector2(548, 909), Vector2(504, 890), Vector2(474, 834), Vector2(431, 750),
	Vector2(737, 636), Vector2(808, 657), Vector2(834, 720), Vector2(817, 806), Vector2(804, 864), Vector2(803, 912), Vector2(786, 943), Vector2(740, 950), Vector2(695, 929), Vector2(670, 894), Vector2(681, 789), Vector2(707, 705),
	Vector2(456, 885), Vector2(514, 912), Vector2(568, 947), Vector2(614, 977), Vector2(634, 1021), Vector2(657, 1076), Vector2(655, 1144), Vector2(595, 1170), Vector2(530, 1154), Vector2(498, 1092), Vector2(469, 1002), Vector2(443, 930),
	Vector2(768, 919), Vector2(812, 904), Vector2(844, 943), Vector2(844, 1000), Vector2(825, 1068), Vector2(848, 1148), Vector2(796, 1170), Vector2(731, 1175), Vector2(701, 1138), Vector2(685, 1098), Vector2(664, 1006), Vector2(690, 958),
	Vector2(329, 850), Vector2(401, 843), Vector2(447, 867), Vector2(459, 923), Vector2(470, 989), Vector2(489, 1038), Vector2(507, 1099), Vector2(489, 1189), Vector2(389, 1203), Vector2(327, 1160), Vector2(310, 1033), Vector2(306, 911),
]

const SEATED_REGIONS := [
	Vector2(445, 825), Vector2(505, 835), Vector2(565, 885), Vector2(610, 960), Vector2(638, 1045), Vector2(635, 1155), Vector2(560, 1175), Vector2(475, 1165), Vector2(450, 1090), Vector2(420, 1005), Vector2(420, 935), Vector2(430, 875),
	Vector2(810, 825), Vector2(750, 835), Vector2(690, 885), Vector2(645, 960), Vector2(617, 1045), Vector2(620, 1155), Vector2(695, 1175), Vector2(780, 1165), Vector2(805, 1090), Vector2(835, 1005), Vector2(835, 935), Vector2(825, 875),
	Vector2(300, 825), Vector2(400, 835), Vector2(470, 905), Vector2(470, 1020), Vector2(490, 1105), Vector2(460, 1155), Vector2(400, 1160), Vector2(330, 1135), Vector2(295, 1090), Vector2(280, 1020), Vector2(285, 930), Vector2(300, 875),
	Vector2(955, 825), Vector2(855, 835), Vector2(785, 905), Vector2(785, 1020), Vector2(765, 1105), Vector2(795, 1155), Vector2(855, 1160), Vector2(925, 1135), Vector2(960, 1090), Vector2(975, 1020), Vector2(970, 930), Vector2(955, 875),
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
]

var pivots: Array[Node2D] = []
var angles := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var angular_speeds := PackedFloat64Array([0, 0, 0, 0, 0, 0])
var _motion := Vector2.ZERO
var skin: MeshInstance2D
var _skin_material: ShaderMaterial
var posture := 1.0
var master_tail: MeshInstance2D
var _tail_material: ShaderMaterial
var _idle_tail := 0.0


func _ready() -> void:
	pivots.resize(7)
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
		pivot.visible = false
	_setup_skin()
	reset_motion()


func _setup_skin() -> void:
	# A connected mesh keeps shoulder/hip boundaries joined as the independent
	# bones move. UVs still sample only the original, unchanged pose artwork.
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var size := Vector2(texture.get_size())
	var columns := ceili(size.x / 20.0)
	var rows := ceili(size.y / 20.0)
	for y in range(rows + 1):
		for x in range(columns + 1):
			var point := Vector2(minf(x * 20.0, size.x), minf(y * 20.0, size.y))
			vertices.append(Vector3(point.x, point.y, 0))
			uvs.append(point / size)
	for y in range(rows):
		for x in range(columns):
			var a := y * (columns + 1) + x
			var b := a + 1
			var c := a + columns + 1
			indices.append_array(PackedInt32Array([a, b, c, b, c + 1, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	skin = MeshInstance2D.new()
	skin.mesh = mesh
	skin.texture = seated_master if seated_master else texture
	skin.position = -anchor
	_skin_material = ShaderMaterial.new()
	_skin_material.shader = preload("res://shaders/cat_master_skin.gdshader") if seated_master else preload("res://shaders/cat_drag_skin.gdshader")
	_skin_material.set_shader_parameter("regions", PackedVector2Array(REGIONS))
	_skin_material.set_shader_parameter("joints", PackedVector2Array(JOINTS))
	skin.material = _skin_material
	add_child(skin)
	if seated_master:
		_skin_material.set_shader_parameter("held_texture", texture)
		_skin_material.set_shader_parameter("seated_regions", PackedVector2Array(SEATED_REGIONS))
		master_tail = MeshInstance2D.new()
		master_tail.mesh = mesh
		master_tail.texture = seated_master
		master_tail.position = -anchor
		master_tail.z_index = -1
		_tail_material = _skin_material.duplicate() as ShaderMaterial
		_tail_material.set_shader_parameter("tail_only", true)
		master_tail.material = _tail_material
		add_child(master_tail)


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
	_skin_material.set_shader_parameter("angles", angles)
	_update_master_tail()


func set_lift_pose(fold: float) -> void:
	# Legs unfold from a tucked pose as weight transfers to the scruff.
	for index in range(1, 5):
		pivots[index].scale = Vector2(1.0, 1.0 - clampf(fold, 0.0, 1.0) * 0.28)
	if not seated_master:
		_skin_material.set_shader_parameter("fold", clampf(fold, 0.0, 1.0))


func set_posture(value: float) -> void:
	posture = clampf(value, 0.0, 1.0)
	if seated_master:
		_skin_material.set_shader_parameter("posture", posture)
	_update_master_tail()


func set_body_only(value: bool) -> void:
	if not seated_master:
		_skin_material.set_shader_parameter("body_only", value)


func set_idle_tail(value: float) -> void:
	_idle_tail = value
	_update_master_tail()


func _update_master_tail() -> void:
	if not is_instance_valid(master_tail):
		return
	_tail_material.set_shader_parameter("posture", posture)
	_tail_material.set_shader_parameter("angles", angles)
	_tail_material.set_shader_parameter("idle_tail", _idle_tail)


func reset_motion() -> void:
	_motion = Vector2.ZERO
	rotation = 0.0
	for index in range(6):
		angles[index] = 0.0
		angular_speeds[index] = 0.0
	for pivot in pivots:
		pivot.rotation = 0.0
	set_lift_pose(0.0)
	_skin_material.set_shader_parameter("angles", angles)
	_update_master_tail()

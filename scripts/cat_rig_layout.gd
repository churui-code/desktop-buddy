class_name CatRigLayout
extends Resource

## Every point is measured in the unchanged master texture, before display
## scaling. Cropping or atlas packing must retain these source coordinates.
@export var master: Texture2D
@export var half_eyes: Texture2D
@export var closed_eyes: Texture2D
@export var glove: Texture2D
@export var display_scale := 0.19
@export var body_joint := Vector2(627, 1154)
@export var head_joint := Vector2(627, 752)
@export var tail_joint := Vector2(320, 1000)
@export var glove_joint := Vector2(823, 275)
## Source anchor and scale let a replacement glove retain its own canvas.
@export var glove_source_joint := Vector2(823, 275)
@export var glove_scale := 1.0
@export var head_cut := Vector4(627, 250, 746, 18)
@export var tail_cut := Vector4(810, 335, 850, 0.25)
@export var head_hit_uv := Rect2(0.22, 0.10, 0.64, 0.50)
@export var eye_left := Vector4(0.315, 0.335, 0.450, 0.480)
@export var eye_right := Vector4(0.545, 0.335, 0.675, 0.480)

@export_group("Petting motion")
@export_range(0.3, 3.0, 0.05) var stroke_period := 1.0
@export var stroke_span := 104.0
@export var stroke_drop := 18.0
@export var hand_angles := Vector2(-0.04, 0.09)
@export var head_angles := Vector2(-0.012, 0.046)
@export var entry_offset := Vector2(125, 95)
@export var enter_seconds := 0.22
@export var exit_seconds := 0.20


func head_cut_y(pixel_x: float) -> float:
	return head_cut.z + head_cut.w * clampf(1.0 - absf((pixel_x - head_cut.x) / head_cut.y), 0.0, 1.0)

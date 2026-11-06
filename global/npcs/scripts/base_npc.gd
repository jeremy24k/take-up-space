@tool
extends CharacterBody2D

@export_range(0, 29) var column_npc: int = 0:
	set(value):
		column_npc = value
		if is_node_ready() and sprite:
			sprite.frame_coords = Vector2i(column_npc, 0)

## Pixels to lower the sort point without moving the art. For someone seated
## on a front-facing bench: the bench (and the hedge behind it) sorts below
## its legs, so with the normal point at the feet it covers whoever sits on
## it. Set here, on the NPC, because a position/offset override on the
## Sprite2D child got dropped when the editor saved the plaza.
@export var sort_lower: int = 0:
	set(value):
		sort_lower = value
		if is_node_ready() and sprite:
			_apply_sort_lower()

@export var is_animated: bool = true
@export var animation_speed: float = 0.5
@export var random_start_offset: bool = true # Enables/disables the start desync

## The sprite offset every NPC uses so that it sorts at its feet (DOCS.md
## "Orden de profundidad de los NPCs").
const FEET_OFFSET_Y: float = -9.0

@onready var sprite: Sprite2D = $Sprite2D
var timer_animation: float = 0.0
var current_frame: int = 0
var total_frames: int = 3


func _ready() -> void:
	sprite.frame_coords = Vector2i(column_npc, 0)
	_apply_sort_lower()
	print("NPC ready with column: %d" % column_npc)

	if Engine.is_editor_hint():
		set_process(false)
	else:
		# Random offset so the NPCs do not animate in lockstep on scene start
		if random_start_offset and is_animated:
			timer_animation = randf_range(0.0, animation_speed)
			current_frame = randi() % total_frames
			sprite.frame_coords = Vector2i(column_npc, current_frame)

func _process(delta: float) -> void:
	if !is_animated:
		return

	timer_animation += delta
	if timer_animation >= animation_speed:
		timer_animation = 0.0
		current_frame = (current_frame + 1) % total_frames
		sprite.frame_coords = Vector2i(column_npc, current_frame)

# =========================
# Depth sorting
# =========================
## Keeps the art where it is (position + offset) and moves the sort point
## (the sprite's position) sort_lower pixels below the usual feet line.
## Idempotent: it can run again in the editor without drifting.
func _apply_sort_lower() -> void:
	var art_y := sprite.position.y + sprite.offset.y
	sprite.offset.y = FEET_OFFSET_Y - sort_lower
	sprite.position.y = art_y - sprite.offset.y
	# The shadow placed itself from the old offset: put it back at the feet.
	var shadow := sprite.get_node_or_null("Shadow") as CharacterShadow
	if shadow:
		shadow.feet_margin = shadow.feet_margin

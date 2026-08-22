@tool
extends CharacterBody2D

@export_range(0, 9) var column_npc: int = 0:
	set(value):
		column_npc = value
		if is_node_ready() and sprite:
			sprite.frame_coords = Vector2i(column_npc, 0)

@export var is_animated: bool = true
@export var animation_speed: float = 0.5
@export var random_start_offset: bool = true # Opción para activar/desactivar la desincronización

@onready var sprite: Sprite2D = $Sprite2D
var timer_animation: float = 0.0
var current_frame: int = 0
var total_frames: int = 3


func _ready() -> void:
	sprite.frame_coords = Vector2i(column_npc, 0)
	print("NPC ready with column: %d" % column_npc)

	if Engine.is_editor_hint():
		set_process(false)
	else:
		# Desfase aleatorio para romper la sincronía al iniciar la escena
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
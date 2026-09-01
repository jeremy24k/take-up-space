extends Node2D

# =========================
# Stair configuration
# =========================
@export_group("Stair Movement")
@export var first_step_vector: Vector2 = Vector2(-32, 0)   # First segment (left)
@export var second_step_vector: Vector2 = Vector2(0, 48)   # Second segment (down)

@export_group("Animations")
@export var first_anim: String = "walk_side"
@export var second_anim: String = "walk_front"
@export var final_anim: String = "idle_front"
@export var flip_sprite: bool = true  # Enable/disable sprite flip

@export_group("Visual Effects")
@export var target_scale: Vector2 = Vector2(0.75, 0.75)
@export var target_color: Color = Color(0.7, 0.7, 0.9, 1.0)
@export var step_duration: float = 0.8

@onready var stair_area: Area2D = $Area2D

# =========================
# Setup and signal connections
# =========================
func _ready() -> void:
	# Connect area signals
	stair_area.body_entered.connect(_on_stairs_area_body_entered)
	stair_area.body_exited.connect(_on_stairs_area_body_exited)

# =========================
# Stairs entry handling
# 1) Lock player control
# 2) Apply visual effects
# 3) Execute movement sequence
# 4) Play final animation
# =========================
func _on_stairs_area_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return

	# Take control away from the player while she is on the stairs
	player.lock_control()

	var total_time = step_duration * 2.0

	# Apply continuous visual animations (scale + color tint)
	_apply_visual_effects(player, total_time)

	# Execute movement sequence
	await _execute_movement_sequence(player)

	# Play final idle animation
	player.play_animation(final_anim)
	
	# Uncomment to change scene after stairs animation
	FadeTransition.transition_to_scene("res://scenes/prologue_scene/scenes/metro_stations.tscn")

# =========================
# Stairs exit handling
# 1) Unlock player control
# 2) Restore visual properties
# =========================
func _on_stairs_area_body_exited(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return

	# Give control back when leaving the stairs
	player.unlock_control()

	# Restore original scale and color
	var tween = create_tween().set_parallel(true)
	tween.tween_property(player, "scale", Vector2(1.0, 1.0), 0.5)
	tween.tween_property(player, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	
	await tween.finished

# =========================
# Visual effects helper
# =========================
func _apply_visual_effects(player: Player, total_time: float) -> void:
	var visual_tween = create_tween().set_parallel(true)
	visual_tween.tween_property(player, "scale", target_scale, total_time)
	visual_tween.tween_property(player, "modulate", target_color, total_time)

# =========================
# Movement sequence helper
# =========================
func _execute_movement_sequence(player: Player) -> void:
	var pos_tween = create_tween()

	# First segment - walking sideways
	player.play_animation(first_anim)
	if flip_sprite:
		player.player_animation.flip_h = true

	pos_tween.tween_property(player, "global_position", player.global_position + first_step_vector, step_duration)

	# Second segment - walking down
	pos_tween.tween_callback(func():
		player.play_animation(second_anim)
	)

	pos_tween.tween_property(player, "global_position", player.global_position + first_step_vector + second_step_vector, step_duration)

	await pos_tween.finished

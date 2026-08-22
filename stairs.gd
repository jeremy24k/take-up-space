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
# 1) Disable physics
# 2) Apply visual effects
# 3) Execute movement sequence
# 4) Play final animation
# =========================
func _on_stairs_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Disable physics while on stairs
	body.set_physics_process(false)
	
	# Get the player's sprite
	var sprite = body.get_node_or_null("AnimatedSprite2D")
	var total_time = step_duration * 2.0
	
	# Apply continuous visual animations (scale + color tint)
	_apply_visual_effects(body, total_time)
	
	# Execute movement sequence
	await _execute_movement_sequence(body, sprite)
	
	# Play final idle animation
	if sprite and final_anim != "":
		sprite.play(final_anim)
	
	# Uncomment to change scene after stairs animation
	get_tree().change_scene_to_file("res://scenes/prologue_scene/scenes/metro_stations.tscn")

# =========================
# Stairs exit handling
# 1) Re-enable physics
# 2) Restore visual properties
# =========================
func _on_stairs_area_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Re-enable physics when leaving stairs
	body.set_physics_process(true)
	
	# Restore original scale and color
	var tween = create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(1.0, 1.0), 0.5)
	tween.tween_property(body, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	
	await tween.finished

# =========================
# Visual effects helper
# =========================
func _apply_visual_effects(body: Node2D, total_time: float) -> void:
	var visual_tween = create_tween().set_parallel(true)
	visual_tween.tween_property(body, "scale", target_scale, total_time)
	visual_tween.tween_property(body, "modulate", target_color, total_time)

# =========================
# Movement sequence helper
# =========================
func _execute_movement_sequence(body: Node2D, sprite: AnimatedSprite2D) -> void:
	var pos_tween = create_tween()
	
	# First segment - walking sideways
	if sprite and first_anim != "":
		sprite.play(first_anim)
		if flip_sprite:
			sprite.flip_h = true
	
	pos_tween.tween_property(body, "global_position", body.global_position + first_step_vector, step_duration)
	
	# Second segment - walking down
	pos_tween.tween_callback(func():
		if sprite and second_anim != "":
			sprite.play(second_anim)
	)
	
	pos_tween.tween_property(body, "global_position", body.global_position + first_step_vector + second_step_vector, step_duration)
	
	await pos_tween.finished

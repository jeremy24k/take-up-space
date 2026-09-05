class_name WalkingNPC
extends CharacterBody2D

# =========================
# Movement configuration
# =========================
const DEFAULT_WALK_SPEED: float = 40.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing: Vector2 = Vector2.DOWN

# =========================
# Approach point configuration
# =========================
@export_group("Approach Point")
## When on, this NPC always walks to its own ApproachPoint marker, ignoring
## whatever target position it is asked to approach.
@export var use_fixed_approach_point: bool = false
## Offset applied to the given target when not using a fixed approach point.
@export var approach_offset: Vector2 = Vector2(-14, 0)

## Optional child marker (add one named "ApproachPoint") for use_fixed_approach_point.
@onready var approach_point: Marker2D = get_node_or_null("ApproachPoint")

# =========================
# Facing and animation
# =========================
## Same guarded pattern as Player.play_animation(): stays silent if the
## animation does not exist yet, so a walking NPC keeps working before its
## walk cycle is drawn.
func _play_animation(animation_name: String) -> void:
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

func face_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	facing = direction
	_play_animation("idle_" + _direction_suffix(direction))

func _direction_suffix(direction: Vector2) -> String:
	# Side movement has priority and controls horizontal flip.
	if abs(direction.x) > abs(direction.y):
		sprite.flip_h = direction.x < 0
		return "side"
	else:
		return "back" if direction.y < 0 else "front"

# =========================
# Approach point resolution
# =========================
## Resolves where this NPC should walk to: its own ApproachPoint marker if
## use_fixed_approach_point is on and the marker exists, otherwise
## target_position + approach_offset.
func resolve_approach_point(target_position: Vector2) -> Vector2:
	if use_fixed_approach_point and approach_point:
		return approach_point.global_position
	return target_position + approach_offset

# =========================
# Scripted movement
# =========================
## Walks in a straight line to target_position, playing the matching walk
## animation, then settles into an idle facing the direction it arrived from.
func walk_to(target_position: Vector2, speed: float = DEFAULT_WALK_SPEED) -> void:
	var direction := global_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		return

	_play_animation("walk_" + _direction_suffix(direction))

	var distance := global_position.distance_to(target_position)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_position, distance / speed)
	await tween.finished

	face_direction(direction)

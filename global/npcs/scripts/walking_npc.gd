class_name WalkingNPC
extends CharacterBody2D

# =========================
# Movement configuration
# =========================
const DEFAULT_WALK_SPEED: float = 40.0
## Physics layer used while standing still, so this NPC blocks Alice like any
## other solid body. Cleared to 0 while walking: a scripted move should never
## be able to pin the player against a wall, and a person-sized sprite should
## still look solid the rest of the time (unlike a small cat, e.g. Wilson).
const SOLID_COLLISION_LAYER: int = 1

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
# Interaction configuration
# =========================
@export_group("Interaction")
## When on, the owning scene freezes this NPC while Alice talks to it. Turn
## it off for passers-by that should keep walking as if they never noticed her.
@export var stops_when_talked_to: bool = true
## Animation played while it is stopped for a dialogue (e.g. the street cat's
## "meow"). Empty = it just freezes on its current frame.
@export var talk_animation: String = ""
## Distance (px) at which it stops walking and turns to Alice, so a passer-by
## gives the player time to press Space. It walks on once she is a bit
## further away. 0 = never stops.
@export var pause_near_player: float = 0.0

## Extra distance before walking on again, so it does not stutter at the edge.
const PAUSE_HYSTERESIS: float = 12.0

var _walk_tween: Tween
var _walk_direction := Vector2.ZERO
var _paused_for_player: bool = false

# =========================
# Pausing near Alice
# =========================
func _physics_process(_delta: float) -> void:
	if pause_near_player <= 0.0 or _walk_tween == null or not _walk_tween.is_valid():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if not _paused_for_player and distance <= pause_near_player:
		_paused_for_player = true
		_walk_tween.pause()
		face_direction(global_position.direction_to(player.global_position))
	elif _paused_for_player and distance <= pause_near_player + PAUSE_HYSTERESIS:
		# Keeps looking at her if she walks around it.
		face_direction(global_position.direction_to(player.global_position))
	elif _paused_for_player:
		_paused_for_player = false
		_play_animation("walk_" + _direction_suffix(_walk_direction))
		_walk_tween.play()

# =========================
# Patrol configuration
# =========================
@export_group("Patrol")
## Points walked in order, then back, forever, once the scene calls
## start_patrol(). Drag Marker2D nodes here (two or more) and reorder freely;
## each leg is a straight line, so add a point to go round a corner. Keep the
## markers outside the NPC (e.g. a PedestrianRoutes folder): as its children
## they would move with it.
@export var patrol_points: Array[Marker2D] = []
@export var patrol_speed: float = 28.0
## Seconds it rests at each end of the route, facing the camera.
@export var patrol_pause: float = 2.5

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
	var idle := "idle_" + _direction_suffix(direction)
	if sprite.sprite_frames.has_animation(idle):
		sprite.play(idle)
	elif sprite.sprite_frames.has_animation("idle_front"):
		# Several sprites only have a front idle (e.g. the street pedestrians):
		# standing still facing the camera beats sliding in a walk cycle.
		sprite.flip_h = false
		sprite.play("idle_front")
	else:
		sprite.stop()

func _direction_suffix(direction: Vector2) -> String:
	# Side movement has priority and controls horizontal flip.
	if abs(direction.x) > abs(direction.y):
		sprite.flip_h = direction.x < 0
		return "side"
	else:
		# Front/back art is drawn unflipped; clear any flip left by a side walk.
		sprite.flip_h = false
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
	collision_layer = 0
	var direction := await _walk_leg(target_position, speed)
	if direction != Vector2.ZERO:
		face_direction(direction)
	collision_layer = SOLID_COLLISION_LAYER

## Walks through each point in order (straight line per leg), so a route can
## step around a corner or a wall instead of cutting through it. Stays
## non-solid for the whole trip, not just leg by leg, and only settles into
## an idle pose once it reaches the last point.
func walk_path(points: Array[Vector2], speed: float = DEFAULT_WALK_SPEED) -> void:
	collision_layer = 0
	var last_direction := Vector2.ZERO
	for point in points:
		var direction := await _walk_leg(point, speed)
		if direction != Vector2.ZERO:
			last_direction = direction
	if last_direction != Vector2.ZERO:
		face_direction(last_direction)
	collision_layer = SOLID_COLLISION_LAYER

## Walks patrol_points forward, then backwards, forever, resting
## patrol_pause seconds at each end. Starts at the first point. Does nothing
## with fewer than two points.
func start_patrol() -> void:
	var points: Array[Vector2] = []
	for marker in patrol_points:
		if marker:
			points.append(marker.global_position)
	if points.size() < 2:
		return
	global_position = points[0]
	var forward := true
	while is_inside_tree():
		var leg: Array[Vector2] = points.duplicate()
		if not forward:
			leg.reverse()
		leg.remove_at(0)
		await walk_path(leg, patrol_speed)
		# Walkers only walk sideways; they rest facing the camera.
		face_direction(Vector2.DOWN)
		await get_tree().create_timer(patrol_pause).timeout
		forward = not forward

## One leg of movement: tweens straight to target_position while playing the
## matching walk animation. Returns the direction walked (Vector2.ZERO if
## already there), with no facing/collision side effects - callers decide those.
func _walk_leg(target_position: Vector2, speed: float) -> Vector2:
	var direction := global_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		return Vector2.ZERO

	_walk_direction = direction
	if _paused_for_player:
		# A new leg started while she was standing next to it: start it paused.
		face_direction(global_position.direction_to(_player_position()))
	else:
		_play_animation("walk_" + _direction_suffix(direction))

	var distance := global_position.distance_to(target_position)
	_walk_tween = create_tween()
	_walk_tween.tween_property(self, "global_position", target_position, distance / speed)
	if _paused_for_player:
		_walk_tween.pause()
	await _walk_tween.finished

	return direction

func _player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player.global_position if player else global_position + _walk_direction

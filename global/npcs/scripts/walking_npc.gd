@tool
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

## This NPC's animations (an .aseprite imported as SpriteFrames). Set it here,
## on the NPC, instead of on its AnimatedSprite2D: the script is @tool, so the
## editor shows the real sprite, and the template's placeholder stays as the
## fallback when this is empty. (Overriding sprite_frames on the child got
## lost in the plaza more than once, 2026-11-03.)
@export var frames: SpriteFrames:
	set(value):
		frames = value
		if is_node_ready():
			_apply_frames()

var facing: Vector2 = Vector2.DOWN
## Where it is going, or where it will go next while it rests between legs
## of a patrol (its sprite may be facing the camera meanwhile). Followers
## look this way when they stand still.
var heading: Vector2 = Vector2.RIGHT

## Prefix of the movement cycle: "walk" plays walk_side/front/back, "run"
## plays run_side/... (e.g. a jogger). A missing front/back cycle falls back
## to the side one, so a sprite drawn only from the side still moves.
@export var move_animation: String = "walk"

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
func _physics_process(delta: float) -> void:
	if _trail_leader != null:
		_walk_the_trail(delta)
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
		play_move(_walk_direction)
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
## If larger than patrol_pause, each rest lasts a random time between the
## two (e.g. 12-15 s, so a jogger does not run all the time).
@export var patrol_pause_max: float = 0.0
## On: goes round the points as a circuit (last point back to the first)
## without stopping, like a jogger doing laps. Off: there and back.
@export var patrol_loop: bool = false

# =========================
# Facing and animation
# =========================
## Same guarded pattern as Player.play_animation(): stays silent if the
## animation does not exist yet, so a walking NPC keeps working before its
## walk cycle is drawn.
func _play_animation(animation_name: String) -> void:
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

## Plays the movement cycle for direction (move_animation prefix). Public so a
## scene can animate an NPC it moves by itself (e.g. Lía glued to Alice). With no
## front/back cycle it uses the side one, flipped by the horizontal part of
## the direction.
func play_move(direction: Vector2) -> void:
	var animation_name := move_animation + "_" + _direction_suffix(direction)
	if not sprite.sprite_frames.has_animation(animation_name):
		animation_name = move_animation + "_side"
		if absf(direction.x) > 0.01:
			sprite.flip_h = direction.x < 0
	_play_animation(animation_name)

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
	elif sprite.sprite_frames.has_animation("idle_side"):
		# Side-only sprites (e.g. a dog) turn towards where they look.
		if absf(direction.x) > 0.01:
			sprite.flip_h = direction.x < 0
		sprite.play("idle_side")
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
	if patrol_loop:
		_patrol_circuit(points)
		return
	var forward := true
	while is_inside_tree():
		var leg: Array[Vector2] = points.duplicate()
		if not forward:
			leg.reverse()
		leg.remove_at(0)
		await walk_path(leg, patrol_speed)
		# Walkers only walk sideways; they rest facing the camera.
		face_direction(Vector2.DOWN)
		forward = not forward
		var next_point := points[1] if forward else points[points.size() - 2]
		heading = global_position.direction_to(next_point)
		await get_tree().create_timer(_rest_time()).timeout

## Laps around points, back to the first one each time, with patrol_pause
## (if any) at the start of every lap.
func _patrol_circuit(points: Array[Vector2]) -> void:
	var lap: Array[Vector2] = points.duplicate()
	lap.remove_at(0)
	lap.append(points[0])
	while is_inside_tree():
		await walk_path(lap, patrol_speed)
		if patrol_pause > 0.0:
			face_direction(Vector2.DOWN)
			heading = global_position.direction_to(lap[0])
			await get_tree().create_timer(_rest_time()).timeout

# =========================
# Following someone's trail
# =========================
## Walks behind leader (e.g. Lía holding Alice's sleeve) along the path the
## leader actually took: the leader's positions are kept as a trail and this
## NPC heads for the point `gap` px back along it, so it only steps where the
## leader already stepped and never cuts a corner through a wall or jumps to
## the other side when the leader turns. It moves with move_and_slide against
## the world (collision mask 1) and is not solid itself, so it never blocks
## the leader. If it is ever stuck far behind, it hops onto the trail.
func follow_trail(leader: Node2D, gap: float, max_speed: float) -> void:
	stop_following()
	_trail_leader = leader
	_trail_gap = gap
	_trail_speed = max_speed
	_trail = PackedVector2Array([global_position, leader.global_position])
	_trail_stuck_time = 0.0
	collision_layer = 0
	collision_mask = SOLID_COLLISION_LAYER

func stop_trail() -> void:
	_trail_leader = null
	velocity = Vector2.ZERO

func is_on_trail() -> bool:
	return _trail_leader != null

var _trail_leader: Node2D
var _trail := PackedVector2Array()
var _trail_gap: float = 24.0
var _trail_speed: float = 120.0
var _trail_stuck_time: float = 0.0
## The leader leaves a trail point every few px; enough of them are kept to
## cover a long detour.
const TRAIL_STEP: float = 3.0
const TRAIL_MAX_POINTS: int = 600
## Closer than this to its spot it stands still.
const TRAIL_SETTLE: float = 2.0
## How fast it closes the gap (higher = tighter).
const TRAIL_STIFFNESS: float = 8.0
## Stuck (barely moving while far behind) this long: it hops onto the trail.
const TRAIL_STUCK_LIMIT: float = 1.2

func _walk_the_trail(delta: float) -> void:
	if not is_instance_valid(_trail_leader):
		stop_trail()
		return
	var lead := _trail_leader.global_position
	if lead.distance_to(_trail[_trail.size() - 1]) >= TRAIL_STEP:
		_trail.append(lead)
		if _trail.size() > TRAIL_MAX_POINTS:
			_trail.remove_at(0)
	var target := _trail_point_behind(_trail_gap)
	var to_target := target - global_position
	if to_target.length() <= TRAIL_SETTLE:
		velocity = Vector2.ZERO
		_trail_stuck_time = 0.0
		face_direction(_trail_heading())
		return
	var before := global_position
	velocity = to_target.normalized() * minf(_trail_speed, to_target.length() * TRAIL_STIFFNESS)
	move_and_slide()
	var moved := global_position - before
	if moved.length() > 0.05:
		play_move(moved)
	# Pushed against something while the leader gets away: catch up.
	if moved.length() < 0.2 and to_target.length() > _trail_gap * 2.0:
		_trail_stuck_time += delta
		if _trail_stuck_time >= TRAIL_STUCK_LIMIT:
			global_position = target
			_trail_stuck_time = 0.0
	else:
		_trail_stuck_time = 0.0

## The point `distance` px back along the trail from the leader (or the
## oldest one if the trail is shorter).
func _trail_point_behind(distance: float) -> Vector2:
	var left := distance
	var i := _trail.size() - 1
	var point := _trail[i]
	while i > 0:
		var previous := _trail[i - 1]
		var step := point.distance_to(previous)
		if step >= left:
			return point.move_toward(previous, left)
		left -= step
		point = previous
		i -= 1
	return point

## Which way the leader was last going (to look that way when standing).
func _trail_heading() -> Vector2:
	var n := _trail.size()
	if n < 2:
		return facing
	return _trail[n - 2].direction_to(_trail[n - 1])

# =========================
# Following someone
# =========================
func _rest_time() -> float:
	if patrol_pause_max > patrol_pause:
		return randf_range(patrol_pause, patrol_pause_max)
	return patrol_pause

## Keeps this NPC at a fixed offset from leader (e.g. a dog on its owner's
## leash): it does not swing round when the leader turns, so on the way
## back it simply goes on the other side. It catches up smoothly, runs with
## move_animation while catching up and, when it stands still, looks where
## the leader is heading (a WalkingNPC's `heading`: at the end of a patrol
## leg, towards the next point). Call stop_following() before moving it by
## script.
func follow(leader: Node2D, offset: Vector2 = Vector2(14, 4)) -> void:
	stop_trail()
	_leader = leader
	_follow_offset = offset
	_leader_last_position = leader.global_position
	collision_layer = 0
	set_process(true)

func stop_following() -> void:
	_leader = null
	set_process(false)

func is_following() -> bool:
	return _leader != null

var _leader: Node2D
var _follow_offset := Vector2.ZERO
var _leader_last_position := Vector2.ZERO
## How fast it closes the gap (higher = tighter leash).
const FOLLOW_STIFFNESS: float = 8.0
## Closer than this to its spot it stands still instead of running.
const FOLLOW_SETTLE: float = 2.0

func _ready() -> void:
	set_process(false)
	_apply_frames()
	if Engine.is_editor_hint():
		# Only the sprite preview runs in the editor.
		set_physics_process(false)

## Puts `frames` on the sprite and shows it standing still (front if it has
## that pose, else its side).
func _apply_frames() -> void:
	if frames == null or sprite == null:
		return
	sprite.sprite_frames = frames
	for idle in ["idle_front", "idle_side"]:
		if frames.has_animation(idle):
			sprite.play(idle)
			return

func _process(delta: float) -> void:
	if _leader == null or not is_instance_valid(_leader):
		stop_following()
		return
	var leader_motion := _leader.global_position - _leader_last_position
	_leader_last_position = _leader.global_position
	var gap := _leader.global_position + _follow_offset - global_position
	if gap.length() <= FOLLOW_SETTLE and leader_motion.length() <= 0.05:
		var look: Vector2 = _leader.heading if _leader is WalkingNPC else Vector2.ZERO
		face_direction(look)
		return
	global_position += gap * minf(1.0, FOLLOW_STIFFNESS * delta)
	play_move(leader_motion if leader_motion.length() > 0.05 else gap)

## One leg of movement: tweens straight to target_position while playing the
## matching walk animation. Returns the direction walked (Vector2.ZERO if
## already there), with no facing/collision side effects - callers decide those.
func _walk_leg(target_position: Vector2, speed: float) -> Vector2:
	var direction := global_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		return Vector2.ZERO

	_walk_direction = direction
	heading = direction
	if _paused_for_player:
		# A new leg started while she was standing next to it: start it paused.
		face_direction(global_position.direction_to(_player_position()))
	else:
		play_move(direction)

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

@tool
class_name PigeonFlock
extends Node2D

# =========================
# Flock configuration
# =========================
## A small group of pigeons pecking around on the ground. When Alice gets
## close they all take off, away from her, and are gone for good (until the
## scene loads again). Place the node where the group should stand; the birds
## spread around that point. Put it in a y-sorted layer, next to the people.
## In the editor it shows a still preview (not saved in the scene) plus the
## area they stand in and how close Alice can get, to help placing it; the
## real birds are made, at random, when the game starts.
signal flew_away
## Alice came within scare_distance + notice_margin for the first time,
## just before she would scare them. A scene can set `calm` in its handler
## (signals run at once) to keep them on the ground and stage something
## (Lía running up to them), then call fly_away_from() itself.
signal player_approached

const FRAMES: SpriteFrames = preload("res://global/npcs/assets/pigeons.aseprite")
const SHADOW_SCENE: PackedScene = preload("res://global/character_shadow.tscn")
## Plumages in pigeons.aseprite: each has <color>_peck, _stand, _sit, _rest.
const COLORS: Array[String] = [
	"city", "city", "city", "gray", "greenneck", "checkered", "white", "brown", "tan", "cream", "albino",
]
const IDLE_POSES: Array[String] = ["peck", "peck", "stand", "rest", "sit"]
## The picture's feet sit this far above the bottom of its 16 px frame.
const FEET_OFFSET := Vector2(0, -7)

## How many birds. 0 picks 3 or 4.
@export_range(0, 8) var count: int = 0:
	set(value):
		count = value
		_refresh_preview()
## How far from this node the birds can stand.
@export var spread: Vector2 = Vector2(20, 10):
	set(value):
		spread = value
		_refresh_preview()
## Each bird wanders this far at most from where it appeared, in short
## walks at walk_speed. walk_chance is how often a pause ends in a walk
## instead of a new pose.
@export var wander_radius: float = 12.0
@export var walk_speed: float = 14.0
@export_range(0.0, 1.0) var walk_chance: float = 0.45
## Birds keep at least this far apart (and do not walk through each other).
@export var min_gap: float = 11.0
## Alice closer than this to any bird scares the whole group.
@export var scare_distance: float = 44.0:
	set(value):
		scare_distance = value
		queue_redraw()
## How much earlier than scare_distance player_approached is emitted.
@export var notice_margin: float = 28.0
## While on, Alice walking up to them does not scare them.
var calm: bool = false
## Flight speed: they leave at takeoff_speed and speed up to max_speed.
@export var takeoff_speed: float = 70.0
@export var max_speed: float = 280.0
@export var acceleration: float = 320.0
## On takeoff they grow a little, as if coming closer to the camera.
@export var takeoff_scale: float = 1.3
@export var takeoff_grow_time: float = 0.35
## Played once per flock when they take off. Leave empty for silence.
@export var takeoff_sound: AudioStream = preload("res://audio/sfx/pigeon_takeoff.ogg")
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var takeoff_volume_db: float = -5.0
## Cooing now and then while they are on the ground: one of these at random,
## every coo_interval seconds, from the flock (AudioStreamPlayer2D, fading
## out with distance) and only while Alice is within coo_hearing_distance.
## Empty = silent flock.
@export var coo_sounds: Array[AudioStream] = [
	preload("res://audio/sfx/pigeon_coo_1.ogg"),
	preload("res://audio/sfx/pigeon_coo_2.ogg"),
	preload("res://audio/sfx/pigeon_coo_3.ogg"),
]
@export var coo_interval: Vector2 = Vector2(5.0, 11.0)
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var coo_volume_db: float = -12.0
@export var coo_hearing_distance: float = 160.0

var _birds: Array[AnimatedSprite2D] = []
var _coo_player: AudioStreamPlayer2D
var _player: Node2D
var _flown: bool = false
var _noticed: bool = false
## Where the scare came from: they fly away from this point.
var _scare_origin := Vector2.ZERO
## Birds in the air -> their flight direction.
var _flying: Dictionary = {}
## Safety net: a bird that never shows on screen never "leaves" it.
const MAX_FLIGHT_TIME: float = 8.0

# =========================
# Setup
# =========================
func _ready() -> void:
	y_sort_enabled = true
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		_refresh_preview()
		return
	# Scenes find every flock through this group (e.g. the plaza's pigeon
	# moment with Lía).
	add_to_group(&"pigeon_flock")
	var total := count if count > 0 else randi_range(3, 4)
	for i in total:
		_birds.append(_make_bird())
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if not coo_sounds.is_empty():
		_coo_player = AudioStreamPlayer2D.new()
		_coo_player.bus = &"SFX"
		_coo_player.volume_db = coo_volume_db
		_coo_player.max_distance = coo_hearing_distance
		add_child(_coo_player)
		_schedule_coo()

func _make_bird() -> AnimatedSprite2D:
	var bird := AnimatedSprite2D.new()
	bird.sprite_frames = FRAMES
	bird.offset = FEET_OFFSET
	bird.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bird.position = _free_spawn_spot()
	bird.set_meta("target", bird.position)
	bird.flip_h = randf() < 0.5
	bird.set_meta("color", COLORS.pick_random())
	bird.set_meta("home", bird.position)
	if Engine.is_editor_hint():
		bird.animation = String(bird.get_meta("color")) + "_" + IDLE_POSES.pick_random()
		add_child(bird)
		return bird
	var shadow := SHADOW_SCENE.instantiate()
	shadow.set("small", true)
	bird.add_child(shadow)
	add_child(bird)
	_change_pose(bird)
	return bird

# =========================
# Editor preview
# =========================
## Rebuilt whenever count or spread change. The preview birds have no owner,
## so the editor never saves them into the scene.
func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for bird in _birds:
		bird.queue_free()
	_birds.clear()
	var total := count if count > 0 else 4
	for i in total:
		_birds.append(_make_bird())
	queue_redraw()

## The area the birds stand in (yellow) and how close Alice can get before
## they fly (red). Editor only.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var area := Rect2(-spread, spread * 2.0)
	draw_rect(area, Color(1, 0.85, 0.2, 0.18))
	draw_rect(area, Color(1, 0.85, 0.2, 0.8), false, 1.0)
	draw_arc(Vector2.ZERO, scare_distance + maxf(spread.x, spread.y), 0.0, TAU, 48, Color(1, 0.3, 0.3, 0.6), 1.0)

# =========================
# On the ground
# =========================
## Every few seconds each bird either switches pose (sometimes turning
## around) or takes a short walk around its spot, so the group never moves
## in step.
func _change_pose(bird: AnimatedSprite2D) -> void:
	if _flown:
		return
	var color := String(bird.get_meta("color"))
	var wait := randf_range(1.5, 4.0)
	var walk_time := _walk(bird, color) if randf() < walk_chance else -1.0
	if walk_time >= 0.0:
		wait += walk_time
	else:
		var pose: String = color + "_" + IDLE_POSES.pick_random()
		if bird.sprite_frames.has_animation(pose):
			bird.play(pose)
		if randf() < 0.3:
			bird.flip_h = not bird.flip_h
	# The bird may be gone (flown off screen) by the time the timer fires: a
	# weak reference, because a lambda holding a freed object raises an error.
	var ref: WeakRef = weakref(bird)
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		var still_here: AnimatedSprite2D = ref.get_ref()
		if still_here:
			_change_pose(still_here))

## A few steps to a random point near home, facing where it goes, then it
## stops pecking. Returns how long the walk takes, or -1 when there is no
## free spot to go to (then it changes pose instead).
func _walk(bird: AnimatedSprite2D, color: String) -> float:
	var home: Vector2 = bird.get_meta("home")
	var target := Vector2.ZERO
	var found := false
	for attempt in 10:
		target = (home + Vector2.from_angle(randf() * TAU) * randf_range(0.4, 1.0) * wander_radius).round()
		if _is_free_path(bird, bird.position, target):
			found = true
			break
	if not found:
		return -1.0
	var duration := bird.position.distance_to(target) / walk_speed
	if duration < 0.1:
		return -1.0
	bird.set_meta("target", target)
	# The art faces left: flip it when walking right.
	bird.flip_h = target.x > bird.position.x
	bird.play(color + "_stand")
	var tween := create_tween()
	tween.tween_property(bird, "position", target, duration)
	tween.tween_callback(func() -> void:
		if not _flown:
			bird.play(color + "_peck"))
	bird.set_meta("walk", tween)
	return duration

# =========================
# Cooing
# =========================
func _schedule_coo() -> void:
	get_tree().create_timer(randf_range(coo_interval.x, coo_interval.y)).timeout.connect(_coo)

func _coo() -> void:
	if _flown or not is_inside_tree():
		return
	if _player and global_position.distance_to(_player.global_position) <= coo_hearing_distance 			and not _coo_player.playing:
		_coo_player.stream = coo_sounds.pick_random()
		_coo_player.play()
	_schedule_coo()

# =========================
# Personal space
# =========================
## Where a new bird can appear: inside spread and min_gap away from the
## others (after a few tries it takes the last one, so it never gets stuck).
func _free_spawn_spot() -> Vector2:
	var spot := Vector2.ZERO
	for attempt in 30:
		spot = Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y)).round()
		if _is_free_path(null, spot, spot):
			break
	return spot

## True if walking from `from` to `to` keeps min_gap from every other bird,
## both where it stands now and where it is heading.
func _is_free_path(bird: AnimatedSprite2D, from: Vector2, to: Vector2) -> bool:
	for other in _birds:
		if other == bird or not is_instance_valid(other):
			continue
		var other_target: Vector2 = other.get_meta("target", other.position)
		if other_target.distance_to(to) < min_gap or other.position.distance_to(to) < min_gap:
			return false
		var closest := Geometry2D.get_closest_point_to_segment(other.position, from, to)
		if closest.distance_to(other.position) < min_gap * 0.8:
			return false
	return true

func _physics_process(_delta: float) -> void:
	if _flown or _player == null:
		return
	var nearest := INF
	for bird in _birds:
		nearest = minf(nearest, bird.global_position.distance_to(_player.global_position))
	if not _noticed and nearest < scare_distance + notice_margin:
		_noticed = true
		player_approached.emit()
	if not calm and nearest < scare_distance:
		fly_away_from(_player.global_position)

## Has the whole group take off now, away from `point` (e.g. Lía).
func fly_away_from(point: Vector2) -> void:
	if _flown:
		return
	_scare_origin = point
	_take_off()

func has_flown() -> bool:
	return _flown

# =========================
# Taking off
# =========================
func _take_off() -> void:
	_flown = true
	set_physics_process(false)
	if _coo_player:
		_coo_player.stop()
	if takeoff_sound:
		SoundManager.play_sfx(takeoff_sound, takeoff_volume_db)
	for bird in _birds:
		_fly(bird)
	flew_away.emit()
	get_tree().create_timer(MAX_FLIGHT_TIME).timeout.connect(queue_free)

## Away from the scare (usually Alice) and up, each with its own small delay and angle. They
## draw above everything while in the air, and their shadows stay behind.
## A bird is freed as soon as it leaves the screen; the flock goes with
## the last one.
func _fly(bird: AnimatedSprite2D) -> void:
	var away := (bird.global_position - _scare_origin).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var direction := (away + Vector2(0, -1.2)).normalized().rotated(randf_range(-0.35, 0.35))
	# The art faces left: flip it when flying right.
	bird.flip_h = direction.x > 0.0
	bird.z_index = 10
	# A null default counts as "no default" for get_meta, so check first.
	if bird.has_meta("walk"):
		(bird.get_meta("walk") as Tween).kill()
	_flap(bird)
	for child in bird.get_children():
		if child is Sprite2D:
			child.hide()
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-8, -15, 16, 16)
	notifier.screen_exited.connect(_on_bird_left_screen.bind(bird))
	bird.add_child(notifier)
	bird.set_meta("speed", 0.0)
	var ref: WeakRef = weakref(bird)
	get_tree().create_timer(randf_range(0.0, 0.15)).timeout.connect(func() -> void:
		var still_here: AnimatedSprite2D = ref.get_ref()
		if still_here:
			still_here.set_meta("speed", takeoff_speed)
			_flying[still_here] = direction
			var grow := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			grow.tween_property(still_here, "scale", Vector2.ONE * takeoff_scale, takeoff_grow_time))

func _process(delta: float) -> void:
	for bird: AnimatedSprite2D in _flying:
		var speed: float = minf(float(bird.get_meta("speed")) + acceleration * delta, max_speed)
		bird.set_meta("speed", speed)
		bird.position += _flying[bird] * speed * delta

func _on_bird_left_screen(bird: AnimatedSprite2D) -> void:
	_flying.erase(bird)
	_birds.erase(bird)
	bird.queue_free()
	if _birds.is_empty():
		queue_free()

## The sheet has no flying cycle: <color>_fly is used if it is ever drawn.
## Until then the wings-up frame of the peck and the standing frame take turns.
func _flap(bird: AnimatedSprite2D) -> void:
	var color := String(bird.get_meta("color"))
	if bird.sprite_frames.has_animation(color + "_fly"):
		bird.play(color + "_fly")
		return
	bird.stop()
	var wings_up: Texture2D = bird.sprite_frames.get_frame_texture(color + "_peck", 0)
	var wings_down: Texture2D = bird.sprite_frames.get_frame_texture(color + "_stand", 0)
	var still := SpriteFrames.new()
	still.add_frame("default", wings_up)
	still.add_frame("default", wings_down)
	still.set_animation_speed("default", 14.0)
	bird.sprite_frames = still
	bird.play("default")

class_name Player
extends CharacterBody2D

# =========================
# Player state definition
# =========================
enum State {
	IDLE,
	WALKING
}

const SPEED: float = 100.0
const INTERACTION_DISTANCE: float = 16.0
## Max pixels Alice is slid sideways to get past the edge of an obstacle (a
## lamp post, the corner of a crosswalk) instead of stopping dead on it.
const CORNER_CORRECTION: int = 8
const CORNER_SLIDE_SPEED: float = 60.0

@onready var player_animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_detector: Area2D = $InteractionDetector
## Alice is drawn in layers (player/alice.aseprite, imported split by layer):
## the body is player_animation, and each piece she can wear is a child
## sprite that copies the body's animation, frame and flip every frame.
@onready var backpack_layer: AnimatedSprite2D = $AnimatedSprite2D/Backpack
@onready var shoes_layer: AnimatedSprite2D = $AnimatedSprite2D/Shoes
@onready var headphones_neck_layer: AnimatedSprite2D = $AnimatedSprite2D/HeadphonesNeck
@onready var headphones_head_layer: AnimatedSprite2D = $AnimatedSprite2D/HeadphonesHead
@onready var outfit_layers: Array[AnimatedSprite2D] = [backpack_layer, shoes_layer, headphones_neck_layer, headphones_head_layer]

var current_state: State = State.IDLE
var last_direction: Vector2 = Vector2.DOWN # Face down by default while idle.
var can_move: bool = true
var is_control_locked: bool = false  # True while a scripted sequence owns the player.

# =========================
# Setup and dialogue hooks
# =========================
func _ready() -> void:
	Dialogic.timeline_started.connect(_on_dialogic_started)
	Dialogic.timeline_ended.connect(_on_dialogic_ended)
	GameManager.outfit_changed.connect(_refresh_outfit)
	# The body advances its own frames after this script's _process, so the
	# layers follow its signals, not the frame loop: otherwise they lag one
	# frame behind on every pose change and flicker.
	player_animation.frame_changed.connect(_sync_outfit)
	player_animation.animation_changed.connect(_sync_outfit)
	_refresh_outfit()

## Flip has no signal; it is set in _physics_process, before this runs.
func _process(_delta: float) -> void:
	_sync_outfit()

# =========================
# Main frame logic
# 1) Read movement input
# 2) Update state
# 3) Update animation
# =========================
func _physics_process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Block movement while dialogue is active.
	if !can_move:
		velocity = Vector2.ZERO
		return
	
	# Keep the last non-zero direction for facing and interaction.
	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
		update_interaction_detector_position()

	# Apply movement.
	_apply_corner_correction(direction, delta)
	velocity = direction * SPEED
	move_and_slide()

	# Update locomotion state.
	match current_state:
		State.IDLE:
			if direction != Vector2.ZERO:
				change_state(State.WALKING)
		
		State.WALKING:
			if direction == Vector2.ZERO:
				change_state(State.IDLE)

	# Refresh animation from current state + facing.
	process_animation_state()
	
# =========================
# Corner correction
# =========================
## Walking straight into an obstacle's edge: if there is room a few pixels to
## one side, slide that way so Alice slips past (crosswalk corners, thin posts)
## instead of having to line up pixel-perfect.
func _apply_corner_correction(direction: Vector2, delta: float) -> void:
	var is_straight := is_zero_approx(direction.x) != is_zero_approx(direction.y)
	if not is_straight:
		return
	var motion := direction * SPEED * delta
	if not test_move(global_transform, motion):
		return
	var side := Vector2(absf(direction.y), absf(direction.x)).sign()
	for offset in range(1, CORNER_CORRECTION + 1):
		for side_sign in [-1.0, 1.0]:
			var shift: Vector2 = side * offset * side_sign
			if test_move(global_transform, shift):
				continue
			if test_move(global_transform.translated(shift), motion):
				continue
			move_and_collide(side * side_sign * minf(offset, CORNER_SLIDE_SPEED * delta))
			return

# =========================
# Dialogue movement lock
# =========================
func _on_dialogic_started() -> void:
	# Thoughts (the cloud at the top, ThoughtBox) never stop her.
	if ThoughtBox.is_showing():
		return
	can_move = false
	# A cutscene lock already owns the pose (e.g. sitting asleep); don't
	# snap her to a generic idle just because a dialogue started.
	if not is_control_locked:
		set_static_idle()

func _on_dialogic_ended() -> void:
	# A cutscene lock outlives any dialogue played inside it.
	if not is_control_locked:
		can_move = true

func set_static_idle() -> void:
	current_state = State.IDLE
	var direction_suffix: String = get_direction_suffix(last_direction)
	player_animation.animation = "idle_" + direction_suffix
	player_animation.stop()

## Changes the facing direction and immediately applies the matching idle
## pose, so it survives the next _physics_process() instead of being
## overwritten by it a frame later.
func face_direction(direction: Vector2) -> void:
	last_direction = direction
	set_static_idle()

# =========================
# Cutscene control lock
# =========================
## Blocks movement and interaction while a scripted sequence is running.
func lock_control() -> void:
	is_control_locked = true
	can_move = false
	set_static_idle()

## Gives control back to the player once the sequence is over.
func unlock_control() -> void:
	is_control_locked = false
	can_move = true

# =========================
# Outfit layers
# =========================
## Shows the pieces Alice has picked up. The headphones are either around her
## neck or on her head (GameManager.headphones_on_head), never both.
func _refresh_outfit() -> void:
	backpack_layer.visible = GameManager.is_item_collected("alice_backpack")
	shoes_layer.visible = GameManager.is_item_collected("alice_shoes")
	var has_headphones := GameManager.is_item_collected("alice_headphones")
	headphones_neck_layer.visible = has_headphones and not GameManager.headphones_on_head
	headphones_head_layer.visible = has_headphones and GameManager.headphones_on_head
	_sync_outfit()

## Every layer shows the same animation, frame and flip as the body, so code
## only ever drives player_animation (play_animation, face_direction...).
func _sync_outfit() -> void:
	for layer in outfit_layers:
		if not layer.visible:
			continue
		if layer.animation != player_animation.animation:
			layer.animation = player_animation.animation
		layer.frame = player_animation.frame
		layer.flip_h = player_animation.flip_h

# =========================
# Cutscene camera
# =========================
## Glides Alice's camera until `target` (a world point) is at the centre of
## the screen, e.g. to show the glass tower or the train coming in. The
## camera limits still apply. Await it; pair it with reset_camera().
func pan_camera_to(target: Vector2, duration: float) -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var offset := camera.offset + target - camera.get_screen_center_position()
	var tween := create_tween()
	tween.tween_property(camera, "offset", offset, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished

## Brings the camera back onto Alice after pan_camera_to(). Await it.
func reset_camera(duration: float) -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := create_tween()
	tween.tween_property(camera, "offset", Vector2.ZERO, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished

# =========================
# State helpers
# =========================
func change_state(new_state: State) -> void:
	current_state = new_state
	
# =========================
# Interaction detector positioning
# =========================
func update_interaction_detector_position() -> void:
	var suffix: String = get_direction_suffix(last_direction)
	
	match suffix:
		"side":
			var sign_x: float = -1.0 if player_animation.flip_h else 1.0
			interaction_detector.position = Vector2(sign_x * INTERACTION_DISTANCE, 0)
		"back":
			interaction_detector.position = Vector2(0, -INTERACTION_DISTANCE)
		"front":
			interaction_detector.position = Vector2(0, INTERACTION_DISTANCE)

# =========================
# Animation control
# =========================
func process_animation_state() -> void:
	player_animation.play(player_animation.animation)

	match current_state:
		State.IDLE:
			var direccion_suffix: String = get_direction_suffix(last_direction)
			player_animation.animation = "idle_" + direccion_suffix

		State.WALKING:
			var direccion_suffix: String = get_direction_suffix(last_direction)
			player_animation.animation = "walk_" + direccion_suffix


## Plays an animation only if it exists, so sequences keep working while
## the sprites for them are still missing.
func play_animation(animation_name: String, fallback_name: String = "") -> void:
	if player_animation.sprite_frames.has_animation(animation_name):
		player_animation.play(animation_name)
	elif fallback_name != "" and player_animation.sprite_frames.has_animation(fallback_name):
		player_animation.play(fallback_name)

## Same guard as play_animation(), but plays the animation in reverse.
func play_animation_backwards(animation_name: String, fallback_name: String = "") -> void:
	if player_animation.sprite_frames.has_animation(animation_name):
		player_animation.play_backwards(animation_name)
	elif fallback_name != "" and player_animation.sprite_frames.has_animation(fallback_name):
		player_animation.play_backwards(fallback_name)

# =========================
# Direction and facing helper
# =========================
func get_direction_suffix(direction: Vector2) -> String:
	# Side movement has priority and controls horizontal flip.
	if abs(direction.x) > abs(direction.y):
		player_animation.flip_h = direction.x < 0
		return "side"
	else:
		return "back" if direction.y < 0 else "front"
	

# =========================
# Interaction input flow
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return

	# A conversation owns Space; a thought does not, so she can still use what
	# is in front of her while one is on screen.
	if Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		return

	if event.is_action_pressed("ui_accept"):
		_try_to_interact()

## When the detector touches more than one area (e.g. a shop window next to
## its door), the one closest to the detector wins.
func _try_to_interact() -> void:
	var closest: Area2D = null
	var closest_distance := INF
	for area in interaction_detector.get_overlapping_areas():
		if not area.has_method("interact"):
			continue
		var distance := interaction_detector.global_position.distance_to(_area_center(area))
		if distance < closest_distance:
			closest = area
			closest_distance = distance
	if closest:
		closest.interact()

## Center of the area's first CollisionShape2D (areas often offset their shape).
func _area_center(area: Area2D) -> Vector2:
	for child in area.get_children():
		if child is CollisionShape2D:
			return child.global_position
	return area.global_position
			
			

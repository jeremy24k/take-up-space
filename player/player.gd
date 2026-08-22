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

@onready var player_animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_detector: Area2D = $InteractionDetector

var current_state: State = State.IDLE
var last_direction: Vector2 = Vector2.DOWN # Face down by default while idle.
var can_move: bool = true

# =========================
# Setup and dialogue hooks
# =========================
func _ready() -> void:
	Dialogic.timeline_started.connect(_on_dialogic_started)
	Dialogic.timeline_ended.connect(_on_dialogic_ended)

# =========================
# Main frame logic
# 1) Read movement input
# 2) Update state
# 3) Update animation
# =========================
func _physics_process(_delta: float) -> void:
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
# Dialogue movement lock
# =========================
func _on_dialogic_started() -> void:
	can_move = false

func _on_dialogic_ended() -> void:
	can_move = true

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
	if Dialogic.current_timeline != null:
		return
		
	if event.is_action_pressed("ui_accept"):
		_try_to_interact()

func _try_to_interact() -> void:
	var areas = interaction_detector.get_overlapping_areas()
	for area in areas:
		if area.has_method("interact"):
			area.interact()
			break
			
			

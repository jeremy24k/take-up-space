class_name Wilson
extends CharacterBody2D

# =========================
# State management
# =========================
enum State {
	IDLE,
	WALKING,
	MEOWING
}

var current_state: State = State.MEOWING    
var last_direction: Vector2 = Vector2.DOWN  # Face down by default while idle.

# =========================
# Movement configuration
# =========================
@export var SPEED: float = 60.0
@export var stop_distance: float = 35.0
@export var target: Node2D

# =========================
# Node references
# =========================
@onready var animate_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var is_following: bool = false

# =========================
# Setup
# =========================
func _ready() -> void:
	GameManager.wilson = self  # Save reference to Wilson for later use.

	if target == null:
		target = get_tree().get_first_node_in_group("player")

	Dialogic.signal_event.connect(_on_dialogic_signal)

	call_deferred("actor_setup")

func _exit_tree() -> void:
	if GameManager.wilson == self:
		GameManager.wilson = null

func actor_setup() -> void:
	await get_tree().physics_frame
	if target:
		nav_agent.target_position = target.global_position

# =========================
# Physics processing
# =========================
func _physics_process(_delta: float) -> void:
	# 1. If not following or no target.
	if not is_following or target == null:
		_stop_movement(State.MEOWING)
		return 

	# Update target position in NavigationAgent2D.
	nav_agent.target_position = target.global_position

	# 2. If Alice is outside the reachable navigation map.
	if not nav_agent.is_target_reachable():
		var final_reachable_point: Vector2 = nav_agent.get_final_position()
		var distance_to_final_point: float = global_position.distance_to(final_reachable_point)

		# If Alice is outside the reachable navigation map, move to the nearest edge.
		if distance_to_final_point > 1.0:
			var next_path_pos: Vector2 = nav_agent.get_next_path_position()
			var dir: Vector2 = global_position.direction_to(next_path_pos)

			if dir != Vector2.ZERO:
				last_direction = dir

			velocity = SPEED * dir
			change_state(State.WALKING)
			process_animation_state()
			move_and_slide()
		else:
			# Once at the nearest edge, stop and wait.
			_stop_movement(State.IDLE)
		return

	# 3. Normal flow when Alice IS reachable.
	var distance_to_target: float = global_position.distance_to(target.global_position)

	if distance_to_target > stop_distance:
		var next_path_position: Vector2 = nav_agent.get_next_path_position()
		var direction: Vector2 = global_position.direction_to(next_path_position)

		if direction != Vector2.ZERO:
			last_direction = direction

		velocity = SPEED * direction
		change_state(State.WALKING)
	else:
		_stop_movement(State.IDLE)
		return
	
	process_animation_state()
	move_and_slide()

# Helper to stop movement cleanly.
func _stop_movement(target_state: State) -> void:
	velocity = Vector2.ZERO
	change_state(target_state)
	process_animation_state()
	move_and_slide()

# =========================
# State transitions
# =========================
func change_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state

# =========================
# Animation handling
# =========================
func process_animation_state() -> void:
	match current_state:
		State.IDLE:
			var direction_suffix: String = get_direction_suffix(last_direction)
			animate_sprite.animation = "idle_" + direction_suffix
		
		State.WALKING:
			var direction_suffix: String = get_direction_suffix(last_direction)
			animate_sprite.animation = "walk_" + direction_suffix
		
		State.MEOWING:
			animate_sprite.animation = "meowing"

	animate_sprite.play(animate_sprite.animation)

# =========================
# Direction utilities
# =========================
func get_direction_suffix(direction: Vector2) -> String:
	# Side movement has priority and controls horizontal flip.
	if abs(direction.x) > abs(direction.y) + 0.2:
		animate_sprite.flip_h = direction.x < 0
		return "side"
	else:
		return "back" if direction.y < 0 else "front"

# =========================
# Dialogic event handling
# =========================
func _on_dialogic_signal(argument: String) -> void:
	if argument == "wilson_start_follow":
		is_following = true
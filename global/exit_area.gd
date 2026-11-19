class_name ExitArea
extends Area2D

enum ExitDirection { UP, DOWN, LEFT, RIGHT }

# =========================
# Exit configuration
# =========================
## Fixed direction Alice walks off in, picked in the inspector.
@export var exit_direction: ExitDirection = ExitDirection.DOWN
## Simple forward step in exit_direction, so the exit reads without needing
## any dedicated art. Set to 0 to skip it and fade in place.
@export var walk_forward_distance: float = 16.0
@export var walk_forward_duration: float = 0.4
## How far into the walk the screen starts cutting to black - the fade plays
## while she is still mid-step, not once she stops moving.
@export var fade_start_delay: float = 0.2
@export var fade_duration: float = 1.0
## Scene loaded once the fade finishes. Leave empty to just play the walk
## with no scene change.
@export_file("*.tscn") var next_scene_path: String = ""
## Optional: the Marker2D under SpawnPoints in the next scene where Alice
## appears (that scene has to read GameManager.take_spawn_point()).
@export var spawn_point: String = ""
## On: instead of the short step, Alice walks on by herself until she is out
## of view (the camera stays put), and only then the fade starts. For exits
## that read as leaving the place (a street, the edge of the map), not doors.
@export var walk_off_screen: bool = false

## Emitted once Alice has walked out (walk_off_screen) or finished her step,
## right before the fade. With no next_scene_path the scene does its own
## ending on it.
signal walked_out

var has_triggered: bool = false

# =========================
# Setup
# =========================
func _ready() -> void:
	body_entered.connect(_on_body_entered)

# =========================
# Exit sequence
# =========================
func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player or has_triggered:
		return

	has_triggered = true
	set_deferred("monitoring", false)
	_exit(player)

func _exit(player: Player) -> void:
	player.lock_control()

	if walk_off_screen:
		await player.walk_off_screen(_direction_vector())
		walked_out.emit()
		if next_scene_path != "":
			GameManager.spawn_point = spawn_point
			FadeTransition.transition_to_scene(next_scene_path, fade_duration)
		return

	# A short continued step in the fixed direction sells the exit without
	# needing any dedicated art.
	if walk_forward_distance != 0.0:
		var direction := _direction_vector()
		var suffix := player.get_direction_suffix(direction)
		player.play_animation("walk_" + suffix, "idle_" + suffix)

		create_tween().tween_property(
			player, "global_position",
			player.global_position + direction * walk_forward_distance,
			walk_forward_duration
		)

	if next_scene_path != "":
		# The scene cuts partway through the walk, not once it stops -
		# not awaited above, so the step keeps playing under the fade.
		await get_tree().create_timer(fade_start_delay).timeout
		GameManager.spawn_point = spawn_point
		FadeTransition.transition_to_scene(next_scene_path, fade_duration)

func _direction_vector() -> Vector2:
	match exit_direction:
		ExitDirection.UP:
			return Vector2.UP
		ExitDirection.LEFT:
			return Vector2.LEFT
		ExitDirection.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

class_name BoundaryArea
extends "res://global/interactable_area.gd"

enum PushDirection { UP, DOWN, LEFT, RIGHT }

# =========================
# Boundary configuration
# =========================
## Direction Alice is walked back in - always pointing into the map.
@export var push_direction: PushDirection = PushDirection.DOWN
@export var push_distance: float = 24.0
@export var push_duration: float = 0.4

var _is_pushing_back: bool = false

# Emitted once Alice has been walked back and has control again.
signal pushed_back

# =========================
# Trigger on step-in
# =========================
# Fires when Alice's body steps on the area, like ThoughtTrigger: no prompt,
# no key press. The scene masks it to the player body only (layer 2).
func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		interact()

# The interaction detector is ignored: only the body counts.
func _on_area_entered(_area: Area2D) -> void:
	pass

func _on_area_exited(_area: Area2D) -> void:
	pass

func update_label_text() -> void:
	pass

# =========================
# Push-back sequence
# =========================
func interact() -> void:
	if not _interaction_enabled or _is_pushing_back:
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if not player:
		return

	_is_pushing_back = true
	interacted.emit()
	await _push_back(player)
	_is_pushing_back = false
	pushed_back.emit()

	if one_time_interaction:
		_interaction_enabled = false
		set_deferred("monitoring", false)

func _push_back(player: Player) -> void:
	player.lock_control()

	if timeline_name != "":
		Dialogic.start(timeline_name)
		await Dialogic.timeline_ended

	var direction := _direction_vector()
	var suffix := player.get_direction_suffix(direction)
	player.play_animation("walk_" + suffix, "idle_" + suffix)

	var tween := create_tween()
	tween.tween_property(
		player, "global_position",
		player.global_position + direction * push_distance,
		push_duration
	)
	await tween.finished

	player.face_direction(direction)
	player.update_interaction_detector_position()
	player.unlock_control()

func _direction_vector() -> Vector2:
	match push_direction:
		PushDirection.UP:
			return Vector2.UP
		PushDirection.LEFT:
			return Vector2.LEFT
		PushDirection.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

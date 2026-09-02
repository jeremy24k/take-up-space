extends "res://global/interactable_area.gd"

# =========================
# Sitting configuration
# =========================
@export var sitting_animation: String = "idle_front"
@export var fade_duration: float = 1.0

# Emitted once Alice is seated and her sitting thoughts are over.
signal player_sat_down(seated_player: Player)

@onready var sit_point: Area2D = $SitPoint

var sequence_started: bool = false

# =========================
# Prompt text
# =========================
func update_label_text() -> void:
	if label:
		label.text = "[Espacio] Sentarse"

# =========================
# Interaction action
# =========================
func interact() -> void:
	# Prevent the sequence from starting more than once.
	if sequence_started:
		return
	sit_down()

# =========================
# Sitting sequence
# =========================
func sit_down() -> void:
	sequence_started = true
	monitoring = false
	if label:
		label.hide()

	var player := get_tree().get_first_node_in_group("player") as Player
	if not player:
		sequence_started = false
		monitoring = true
		return

	# Stop the player while the sitting sequence is running.
	player.lock_control()
	await FadeTransition.fade_out(fade_duration)

	# Move and change the player while the screen is black.
	player.global_position = sit_point.global_position
	player.play_animation(sitting_animation, "idle_front")

	await FadeTransition.fade_in(fade_duration)

	# Let the scene decide what happens next (thoughts, falling asleep, ...).
	player_sat_down.emit(player)

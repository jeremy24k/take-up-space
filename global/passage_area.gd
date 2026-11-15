class_name PassageArea
extends Area2D

# =========================
# Passage configuration
# =========================
## A short way between two rooms of the same scene that has no art (a door
## that leads through a wall): when Alice walks in, the screen dips to black
## and she comes out at exit_point, so she never walks through a black strip.
## Put one at each end; each exit_point must be outside the other end's area.
@export var exit_point: Marker2D
## The way Alice faces when she comes out.
@export var exit_facing: Vector2 = Vector2.UP
@export var fade_time: float = 0.2

var _is_passing: bool = false

# Emitted once Alice is on the other side and has control again.
signal passed

# =========================
# Setup
# =========================
func _ready() -> void:
	body_entered.connect(_on_body_entered)

# =========================
# Passage sequence
# =========================
func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player or _is_passing or exit_point == null:
		return
	_is_passing = true
	player.lock_control()
	await FadeTransition.fade_out(fade_time)
	player.global_position = exit_point.global_position
	player.face_direction(exit_facing)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	await FadeTransition.fade_in(fade_time)
	player.unlock_control()
	_is_passing = false
	passed.emit()

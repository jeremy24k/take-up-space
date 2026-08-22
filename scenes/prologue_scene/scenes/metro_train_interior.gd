extends Node2D

# =========================
# Camera shake configuration
# =========================
@export var shake_intensity: float = 0.5
@export var shake_speed: float = 15.0

@onready var camera: Camera2D = $Player/Camera2D
@onready var player: CharacterBody2D = $Player
@onready var thought_trigger: Node = $InitialThoughtTrigger

var noise_y: float = 0.0

# =========================
# Player spawn
# =========================
func _ready() -> void:
	# Place the player at the door used to enter the train.
	var door_spawn := get_node_or_null("SpawnContainers/DoorSpawn_%d" % GameManager.target_door_id) as Marker2D
	if door_spawn:
		player.global_position = door_spawn.global_position
		thought_trigger.call("show_thought", player)

# =========================
# Camera movement
# =========================
func _process(delta: float) -> void:
	# Apply a small movement while the train is moving.
	noise_y += delta * shake_speed
	var offset_x: float = sin(noise_y * 0.8) * shake_intensity
	var offset_y: float = cos(noise_y) * shake_intensity
	camera.offset = Vector2(offset_x, offset_y)

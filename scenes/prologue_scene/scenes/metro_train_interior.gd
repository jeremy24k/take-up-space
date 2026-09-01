extends Node2D

# =========================
# Camera shake configuration
# =========================
@export var shake_intensity: float = 0.5
@export var shake_speed: float = 15.0

# =========================
# Falling asleep configuration
# =========================
@export_group("Falling Asleep")
## Animation played while Alice starts to nod off (falls back to the sitting one).
@export var sleepy_animation: String = "sit_sleepy"
## Animation played once Alice is asleep (falls back to the sitting one).
@export var asleep_animation: String = "sit_asleep"
## Time between sitting down and the first sleepy frame.
@export var sleepy_delay: float = 2.0
## Time between the sleepy frame and the asleep one.
@export var asleep_delay: float = 1.5
## How long the screen, the lights and the sound take to fade out.
@export var darkening_duration: float = 3.5
## Color the scene fades to while Alice falls asleep.
@export var sleep_color: Color = Color(0.02, 0.03, 0.06, 1.0)
## Volume the train ambience fades down to before stopping.
@export var ambience_silence_db: float = -40.0

# Emitted once the screen is fully dark and Alice is asleep.
signal player_fell_asleep

@onready var camera: Camera2D = $Player/Camera2D
@onready var player: Player = $Player
@onready var thought_trigger: ThoughtTrigger = $InitialThoughtTrigger
@onready var interactive_container: Node2D = $InteractiveContainer
@onready var lights_container: LightsContainer = $LightsContainer
@onready var dark_filter: CanvasModulate = $LightsContainer/DarkFilter
@onready var train_ambience: AudioStreamPlayer = $TrainAmbience

var noise_y: float = 0.0
var is_falling_asleep: bool = false

# =========================
# Player spawn
# =========================
func _ready() -> void:
	# Place the player at the door used to enter the train.
	var door_spawn := get_node_or_null("SpawnContainers/DoorSpawn_%d" % GameManager.target_door_id) as Marker2D
	if door_spawn:
		player.global_position = door_spawn.global_position
		thought_trigger.show_thought(player)

	# Start the train loop only if an ambience track has been assigned.
	if train_ambience.stream:
		train_ambience.play()

	# Any seat in the car can start the falling asleep sequence.
	for seat in interactive_container.get_children():
		if seat.has_signal("player_sat_down"):
			seat.player_sat_down.connect(_on_player_sat_down)

# =========================
# Camera movement
# =========================
func _process(delta: float) -> void:
	# Apply a small movement while the train is moving.
	noise_y += delta * shake_speed
	var offset_x: float = sin(noise_y * 0.8) * shake_intensity
	var offset_y: float = cos(noise_y) * shake_intensity
	camera.offset = Vector2(offset_x, offset_y)

# =========================
# Falling asleep sequence
# =========================
func _on_player_sat_down(seated_player: Player) -> void:
	# Prevent the sequence from starting more than once.
	if is_falling_asleep:
		return
	is_falling_asleep = true
	_fall_asleep(seated_player)

func _fall_asleep(seated_player: Player) -> void:
	# 1. Alice starts to nod off.
	await get_tree().create_timer(sleepy_delay).timeout
	seated_player.play_animation(sleepy_animation)

	# 2. Her head drops.
	await get_tree().create_timer(asleep_delay).timeout
	seated_player.play_animation(asleep_animation)

	# 3. Image, shake and sound fade out together.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dark_filter, "color", sleep_color, darkening_duration)
	tween.tween_property(self, "shake_intensity", 0.0, darkening_duration)
	if train_ambience.stream:
		tween.tween_property(train_ambience, "volume_db", ambience_silence_db, darkening_duration)
	lights_container.fade_out_lights(darkening_duration)

	await tween.finished

	# The sudden silence is what sells the cut.
	if train_ambience.playing:
		train_ambience.stop()

	player_fell_asleep.emit()

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

# =========================
# Awakening configuration
# =========================
@export_group("Awakening")
## Animation played once Alice opens her eyes, signaled by the worker's
## dialogue (a [signal arg="alice_wakes_up"] event mid-timeline).
@export var awakening_animation: String = "sit_down"
## Cold tone of the stopped, powered down train car.
@export var awakening_color: Color = Color(0.28, 0.33, 0.46, 1.0)
## How long the car takes to come back into view as she opens her eyes.
@export var awakening_fade_duration: float = 2.0
## Energy the exit light reaches once it is guiding Alice to the platform.
@export var exit_light_energy: float = 0.9
## Timeline the worker plays once he reaches Alice.
@export var worker_timeline: String = "unknown_station_worker"
## How fast the worker walks over to Alice's seat.
@export var worker_walk_speed: float = 40.0

# Emitted once the screen is fully dark and Alice is asleep.
signal player_fell_asleep
# Emitted once Alice is awake and back in control.
signal player_woke_up

@onready var camera: Camera2D = $Player/Camera2D
@onready var player: Player = $Player
@onready var thought_trigger: ThoughtTrigger = $ThoughtTriggers/InitialThoughtTrigger
@onready var seat_thought_trigger: ThoughtTrigger = $ThoughtTriggers/SeatThoughtTrigger
@onready var interactive_container: Node2D = $InteractiveContainer
@onready var lights_container: LightsContainer = $LightsContainer
@onready var dark_filter: CanvasModulate = $LightsContainer/DarkFilter
@onready var exit_light: PointLight2D = $LightsContainer/ExitLight
@onready var train_ambience: AudioStreamPlayer = $TrainAmbience
@onready var npcs: Node2D = $Train/NPCS
@onready var worker_npc: WalkingNPC = $Train/NPCS/WorkerNPC
@onready var worker_collision: CollisionShape2D = $Train/NPCS/WorkerNPC/CollisionShape2D
@onready var exit_door: SceneTransitionArea = $ExitDoorArea

var noise_y: float = 0.0
var is_falling_asleep: bool = false

# =========================
# Setup
# =========================
func _ready() -> void:
	_setup_boarding_mode()

func _setup_boarding_mode() -> void:
	# The worker and the open door only exist once the train has stopped.
	_set_worker_active(false)
	exit_door.hide()
	exit_door.set_deferred("monitoring", false)

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
	# 1. What she thinks once she is settled in the seat.
	await seat_thought_trigger.show_thought(seated_player)

	# 2. Alice starts to nod off.
	await get_tree().create_timer(sleepy_delay).timeout
	seated_player.play_animation(sleepy_animation)

	# 3. Her head drops.
	await get_tree().create_timer(asleep_delay).timeout
	seated_player.play_animation(asleep_animation)

	# 4. Image, shake and sound fade out together.
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

	# 5. The car changes around her while the screen is dark.
	_setup_awakening_mode()
	await _wake_up(seated_player)


# =========================
# Awakening sequence
# =========================
## Rebuilds the car around Alice: same scene, same seat, stopped train.
func _setup_awakening_mode() -> void:
	# The train is stopped: no shake, no lights.
	shake_intensity = 0.0
	lights_container.turn_off_lights()

	# The car is empty now, and the seats must not start a second nap.
	_empty_the_car()
	interactive_container.hide()
	for seat in interactive_container.get_children():
		seat.set_deferred("monitoring", false)

	# The worker steps in and the door opens once the train has stopped.
	_set_worker_active(true)
	exit_door.show()
	exit_door.set_deferred("monitoring", true)

func _wake_up(sleeping_player: Player) -> void:
	# She is already locked from sitting down, and re-locking here would reset
	# her pose to a generic idle, erasing the sit_asleep animation she is in.

	# 1. The car comes back into view while she is still out, and the open
	# door lights up so she has somewhere to head towards once she can move.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dark_filter, "color", awakening_color, awakening_fade_duration)
	tween.tween_property(exit_light, "energy", exit_light_energy, awakening_fade_duration)

	# 2. The worker walks over while she is still out. She stays on
	# asleep_animation the whole time, since nothing here touches it.
	var approach_point: Vector2 = worker_npc.resolve_approach_point(sleeping_player.global_position)
	await worker_npc.walk_to(approach_point, worker_walk_speed)
	worker_npc.face_direction(worker_npc.global_position.direction_to(sleeping_player.global_position))

	# 3. Dialogic drives the whole conversation, including the exact moment
	# her eyes open - a [signal arg="alice_wakes_up"] event mid-timeline.
	Dialogic.start(worker_timeline)
	await _wait_for_signal("alice_wakes_up")
	sleeping_player.play_animation_backwards(awakening_animation)

	await Dialogic.timeline_ended

	# 4. She faces the open door before Alice gets control back.
	sleeping_player.face_direction(Vector2.DOWN)
	sleeping_player.unlock_control()
	player_woke_up.emit()

## Waits for a specific Dialogic [signal] event, ignoring any other signal
## that might fire in the meantime (Dialogic.signal_event is global).
func _wait_for_signal(expected_argument: String) -> void:
	var argument: Variant = await Dialogic.signal_event
	while argument != expected_argument:
		argument = await Dialogic.signal_event

# =========================
# Passenger helpers
# =========================
## The worker shares the NPCS container with the passengers, so the car is
## emptied one by one: hiding the container would take him down with it.
func _empty_the_car() -> void:
	for passenger in npcs.get_children():
		if passenger == worker_npc:
			continue

		passenger.hide()
		passenger.process_mode = Node.PROCESS_MODE_DISABLED

		# Their bodies would keep blocking Alice in an otherwise empty car.
		var passenger_collision := passenger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if passenger_collision:
			passenger_collision.set_deferred("disabled", true)

# =========================
# Worker visibility helper
# =========================
## Hiding the NPC is not enough: his body would still block Alice, so the
## collision goes with him.
func _set_worker_active(is_active: bool) -> void:
	worker_npc.visible = is_active
	worker_npc.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	worker_collision.set_deferred("disabled", not is_active)

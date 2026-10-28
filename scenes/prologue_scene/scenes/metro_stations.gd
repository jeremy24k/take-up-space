extends Node2D

# =========================
# Train arrival
# =========================
## Seconds Alice waits on the platform before the train comes in on its own.
## Walking to the platform edge (TrainTriggerArea) brings it in right away.
@export var platform_wait: float = 5.0
## The camera glides to where the train stops, so the player sees it come in
## and open its doors, then goes back to Alice. The point is the train's stop
## (station_position_x, its y) plus this offset, to frame the doors.
@export var train_view_offset := Vector2(0, 40)
const TRAIN_PAN_TIME: float = 1.0
## Seconds held after the train stops: the doors open 1 s after it does.
const TRAIN_HOLD_TIME: float = 1.6
const TRAIN_RETURN_TIME: float = 0.8
## Starts with the train already braking: it comes in in 4 s, then the doors.
const TRAIN_ARRIVAL_SOUND := preload("res://audio/sfx/train_arrival.ogg")
## The chime when the doors open and close.
const TRAIN_CHIME_SOUND := preload("res://audio/sfx/train_chime.ogg")

@onready var player: Player = $MiddleLayer/Player
@onready var metro_train = $MiddleLayer/MetroTrain
@onready var metro_train_area: Area2D = $TrainTriggerArea
@onready var platform_area: Area2D = $PlatformArea

var _train_called: bool = false
var _train_in: bool = false

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	Dialogic.start("metro_station")
	metro_train.doors_opened.connect(SoundManager.play_sfx.bind(TRAIN_CHIME_SOUND))
	metro_train.doors_closed.connect(SoundManager.play_sfx.bind(TRAIN_CHIME_SOUND))
	metro_train_area.body_entered.connect(_on_train_entered)
	platform_area.body_entered.connect(_on_platform_entered)

# =========================
# Triggers
# =========================
func _on_train_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_call_train()

## Anywhere on the platform counts: a player who just stands and waits still
## gets the train, instead of having to find the strip next to the tracks.
func _on_platform_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	platform_area.set_deferred("monitoring", false)
	await get_tree().create_timer(platform_wait).timeout
	_call_train()

func _call_train() -> void:
	if _train_called:
		return
	_train_called = true
	metro_train_area.set_deferred("monitoring", false)
	platform_area.set_deferred("monitoring", false)

	# Never cut a conversation short: the train waits for it, so the player
	# is free to watch it come in.
	while Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		await Dialogic.timeline_ended
	player.lock_control()
	metro_train.train_arrived.connect(func() -> void: _train_in = true, CONNECT_ONE_SHOT)
	SoundManager.play_sfx(TRAIN_ARRIVAL_SOUND)
	metro_train.enter_in_station()

	var stop := Vector2(metro_train.station_position_x, metro_train.global_position.y)
	await player.pan_camera_to(stop + train_view_offset, TRAIN_PAN_TIME)
	while not _train_in:
		await get_tree().process_frame
	await get_tree().create_timer(TRAIN_HOLD_TIME).timeout
	await player.reset_camera(TRAIN_RETURN_TIME)
	player.unlock_control()
	Dialogic.start("metro_is_entering_station")

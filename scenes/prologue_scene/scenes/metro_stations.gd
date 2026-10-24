extends Node2D

# =========================
# Train arrival
# =========================
## Seconds Alice waits on the platform before the train comes in on its own.
## Walking to the platform edge (TrainTriggerArea) brings it in right away.
@export var platform_wait: float = 5.0

@onready var metro_train = $MiddleLayer/MetroTrain
@onready var metro_train_area: Area2D = $TrainTriggerArea
@onready var platform_area: Area2D = $PlatformArea

var _train_called: bool = false

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	Dialogic.start("metro_station")
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

	metro_train.enter_in_station()

	# Never cut a conversation short: let it finish, then announce the train.
	if Dialogic.current_timeline != null:
		await Dialogic.timeline_ended
	Dialogic.start("metro_is_entering_station")

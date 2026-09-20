extends Node2D

@onready var metro_train: Node2D = $MiddleLayer/MetroTrain
@onready var train_trigger_area: Area2D = $InteractableDetectors/TrainTriggerArea
@onready var worker_interactable: InteractableArea = $MiddleLayer/NPCS/WorkerNPC/InteractableArea
@export var wait_time_for_phone_missing: float = 1

var train_has_left: bool = false
var worker_dialogue_started: bool = false

# =========================
# Setup
# =========================
func _ready() -> void:
	train_trigger_area.body_entered.connect(_on_train_trigger_area_body_entered)
	worker_interactable.interacted.connect(_on_worker_interacted)
	worker_interactable.area_entered.connect(_on_worker_area_entered)

# =========================
# Train departure sequence
# =========================
func _on_train_trigger_area_body_entered(body: Node2D) -> void:
	if train_has_left or not body.is_in_group("player"):
		return

	print("Train has left the station.")
	train_has_left = true
	train_trigger_area.set_deferred("monitoring", false)
	_depart_train()

func _depart_train() -> void:
	# The train pulls away while Alice is still in control for a beat, so the
	# player can walk around the platform and feel the disorientation before the
	# phone revelation lands.
	metro_train.leave_station()
	await get_tree().create_timer(wait_time_for_phone_missing).timeout # Wait a beat before the phone revelation lands.

	Dialogic.start("unknown_station_lost_phone")
	await Dialogic.timeline_ended

# =========================
# Worker conversation
# =========================
func _on_worker_area_entered(area: Area2D) -> void:
	# Getting close is enough - no need to press the interact key for this one.
	if area.get_parent() is Player:
		worker_interactable.interact()

func _on_worker_interacted() -> void:
	# Prevent the sequence from starting more than once.
	if worker_dialogue_started:
		return
	worker_dialogue_started = true
	# The timeline is launched by InteractableArea via timeline_name.
	# The player retains control until Dialogic hands it back.

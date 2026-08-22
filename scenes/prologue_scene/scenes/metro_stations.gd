extends Node2D

@onready var metro_train = $MiddleLayer/MetroTrain
@onready var metro_train_area = $TrainTriggerArea

func _ready() -> void:
	metro_train_area.body_entered.connect(_on_train_entered)

func _on_train_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		metro_train_area.set_deferred("monitoring", false)

		metro_train.enter_in_station()

		print("Train is entering the station.")
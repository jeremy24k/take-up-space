extends Node2D

# =========================
# Train movement configuration
# =========================
@export var arrival_time: float = 4.0
@export var station_position_x: float = 0.0
## Scene loaded once the train pulls away. Leave empty to just depart with
## no follow-up (e.g. an already-boarded train leaving an arrival platform).
@export_file("*.tscn") var next_scene_path: String = "res://scenes/prologue_scene/scenes/metro_train_interior.tscn"
@onready var train_visual: Node2D = $Train
@onready var interactive_areas: Node2D = $EnteredTrainArea
signal train_arrived
signal train_leaving_station
signal doors_opened
signal doors_closed

# =========================
# Setup
# =========================
func _ready() -> void:
		interactive_areas.visible = false

func enter_in_station() -> void:

	# Move the train to the station before opening the doors.
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Move the train to the station.
	tween.tween_property(self, "position:x", station_position_x, arrival_time)

	await tween.finished
	train_arrived.emit()
	print("Train has arrived at the station.")

	await get_tree().create_timer(1.0).timeout
	open_doors()

func open_doors() -> void:
	# Play the opening animation on every train door.
	for child in train_visual.get_children():
		if child is AnimatedSprite2D and child.name.begins_with("AnimatedDoor"):
			child.sprite_frames.set_animation_loop("opening_door", false)
			child.play("opening_door")

	print("Doors have been opened.")
	doors_opened.emit()
	interactive_areas.visible = true


func close_doors() -> void:
	# Play the closing animation and hide the interaction areas.
	for child in train_visual.get_children():
		if child is AnimatedSprite2D and child.name.begins_with("AnimatedDoor"):
			child.sprite_frames.set_animation_loop("closing_door", false)
			child.play("closing_door")

	print("Doors have been closed.")
	doors_closed.emit()
	interactive_areas.visible = false

	# Wait for the doors to close.
	await get_tree().create_timer(2.0).timeout
	leave_station()

func leave_station() -> void:
	# Move the train away before loading the interior scene.
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var leave_station_position_x: float = station_position_x - station_position_x * 2

	tween.tween_property(self, "position:x", leave_station_position_x, arrival_time * 1.5)

	await tween.finished
	train_leaving_station.emit()

	print("Train has left the station.")

	if next_scene_path != "":
		FadeTransition.transition_to_scene(next_scene_path)

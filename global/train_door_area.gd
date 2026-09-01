class_name TrainDoorArea
extends "res://global/interactable_area.gd"

# =========================
# Train door configuration
# =========================
@export var metro_train: Node2D
@export var door_id: int = 1

# =========================
# Setup
# =========================
func _ready() -> void:
	super._ready()
	# 'owner' is the root of the scene this node lives in (MetroTrain).
	if not metro_train:
		metro_train = owner as Node2D

# =========================
# Prompt text
# =========================
## Updates the interaction label text displayed to the player
# func update_label_text() -> void:
# 	if label:
# 		label.text = "[E] Enter the train"

# =========================
# Interaction action
# =========================
## Overrides the base interaction/collection action for the train boarding flow
func _collect_item() -> void:
	# Prevent multiple interactions while the sequence is starting
	monitoring = false 
	
	# Look the player up by group in the station scene.
	var player = get_tree().get_first_node_in_group("player") as Player
	
	if metro_train and player:     
		_board_train(player)

# =========================
# Boarding sequence
# =========================
## Handles the complete train boarding sequence
func _board_train(player: Player) -> void:
	# 1. Disable player movement
	player.lock_control()

	# Optional: Play walking animation towards the train
	player.play_animation("walk_back")

	# 2. Move player towards the dark area inside the train car using a Tween
	var dark_position: Vector2 = player.global_position + Vector2(0, -16)
	var tween = create_tween()
	
	tween.parallel().tween_property(player, "global_position", dark_position, 1.0)
	tween.parallel().tween_property(player, "modulate", Color(0.1, 0.1, 0.1, 1.0), 0.8)
	tween.parallel().tween_property(player, "z_index", -1, 0.8)

	await tween.finished

	player.play_animation("idle_back")

	# 3. Close the train doors
	await get_tree().create_timer(0.2).timeout
	if metro_train.has_method("close_doors"):
		metro_train.close_doors()

	# 4. Transition to the train interior scene
	await get_tree().create_timer(1.2).timeout
	GameManager.target_door_id = door_id
class_name TrainDoorArea
extends "res://global/interactable_area.gd"

@export var metro_train: Node2D

func _ready() -> void:
	super._ready()
	# 'owner' hace referencia a la raíz de la escena donde vive este nodo (MetroTrain)
	if not metro_train:
		metro_train = owner as Node2D

## Updates the interaction label text displayed to the player
# func update_label_text() -> void:
# 	if label:
# 		label.text = "[E] Enter the train"

## Overrides the base interaction/collection action for the train boarding flow
func _collect_item() -> void:
	# Prevent multiple interactions while the sequence is starting
	monitoring = false 
	
	# Buscamos al jugador por grupo en la escena de la estación
	var player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	if metro_train and player:     
		_board_train(player)

## Handles the complete train boarding sequence
func _board_train(player: CharacterBody2D) -> void:
	# 1. Disable player movement
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	# Optional: Play walking animation towards the train
	var player_animation = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player_animation:
		player_animation.play("walk_back")

	# 2. Move player towards the dark area inside the train car using a Tween
	var dark_position: Vector2 = player.global_position + Vector2(0, -16)
	var tween = create_tween()
	
	tween.parallel().tween_property(player, "global_position", dark_position, 1.0)
	tween.parallel().tween_property(player, "modulate", Color(0.1, 0.1, 0.1, 1.0), 0.8)
	tween.parallel().tween_property(player, "z_index", -1, 0.8)

	await tween.finished
	
	if player_animation:
		player_animation.play("idle_back")

	# 3. Close the train doors
	await get_tree().create_timer(0.2).timeout
	if metro_train.has_method("close_doors"):
		metro_train.close_doors()

	# 4. Transition to the train interior scene
	await get_tree().create_timer(1.2).timeout
	# get_tree().change_scene_to_file("res://scenes/TrainInterior.tscn")
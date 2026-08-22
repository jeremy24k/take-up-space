extends "res://global/interactable_area.gd"

# =========================
# Item configuration
# =========================
@export var item_id: String = ""
@export var sprite_2d: Sprite2D

# =========================
# Setup
# =========================
func _ready() -> void:
	super._ready()  # Inherits area signal connections
	
	if GameManager.is_item_collected(item_id):
		queue_free()
		return
	
	# Listen for signals emitted by Dialogic.
	Dialogic.signal_event.connect(_on_dialogic_signal)

# Override label text using quest_step logic.
func update_label_text() -> void:
	if label:
		if GameManager.quest_step >= 3:
			label.text = "[Recoger]"
		else:
			label.text = "[Espacio]"

# =========================
# Dialogic event handling
# =========================
func _on_dialogic_signal(argument: String) -> void:
	if argument.begins_with("item_picked:"):
		var picked_id = argument.split(":")[1]
		if picked_id == item_id:
			_collect_item()

# =========================
# Item collection logic
# =========================
func _collect_item() -> void:
	# Only allow saving/removing if we're in the correct phase.
	if GameManager.quest_step >= 3:
		GameManager.add_item(item_id)
		print("Item saved in GameManager: ", item_id)
		queue_free()

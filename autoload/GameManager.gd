extends Node

# =========================
# Quest state
# =========================
# Door used to enter the train interior.
var target_door_id: int = 1

# True after Alice checks the backpack.
var prep_items_unlocked: bool = false

# False once she realizes she left her phone on the train.
var has_phone: bool = true

@export var quest_step: int = 0
var collected_items: Array[String] = []  # List of collected item IDs

var missing_prep_items: Array[String] = [  # Items needed before the quest can start
	"alice_wallet",
	"alice_headphones",
	"alice_shoes",
]

var wilson: Wilson = null

# Emitted every time the quest step changes.
signal quest_step_changed(new_step: int)

# =========================
# Setup
# =========================
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)

# =========================
# Dialogic event handling
# =========================
func _on_dialogic_signal(argument: String) -> void:
	match argument:
		"step_1":
			if quest_step < 1:
				set_quest_step(1)
		"step_2":
			if quest_step == 1:
				set_quest_step(2)
		"step_3":
			if quest_step == 2:
				set_quest_step(3)
		"prep_items_unlocked":
			prep_items_unlocked = true
		"no_phone":
			has_phone = false
		"step_4":
			if quest_step == 3 and has_all_prep_items():  # All required items collected
				set_quest_step(4)

# =========================
# Quest progression
# =========================
func set_quest_step(new_step: int) -> void:
	quest_step = new_step
	quest_step_changed.emit(quest_step)
	print("Quest step: ", quest_step)

# =========================
# Item collection
# =========================
func add_item(item_id: String) -> void:
	if not collected_items.has(item_id):
		collected_items.append(item_id)
		print("Item added to GameManager: ", item_id)
		get_missing_items_count()
		print("Missing items: ", get_missing_items_count())

func is_item_collected(item_id: String) -> bool:
	return collected_items.has(item_id)

func are_prep_items_unlocked() -> bool:
	return prep_items_unlocked

# =========================
# Quest validation
# =========================
func has_all_prep_items() -> bool:
	for item_id in missing_prep_items:
		if not is_item_collected(item_id):
			return false
	return true

func get_missing_items_count() -> int:
	return missing_prep_items.size() - collected_items.size()
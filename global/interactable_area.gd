class_name InteractableArea
extends Area2D

# =========================
# Interaction configuration
# =========================
@export var timeline_name: String = ""        # Timeline to execute if exists
@export var prompt_text: String = ""           # Optional label text, set per instance
@export var one_time_interaction: bool = false  # If true, trigger only on the first interaction
@onready var label: Label = $Label              # Unified label name

var _interaction_enabled: bool = true

# Emitted every time the player interacts with this area.
signal interacted

# =========================
# Setup
# =========================
func _ready() -> void:
	if label:
		label.hide()

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	# No prompt stays on screen over a dialogue, not even another area's.
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)

# =========================
# Prompt visibility
# =========================
## Only Alice's InteractionDetector counts. Other areas on layer 4 (e.g. a
## pedestrian's talk area walking past) must not show or hide this prompt.
func _is_player_detector(area: Area2D) -> bool:
	return area.get_parent() is Player

func _on_area_entered(area: Area2D) -> void:
	if not _interaction_enabled or not _is_player_detector(area):
		return

	update_label_text()  # Calls child version if it exists
	if label and Dialogic.current_timeline == null:
		label.show()

func _on_area_exited(area: Area2D) -> void:
	if not _interaction_enabled or not _is_player_detector(area):
		return

	if label:
		label.hide()

func _on_dialogue_started() -> void:
	if label:
		label.hide()

## Brings the prompt back if Alice is still standing at this area.
func _on_dialogue_ended() -> void:
	if not label or not _interaction_enabled or not monitoring:
		return
	for area in get_overlapping_areas():
		if _is_player_detector(area):
			update_label_text()
			label.show()
			return

# =========================
# Virtual methods (to override in child classes)
# =========================
func update_label_text() -> void:
	# Instances can set their prompt without needing a dedicated script.
	if label and prompt_text != "":
		label.text = prompt_text

func _collect_item() -> void:
	pass

# =========================
# Interaction action
# =========================
func interact() -> void:
	if not _interaction_enabled:
		return

	interacted.emit()

	if label:
		label.hide()

	if one_time_interaction:
		_interaction_enabled = false
		set_deferred("monitoring", false)

	# If there's a Dialogic timeline, start it.
	if timeline_name != "":
		Dialogic.start(timeline_name)
	else:
		# If no dialogue is associated, collect immediately.
		_collect_item()
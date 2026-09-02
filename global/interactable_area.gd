class_name InteractableArea
extends Area2D

# =========================
# Interaction configuration
# =========================
@export var timeline_name: String = ""  # Timeline to execute if exists
@export var prompt_text: String = ""    # Optional label text, set per instance
@onready var label: Label = $Label      # Unified label name

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

# =========================
# Prompt visibility
# =========================
func _on_area_entered(_area: Area2D) -> void:
	update_label_text()  # Calls child version if it exists
	if label:
		label.show()

func _on_area_exited(_area: Area2D) -> void:
	if label:
		label.hide()

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
	interacted.emit()

	if label:
		label.hide()

	# If there's a Dialogic timeline, start it.
	if timeline_name != "":
		Dialogic.start(timeline_name)
	else:
		# If no dialogue is associated, collect immediately.
		_collect_item()
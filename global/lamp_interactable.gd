extends "res://global/interactable_area.gd"

# =========================
# Lamp references
# =========================
@export var lamp_light: PointLight2D  # Reference to the lamp light

# =========================
# Setup
# =========================
func _ready() -> void:
	super._ready()
	
	# Listen for timeline events that refresh lamp state.
	Dialogic.signal_event.connect(_on_dialogic_signal)
	# Apply current state on scene start.
	_update_lamp_light()

# =========================
# Dialogic event handling
# =========================
func _on_dialogic_signal(argument: String) -> void:
	if argument == "update_lamp":
		_update_lamp_light()

# =========================
# Lamp state sync
# =========================
func _update_lamp_light() -> void:
	# Mirror Dialogic variable into the scene light.
	if lamp_light:
		lamp_light.enabled = Dialogic.VAR.lamp_is_on

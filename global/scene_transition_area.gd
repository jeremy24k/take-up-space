class_name SceneTransitionArea
extends "res://global/interactable_area.gd"

# =========================
# Transition configuration
# =========================
## Scene loaded when the player interacts with this area.
@export_file("*.tscn") var target_scene_path: String = ""
@export var fade_duration: float = 1.0

## While locked the area reports the attempt instead of changing scene,
## so the owning scene can play a dialogue or a thought first.
var is_locked: bool = false

# Emitted when the player interacts while the area is still locked.
signal blocked_interaction
# Emitted right before the scene starts changing.
signal transition_started

var has_triggered: bool = false

# =========================
# Interaction action
# =========================
func interact() -> void:
	# Prevent a second interaction while the transition is running.
	if has_triggered:
		return

	interacted.emit()

	if is_locked:
		blocked_interaction.emit()
		return

	if target_scene_path.is_empty():
		push_warning("SceneTransitionArea '%s' has no target scene assigned." % name)
		return

	has_triggered = true
	monitoring = false
	if label:
		label.hide()

	transition_started.emit()
	FadeTransition.transition_to_scene(target_scene_path, fade_duration)

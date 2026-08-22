extends CanvasLayer

# =========================
# Fade configuration
# =========================
@export var default_duration: float = 1.0

var overlay: ColorRect

func _ready() -> void:
	layer = 100
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

# =========================
# Public fade actions
# =========================
func fade_out(duration: float = -1.0) -> void:
	await _fade_to(1.0, duration)

func fade_in(duration: float = -1.0) -> void:
	await _fade_to(0.0, duration)

func transition_to_scene(scene_path: String, duration: float = -1.0) -> void:
	await fade_out(duration)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in(duration)

# =========================
# Fade animation
# =========================
func _fade_to(target_alpha: float, duration: float) -> void:
	if not overlay:
		return

	var fade_duration := default_duration if duration < 0.0 else duration
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", target_alpha, fade_duration)
	await tween.finished

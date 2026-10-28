extends CanvasLayer

# =========================
# Fade configuration
# =========================
@export var default_duration: float = 1.0

const INTERLUDE_FONT := preload("res://fonts/m3x6.ttf")
const INTERLUDE_FADE: float = 0.6
## Seconds a line stays on screen: a base plus a little per character.
const INTERLUDE_HOLD_BASE: float = 1.6
const INTERLUDE_HOLD_PER_CHAR: float = 0.04
## Narration is lilac; Alice's own thoughts, written between «», are white.
const INTERLUDE_NARRATION_COLOR := Color(0.82, 0.72, 1.0)
const INTERLUDE_THOUGHT_COLOR := Color(1, 1, 1)
## A full-screen picture between the lines (the cover, as Alice steps out).
const INTERLUDE_IMAGE_FADE: float = 1.4
const INTERLUDE_IMAGE_HOLD: float = 3.5

var overlay: ColorRect
var interlude_label: Label
var interlude_image: TextureRect
var _skip_line: bool = false

func _ready() -> void:
	layer = 100
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_create_interlude_image()
	_create_interlude_label()

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

## Same as transition_to_scene, but while the screen is black it shows a few
## lines, one at a time. A short bridge between two places, so Alice does not
## seem to teleport (e.g. from her building straight into the metro).
## Space skips the current line. Lines written between «» are Alice's
## thoughts and show in white; the rest is narration. An image, if given,
## fills the screen for a moment before line number image_before_line
## (0 = before the first; lines.size() = after the last).
func transition_with_interlude(scene_path: String, lines: PackedStringArray, duration: float = -1.0,
		image: Texture2D = null, image_before_line: int = 0) -> void:
	await fade_out(duration)
	for i in lines.size():
		if image and i == image_before_line:
			await _show_interlude_image(image)
		await _show_interlude_line(lines[i])
	if image and image_before_line >= lines.size():
		await _show_interlude_image(image)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in(duration)

# =========================
# Interlude text
# =========================
func _create_interlude_label() -> void:
	interlude_label = Label.new()
	interlude_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interlude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interlude_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interlude_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interlude_label.add_theme_font_override("font", INTERLUDE_FONT)
	interlude_label.add_theme_font_size_override("font_size", 48)
	interlude_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interlude_label.hide()
	add_child(interlude_label)

## Covers the whole screen, cropping the sides if the picture is wider. It is
## an illustration, not pixel art: filtered smoothly when scaled.
func _create_interlude_image() -> void:
	interlude_image = TextureRect.new()
	interlude_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interlude_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	interlude_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	interlude_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	interlude_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interlude_image.hide()
	add_child(interlude_image)

func _show_interlude_image(image: Texture2D) -> void:
	interlude_image.texture = image
	interlude_image.modulate.a = 0.0
	interlude_image.show()
	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(interlude_image, "modulate:a", 1.0, INTERLUDE_IMAGE_FADE)
	await fade_in_tween.finished

	_skip_line = false
	var hold := INTERLUDE_IMAGE_HOLD
	while hold > 0.0 and not _skip_line:
		await get_tree().process_frame
		hold -= get_process_delta_time()

	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(interlude_image, "modulate:a", 0.0, INTERLUDE_IMAGE_FADE)
	await fade_out_tween.finished
	interlude_image.hide()

func _show_interlude_line(line: String) -> void:
	interlude_label.text = line
	var is_thought := line.begins_with("«")
	interlude_label.add_theme_color_override("font_color",
		INTERLUDE_THOUGHT_COLOR if is_thought else INTERLUDE_NARRATION_COLOR)
	interlude_label.modulate.a = 0.0
	interlude_label.show()
	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(interlude_label, "modulate:a", 1.0, INTERLUDE_FADE)
	await fade_in_tween.finished

	_skip_line = false
	var hold := INTERLUDE_HOLD_BASE + line.length() * INTERLUDE_HOLD_PER_CHAR
	while hold > 0.0 and not _skip_line:
		await get_tree().process_frame
		hold -= get_process_delta_time()

	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(interlude_label, "modulate:a", 0.0, INTERLUDE_FADE)
	await fade_out_tween.finished
	interlude_label.hide()

func _input(event: InputEvent) -> void:
	if (interlude_label.visible or interlude_image.visible) and event.is_action_pressed("ui_accept"):
		_skip_line = true

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

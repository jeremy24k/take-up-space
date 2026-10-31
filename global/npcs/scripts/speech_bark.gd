class_name SpeechBark
extends Node2D

# =========================
# Speech bark configuration
# =========================
## A short line over a character's head that stops nobody: a child chatting
## while she walks along, a shout across the plaza. Not a conversation (those
## go in the bottom box) and not Alice's mind (the thought cloud): someone
## else talking out loud. Put it as a child of the character; its position is
## the point the bubble hangs from. The text is written in Spanish and shows
## translated. Drawn in screen space, like ThoughtNotice, so scene tints and
## the night do not darken it.
const FONT := preload("res://fonts/m3x6.ttf")
const FONT_SIZE: int = 32
const FADE_TIME: float = 0.2
const BACKGROUND := Color(0.98, 0.95, 0.9, 1)
const BORDER := Color(0.22, 0.16, 0.28, 1)
const TEXT_COLOR := Color(0.22, 0.16, 0.28, 1)

var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _tween: Tween
var _token: int = 0

# =========================
# Setup
# =========================
func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)

	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 6

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_panel.hide()
	_layer.add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_panel.add_child(_label)

# =========================
# Public API
# =========================
## Shows `text` for a few seconds (longer lines stay longer). Await it if the
## next thing should wait. A new line replaces the one on screen.
func say(text: String, duration: float = -1.0) -> void:
	_token += 1
	var token := _token
	_label.text = text
	_panel.reset_size()
	_panel.show()
	_fade_to(1.0)
	var hold := duration if duration > 0.0 else 1.8 + tr(text).length() * 0.05
	await get_tree().create_timer(hold).timeout
	if token == _token:
		await hide_now()

func hide_now() -> void:
	_token += 1
	await _fade_to(0.0)
	_panel.hide()

func is_showing() -> bool:
	return _panel.visible

# =========================
# Placement
# =========================
## Follows the character on screen. A conversation in the bottom box takes
## over, so the bubble steps aside meanwhile.
func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var talking := Dialogic.current_timeline != null and not ThoughtBox.is_showing()
	_layer.visible = not talking
	var screen := get_viewport().get_canvas_transform() * global_position
	_panel.position = (screen - Vector2(_panel.size.x / 2.0, _panel.size.y)).round()

func _fade_to(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", alpha, FADE_TIME)
	await _tween.finished

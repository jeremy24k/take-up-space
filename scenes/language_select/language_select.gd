extends Control

# =========================
# Language screen configuration
# =========================
## First screen of the game: the player picks a language with the arrows and
## confirms with Space (or Enter). The last language used comes preselected.
const FIRST_SCENE := "res://scenes/prologue_scene/scenes/apartment.tscn"
const SELECTED_COLOR := Color(1, 1, 1)
const IDLE_COLOR := Color(0.55, 0.5, 0.7)
const MOVE_SOUND := preload("res://audio/sfx/ui_move.ogg")
## Language code -> its option on screen, in the order they are listed.
@onready var options: Dictionary = {
	"es": $Center/Box/Spanish,
	"en": $Center/Box/English,
}

var _selected: int = 0
var _confirmed: bool = false

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	_selected = maxi(options.keys().find(Localization.language), 0)
	_refresh()

# =========================
# Input
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if _confirmed:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()

func _move(step: int) -> void:
	_selected = wrapi(_selected + step, 0, options.size())
	SoundManager.play_sfx(MOVE_SOUND)
	_refresh()

func _confirm() -> void:
	_confirmed = true
	Localization.set_language(options.keys()[_selected])
	FadeTransition.transition_to_scene(FIRST_SCENE)

# =========================
# Display
# =========================
## The selected option is white and framed by arrows; the others are dim.
func _refresh() -> void:
	var codes: Array = options.keys()
	for i in codes.size():
		var label: Label = options[codes[i]]
		var name_text: String = label.get_meta("language_name")
		var is_selected := i == _selected
		label.text = "> %s <" % name_text if is_selected else name_text
		label.add_theme_color_override("font_color", SELECTED_COLOR if is_selected else IDLE_COLOR)

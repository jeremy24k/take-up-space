extends Control

# =========================
# Demo end configuration
# =========================
## Lets the fade from Leo's store finish before the title shows up.
const START_DELAY: float = 0.8
const TITLE_FADE: float = 2.0
## Pause after "Continuará..." before the thanks come in.
const THANKS_DELAY: float = 1.2
const THANKS_FADE: float = 1.2
const OPTIONS_FADE: float = 0.8
## "Empezar de nuevo" goes back to the very start: the language screen.
const RESTART_SCENE := "res://scenes/language_select/language_select.tscn"
const SELECTED_COLOR := Color(1, 1, 1)
const IDLE_COLOR := Color(0.55, 0.5, 0.7)
const MOVE_SOUND := preload("res://audio/sfx/ui_move.ogg")
## The cover stays dimmed behind the text, so it is a backdrop, not a picture
## to read over.
const COVER_ALPHA: float = 0.3

@onready var cover: TextureRect = $Cover
@onready var to_be_continued: Label = $Center/Box/ToBeContinued
@onready var thanks: Label = $Center/Box/Thanks
@onready var comment: Label = $Center/Box/Comment
@onready var options_box: VBoxContainer = $Center/Box/Options
## In the order they are listed. Their Spanish text is set in the scene; the
## label shows it translated.
@onready var options: Array[Label] = [$Center/Box/Options/Restart, $Center/Box/Options/Quit]

var _option_names: Array[String] = []
var _selected: int = 0
var _accepting: bool = false

# =========================
# Lifecycle
# =========================
## Black screen after Leo's store. Alice's reflection already played on the
## way here (FadeTransition interlude from leo_store.gd), so this shows
## "Continuará..." (Lía's scene is next and does not exist yet) over the
## dimmed cover, then the thanks, then two options: play again or close.
func _ready() -> void:
	# In a browser the game cannot close its own tab: no "Salir" there.
	if OS.has_feature("web"):
		$Center/Box/Options/Quit.hide()
		options.erase($Center/Box/Options/Quit)
	for label in options:
		_option_names.append(label.text)
	for node: CanvasItem in [to_be_continued, thanks, comment, options_box]:
		node.modulate.a = 0.0
	_refresh()
	await get_tree().create_timer(START_DELAY).timeout
	var tween := create_tween()
	tween.tween_property(to_be_continued, "modulate:a", 1.0, TITLE_FADE)
	tween.parallel().tween_property(cover, "modulate:a", COVER_ALPHA, TITLE_FADE)
	tween.tween_interval(THANKS_DELAY)
	tween.tween_property(thanks, "modulate:a", 1.0, THANKS_FADE)
	tween.parallel().tween_property(comment, "modulate:a", 1.0, THANKS_FADE)
	tween.tween_property(options_box, "modulate:a", 1.0, OPTIONS_FADE)
	await tween.finished
	_accepting = true

# =========================
# Options
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if not _accepting:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_choose()

func _move(step: int) -> void:
	_selected = wrapi(_selected + step, 0, options.size())
	SoundManager.play_sfx(MOVE_SOUND)
	_refresh()

func _choose() -> void:
	_accepting = false
	if options[_selected] == $Center/Box/Options/Restart:
		GameManager.reset()
		Dialogic.VAR.reset()
		FadeTransition.transition_to_scene(RESTART_SCENE)
	else:
		AppExit.quit_game()

## The selected option is white and framed by arrows; the other is dim.
func _refresh() -> void:
	for i in options.size():
		var is_selected := i == _selected
		var name_text := tr(_option_names[i])
		options[i].text = "> %s <" % name_text if is_selected else name_text
		options[i].add_theme_color_override("font_color", SELECTED_COLOR if is_selected else IDLE_COLOR)

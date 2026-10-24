extends Control

# =========================
# Demo end configuration
# =========================
## Lets the fade from Leo's store finish before the title shows up.
const START_DELAY: float = 0.8
const TITLE_FADE: float = 2.0

@onready var to_be_continued: Label = $ToBeContinued
@onready var exit_hint: Label = $ExitHint

var _can_exit: bool = false

# =========================
# Lifecycle
# =========================
## Black screen after Leo's store. Alice's reflection already played on the
## way here (FadeTransition interlude from leo_store.gd), so this only shows
## "Continuará...": Lía's scene is next and does not exist yet. There is
## nothing after it, so Space closes the game (through AppExit, see there).
func _ready() -> void:
	to_be_continued.modulate.a = 0.0
	exit_hint.modulate.a = 0.0
	await get_tree().create_timer(START_DELAY).timeout
	var tween := create_tween()
	tween.tween_property(to_be_continued, "modulate:a", 1.0, TITLE_FADE)
	tween.tween_property(exit_hint, "modulate:a", 1.0, TITLE_FADE / 2.0)
	await tween.finished
	_can_exit = true

# =========================
# Exit
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if _can_exit and event.is_action_pressed("ui_accept"):
		AppExit.quit_game()

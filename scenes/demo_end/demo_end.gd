extends Control

# =========================
# Demo end configuration
# =========================
## Lets the fade from Leo's store finish before the reflection starts.
const START_DELAY: float = 1.2
const TITLE_FADE: float = 2.0

@onready var to_be_continued: Label = $ToBeContinued

# =========================
# Lifecycle
# =========================
## Black screen after Leo's store: Alice's reflection (which depends on what
## she chose with Leo) and then "Continuará...", since Lía's scene is next.
func _ready() -> void:
	to_be_continued.modulate.a = 0.0
	await get_tree().create_timer(START_DELAY).timeout
	Dialogic.start("leo_store_reflection")
	await Dialogic.timeline_ended
	var tween := create_tween()
	tween.tween_property(to_be_continued, "modulate:a", 1.0, TITLE_FADE)

extends Node2D

# =========================
# Mirror rehearsal
# =========================
## Before leaving, Alice rehearses in front of the bathroom mirror. These are
## the game's first "Rompecabezas de la Ansiedad", relaxed (no clock), so the
## player learns the three outcomes without pressure: building a sentence,
## fumbling one, and staying silent with "(...)". bathroom_glass.dtl plays
## them with [signal arg="anxiety_puzzle:<id>"].
const ANXIETY_PUZZLES := {
	"practice_store": preload("res://scenes/prologue_scene/puzzles/practice_store.tres"),
	"practice_directions": preload("res://scenes/prologue_scene/puzzles/practice_directions.tres"),
	"practice_are_you_ok": preload("res://scenes/prologue_scene/puzzles/practice_are_you_ok.tres"),
}

# =========================
# Leaving the building
# =========================
## Black-screen lines when Alice takes the stairs out (the cover shows before
## the third one, see the staircase's interlude_image). They live here, not
## on the Staircase node in the scene: an editor holding an old copy of
## apartment.tscn kept saving it over them, and the exit lost its text.
const LEAVING_LINES: PackedStringArray = [
	"Alice cierra la puerta de su edificio.",
	"El aire de la mañana le golpea la cara. Hace frío.",
	"Camina rápido. No quiere cruzarse con nadie.",
	"Las escaleras del metro aparecen al final de la calle. ",
]

@onready var staircase: Node2D = $InferiorLayer/Staircase

# =========================
# Setup
# =========================
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	staircase.interlude_lines = LEAVING_LINES

# =========================
# Anxiety puzzle
# =========================
func _on_dialogic_signal(argument: Variant) -> void:
	if not (argument is String and argument.begins_with("anxiety_puzzle:")):
		return
	var data: AnxietyPuzzleData = ANXIETY_PUZZLES.get(argument.get_slice(":", 1))
	if data == null:
		push_warning("Unknown anxiety puzzle '%s'" % argument)
		return
	AnxietyPuzzle.play_from_dialogic(self, data)

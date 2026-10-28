class_name AnxietyPuzzleData
extends Resource

# =========================
# Puzzle definition
# =========================
## One "Rompecabezas de la Ansiedad": the answers Alice can build, word by word.
## result key -> the words of that answer, in order (e.g. "truth" -> ["La",
## "verdad...", "no.", "Me", "perdí."]). The key is what the puzzle returns, so
## the timeline can branch on it.
@export var phrases: Dictionary = {}
## Words that belong to no answer. They are mixed in to confuse the player.
@export var extra_words: PackedStringArray = []
## Alice's thought shown above the words: what she could say, not how. It is
## the hint that makes the scrambled words solvable.
@export var prompt: String = ""
## Seconds before Alice freezes and the puzzle returns "silence".
@export var time_limit: float = 20.0
## Seconds lost when a word comes in the wrong order.
@export var mistake_penalty: float = 1.5
## Tutorial: the first word of every answer blinks as soon as the puzzle
## opens, not only after a mistake. For the first puzzle of the game.
@export var hint_from_start: bool = false
## Rehearsal (the mirror in the apartment): no clock, no closing vignette and
## no time lost on mistakes. Alice can only stop by choosing "(...)".
@export var relaxed: bool = false
## The same puzzle in other languages, by language code (e.g. "en" -> the
## English .tres next to this one). Words cannot be translated one by one:
## another language has its own word order and word count. The answers keep
## the same keys, since the timelines branch on them. A language not listed
## here plays this version (Spanish).
@export var translations: Dictionary = {}

# =========================
# Language
# =========================
func for_current_language() -> AnxietyPuzzleData:
	var language := TranslationServer.get_locale().get_slice("_", 0)
	var translated: AnxietyPuzzleData = translations.get(language)
	return translated if translated else self

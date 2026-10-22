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

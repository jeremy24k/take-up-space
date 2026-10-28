extends Node

# =========================
# Language
# =========================
## The player's language. It is picked on the language screen at startup
## (scenes/language_select) and remembered between sessions, so a scene run
## on its own from the editor also plays in the last language used.
## Spanish is the original: every text is written in Spanish, and the other
## languages come from the CSV files in translations/ (see TranslationCollector).
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES: PackedStringArray = ["es", "en"]
const DEFAULT_LANGUAGE := "es"

var language: String = DEFAULT_LANGUAGE

# =========================
# Setup
# =========================
func _ready() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	var saved: String = settings.get_value("game", "language", DEFAULT_LANGUAGE)
	_apply(saved if saved in LANGUAGES else DEFAULT_LANGUAGE)

# =========================
# Public API
# =========================
## Switches every text in the game and remembers the choice.
func set_language(code: String) -> void:
	if not code in LANGUAGES:
		return
	_apply(code)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("game", "language", code)
	settings.save(SETTINGS_PATH)

func _apply(code: String) -> void:
	language = code
	TranslationServer.set_locale(code)

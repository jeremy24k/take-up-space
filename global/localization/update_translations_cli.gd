extends SceneTree

# =========================
# Command line entry point
# =========================
## Updates every translation CSV (Dialogic timelines, character names and the
## game text) without opening the editor:
## godot --headless --path . --script res://global/localization/update_translations_cli.gd
## Close the editor first: it would save its stale copies of the timelines
## over the new "#id:" tags.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TranslationCollector.FOLDER)
	TranslationCollector.update_dialogic()
	var count := TranslationCollector.update_game_text()
	print("Translations updated (%d game texts)." % count)
	quit()

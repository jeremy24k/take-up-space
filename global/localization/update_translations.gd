@tool
extends EditorScript

# =========================
# Editor entry point
# =========================
## Open this file in the script editor and press Ctrl+Shift+X (File > Run) to
## add the new game texts (thoughts, remarks, prompts...) to
## translations/game_text.csv. Dialogue lines are not handled here: use
## Dialogic's own button (Dialogic > Settings > Translation > Update CSV files).
func _run() -> void:
	var count := TranslationCollector.update_game_text()
	EditorInterface.get_resource_filesystem().scan()
	print("game_text.csv updated (%d texts)." % count)

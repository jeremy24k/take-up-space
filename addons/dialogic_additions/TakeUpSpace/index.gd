@tool
extends DialogicIndexer

# =========================
# Take Up Space additions
# =========================
## Project-specific Dialogic pieces. They live in Dialogic's extensions folder
## (dialogic/extensions_folder, res://addons/dialogic_additions/ by default)
## so addons/dialogic, which is third-party, stays untouched.
func _get_special_resources() -> Dictionary:
	return {&"PortraitAnimation": list_animations("Animations")}

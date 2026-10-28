class_name TranslationCollector
extends RefCounted

# =========================
# Translation files
# =========================
## Gathers every player-facing text into the CSV files under translations/,
## keeping the translations already written there. Two kinds of text:
## - Dialogic timelines and character names: Dialogic's own system. Each line
##   gets a "#id:" in its .dtl and a row keyed by that id.
## - Everything else (thoughts, remarks, prompts, labels, code constants):
##   game_text.csv, keyed by the Spanish text itself, so Spanish needs no
##   column and a line nobody translated yet just shows in Spanish.
## Run it from the command line (update_translations_cli.gd) or, for the game
## text only, from the editor (update_translations.gd, Ctrl+Shift+X).
const FOLDER := "res://translations"
const GAME_TEXT_CSV := "res://translations/game_text.csv"
const ORIGINAL_LOCALE := "es"
const LOCALES: PackedStringArray = ["en"]

## Exported properties that hold text the player reads, on any node.
const TEXT_PROPERTIES: PackedStringArray = ["lines", "first_line", "thought_lines", "thought_text", "prompt_text", "interlude_lines"]
## "text" is only player-facing on these.
const TEXT_NODE_TYPES: PackedStringArray = ["Label", "Button", "RichTextLabel"]
## Folders that are not ours.
const SKIPPED_FOLDERS: PackedStringArray = ["res://addons", "res://.godot", "res://.mcp"]

# =========================
# Dialogic
# =========================
## Same steps as Dialogic's "Update CSV files" button (per project mode),
## without the editor UI.
static func update_dialogic() -> void:
	ProjectSettings.set_setting("dialogic/translation/enabled", true)
	ProjectSettings.set_setting("dialogic/translation/original_locale", ORIGINAL_LOCALE)
	ProjectSettings.set_setting("dialogic/translation/file_mode", 0)
	ProjectSettings.set_setting("dialogic/translation/save_mode", 0)
	ProjectSettings.set_setting("dialogic/translation/translation_folder", FOLDER)
	ProjectSettings.set_setting("dialogic/translation/add_separator", true)
	ProjectSettings.set_setting("dialogic/translation/intern/save_mode", 0)
	ProjectSettings.set_setting("dialogic/translation/intern/file_mode", 0)
	ProjectSettings.set_setting("dialogic/translation/intern/translation_folder", FOLDER)

	var timelines_csv := DialogicCsvFile.new(FOLDER.path_join("dialogic_timeline_translations.csv"), ORIGINAL_LOCALE, true)
	for timeline_path: String in DialogicResourceUtil.list_resources_of_type(".dtl"):
		if _is_skipped(timeline_path):
			continue
		var timeline: DialogicTimeline = load(timeline_path)
		if timeline.events.is_empty():
			continue
		timeline.process()
		timelines_csv.collect_lines_from_timeline(timeline)
		# New "#id:" tags are written back into the .dtl.
		timeline.set_meta("timeline_not_saved", true)
		ResourceSaver.save(timeline, timeline_path)
	timelines_csv.update_csv_file_on_disk()

	var names_csv := DialogicCsvFile.new(FOLDER.path_join("dialogic_character_translations.csv"), ORIGINAL_LOCALE, true)
	var characters := {}
	for character_path: String in DialogicResourceUtil.list_resources_of_type(".dch"):
		if _is_skipped(character_path):
			continue
		var character: DialogicCharacter = load(character_path)
		characters[character.get_set_translation_id()] = character
		ResourceSaver.save(character)
	names_csv.collect_lines_from_characters(characters)
	names_csv.update_csv_file_on_disk()
	ProjectSettings.save()

# =========================
# Game text
# =========================
## Rewrites game_text.csv with every text found now, in a stable order,
## keeping the translations of the texts that were already there.
static func update_game_text() -> int:
	var found: Array[String] = []
	for path in _list_files("res://", [".tscn"]):
		_collect_from_scene(path, found)
	for path in _list_files("res://", [".tres"]):
		_collect_from_resource(path, found)
	for path in _list_files("res://", [".gd"]):
		_collect_from_script(path, found)

	var old := _read_csv(GAME_TEXT_CSV)
	var file := FileAccess.open(GAME_TEXT_CSV, FileAccess.WRITE)
	var header := PackedStringArray(["keys"])
	header.append_array(LOCALES)
	file.store_csv_line(header)
	for text in found:
		var row := PackedStringArray([text])
		var old_row: PackedStringArray = old.get(text, PackedStringArray())
		for i in LOCALES.size():
			row.append(old_row[i + 1] if old_row.size() > i + 1 else "")
		file.store_csv_line(row)
	file.close()
	return found.size()

static func _collect_from_scene(path: String, found: Array[String]) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var state := scene.get_state()
	if _translation_disabled(state):
		return
	for node in state.get_node_count():
		var type := state.get_node_type(node)
		for property in state.get_node_property_count(node):
			var property_name := state.get_node_property_name(node, property)
			var is_text := property_name in TEXT_PROPERTIES
			if property_name == "text" and type in TEXT_NODE_TYPES:
				is_text = true
			if is_text:
				_add_value(state.get_node_property_value(node, property), found)

## Scenes whose root turns translation off (e.g. the language screen, which
## shows each language in its own words).
static func _translation_disabled(state: SceneState) -> bool:
	for property in state.get_node_property_count(0):
		if state.get_node_property_name(0, property) == "auto_translate_mode":
			return state.get_node_property_value(0, property) == Node.AUTO_TRANSLATE_MODE_DISABLED
	return false

static func _collect_from_script(path: String, found: Array[String]) -> void:
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return
	# Exported defaults (e.g. a prompt_text set in the script).
	for property in script.get_script_property_list():
		if property.name in TEXT_PROPERTIES:
			_add_value(script.get_property_default_value(property.name), found)
	# String literals the code wraps in tr() (e.g. a label set from code).
	var source := FileAccess.get_file_as_string(path)
	var calls := RegEx.create_from_string(r'\btr\("((?:[^"\\]|\\.)*)"\)')
	for call in calls.search_all(source):
		_add_value(call.get_string(1).c_unescape(), found)
	# Constants that read like sentences (e.g. LOST_LINES, STUMBLE_LINE).
	var constants: Dictionary = script.get_script_constant_map()
	for constant_name in constants:
		var value: Variant = constants[constant_name]
		if value is String and _reads_like_text(value):
			_add_value(value, found)
		elif value is Array or value is PackedStringArray:
			for item in value:
				if item is String and _reads_like_text(item):
					_add_value(item, found)

## Shared lists of lines kept in their own .tres (e.g. ambient_npc_pool.tres).
static func _collect_from_resource(path: String, found: Array[String]) -> void:
	var resource := load(path)
	if resource == null or resource is AnxietyPuzzleData:
		return
	for property in resource.get_property_list():
		if property.name in TEXT_PROPERTIES:
			_add_value(resource.get(property.name), found)

static func _add_value(value: Variant, found: Array[String]) -> void:
	if value is String:
		var text := (value as String)
		if not text.strip_edges().is_empty() and not text in found:
			found.append(text)
	elif value is Array or value is PackedStringArray:
		for item in value:
			_add_value(item, found)

## A sentence, not an id, a path or a format string.
static func _reads_like_text(text: String) -> bool:
	if text.contains("res://") or text.contains("uid://") or text.contains("%") or text.contains("[") or text.contains("{"):
		return false
	return text.contains(" ") or text.ends_with(".") or text.ends_with("?") or text.ends_with("!")

# =========================
# Helpers
# =========================
static func _read_csv(path: String) -> Dictionary:
	var rows := {}
	if not FileAccess.file_exists(path):
		return rows
	var file := FileAccess.open(path, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 0 and not row[0].is_empty():
			rows[row[0]] = row
	return rows

static func _list_files(folder: String, extensions: Array) -> Array[String]:
	var files: Array[String] = []
	if _is_skipped(folder):
		return files
	var dir := DirAccess.open(folder)
	if dir == null:
		return files
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			files.append_array(_list_files(folder.path_join(sub), extensions))
	for file_name in dir.get_files():
		if file_name.get_extension() in extensions.map(func(e): return e.trim_prefix(".")):
			files.append(folder.path_join(file_name))
	files.sort()
	return files

static func _is_skipped(path: String) -> bool:
	for folder in SKIPPED_FOLDERS:
		if path.begins_with(folder):
			return true
	return false

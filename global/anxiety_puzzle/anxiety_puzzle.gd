class_name AnxietyPuzzle
extends CanvasLayer

# =========================
# Puzzle configuration
# =========================
## Returned when Alice says nothing: the "(...)" word, or the time ran out.
const SILENCE := "silence"
const SILENCE_WORD := "(...)"
const WORD_SCENE := preload("res://global/anxiety_puzzle/thought_word.tscn")
const FONT := preload("res://fonts/m3x6.ttf")
## Screen area the words float in: below the prompt, above Dialogic's text box.
const CLOUD_RECT := Rect2(170, 110, 940, 320)
## Minimum empty space around each word when scattering them.
const WORD_GAP: float = 18.0
const PLACEMENT_TRIES: int = 80
const FADE_TIME: float = 0.35
## Holding Space must not pick several words in a row.
const PICK_COOLDOWN: float = 0.2
const STUMBLE_COLOR := Color(1, 0.45, 0.45)
## After a mistake the first word of every answer blinks this color, as a hint.
const HINT_COLOR := Color(1, 0.88, 0.54)
const HINT_BLINKS: int = 3

@onready var root: Control = $Root
@onready var vignette: ColorRect = $Root/Vignette
@onready var word_cloud: Control = $Root/WordCloud
@onready var sentence_line: HBoxContainer = $Root/SentenceLine
@onready var prompt_label: Label = $Root/Prompt

var _data: AnxietyPuzzleData
var _words: Array[ThoughtWord] = []
var _picked: PackedStringArray = []
var _time_left: float = 0.0
var _cooldown: float = 0.0
var _accepting: bool = false
var _done: bool = false
## The clock waits for the player's first key or click, so the first time
## they can read the prompt and the controls before the panic starts.
var _clock_started: bool = false

## Emitted once with the key of the answer Alice built, or SILENCE.
signal finished(result: String)

# =========================
# Public entry point
# =========================
## "El Rompecabezas de la Ansiedad": Alice has to build her answer from her
## scrambled thoughts before she freezes. Await it; it frees itself.
## [codeblock]
## var result := await puzzle.run(data)  # "truth", "lie", ... or "silence"
## [/codeblock]
func run(data: AnxietyPuzzleData) -> String:
	_data = data
	_time_left = data.time_limit
	prompt_label.text = data.prompt
	_spawn_words()
	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, FADE_TIME)
	await tween.finished
	_accepting = true
	var result: String = await finished
	return result

# =========================
# Words
# =========================
## Every word of every answer, plus the distractors and the silence option,
## all mixed in one cloud: Alice does not know yet what she is going to say.
func _spawn_words() -> void:
	var texts: PackedStringArray = []
	for key in _data.phrases:
		for word in _data.phrases[key]:
			if not texts.has(word):
				texts.append(word)
	for word in _data.extra_words:
		if not texts.has(word):
			texts.append(word)
	texts.append(SILENCE_WORD)
	for text in texts:
		var word := WORD_SCENE.instantiate() as ThoughtWord
		word_cloud.add_child(word)
		word.setup(text)
		word.pressed.connect(_on_word_pressed.bind(word))
		_words.append(word)
	_scatter_words()

## Places every word at a random free spot of the cloud and focuses one.
func _scatter_words() -> void:
	_words.shuffle()
	var taken: Array[Rect2] = []
	for word in _words:
		word.show()
		word.reset_size()
		var area := Rect2(CLOUD_RECT.position, CLOUD_RECT.size - word.size)
		var spot := area.position
		for attempt in PLACEMENT_TRIES:
			spot = (area.position + Vector2(randf() * area.size.x, randf() * area.size.y)).round()
			var rect := Rect2(spot, word.size).grow(WORD_GAP)
			if not taken.any(func(other: Rect2) -> bool: return other.intersects(rect)):
				break
		taken.append(Rect2(spot, word.size))
		word.base_position = spot
		word.position = spot
	_words[0].grab_focus()

func _focus_any_visible() -> void:
	for word in _words:
		if word.visible:
			word.grab_focus()
			return

# =========================
# Building the sentence
# =========================
func _on_word_pressed(word: ThoughtWord) -> void:
	if not _accepting or _cooldown > 0.0:
		return
	_cooldown = PICK_COOLDOWN
	if word.text == SILENCE_WORD:
		_finish(SILENCE)
		return

	_picked.append(word.text)
	word.hide()
	sentence_line.add_child(_make_sentence_word(word.text))
	_focus_any_visible()

	var answer := _matching_answer()
	if answer == "":
		_stumble()
	elif _data.phrases[answer].size() == _picked.size():
		_finish(answer)

## The answer the picked words are building, or "" if no answer starts like
## that. A complete match always wins over a longer answer that also fits.
func _matching_answer() -> String:
	var partial := ""
	for key in _data.phrases:
		var words: PackedStringArray = _data.phrases[key]
		if words.size() < _picked.size() or words.slice(0, _picked.size()) != _picked:
			continue
		if words.size() == _picked.size():
			return key
		partial = key
	return partial

## Wrong word: the half-built sentence shakes, falls apart and every thought
## scatters again. It also costs her a bit of time.
func _stumble() -> void:
	_accepting = false
	_time_left -= _data.mistake_penalty
	sentence_line.modulate = STUMBLE_COLOR
	var start := sentence_line.position
	var tween := create_tween()
	for step in [9, -9, 6, -6, 3, 0]:
		tween.tween_property(sentence_line, "position:x", start.x + step, 0.04)
	tween.tween_interval(0.25)
	await tween.finished
	for child in sentence_line.get_children():
		child.queue_free()
	sentence_line.modulate = Color.WHITE
	_picked.clear()
	_scatter_words()
	_accepting = not _done
	_blink_answer_starts()

## Second hint: after a mistake, the words every answer starts with blink, so
## the player knows where to begin without being told the whole order.
func _blink_answer_starts() -> void:
	var starts: PackedStringArray = []
	for key in _data.phrases:
		starts.append(_data.phrases[key][0])
	for word in _words:
		if not starts.has(word.text):
			continue
		var tween := word.create_tween()
		for blink in HINT_BLINKS:
			tween.tween_property(word, "modulate", HINT_COLOR, 0.18)
			tween.tween_property(word, "modulate", Color.WHITE, 0.18)

func _make_sentence_word(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color(0.13, 0.05, 0.22))
	label.add_theme_constant_override("outline_size", 6)
	return label

# =========================
# Time pressure
# =========================
func _input(event: InputEvent) -> void:
	if not _accepting or _clock_started:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_clock_started = true

func _process(delta: float) -> void:
	if not _accepting:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not _clock_started:
		return
	_time_left -= delta
	var pressure := clampf(1.0 - _time_left / _data.time_limit, 0.0, 1.0)
	vignette.material.set_shader_parameter("pressure", pressure)
	for word in _words:
		word.pressure = pressure
	if _time_left <= 0.0:
		_finish(SILENCE)

# =========================
# Ending
# =========================
func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	_accepting = false
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	finished.emit(result)
	queue_free()

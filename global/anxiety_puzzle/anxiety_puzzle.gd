class_name AnxietyPuzzle
extends CanvasLayer

# =========================
# Puzzle configuration
# =========================
## Returned when Alice says nothing: the "(...)" word, or the time ran out.
const SILENCE := "silence"
const SILENCE_WORD := "(...)"
const SCENE_PATH := "res://global/anxiety_puzzle/anxiety_puzzle.tscn"
const WORD_SCENE := preload("res://global/anxiety_puzzle/thought_word.tscn")
const FONT := preload("res://fonts/m3x6.ttf")
## Screen area the words float in: below the prompt, above the sentence line.
const CLOUD_RECT := Rect2(120, 100, 1040, 340)
## Minimum empty space around each word when scattering them.
const WORD_GAP: float = 16.0
const PLACEMENT_TRIES: int = 80
const FADE_TIME: float = 0.35
## Holding Space must not pick several words in a row.
const PICK_COOLDOWN: float = 0.2
const STUMBLE_COLOR := Color(1, 0.45, 0.45)
## After a mistake the first word of every answer blinks this color, as a hint.
const HINT_COLOR := Color(1, 0.88, 0.54)
const HINT_BLINKS: int = 3
## Alice's own reaction to a sentence that goes nowhere, shown for a moment
## in place of the prompt. Without it the reshuffle looked like a glitch.
const STUMBLE_LINE := "No... así no."
const STUMBLE_LINE_TIME: float = 1.2
## Thoughts that crowd in while she tries to talk. Real puzzles only: they
## float as distractors and swap in and out with the extra_words.
const INTRUSIVE_THOUGHTS: PackedStringArray = [
	"¿Me puedo ir a casa?",
	"Me tengo que ir.",
	"Todos me miran.",
	"Quiero irme.",
	"¿Y si me equivoco?",
	"Wilson me espera.",
]
## How many of them are already in the cloud when the puzzle opens.
const INTRUSIVE_AT_START: int = 1
## Seconds between two thoughts swapping (calm -> about to freeze), with a
## random spread so the swaps never fall into a rhythm.
const SWAP_INTERVAL := Vector2(3.2, 1.4)
const SWAP_SPREAD: float = 0.35
const SWAP_FADE: float = 0.25
const ARROW_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
## Words of the sentence line, same look as thought_word.tscn: 4x the m3x6
## pixel font, with a thick near-black outline, readable over any scene.
const WORD_FONT_SIZE: int = 64
const WORD_OUTLINE_SIZE: int = 10
const WORD_OUTLINE_COLOR := Color(0.04, 0.01, 0.07)
## Alice's body under the clock: her heartbeat speeds up and gets louder as
## the time runs out, and her breathing comes in softly near the end.
## Only in real puzzles; the mirror rehearsal stays quiet.
const HEARTBEAT := preload("res://audio/sfx/heartbeat_loop.ogg")
const BREATHING := preload("res://audio/sfx/breathing_loop.ogg")
const HEARTBEAT_DB := Vector2(-20.0, -6.0)  # calm -> about to freeze
const HEARTBEAT_PITCH := Vector2(1.0, 1.4)
## Playtest feedback: the panting was too much. It now starts at 60% of the
## time and never gets louder than a background breath.
const BREATHING_DB := Vector2(-40.0, -24.0)
const BREATHING_FROM: float = 0.6
const SILENT_DB: float = -60.0

@onready var root: Control = $Root
@onready var vignette: ColorRect = $Root/Vignette
@onready var word_cloud: Control = $Root/WordCloud
@onready var sentence_line: HBoxContainer = $Root/SentenceLine
@onready var prompt_label: Label = $Root/Prompt

var _data: AnxietyPuzzleData
var _words: Array[ThoughtWord] = []
## No word has the focus until the first arrow: otherwise Space (for example,
## to finish reading) said whatever random word happened to be focused.
var _awaiting_first_focus: bool = true
var _picked: PackedStringArray = []
var _time_left: float = 0.0
var _cooldown: float = 0.0
var _accepting: bool = false
var _done: bool = false
var _heartbeat: AudioStreamPlayer
var _breathing: AudioStreamPlayer
## Distractor words that can change into another thought. Answer words and
## "(...)" never change, so the puzzle always stays solvable.
var _swappable: Array[ThoughtWord] = []
var _swap_timer: float = 0.0

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
	# The words are the puzzle, so each language has its own version.
	data = data.for_current_language()
	_data = data
	# The world goes muffled, as if under water, while she is stuck here.
	SoundManager.set_muffled(true)
	# Saving the .tres from the editor has dropped extra_words more than once,
	# silently: say so instead of quietly playing an easier puzzle.
	if not data.relaxed and data.extra_words.is_empty():
		push_warning("Anxiety puzzle '%s' has no extra_words (distractors)" % data.resource_path)
	_time_left = data.time_limit
	prompt_label.text = data.prompt
	if not data.relaxed:
		_heartbeat = _make_loop(HEARTBEAT)
		_breathing = _make_loop(BREATHING)
	_spawn_words()
	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, FADE_TIME)
	await tween.finished
	_accepting = true
	if data.hint_from_start:
		_blink_answer_starts()
	var result: String = await finished
	return result

## Plays a puzzle from a Dialogic [signal arg="anxiety_puzzle:<id>"] handler.
## Pausing Dialogic here, inside the signal event, keeps it from running the
## next event (the if on {anxiety_result}) until the puzzle has an answer.
## The scene decides which puzzle an id means; this only runs it.
static func play_from_dialogic(host: Node, data: AnxietyPuzzleData) -> void:
	Dialogic.paused = true
	# Loaded, not preloaded: the scene's own script cannot preload it.
	var puzzle := (load(SCENE_PATH) as PackedScene).instantiate() as AnxietyPuzzle
	host.add_child(puzzle)
	var result := await puzzle.run(data)
	Dialogic.VAR.set_variable("anxiety_result", result)
	Dialogic.paused = false

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
	var answer_count := texts.size()
	for word in _data.extra_words:
		if not texts.has(word):
			texts.append(word)
	if not _data.relaxed:
		var intrusive := _intrusive_thoughts()
		intrusive.shuffle()
		for thought in intrusive.slice(0, INTRUSIVE_AT_START):
			if not texts.has(thought):
				texts.append(thought)
	var swappable_count := texts.size() - answer_count
	texts.append(SILENCE_WORD)
	for i in texts.size():
		var word := WORD_SCENE.instantiate() as ThoughtWord
		word_cloud.add_child(word)
		word.setup(texts[i])
		word.pressed.connect(_on_word_pressed.bind(word))
		_words.append(word)
		if i >= answer_count and i < answer_count + swappable_count:
			_swappable.append(word)
	_swap_timer = _next_swap_delay()
	_scatter_words()

## Places every word at a random free spot of the cloud and focuses one.
func _scatter_words() -> void:
	_words.shuffle()
	var taken: Array[Rect2] = []
	for word in _words:
		word.show()
		word.modulate.a = 1.0
		_place_word(word, taken)
		taken.append(Rect2(word.base_position, word.size))
	if not _awaiting_first_focus:
		_words[0].grab_focus()

## Moves one word to a random spot of the cloud that none of the taken rects
## covers (or the last one tried, if the cloud is too crowded).
func _place_word(word: ThoughtWord, taken: Array[Rect2]) -> void:
	word.reset_size()
	var area := Rect2(CLOUD_RECT.position, CLOUD_RECT.size - word.size)
	var spot := area.position
	for attempt in PLACEMENT_TRIES:
		spot = (area.position + Vector2(randf() * area.size.x, randf() * area.size.y)).round()
		var rect := Rect2(spot, word.size).grow(WORD_GAP)
		if not taken.any(func(other: Rect2) -> bool: return other.intersects(rect)):
			break
	word.base_position = spot
	word.position = spot

func _intrusive_thoughts() -> Array[String]:
	var thoughts: Array[String] = []
	for thought in INTRUSIVE_THOUGHTS:
		thoughts.append(tr(thought))
	return thoughts

# =========================
# Swapping thoughts
# =========================
## Her head does not hold still: every few seconds one distractor fades out
## and comes back somewhere else as another thought. Faster under pressure.
func _update_swaps(delta: float, pressure: float) -> void:
	_swap_timer -= delta
	if _swap_timer > 0.0:
		return
	_swap_timer = _next_swap_delay(pressure)
	_swap_one_thought()

func _next_swap_delay(pressure: float = 0.0) -> float:
	var delay := lerpf(SWAP_INTERVAL.x, SWAP_INTERVAL.y, pressure)
	return delay * randf_range(1.0 - SWAP_SPREAD, 1.0 + SWAP_SPREAD)

func _swap_one_thought() -> void:
	# The focused word is the one she is holding on to: it never slips away.
	var candidates := _swappable.filter(func(word: ThoughtWord) -> bool:
		return word.visible and not word.has_focus() and word.modulate.a >= 1.0)
	if candidates.is_empty():
		return
	var shown: PackedStringArray = []
	for word in _words:
		shown.append(word.text)
	var pool: PackedStringArray = []
	for text in Array(_data.extra_words) + _intrusive_thoughts():
		if not shown.has(text) and not pool.has(text):
			pool.append(text)
	if pool.is_empty():
		return
	var word: ThoughtWord = candidates.pick_random()
	var new_text: String = pool[randi() % pool.size()]
	var tween := word.create_tween()
	tween.tween_property(word, "modulate:a", 0.0, SWAP_FADE)
	tween.tween_callback(_replace_thought.bind(word, new_text))
	tween.tween_property(word, "modulate:a", 1.0, SWAP_FADE)

func _replace_thought(word: ThoughtWord, new_text: String) -> void:
	# Picked (hidden) while fading out: the next scatter brings it back as is.
	if _done or not word.visible:
		return
	word.text = new_text
	var taken: Array[Rect2] = []
	for other in _words:
		if other != word and other.visible:
			taken.append(Rect2(other.base_position, other.size))
	_place_word(word, taken)

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
	_awaiting_first_focus = false
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
	if not _data.relaxed:
		_time_left -= _data.mistake_penalty
	sentence_line.modulate = STUMBLE_COLOR
	_show_stumble_line()
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

## Shows Alice's reaction where the prompt is, then puts the prompt back.
func _show_stumble_line() -> void:
	prompt_label.text = STUMBLE_LINE
	await get_tree().create_timer(STUMBLE_LINE_TIME).timeout
	if is_instance_valid(prompt_label) and not _done:
		prompt_label.text = _data.prompt

## Second hint: after a mistake (or from the start, in a tutorial puzzle), the
## words every answer starts with blink, so the player knows where to begin
## without being told the whole order.
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
	label.add_theme_font_size_override("font_size", WORD_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", WORD_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", WORD_OUTLINE_SIZE)
	return label

# =========================
# Time pressure
# =========================
func _input(event: InputEvent) -> void:
	if not _accepting:
		return
	if _awaiting_first_focus and ARROW_ACTIONS.any(func(action: StringName) -> bool: return event.is_action_pressed(action)):
		_awaiting_first_focus = false
		_focus_any_visible()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _accepting:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	# A rehearsal has no clock: no pressure, no closing vignette, no freezing.
	# A real puzzle starts ticking as soon as the words are up: the mirror
	# already taught how to play, so there is no grace time to read.
	if _data.relaxed:
		return
	_time_left -= delta
	var pressure := clampf(1.0 - _time_left / _data.time_limit, 0.0, 1.0)
	vignette.material.set_shader_parameter("pressure", pressure)
	for word in _words:
		word.pressure = pressure
	_heartbeat.volume_db = lerpf(HEARTBEAT_DB.x, HEARTBEAT_DB.y, pressure)
	_heartbeat.pitch_scale = lerpf(HEARTBEAT_PITCH.x, HEARTBEAT_PITCH.y, pressure)
	var breath := clampf((pressure - BREATHING_FROM) / (1.0 - BREATHING_FROM), 0.0, 1.0)
	_breathing.volume_db = lerpf(BREATHING_DB.x, BREATHING_DB.y, breath)
	_update_swaps(delta, pressure)
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
	SoundManager.set_muffled(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, FADE_TIME)
	for loop_player in [_heartbeat, _breathing]:
		if loop_player:
			tween.tween_property(loop_player, "volume_db", SILENT_DB, FADE_TIME)
	await tween.finished
	finished.emit(result)
	queue_free()

# =========================
# Body sounds
# =========================
func _make_loop(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	return player

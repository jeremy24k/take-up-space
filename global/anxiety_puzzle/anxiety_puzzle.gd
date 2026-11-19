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
## It stays up there and never blocks picking words: big in the middle it
## felt unfair after a mistake (2026-11-17).
const STUMBLE_LINE := "No... así no."
const STUMBLE_LINE_TIME: float = 1.2
## Running out of time shows big in the middle of the cloud, where the words
## were (up in the prompt it went unnoticed). It pops in from POP_FROM scale.
const CENTER_LINE_FONT_SIZE: int = 72
const CENTER_LINE_POP_FROM: float = 0.6
const CENTER_LINE_POP_TIME: float = 0.22
const CENTER_LINE_FADE: float = 0.2
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
## The time shows without a clock: the dark edges beat like her heart, a
## double thump that speeds up (beats per second, calm -> about to freeze)
## and pushes further in as the time runs out.
const BEAT_RATE := Vector2(1.0, 2.1)
const BEAT_DEPTH := Vector2(0.02, 0.09)
## When the time runs out it must read as Alice freezing, not as the game
## eating the input: this line takes the prompt's place and the words sink
## and fade before the puzzle closes. One of these at random, never the
## same as last time (in any puzzle). Only when the clock runs out, not when
## she picks "(...)".
const TIME_OUT_LINES: PackedStringArray = [
	"(Se le pasa el momento.)",
	"(Se queda en blanco.)",
	"(Le arde la cara. Siente que todos la miran.)",
	"(Le sudan las manos. Ya no sabe qué iba a decir.)",
	"(Un nudo en la garganta. Nada.)",
	"(Oye su corazón más fuerte que su voz.)",
	"(Un vacío en el estómago. Se calla.)",
	"(Abre la boca. Ya es tarde.)",
]
const TIME_OUT_HOLD: float = 1.4
## The words sink and fade first; then her line shows in the middle.
const TIME_OUT_SINK_TIME: float = 0.5
const TIME_OUT_SINK: float = 24.0
## Right after it opens, Space does nothing for a moment: a press meant to
## finish reading the last line must not say the word already selected.
const OPEN_GRACE: float = 0.5
## Arrow navigation: how much a word off to the side counts against it
## compared with one straight ahead.
const NAV_SIDE_WEIGHT: float = 2.0

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
var _heartbeat: AudioStreamPlayer
var _breathing: AudioStreamPlayer
## Distractor words that can change into another thought. Answer words and
## "(...)" never change, so the puzzle always stays solvable.
var _swappable: Array[ThoughtWord] = []
var _swap_timer: float = 0.0
var _beat_phase: float = 0.0
var _center_line: Label
## Bumped by each stumble, so an older one never puts the prompt back early.
var _stumble_token: int = 0

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
	_cooldown = OPEN_GRACE
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

## Places every word at a random free spot of the cloud and selects the
## first one in reading order, so an arrow or Space always does something.
func _scatter_words() -> void:
	_words.shuffle()
	var taken: Array[Rect2] = []
	for word in _words:
		word.show()
		word.modulate.a = 1.0
		_place_word(word, taken)
		taken.append(Rect2(word.base_position, word.size))
	_focus_first_word()

## Moves one word to a random spot of the cloud that none of the taken rects
## covers. If the cloud is too crowded for that, it takes the spot that
## overlaps the least: before, it kept the last spot tried, and a swapped
## thought could land right on top of another word.
func _place_word(word: ThoughtWord, taken: Array[Rect2]) -> void:
	word.reset_size()
	var area := Rect2(CLOUD_RECT.position, CLOUD_RECT.size - word.size)
	var best_spot := area.position
	var best_score := INF
	for attempt in PLACEMENT_TRIES:
		var spot := (area.position + Vector2(randf() * area.size.x, randf() * area.size.y)).round()
		var score := _overlap_score(Rect2(spot, word.size), taken)
		if score < best_score:
			best_score = score
			best_spot = spot
			if score == 0.0:
				break
	# Random tries can miss the one free gap of a crowded cloud: sweep it all.
	if best_score > 0.0:
		var step := WORD_GAP / 2.0
		var y := area.position.y
		while y <= area.end.y and best_score > 0.0:
			var x := area.position.x
			while x <= area.end.x:
				var score := _overlap_score(Rect2(Vector2(x, y), word.size), taken)
				if score < best_score:
					best_score = score
					best_spot = Vector2(x, y)
					if score == 0.0:
						break
				x += step
			y += step
	word.base_position = best_spot
	word.position = best_spot

## How badly a word placed at rect would collide with the taken rects. Text
## on top of text is far worse than words only closer than WORD_GAP.
func _overlap_score(rect: Rect2, taken: Array[Rect2]) -> float:
	var padded := rect.grow(WORD_GAP)
	var score := 0.0
	for other in taken:
		score += other.intersection(rect).get_area() * 1000.0
		score += other.intersection(padded).get_area()
	return score

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
	var slipping: ThoughtWord = candidates.pick_random()
	var new_text: String = pool[randi() % pool.size()]
	var tween := slipping.create_tween()
	tween.tween_property(slipping, "modulate:a", 0.0, SWAP_FADE)
	tween.tween_callback(_replace_thought.bind(slipping, new_text))
	tween.tween_property(slipping, "modulate:a", 1.0, SWAP_FADE)

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

## The visible word closest to the top-left corner (reading order). Never
## "(...)" unless it is the only one left: that one ends the puzzle.
func _focus_first_word() -> void:
	var best: ThoughtWord = null
	for word in _words:
		if not word.visible or (word.text == SILENCE_WORD and best != null):
			continue
		if best == null or best.text == SILENCE_WORD or _reading_order(word) < _reading_order(best):
			best = word
	if best:
		best.grab_focus()

## Rows of about one word height, then left to right.
func _reading_order(word: ThoughtWord) -> float:
	return roundf(word.base_position.y / word.size.y) * 100000.0 + word.base_position.x

func _word_center(word: ThoughtWord) -> Vector2:
	return word.base_position + word.size / 2.0

## The word an arrow leads to from the focused one: the closest one in that
## direction, preferring the ones straight ahead over the ones off to the
## side. Godot's own focus search jumped to unexpected words.
func _word_towards(from: ThoughtWord, direction: Vector2) -> ThoughtWord:
	var origin := _word_center(from)
	# Up or down means another row: a word only a few pixels higher is on the
	# same line and belongs to left/right.
	var min_ahead := from.size.y * 0.5 if direction.y != 0.0 else 1.0
	var best: ThoughtWord = null
	var best_score := INF
	for word in _words:
		if word == from or not word.visible:
			continue
		var to_word := _word_center(word) - origin
		var ahead := to_word.dot(direction)
		if ahead < min_ahead:
			continue
		var score := ahead + absf(to_word.cross(direction)) * NAV_SIDE_WEIGHT
		if score < best_score:
			best_score = score
			best = word
	return best

func _focused_word() -> ThoughtWord:
	for word in _words:
		if word.has_focus():
			return word
	return null

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
	_focus_first_word()

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
	var start := sentence_line.position
	var tween := create_tween()
	for step in [9, -9, 6, -6, 3, 0]:
		tween.tween_property(sentence_line, "position:x", start.x + step, 0.04)
	_show_stumble_line()
	await tween.finished
	if _done:
		return
	for child in sentence_line.get_children():
		child.queue_free()
	sentence_line.modulate = Color.WHITE
	_picked.clear()
	_scatter_words()
	_accepting = not _done
	_blink_answer_starts()

## Shows Alice's reaction where the prompt is, then puts the prompt back
## (unless a newer stumble replaced it meanwhile).
func _show_stumble_line() -> void:
	_stumble_token += 1
	var token := _stumble_token
	prompt_label.text = STUMBLE_LINE
	await get_tree().create_timer(STUMBLE_LINE_TIME).timeout
	if is_instance_valid(prompt_label) and not _done and token == _stumble_token:
		prompt_label.text = _data.prompt

## Alice's reaction big in the middle of the cloud: it pops in (and shakes a
## little if asked), holds, and fades out. Await it.
func _show_center_line(text: String, hold: float, shake: bool) -> void:
	if _center_line == null:
		_center_line = Label.new()
		_center_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_center_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_center_line.add_theme_font_override("font", FONT)
		_center_line.add_theme_font_size_override("font_size", CENTER_LINE_FONT_SIZE)
		_center_line.add_theme_color_override("font_outline_color", WORD_OUTLINE_COLOR)
		_center_line.add_theme_constant_override("outline_size", WORD_OUTLINE_SIZE)
		_center_line.add_theme_color_override("font_color", prompt_label.get_theme_color("font_color"))
		_center_line.position = CLOUD_RECT.position
		_center_line.size = CLOUD_RECT.size
		_center_line.pivot_offset = CLOUD_RECT.size / 2.0
		_center_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_center_line)
	_center_line.text = text
	_center_line.show()
	_center_line.modulate.a = 0.0
	_center_line.scale = Vector2.ONE * CENTER_LINE_POP_FROM
	_center_line.position = CLOUD_RECT.position
	var pop := create_tween().set_parallel(true)
	pop.tween_property(_center_line, "modulate:a", 1.0, CENTER_LINE_FADE)
	pop.tween_property(_center_line, "scale", Vector2.ONE, CENTER_LINE_POP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await pop.finished
	if shake:
		var shaking := create_tween()
		for step in [6, -6, 4, -4, 2, 0]:
			shaking.tween_property(_center_line, "position:x", CLOUD_RECT.position.x + step, 0.04)
		await shaking.finished
	await get_tree().create_timer(hold).timeout
	var out := create_tween()
	out.tween_property(_center_line, "modulate:a", 0.0, CENTER_LINE_FADE)
	await out.finished
	_center_line.hide()

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
## Arrows move between the words here, before the GUI's own navigation.
func _input(event: InputEvent) -> void:
	if not _accepting:
		return
	for action in ARROW_ACTIONS:
		if not event.is_action_pressed(action, true):
			continue
		get_viewport().set_input_as_handled()
		var current := _focused_word()
		if current == null:
			_focus_first_word()
			return
		var next := _word_towards(current, _arrow_direction(action))
		if next:
			next.grab_focus()
		return

func _arrow_direction(action: StringName) -> Vector2:
	match action:
		&"ui_left":
			return Vector2.LEFT
		&"ui_right":
			return Vector2.RIGHT
		&"ui_up":
			return Vector2.UP
	return Vector2.DOWN

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
	_beat_phase = fmod(_beat_phase + delta * lerpf(BEAT_RATE.x, BEAT_RATE.y, pressure), 1.0)
	vignette.material.set_shader_parameter("beat",
		_heartbeat_pulse(_beat_phase) * lerpf(BEAT_DEPTH.x, BEAT_DEPTH.y, pressure))
	for word in _words:
		word.pressure = pressure
	_heartbeat.volume_db = lerpf(HEARTBEAT_DB.x, HEARTBEAT_DB.y, pressure)
	_heartbeat.pitch_scale = lerpf(HEARTBEAT_PITCH.x, HEARTBEAT_PITCH.y, pressure)
	var breath := clampf((pressure - BREATHING_FROM) / (1.0 - BREATHING_FROM), 0.0, 1.0)
	_breathing.volume_db = lerpf(BREATHING_DB.x, BREATHING_DB.y, breath)
	_update_swaps(delta, pressure)
	if _time_left <= 0.0:
		_run_out_of_time()

static var _last_time_out_line: String = ""

func _next_time_out_line() -> String:
	var choices := Array(TIME_OUT_LINES).filter(func(line: String) -> bool:
		return line != _last_time_out_line)
	_last_time_out_line = choices.pick_random()
	return _last_time_out_line

## Lub-dub: a strong thump and a softer one right after, then rest.
func _heartbeat_pulse(phase: float) -> float:
	var lub := exp(-pow(phase / 0.07, 2.0))
	var dub := 0.6 * exp(-pow((phase - 0.2) / 0.07, 2.0))
	return maxf(lub, dub)

## She froze: the moment slips away on screen before the puzzle closes, so
## running out of time reads as part of the story.
func _run_out_of_time() -> void:
	if _done or not _accepting:
		return
	_accepting = false
	var sink := create_tween().set_parallel(true)
	for word in _words:
		if word.visible:
			word.release_focus()
			sink.tween_property(word, "modulate:a", 0.0, TIME_OUT_SINK_TIME)
			sink.tween_property(word, "base_position:y", word.base_position.y + TIME_OUT_SINK, TIME_OUT_SINK_TIME)
	sink.tween_property(sentence_line, "modulate:a", 0.0, TIME_OUT_SINK_TIME)
	await sink.finished
	await _show_center_line(_next_time_out_line(), TIME_OUT_HOLD, false)
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

extends Node

# =========================
# Thought box (layout B)
# =========================
## Alice's mind. The game has two visual languages, both through Dialogic:
## - the "dialogue" style: the box at the bottom, for conversations and
##   monologues from .dtl files. It stops her and waits for Space;
## - the "thought" style: the cloud at the top, for her thoughts (floor
##   triggers, map edges, one-line remarks on inert things). It never stops
##   her: the text shows at once and each line moves on by itself through
##   Dialogic's native auto-advance.
## Both styles share their root, so switching only re-applies overrides to the
## same layout (no rebuild, no flicker).
## The thought style is set by a [style] event at the top of each thought
## timeline, which makes it the base style while the thought runs. Setting it
## from code before Dialogic.start() does not stick: start() clears the base
## style and every text event switches back to the base one. When a
## conversation starts, its first text event brings back the default style
## ("dialogue", dialogic/layout/default_style) on its own.
const THOUGHT_STYLE_NAME := "Thought"
## Set on every thought timeline, so the Player (and anyone else) can tell a
## thought from a conversation.
const THOUGHT_META := &"thought"
## Reading time of each line: a base plus a little per character.
const DEFAULT_HOLD_BASE: float = 2.0
const HOLD_PER_CHAR: float = 0.03
## Text shows all at once: no press needed to finish the typing.
const INSTANT_TEXT := "[lspeed=0!]"

# =========================
# Juice configuration
# =========================
## The cloud thins down to this opacity as the line's time runs out (the
## text stays solid: only the panel's modulate changes).
const CLOUD_ALPHA_MIN: float = 0.55
## Entry: from a bit smaller and lower to its place, overshooting slightly.
## The dialogue box enters from below; the cloud floats up instead.
const ENTER_TIME: float = 0.22
const ENTER_SCALE: float = 0.92
const ENTER_DRIFT: float = 4.0
## Exit: it dissolves upwards. Played by a [signal] near the end of every
## thought timeline, followed by a [wait] as long as the tween.
const EXIT_SIGNAL := "thought_out"
const EXIT_TIME: float = 0.22
const EXIT_DRIFT: float = 6.0
## Small bubbles rising from Alice's head towards the cloud before it shows:
## the classic thought-bubble tail. Sizes grow towards the cloud; each one sits
## at that fraction of the way from her head to the cloud.
const BUBBLE_RADII: Array[float] = [4.0, 6.0, 9.0]
const BUBBLE_PATH_POINTS: Array[float] = [0.16, 0.36, 0.62]
const BUBBLE_POP_TIME: float = 0.12
const BUBBLE_STAGGER: float = 0.06
const BUBBLE_FADE_TIME: float = 0.25
const BUBBLE_FILL := Color(0.16, 0.11, 0.26, 0.85)
const BUBBLE_EDGE := Color(0.82, 0.72, 1.0, 1.0)
## Where Alice's head is, in world pixels from her origin.
const HEAD_OFFSET := Vector2(0, -22)
## Bottom of the cloud, measured up from the bottom of the screen (thought_style
## puts its 96 px box 648 px above the bottom edge).
const CLOUD_BOTTOM_FROM_SCREEN_BOTTOM: float = 648.0
## Bubbles draw in screen space, under Dialogic's layout.
const BUBBLE_LAYER: int = 1

var _token_counter: int = 0
## True from the moment a say() starts preparing until its timeline is on
## screen. Two thoughts starting at once (e.g. an NPC and a floor trigger on
## the same step) would otherwise overlap: Dialogic would start the second one
## while the first is not showing yet, _on_timeline_started would take it for a
## conversation and turn auto-advance off, and the cloud would never close.
var _starting: bool = false
## Sources currently asking for the notice over Alice, and the notice itself
## (in the bubble layer, created the first time it is needed).
var _notice_sources: Dictionary = {}
var _notice: ThoughtNotice
## Auto-advance settings of the dialogue style, restored after each thought.
var _saved_fixed_delay: float = 1.0
var _saved_per_character_delay: float = 0.1
var _auto_advance_owned: bool = false
## Where the layout put the cloud; the tweens move around it and restore it.
var _cloud_base_position := Vector2.ZERO
var _cloud_tween: Tween
var _bubble_layer: CanvasLayer
## The cloud's own panel (thought_style.tres points its textbox at it): a
## nine-slice StyleBoxTexture of thought_cloud.aseprite. Its opacity follows
## the auto-advance progress: the thought "evaporates".
var _thought_panel: StyleBoxTexture = preload("res://dialogic/styles/thought_panel.tres")

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.layer = BUBBLE_LAYER
	add_child(_bubble_layer)
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_timeline_started() -> void:
	if is_showing():
		# Hidden from the very first frame, so the entry tween starts clean.
		var cloud := _cloud()
		if cloud:
			cloud.modulate.a = 0.0
	else:
		# A conversation never inherits the thought's auto-advance or juice.
		_release_auto_advance()
		_reset_cloud()
		# Nor its style. Dialogic.start() only clears its state when no layout
		# is active, so a conversation started over a thought (e.g. the train
		# arriving while a remark is up) kept "Thought" as its base style and
		# showed in the cloud, name tag cut off at the top of the screen.
		# timeline_started fires before the first text event, so this is in time.
		var styles: Node = Dialogic.Styles
		if styles.base_style == THOUGHT_STYLE_NAME or styles.get_current_style() == THOUGHT_STYLE_NAME:
			styles.change_style("")

func _on_dialogic_signal(argument: Variant) -> void:
	if argument is String and argument == EXIT_SIGNAL and is_showing():
		_leave_cloud()

# =========================
# Public API
# =========================
## True while a thought (not a conversation) is on screen.
func is_showing() -> bool:
	return is_thought(Dialogic.current_timeline)

func is_thought(timeline: Variant) -> bool:
	return timeline is DialogicTimeline and (timeline as DialogicTimeline).has_meta(THOUGHT_META)

## The small thought cloud over Alice's head (ThoughtNotice) that says "Space
## here gives a thought". Each source (e.g. an AmbientThought) turns its share
## on and off; the notice shows while at least one source wants it.
func set_notice(source: Object, on: bool) -> void:
	if on:
		_notice_sources[source] = true
	else:
		_notice_sources.erase(source)
	for key in _notice_sources.keys():
		if not is_instance_valid(key):
			_notice_sources.erase(key)
	_refresh_notice()

## Never while a thought is being prepared or is on screen: between two
## thoughts (Space pressed again) there is a gap of ~0.2 s with no timeline
## (the bubbles rise first), and the areas ask for the notice in it.
func _refresh_notice() -> void:
	if not is_instance_valid(_notice):
		_notice = ThoughtNotice.new()
		_bubble_layer.add_child(_notice)
	# Alice is a new node after every scene change.
	_notice.target = get_tree().get_first_node_in_group("player") as Node2D
	var busy := _starting or is_showing()
	_notice.set_shown(not _notice_sources.is_empty() and _notice.target != null and not busy)

## Shows Alice's thought in the cloud, one line after the other, and returns
## when the cloud is gone (awaitable). A thought already on screen is replaced.
## With close_on_move, walking closes it at once: used by remarks on objects,
## which the player leaves by walking away. Floor thoughts fire while she
## walks, so they keep it off.
func say(lines: Array[String], close_on_move := false, hold_base := DEFAULT_HOLD_BASE) -> void:
	var clean: Array[String] = []
	for line in lines:
		if not line.strip_edges().is_empty():
			clean.append(line)
	if clean.is_empty():
		return

	# One thought starts at a time; the next one then replaces it as usual.
	while _starting:
		await get_tree().process_frame
	_starting = true
	_refresh_notice()

	# A conversation keeps the screen: the thought waits for it to end.
	while Dialogic.current_timeline != null and not is_showing():
		await Dialogic.timeline_ended
	if is_showing():
		await Dialogic.end_timeline(true)

	var timeline := _build_timeline(clean)
	_token_counter += 1
	var token := _token_counter
	timeline.set_meta(THOUGHT_META, token)

	var bubbles := await _rise_bubbles()
	_take_auto_advance(hold_base)
	Dialogic.start(timeline)
	await _watch(token, close_on_move, bubbles)

	# Only the last thought hands the screen back.
	if _token_counter == token:
		_release_auto_advance()
		_reset_cloud()
	_refresh_notice()

# =========================
# Timeline
# =========================
func _build_timeline(lines: Array[String]) -> DialogicTimeline:
	# No speaker: the cloud has no name tag, it is her head. Each line is its
	# own text event; [br] (not \n) would be a break inside one line. The
	# closing signal + wait give the exit tween its time on screen.
	var text := '[style name="%s"]\n' % THOUGHT_STYLE_NAME
	for line in lines:
		text += INSTANT_TEXT + line + "\n"
	text += '[signal arg="%s"]\n' % EXIT_SIGNAL
	text += '[wait time="%s" hide_text="false"]' % EXIT_TIME
	var timeline := DialogicTimeline.new()
	timeline.from_text(text)
	return timeline

## Waits while this thought is on screen. Dialogic.start() takes a few frames
## to set the timeline, and it runs a copy of it, so the token in the meta is
## what identifies it.
func _watch(token: int, close_on_move: bool, bubbles: Array[Node2D]) -> void:
	var tree := get_tree()
	var start_wait := 1.0
	while not _is_showing_token(token) and start_wait > 0.0:
		await tree.process_frame
		start_wait -= get_process_delta_time()
	_starting = false

	await _enter_cloud(token)
	_fade_bubbles(bubbles)

	while _is_showing_token(token):
		await tree.process_frame
		_evaporate_cloud()
		if close_on_move and Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO:
			await _leave_cloud()
			if _is_showing_token(token):
				await Dialogic.end_timeline()
			return

func _is_showing_token(token: int) -> bool:
	var current: Variant = Dialogic.current_timeline
	return is_thought(current) and (current as DialogicTimeline).get_meta(THOUGHT_META) == token

# =========================
# Cloud entry and exit
# =========================
## The textbox's Sizer: the node the layout positions, so scaling and drifting
## it moves the whole cloud.
func _cloud() -> Control:
	var layout: Node = Dialogic.Styles.get_layout_node()
	if layout == null:
		return null
	var textbox := layout.find_child("VN_TextboxLayer", true, false)
	if textbox == null:
		return null
	return textbox.get_node_or_null("Anchor/AnimationParent/Sizer") as Control

func _enter_cloud(token: int) -> void:
	# Wait for the panel to show: the [style] event (which moves the box up)
	# runs first, so only then is its final position known.
	var cloud := _cloud()
	var tree := get_tree()
	while cloud and _is_showing_token(token) and not cloud.is_visible_in_tree():
		await tree.process_frame
	if cloud == null or not _is_showing_token(token):
		return

	_cloud_base_position = cloud.position
	cloud.pivot_offset = cloud.size / 2.0
	cloud.scale = Vector2.ONE * ENTER_SCALE
	cloud.position = _cloud_base_position + Vector2(0, ENTER_DRIFT)
	cloud.modulate.a = 0.0
	_set_cloud_alpha(1.0)

	_kill_cloud_tween()
	_cloud_tween = create_tween().set_parallel(true)
	_cloud_tween.tween_property(cloud, "modulate:a", 1.0, ENTER_TIME)
	_cloud_tween.tween_property(cloud, "position", _cloud_base_position, ENTER_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_cloud_tween.tween_property(cloud, "scale", Vector2.ONE, ENTER_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await _cloud_tween.finished

func _leave_cloud() -> void:
	var cloud := _cloud()
	if cloud == null:
		return
	_kill_cloud_tween()
	_cloud_tween = create_tween().set_parallel(true)
	_cloud_tween.tween_property(cloud, "modulate:a", 0.0, EXIT_TIME)
	_cloud_tween.tween_property(cloud, "position", _cloud_base_position - Vector2(0, EXIT_DRIFT), EXIT_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await _cloud_tween.finished

## Both styles share one layout: whatever the tweens changed must be back to
## normal before the dialogue box shows again.
func _reset_cloud() -> void:
	_kill_cloud_tween()
	_set_cloud_alpha(1.0)
	var cloud := _cloud()
	if cloud == null:
		return
	cloud.modulate.a = 1.0
	cloud.scale = Vector2.ONE
	if _cloud_base_position != Vector2.ZERO:
		cloud.position = _cloud_base_position
		_cloud_base_position = Vector2.ZERO

func _kill_cloud_tween() -> void:
	if _cloud_tween and _cloud_tween.is_valid():
		_cloud_tween.kill()

# =========================
# Evaporating cloud
# =========================
## The cloud thins as the line's time runs out, and comes back with the next
## line: the player sees how long it stays without a progress bar.
func _evaporate_cloud() -> void:
	var progress: float = Dialogic.Inputs.auto_advance.get_progress()
	if progress >= 0.0:
		_set_cloud_alpha(lerpf(1.0, CLOUD_ALPHA_MIN, clampf(progress, 0.0, 1.0)))

func _set_cloud_alpha(alpha: float) -> void:
	_thought_panel.modulate_color.a = alpha

# =========================
# Bubbles from Alice's head
# =========================
## Pops the bubbles one after the other, from her head up towards the cloud,
## and returns them so they can fade once the cloud is in.
func _rise_bubbles() -> Array[Node2D]:
	var bubbles: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.is_inside_tree() or not player.is_visible_in_tree():
		return bubbles

	var head: Vector2 = player.get_global_transform_with_canvas() * HEAD_OFFSET
	var screen := get_viewport().get_visible_rect().size
	var cloud_bottom := Vector2(screen.x / 2.0, screen.y - CLOUD_BOTTOM_FROM_SCREEN_BOTTOM)
	for i in BUBBLE_RADII.size():
		var bubble := ThoughtBubble.new(BUBBLE_RADII[i], BUBBLE_FILL, BUBBLE_EDGE)
		bubble.position = head.lerp(cloud_bottom, BUBBLE_PATH_POINTS[i]).round()
		bubble.scale = Vector2.ZERO
		_bubble_layer.add_child(bubble)
		bubble.create_tween().tween_property(bubble, "scale", Vector2.ONE, BUBBLE_POP_TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		bubbles.append(bubble)
		await get_tree().create_timer(BUBBLE_STAGGER).timeout
	return bubbles

func _fade_bubbles(bubbles: Array[Node2D]) -> void:
	for bubble in bubbles:
		if not is_instance_valid(bubble):
			continue
		var tween := bubble.create_tween()
		tween.tween_property(bubble, "modulate:a", 0.0, BUBBLE_FADE_TIME)
		tween.tween_callback(bubble.queue_free)

## One round bubble of the tail, drawn without antialiasing to stay pixel-crisp.
class ThoughtBubble extends Node2D:
	var radius: float
	var fill: Color
	var edge: Color

	func _init(bubble_radius: float, fill_color: Color, edge_color: Color) -> void:
		radius = bubble_radius
		fill = fill_color
		edge = edge_color

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius + 2.0, edge, true, -1.0, false)
		draw_circle(Vector2.ZERO, radius, fill, true, -1.0, false)

# =========================
# Auto-advance
# =========================
## Dialogic's own auto-advance, only while a thought is up: the dialogue style
## never inherits it.
func _take_auto_advance(hold_base: float) -> void:
	var auto_advance: DialogicAutoAdvance = Dialogic.Inputs.auto_advance
	if not _auto_advance_owned:
		_saved_fixed_delay = auto_advance.fixed_delay
		_saved_per_character_delay = auto_advance.per_character_delay
		_auto_advance_owned = true
	auto_advance.fixed_delay = hold_base
	auto_advance.per_character_delay = HOLD_PER_CHAR
	auto_advance.enabled_forced = true

func _release_auto_advance() -> void:
	if not _auto_advance_owned:
		return
	var auto_advance: DialogicAutoAdvance = Dialogic.Inputs.auto_advance
	auto_advance.enabled_forced = false
	auto_advance.fixed_delay = _saved_fixed_delay
	auto_advance.per_character_delay = _saved_per_character_delay
	_auto_advance_owned = false

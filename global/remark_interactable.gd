class_name RemarkInteractable
extends "res://global/interactable_area.gd"

# =========================
# Remark configuration
# =========================
## Something that looks interactive but has little to say: an ambient NPC, a
## locked door, a second vending machine. Pressing Space opens the dialogue box
## with a single line of Alice's, written here instead of in its own .dtl.
## Everything the player triggers with Space uses the box; one line means "a
## dead end", several lines or a choice mean real content.
## Used in order, looping. Ignored when a pool is set.
@export var lines: Array[String] = []
## Off: once the last line is reached it repeats instead of starting over.
@export var loop_lines: bool = true
## Shared lines (e.g. every ambient NPC), picked without repeating.
@export var pool: RemarkPool
## Objects that look the same share an id ("vending", "station_map"...). The
## first one Alice tries, in any scene, plays first_timeline (or says
## first_line); the rest only say their lines.
@export var group_id: String = ""
@export var first_timeline: String = ""
@export var first_line: String = ""
## Who says the line (a .dch id).
@export var speaker: String = "alice"

# =========================
# One-line box behavior
# =========================
## A one-line box gets out of the way: the text shows all at once, Alice can
## keep walking, and the box closes when she moves, when Space is pressed, or
## on its own after a while. One press (to interact) is all it costs.
const HOLD_BASE: float = 3.0
const HOLD_PER_CHAR: float = 0.05
## The Space that closes a box must not open the same one again.
const REOPEN_COOLDOWN_MSEC: int = 250
## Set on the timeline so the Player knows not to stop her.
const REMARK_META := &"remark"

var _next_line: int = 0
var _closed_at_msec: int = -REOPEN_COOLDOWN_MSEC
var _remark_token: int = 0

# =========================
# Interaction
# =========================
func interact() -> void:
	if not _interaction_enabled:
		return
	if Time.get_ticks_msec() - _closed_at_msec < REOPEN_COOLDOWN_MSEC:
		return

	# First, so the scene can still switch timeline_name or lines.
	interacted.emit()

	if timeline_name != "":
		_start_dialogue(timeline_name)
		return

	var line := ""
	if group_id != "" and not GameManager.has_seen_group(group_id):
		GameManager.mark_group_seen(group_id)
		if first_timeline != "":
			_start_dialogue(first_timeline)
			return
		line = first_line
	if line == "":
		line = _pick_line()
	if line == "":
		return

	_say(line)

## [lspeed=0!] shows the whole line at once: no press to finish the typing.
func _say(line: String) -> void:
	var timeline := DialogicTimeline.new()
	timeline.from_text("%s: [lspeed=0!]%s" % [speaker, line])
	# Dialogic may run a copy of the resource, so the box is recognised by
	# this token in its meta, not by identity.
	_remark_token += 1
	var token := "%d:%d" % [get_instance_id(), _remark_token]
	timeline.set_meta(REMARK_META, token)
	_start_dialogue(timeline)

	# Dialogic.start() can take a few frames to set the timeline (it may build
	# the layout first), so wait for the box before watching it.
	var tree := get_tree()
	var start_wait := 1.0
	while not _is_showing(token) and start_wait > 0.0:
		await tree.process_frame
		start_wait -= get_process_delta_time()

	var time_left := HOLD_BASE + line.length() * HOLD_PER_CHAR
	while _is_showing(token):
		await tree.process_frame
		time_left -= get_process_delta_time()
		var walking := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO
		if walking or time_left <= 0.0:
			if _is_showing(token):
				Dialogic.end_timeline()
			break
	_closed_at_msec = Time.get_ticks_msec()

func _is_showing(token: String) -> bool:
	var current: DialogicTimeline = Dialogic.current_timeline
	return current != null and current.get_meta(REMARK_META, "") == token

## Same as InteractableArea.interact() for a timeline, without emitting
## `interacted` a second time.
func _start_dialogue(timeline: Variant) -> void:
	if label:
		label.hide()
	if one_time_interaction:
		_interaction_enabled = false
		set_deferred("monitoring", false)
	Dialogic.start(timeline)

func _pick_line() -> String:
	if pool:
		return pool.pick_line()
	if lines.is_empty():
		return ""
	var index := _next_line % lines.size() if loop_lines else mini(_next_line, lines.size() - 1)
	_next_line += 1
	return lines[index]

class_name RemarkInteractable
extends "res://global/interactable_area.gd"

# =========================
# Remark configuration
# =========================
## Something that looks interactive but has little to say: an ambient NPC, a
## locked door, a second vending machine. Pressing Space shows a single line
## of Alice's in the thought cloud, written here instead of in its own .dtl.
## Real content (first_timeline, timeline_name) opens the dialogue box.
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

# =========================
# Remark behavior
# =========================
## The line shows in the thought cloud (ThoughtBox): text at once, Alice keeps
## walking, and the cloud goes away by itself, on Space, or when she walks
## off. One press (to interact) is all it costs.
## The Space that closes a cloud must not open the same one again.
const REOPEN_COOLDOWN_MSEC: int = 250

var _next_line: int = 0
var _closed_at_msec: int = -REOPEN_COOLDOWN_MSEC

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

func _say(line: String) -> void:
	var remark_lines: Array[String] = [line]
	await ThoughtBox.say(remark_lines, true)
	_closed_at_msec = Time.get_ticks_msec()

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

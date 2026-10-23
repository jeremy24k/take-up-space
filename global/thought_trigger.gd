class_name ThoughtTrigger
extends Area2D

# =========================
# Thought configuration
# =========================
## A spontaneous thought of Alice's: it fires when she steps on the area (or
## from code with show_thought) and shows in the thought cloud at the top of
## the screen (ThoughtBox, the Dialogic "thought" style). It never stops her.
@export var thought_text: String = ""
@export var thought_lines: Array[String] = []
## Base seconds each line stays up (plus a little per character).
@export var display_duration: float = ThoughtBox.DEFAULT_HOLD_BASE
@export var trigger_once: bool = true
## If another thought is still on screen, wait for it to end instead of
## cutting it off (by default a new thought replaces the current one).
@export var wait_for_current: bool = false

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return

	if trigger_once:
		# The Area2D is kept alive, only the monitoring is turned off.
		set_deferred("monitoring", false)

	show_thought(player)

# =========================
# Showing the thought
# =========================
## Coroutine: can be awaited to know when every line is over. The player is
## not used by the cloud itself; it stays in the signature for the callers
## (and for effects tied to Alice later on).
func show_thought(_player_node: Player = null) -> void:
	var lines: Array[String] = []
	if thought_lines.is_empty():
		lines.append(thought_text)
	else:
		lines = thought_lines

	if wait_for_current:
		while ThoughtBox.is_showing():
			await get_tree().process_frame
			if not is_inside_tree():
				return

	await ThoughtBox.say(lines, false, display_duration)

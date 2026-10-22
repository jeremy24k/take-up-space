class_name ThoughtTrigger
extends Area2D

@export var thought_text: String = "I'm thinking..."
@export var thought_lines: Array[String] = []
@export var display_duration: float = 2.5
@export var trigger_once: bool = true
## Bubble width in screen pixels.
@export var max_width: float = 420.0

## The bubble is drawn on screen, not in the world, so the camera zoom does not
## multiply its font: sizes can sit between the world's 3x pixel steps, it never
## leaves the screen, and no map tile can cover it.
const BUBBLE_LAYER: int = 1
## Where the bottom of the text sits, in world pixels from Alice's origin.
const HEAD_OFFSET := Vector2(0, -22)
const SCREEN_MARGIN: float = 8.0

@onready var label_template: Label = $Label

# Shared by every trigger, so a new thought can cancel the one still running.
static var active_sequence_id: int = 0

func _ready() -> void:
	label_template.hide()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return

	if trigger_once:
		# The Area2D is kept alive, only the monitoring is turned off.
		set_deferred("monitoring", false)

	show_thought(player)

# Coroutine: can be awaited to know when every thought line is over.
func show_thought(player_node: Player) -> void:
	var lines: Array[String] = []
	if thought_lines.is_empty():
		lines.append(thought_text)
	else:
		lines = thought_lines
	await _play_thought_sequence(player_node, lines)

func _play_thought_sequence(player_node: Player, lines: Array[String]) -> void:
	# 1. Take ownership: any sequence still running on Alice is now stale.
	active_sequence_id += 1
	var sequence_id: int = active_sequence_id

	# 2. Remove the thought bubble Alice may already be showing.
	_clear_active_bubble(player_node)

	# Create one bubble and reuse it for every line. It hangs from Alice so it
	# goes away with her, but its CanvasLayer draws it in screen space.
	var bubble := CanvasLayer.new()
	bubble.name = "ThoughtBubble"
	bubble.layer = BUBBLE_LAYER
	player_node.add_child(bubble)

	var new_label: Label = label_template.duplicate() as Label
	bubble.add_child(new_label)

	# 3. Size and word wrapping setup.
	new_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	new_label.custom_minimum_size = Vector2(max_width, 0.0)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Show each line in order using the same bubble.
	for line in lines:
		if line.is_empty():
			continue

		new_label.text = line
		# Force the real size to be recalculated from the number of lines.
		new_label.reset_size()
		_follow_player(new_label, player_node)
		new_label.show()
		new_label.modulate.a = 0.0

		var tween := player_node.create_tween()
		tween.tween_property(new_label, "modulate:a", 1.0, 0.3)
		tween.tween_interval(display_duration)
		tween.tween_property(new_label, "modulate:a", 0.0, 0.4)

		var tree := player_node.get_tree()
		while tween.is_running():
			await tree.process_frame
			# A newer thought took over and already freed this bubble, or Alice
			# left the scene. Leaving now avoids touching a dead instance.
			if sequence_id != active_sequence_id or not is_instance_valid(new_label):
				return
			_follow_player(new_label, player_node)

	bubble.queue_free()

# =========================
# Bubble positioning
# =========================
## Keeps the bubble centered over Alice's head on screen, pushed back inside
## the screen edges when she stands next to them.
func _follow_player(bubble_label: Label, player_node: Player) -> void:
	var anchor: Vector2 = player_node.get_global_transform_with_canvas() * HEAD_OFFSET
	var screen_width: float = bubble_label.get_viewport_rect().size.x
	var x := clampf(anchor.x - bubble_label.size.x / 2.0,
		SCREEN_MARGIN, screen_width - SCREEN_MARGIN - bubble_label.size.x)
	# Measured from the text itself, not the Label box: the box keeps extra room
	# under the text that changes with the line count.
	var lines := bubble_label.get_line_count()
	var text_height := lines * bubble_label.get_line_height() \
		+ (lines - 1) * bubble_label.get_theme_constant("line_spacing")
	# Whole pixels keep the pixel font crisp.
	bubble_label.position = Vector2(x, anchor.y - text_height).round()

# =========================
# Bubble cleanup
# =========================
func _clear_active_bubble(player_node: Player) -> void:
	var bubble := player_node.get_node_or_null("ThoughtBubble")
	if not bubble:
		return

	# Detaching first releases the name, so the next bubble can reuse it
	# instead of being renamed to "ThoughtBubble2" by the engine.
	player_node.remove_child(bubble)
	bubble.queue_free()

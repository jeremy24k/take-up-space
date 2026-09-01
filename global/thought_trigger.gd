class_name ThoughtTrigger
extends Area2D

@export var thought_text: String = "I'm thinking..."
@export var thought_lines: Array[String] = []
@export var display_duration: float = 2.5
@export var trigger_once: bool = true

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

	# Create one bubble and reuse it for every line.
	var new_label: Label = label_template.duplicate() as Label
	new_label.name = "ThoughtBubble"
	
	# Add the copy directly as a child of Alice.
	player_node.add_child(new_label)
	
	# 3. Size and word wrapping setup.
	var max_width: float = 110.0
	new_label.custom_minimum_size = Vector2(max_width, 0.0)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Force the real size to be recalculated from the number of lines.
	new_label.reset_size()
	
	# 4. Dynamic positioning ABOVE the character.
	# Subtracting new_label.size.y keeps the BOTTOM of the text above her head.
	var base_height_above_head: float = 24.0 # Height of the bubble above the character.
	new_label.position = Vector2(-max_width / 2.0, -new_label.size.y - base_height_above_head)
	
	# Show each line in order using the same bubble.
	for line in lines:
		if line.is_empty():
			continue

		new_label.text = line
		new_label.reset_size()
		new_label.position = Vector2(-max_width / 2.0, -new_label.size.y - base_height_above_head)
		new_label.show()
		new_label.modulate.a = 0.0

		var tween := player_node.create_tween()
		tween.tween_property(new_label, "modulate:a", 1.0, 0.3)
		tween.tween_interval(display_duration)
		tween.tween_property(new_label, "modulate:a", 0.0, 0.4)
		await tween.finished

		# A newer thought took over while this line was playing, and it already
		# freed this bubble. Leaving now avoids touching a dead instance.
		if sequence_id != active_sequence_id:
			return

	new_label.queue_free()

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

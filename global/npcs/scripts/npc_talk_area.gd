class_name NpcTalkArea
extends "res://global/interactable_area.gd"

# =========================
# Hint configuration
# =========================
## Where the "..." bubble floats, relative to this area: over the head of the
## NPC it belongs to. It is the InteractionHint child's own position, so it
## is placed by dragging the bubble in the editor (Editable Children on the
## instance). Code can still move it later with set_hint_position().
var hint_position := Vector2.ZERO

@onready var hint: InteractionHint = $InteractionHint

# =========================
# Setup
# =========================
## Use this instead of a plain InteractableArea for every character Alice can
## talk to: the bubble comes with it, so no talking NPC can be left without
## one, and it goes away together with the interaction.
func _ready() -> void:
	super._ready()
	# Inside a character that walks through a y-sorted scene (Wilson, the
	# street pedestrians), the bubble joins that y-sort so walls and trees can
	# hide it together with the character. Static NPCs keep it on top.
	var owner_item := get_parent() as CanvasItem
	if owner_item and owner_item.y_sort_enabled:
		y_sort_enabled = true
	set_hint_position(hint.position)
	# Bubble and "[Espacio]" take turns: the bubble says "you can talk to this
	# one" from afar, the prompt replaces it once Alice is close enough.
	if label:
		label.visibility_changed.connect(func() -> void: hint.set_suppressed(label.visible))

# =========================
# Hint placement
# =========================
## Moves the bubble, e.g. when the owner's sprite changes height (Wilson's
## "MEOW!" frames have text over his head; his idle ones do not).
func set_hint_position(new_position: Vector2) -> void:
	hint_position = new_position
	if y_sort_enabled:
		hint.use_depth_sorting(new_position)
	else:
		hint.set_base_position(new_position)

# =========================
# Interaction action
# =========================
func interact() -> void:
	super.interact()
	# One-time talks (e.g. the worker who brushes Alice off) lose the bubble.
	if not _interaction_enabled:
		hint.retire()

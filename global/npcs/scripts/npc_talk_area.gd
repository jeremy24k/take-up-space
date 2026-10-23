class_name NpcTalkArea
extends "res://global/interactable_area.gd"

# =========================
# Hint configuration
# =========================
## Where the "..." bubble floats, relative to this area: over the head of the
## NPC it belongs to. The area itself is often offset from the NPC (it sits
## where Alice stands to talk), so this is set per instance.
@export var hint_position := Vector2(0, -38)

@onready var hint: InteractionHint = $InteractionHint

# =========================
# Setup
# =========================
## Use this instead of a plain InteractableArea for every character Alice can
## talk to: the bubble comes with it, so no talking NPC can be left without
## one, and it goes away together with the interaction.
func _ready() -> void:
	super._ready()
	hint.set_base_position(hint_position)
	# Bubble and "[Espacio]" take turns: the bubble says "you can talk to this
	# one" from afar, the prompt replaces it once Alice is close enough.
	if label:
		label.visibility_changed.connect(func() -> void: hint.set_suppressed(label.visible))

# =========================
# Interaction action
# =========================
func interact() -> void:
	super.interact()
	# One-time talks (e.g. the worker who brushes Alice off) lose the bubble.
	if not _interaction_enabled:
		hint.retire()

class_name AmbientThought
extends "res://global/remark_interactable.gd"

# =========================
# Background person
# =========================
## Placed on a background person (someone Alice does not talk to). It works
## like any RemarkInteractable (Space shows one line in the cloud, cycling
## through `lines` or picking from `pool`), but nothing floats over the NPC:
## the "..." bubble is a promise that only people with a real conversation
## make. Instead, while Alice stands by them, three small thought bubbles show
## over HER head (ThoughtBox.set_notice): something crosses her mind, and the
## player decides whether to read it.

# =========================
# Setup
# =========================
## The base class still shows and hides its "[Espacio]" label at the right
## moments (Alice in reach, no dialogue on screen); the label is just kept
## invisible and its visibility drives the notice over Alice instead.
func _ready() -> void:
	super._ready()
	if label:
		label.self_modulate.a = 0.0
		label.visibility_changed.connect(_on_prompt_visibility_changed)

func _exit_tree() -> void:
	ThoughtBox.set_notice(self, false)

func _on_prompt_visibility_changed() -> void:
	ThoughtBox.set_notice(self, label.visible)

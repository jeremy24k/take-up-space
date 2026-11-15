class_name RandomStartSound2D
extends AudioStreamPlayer2D

# =========================
# Random start
# =========================
## A positional loop (a fountain, a machine) that starts at a random point
## of its stream, so two of them, or every visit, never sound in sync.
## Leave autoplay off: this plays it.
func _ready() -> void:
	if stream:
		play(randf() * stream.get_length())

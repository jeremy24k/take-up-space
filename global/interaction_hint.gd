class_name InteractionHint
extends Sprite2D

# =========================
# Bob configuration
# =========================
## Pixels the bubble rises at the top of its bob.
@export var bob_height: float = 2.0
## Seconds for one way of the bob (up or down).
@export var bob_time: float = 0.6

var _base_y: float = 0.0

# =========================
# Lifecycle
# =========================
## Floating "..." bubble placed over NPCs Alice can talk to, so they stand out
## from the decorative ones. It hides while any dialogue is on screen.
func _ready() -> void:
	_base_y = position.y
	_start_bob()
	Dialogic.timeline_started.connect(hide)
	Dialogic.timeline_ended.connect(show)

# =========================
# Bob animation
# =========================
func _start_bob() -> void:
	var tween := create_tween().set_loops()
	tween.tween_method(_set_bob, 0.0, bob_height, bob_time).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_bob, bob_height, 0.0, bob_time).set_trans(Tween.TRANS_SINE)

## Snaps to whole pixels so the pixel art never renders half a pixel off.
func _set_bob(amount: float) -> void:
	position.y = _base_y - roundf(amount)

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
## Once retired (the NPC has nothing left to say) the bubble stays hidden,
## even after the next dialogue ends.
var _retired: bool = false
## True while any dialogue is on screen.
var _in_dialogue: bool = false
## True while something else takes its place, e.g. the "[Espacio]" prompt.
var _suppressed: bool = false

# =========================
# Lifecycle
# =========================
## Floating "..." bubble placed over NPCs Alice can talk to, so they stand out
## from the decorative ones. It hides while any dialogue is on screen.
## Usually it comes inside an NpcTalkArea instead of being placed by hand.
func _ready() -> void:
	_base_y = position.y
	_start_bob()
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)

# =========================
# Placement and state
# =========================
## Moves the bubble after _ready without breaking the bob around its base.
func set_base_position(new_position: Vector2) -> void:
	position = new_position
	_base_y = new_position.y

func retire() -> void:
	_retired = true
	_refresh()

## Hides the bubble while something else stands for it (the area's prompt).
func set_suppressed(value: bool) -> void:
	_suppressed = value
	_refresh()

func _on_dialogue_started() -> void:
	# A thought in the cloud does not stop Alice, so the street stays as it is.
	if ThoughtBox.is_showing():
		return
	_in_dialogue = true
	_refresh()

func _on_dialogue_ended() -> void:
	_in_dialogue = false
	_refresh()

func _refresh() -> void:
	visible = not (_retired or _in_dialogue or _suppressed)

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

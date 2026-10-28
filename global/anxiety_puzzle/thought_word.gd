class_name ThoughtWord
extends Button

# =========================
# Float and tremble
# =========================
## Screen pixels the word drifts up and down while it floats.
const BOB_HEIGHT: float = 3.0
## Tremble at full pressure, in screen pixels (1 art pixel = 3 screen pixels).
const MAX_JITTER: int = 3
## Seconds between tremble jumps; every frame would just look like noise.
const JITTER_STEP: float = 0.07

## Where the puzzle placed the word. The bob and the tremble move around it.
var base_position := Vector2.ZERO
## 0 when the puzzle starts, 1 when the time is about to run out.
var pressure: float = 0.0

var _bob_phase: float = 0.0
var _bob_speed: float = 1.0
var _jitter := Vector2.ZERO
var _jitter_timer: float = 0.0

# =========================
# Setup
# =========================
## A loose thought of Alice, not a menu button: no box, just outlined text
## that floats at its own pace and shakes harder as she panics.
func setup(word: String) -> void:
	text = word
	_bob_phase = randf() * TAU
	_bob_speed = randf_range(1.6, 2.6)

# =========================
# Per-frame motion
# =========================
func _process(delta: float) -> void:
	_bob_phase += delta * _bob_speed
	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		_jitter_timer = JITTER_STEP
		_jitter = _random_jitter()
	# The focused word holds still: it is the one Alice is holding on to.
	var tremble := Vector2.ZERO if has_focus() else _jitter
	position = (base_position + Vector2(0, sin(_bob_phase) * BOB_HEIGHT) + tremble).round()

func _random_jitter() -> Vector2:
	var amount := roundi(pressure * MAX_JITTER)
	if amount == 0:
		return Vector2.ZERO
	return Vector2(randi_range(-amount, amount), randi_range(-amount, amount))

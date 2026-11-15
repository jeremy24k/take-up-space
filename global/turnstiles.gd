class_name Turnstiles
extends Node2D

# =========================
# Metro turnstiles
# =========================
## A row of turnstiles where only one lets Alice through. Put it on the node
## whose children are the BoundaryAreas in front of the turnstiles that do
## not work (one per lane, just below the arm): bumping into one, Alice
## thinks a line and is walked back. The first time and every time after
## say different things; the second one sends her looking for the green
## turnstile, which glows and breathes (green_light). Used in both metro
## stations (playtest 2026-11-14: the tester could not tell which one worked).

## The light over the turnstile that works.
@export var green_light: PointLight2D
@export var light_energy := Vector2(0.7, 1.4)
@export var light_period: float = 1.6

const FIRST_LINES: Array[String] = ["Este no funciona..."]
const AGAIN_LINES: Array[String] = ["Este tampoco.", "Tiene que haber uno que funcione."]
## Holding the arrow into a red turnstile bumps it again right after the
## push back: within this many seconds she is pushed back without a new
## thought, so the one on screen is not replaced.
const QUIET_TIME: float = 3.0
const NO_LINES: Array[String] = []

var _bumps: int = 0
var _last_bump_msec: int = -100000

func _ready() -> void:
	for turnstile in get_children():
		if turnstile is BoundaryArea:
			# Runs before the push back reads its lines (signals are immediate).
			turnstile.interacted.connect(_on_bumped.bind(turnstile))
	if green_light:
		_breathe()

func _on_bumped(turnstile: BoundaryArea) -> void:
	var now := Time.get_ticks_msec()
	var quiet := now - _last_bump_msec < QUIET_TIME * 1000.0
	_last_bump_msec = now
	if quiet:
		turnstile.thought_lines = NO_LINES
		return
	turnstile.thought_lines = FIRST_LINES if _bumps == 0 else AGAIN_LINES
	_bumps += 1

func _breathe() -> void:
	var half := light_period / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(green_light, "energy", light_energy.y, half).set_trans(Tween.TRANS_SINE)
	tween.tween_property(green_light, "energy", light_energy.x, half).set_trans(Tween.TRANS_SINE)

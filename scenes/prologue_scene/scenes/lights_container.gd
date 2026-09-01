class_name LightsContainer
extends Node2D

# =========================
# Light configuration
# =========================
@export_group("Light Configuration")
## Drag the scene lights you want to flicker here.
@export var flickering_lights: Array[PointLight2D] = []

@export_group("Flicker Timing")
@export var min_interval: float = 3.0  ## Minimum time between flickers (seconds)
@export var max_interval: float = 8.0  ## Maximum time between flickers (seconds)

@export_group("Intensity")
@export var min_energy: float = 0.1    ## How dim the light gets when flickering
@export var max_energy: float = 1.0    ## Normal light energy

var flicker_enabled: bool = true
var flicker_tween: Tween

# =========================
# Setup
# =========================
func _ready() -> void:
	_schedule_next_flicker()

# =========================
# Flicker scheduling
# =========================
func _schedule_next_flicker() -> void:
	# Schedule the next flicker at a random time.
	var wait_time = randf_range(min_interval, max_interval)
	get_tree().create_timer(wait_time).timeout.connect(_flicker_random_light)

# =========================
# Light selection
# =========================
func _flicker_random_light() -> void:
	# The lights stop reacting once they have been faded out.
	if not flicker_enabled:
		return

	if flickering_lights.is_empty():
		return
		
	# Pick a random light from the array.
	var light = flickering_lights.pick_random()
	if light:
		_do_flicker_animation(light)
		
	# Reschedule for the next flicker.
	_schedule_next_flicker()

# =========================
# Flicker animation
# =========================
func _do_flicker_animation(light: PointLight2D) -> void:
	flicker_tween = create_tween()
	
	# Simulate sparks/dips in quick succession.
	flicker_tween.tween_property(light, "energy", min_energy, 0.05)
	flicker_tween.tween_property(light, "energy", max_energy, 0.07)
	flicker_tween.tween_property(light, "energy", min_energy, 0.04)
	flicker_tween.tween_property(light, "energy", max_energy, 0.1)
	flicker_tween.tween_property(light, "energy", min_energy, 0.05)
	flicker_tween.tween_property(light, "energy", max_energy, 0.07)
	flicker_tween.tween_property(light, "energy", min_energy, 0.04)
	flicker_tween.tween_property(light, "energy", max_energy, 0.1)

# =========================
# Light fade out
# =========================
## Stops the flicker loop and dims every light (used when Alice falls asleep).
func fade_out_lights(duration: float) -> void:
	flicker_enabled = false

	# Kill the flicker in progress so it does not fight the fade.
	if flicker_tween and flicker_tween.is_running():
		flicker_tween.kill()

	var tween := create_tween().set_parallel(true)
	for light in flickering_lights:
		if light:
			tween.tween_property(light, "energy", 0.0, duration)

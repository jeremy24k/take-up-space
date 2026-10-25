extends "res://scenes/prologue_scene/script/basic_door.gd"

# =========================
# Door state configuration
# =========================
## Opens after the goodbye to Wilson. From then on it works as an automatic
## door for Alice only, on both sides: it used to lock for good on the first
## body leaving its area (Wilson included), and if Alice went back in she got
## stuck in the black corridor behind a closed door.
var exits_unlocked: bool = false

# =========================
# Enter/exit handling
# =========================
func _on_area_2d_body_entered(_body: Node2D) -> void:
	if not _body.is_in_group("player"):
		return

	if exits_unlocked:
		super._on_area_2d_body_entered(_body)
		return

	# Having the three items is not enough: she leaves once she has packed
	# them in the backpack (step 4) and rehearsed at the bathroom mirror.
	if GameManager.quest_step >= 4 and GameManager.mirror_practice_done:
		_trigger_exit_sequence()
	else:
		_trigger_missing_items_dialogue()

func _on_area_2d_body_exited(_body: Node2D) -> void:
	# Only Alice moves this door: Wilson must not open it, or close it on her.
	if _body.is_in_group("player"):
		super._on_area_2d_body_exited(_body)

# =========================
# Dialogue triggers
# =========================
func _trigger_missing_items_dialogue() -> void:
	Dialogic.start("apartment/alice_cant_leave_yet")

func _trigger_exit_sequence() -> void:
	Dialogic.start("apartment/wilson_stay_home")

	if not Dialogic.timeline_ended.is_connected(_on_goodbye_finished):
		Dialogic.timeline_ended.connect(_on_goodbye_finished, CONNECT_ONE_SHOT)

# =========================
# Exit sequence callbacks
# =========================
func _on_goodbye_finished() -> void:
	exits_unlocked = true
	# Alice is standing in the doorway: count her, so the door closes behind
	# her when she walks off and opens again if she comes back.
	bodies_inside = 1

	if GameManager.wilson:
		GameManager.wilson.is_following = false

	sprite_door.play("open_door")
	collision_door.set_deferred("disabled", true)

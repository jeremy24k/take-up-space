extends "res://scenes/prologue_scene/script/basic_door.gd"

# =========================
# Door state configuration
# =========================
var exits_unlocked: bool = false
var door_permanently_closed: bool = false

# =========================
# Enter/exit handling
# =========================
func _on_area_2d_body_entered(_body: Node2D) -> void:
	if door_permanently_closed or not _is_player_body(_body):
		return

	if exits_unlocked:
		super._on_area_2d_body_entered(_body)
		return

	if GameManager.has_all_prep_items():
		_trigger_exit_sequence()
	else:
		_trigger_missing_items_dialogue()

func _on_area_2d_body_exited(_body: Node2D) -> void:
	if not _is_player_body(_body):
		return

	if exits_unlocked and not door_permanently_closed:
		_lock_door_permanently()
	else:
		super._on_area_2d_body_exited(_body)

# =========================
# Dialogue triggers
# =========================
func _trigger_missing_items_dialogue() -> void:
	Dialogic.start("alice_cant_leave_yet")

func _trigger_exit_sequence() -> void:
	Dialogic.start("wilson_stay_home")

	if not Dialogic.timeline_ended.is_connected(_on_goodbye_finished):
		Dialogic.timeline_ended.connect(_on_goodbye_finished, CONNECT_ONE_SHOT)

# =========================
# Exit sequence callbacks
# =========================
func _on_goodbye_finished() -> void:
	exits_unlocked = true

	if GameManager.wilson:
		GameManager.wilson.is_following = false

	sprite_door.play("open_door")
	collision_door.set_deferred("disabled", true)

# =========================
# Door locking
# =========================
func _lock_door_permanently() -> void:
	door_permanently_closed = true
	
	sprite_door.play("closed_door")
	collision_door.set_deferred("disabled", false)

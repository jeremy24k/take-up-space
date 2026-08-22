extends StaticBody2D

# =========================
# Door node references
# =========================
@onready var collision_door: CollisionShape2D = $CollisionCenter
# Door animation player.
@onready var sprite_door: AnimatedSprite2D = $DoorAnimatedSprite
# Detection area that tracks player presence.
@onready var detector_area: Area2D = $DetectorArea

# =========================
# Runtime state guards
# =========================
# Track how many bodies are inside to handle multiple characters.
var bodies_inside: int = 0

# =========================
# Setup
# =========================
func _ready() -> void:
	sprite_door.play("closed_door") # Ensure door starts closed.

	# Connect enter/exit events to open and close logic.
	detector_area.body_entered.connect(_on_area_2d_body_entered)
	detector_area.body_exited.connect(_on_area_2d_body_exited)

# =========================
# Enter/exit handling
# =========================
func _on_area_2d_body_entered(_body: Node2D) -> void:
	if not _is_player_body(_body):
		return

	# Increment counter when any CharacterBody2D enters.
	bodies_inside += 1

	# Open door if it was closed (first body enters).
	if bodies_inside == 1:
		sprite_door.play("open_door") 
		collision_door.set_deferred("disabled", true)
		print("Door opened by: ", _body.name)

func _on_area_2d_body_exited(_body: Node2D) -> void:
	if not _is_player_body(_body):
		return

	# Decrement counter when any CharacterBody2D exits.
	bodies_inside -= 1

	# Close door only when the last body leaves.
	if bodies_inside <= 0:
		bodies_inside = 0  # Safety check to prevent negative values.
		sprite_door.play("closed_door") 
		collision_door.set_deferred("disabled", false)
		print("Door closed")

# =========================
# Body filter helper
# =========================
func _is_player_body(body: Node2D) -> bool:
	# Now accepts ANY CharacterBody2D (player, NPCs, enemies, etc.)
	return body is CharacterBody2D

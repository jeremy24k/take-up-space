class_name SpawnPoint
extends Marker2D

# =========================
# Spawn point
# =========================
## A Marker2D under a scene's SpawnPoints where Alice arrives (the previous
## scene names it in an area's spawn_point; the scene reads it with
## GameManager.take_spawn_point() and calls SpawnPoint.arrive()). A plain
## Marker2D works too: she just appears there.

enum Direction { UP, DOWN, LEFT, RIGHT }

## On: Alice starts out of view and walks in by herself to this point, with
## the camera already here; control comes back when she arrives. For
## arrivals that read as coming into the place (from a street, the edge of
## the map), not through a door.
@export var walk_in: bool = false
## The way she walks in (and faces once here). Without walk_in, only the
## way she faces.
@export var direction: Direction = Direction.DOWN

## Puts Alice at `point`: walking in if it is a SpawnPoint with walk_in,
## otherwise just there, facing `default_facing` (or the point's direction).
## Not awaited by the callers: the scene goes on setting itself up.
static func arrive(player: Player, point: Marker2D, default_facing: Vector2 = Vector2.DOWN) -> void:
	var spawn := point as SpawnPoint
	if spawn and spawn.walk_in:
		await player.walk_in_from_off_screen(point.global_position, spawn.direction_vector())
		return
	player.global_position = point.global_position
	player.face_direction(spawn.direction_vector() if spawn else default_facing)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()

func direction_vector() -> Vector2:
	match direction:
		Direction.UP:
			return Vector2.UP
		Direction.LEFT:
			return Vector2.LEFT
		Direction.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

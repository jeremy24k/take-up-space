@tool
class_name CuriosityPoint
extends Marker2D

# =========================
# Something worth a look
# =========================
## A spot that catches a companion's eye (Lía in the plaza): when Alice walks
## within trigger_radius of it for the first time, the scene can send the
## companion over to look at it. The point does nothing by itself; the
## owning scene polls the points and decides (plaza.gd). Its node name is its
## id (the key of its lines in the scene's data). Put the marker where the
## thing is; the companion stops look_distance px short of it, on her side.
@export var trigger_radius: float = 48.0:
	set(value):
		trigger_radius = value
		queue_redraw()
@export var look_distance: float = 16.0:
	set(value):
		look_distance = value
		queue_redraw()

## Editor only: the trigger circle (green) and where the companion stands
## (yellow ring).
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 48, Color(0.3, 1, 0.4, 0.6), 1.0)
	draw_arc(Vector2.ZERO, look_distance, 0.0, TAU, 24, Color(1, 0.85, 0.2, 0.8), 1.0)
	draw_circle(Vector2.ZERO, 2.0, Color(0.3, 1, 0.4, 0.9))

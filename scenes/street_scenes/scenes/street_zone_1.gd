extends Node2D

# =========================
# Pedestrian configuration
# =========================
const PEDESTRIAN_SPEED: float = 28.0
## Seconds a pedestrian waits at each end of its route before turning back.
const PEDESTRIAN_PAUSE: float = 2.5

## Each child of PedestrianRoutes is named after a pedestrian in NPCS and holds
## the Marker2D points that pedestrian walks through, in order, back and forth.
@onready var npcs: Node2D = $MiddleLayer/NPCS
@onready var pedestrian_routes: Node2D = $PedestrianRoutes

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	for route in pedestrian_routes.get_children():
		var pedestrian := npcs.get_node_or_null(NodePath(route.name)) as WalkingNPC
		if pedestrian == null:
			push_warning("PedestrianRoutes/%s has no matching NPC in NPCS" % route.name)
			continue
		var points: Array[Vector2] = []
		for marker in route.get_children():
			if marker is Marker2D:
				points.append(marker.global_position)
		if points.size() < 2:
			continue
		var talk_area := pedestrian.get_node_or_null("InteractableArea")
		if talk_area:
			talk_area.interacted.connect(_on_pedestrian_interacted.bind(pedestrian))
		_patrol(pedestrian, points)

# =========================
# Pedestrian patrol
# =========================
## Walks the route forward, then backwards, forever, pausing at each end.
func _patrol(pedestrian: WalkingNPC, points: Array[Vector2]) -> void:
	pedestrian.global_position = points[0]
	var forward := true
	while is_inside_tree():
		var leg: Array[Vector2] = points.duplicate()
		if not forward:
			leg.reverse()
		leg.remove_at(0)
		await pedestrian.walk_path(leg, PEDESTRIAN_SPEED)
		# Pedestrians only walk sideways; they rest facing the camera.
		pedestrian.face_direction(Vector2.DOWN)
		await get_tree().create_timer(PEDESTRIAN_PAUSE).timeout
		forward = not forward

# =========================
# Talking to a pedestrian
# =========================
## Freezes the pedestrian (and its walk tween, which is bound to it) while the
## dialogue runs, so it does not walk away mid-conversation.
func _on_pedestrian_interacted(pedestrian: WalkingNPC) -> void:
	pedestrian.process_mode = Node.PROCESS_MODE_DISABLED
	Dialogic.timeline_ended.connect(func() -> void:
		pedestrian.process_mode = Node.PROCESS_MODE_INHERIT, CONNECT_ONE_SHOT)

class_name CutsceneNav
extends NavigationRegion2D

# =========================
# Cutscene navigation
# =========================
## Routes for people moved by a cutscene (tweens, no physics: their
## collisions are often off), so they walk round benches, hedges and the
## fountain instead of straight through them. The walkable area is baked
## once, in the background, from every static collision under source_root
## (tile collisions and StaticBody2D) inside `bounds`. Until it is ready,
## route() returns the straight line.

## Area to bake, in global coordinates. Keep it to the walkable map.
@export var bounds: Rect2 = Rect2(0, 0, 1280, 768)
## How far from walls and objects the routes keep (about half a body).
@export var agent_radius: float = 6.0
## Physics layers that block the way.
@export_flags_2d_physics var blocking_layers: int = 1
## Whose collisions count (the scene root by default).
@export var source_root: NodePath = ^".."
## Tile layers whose painted cells routes must keep off, without blocking
## Alice (e.g. the plaza's lawns: people in a cutscene stay on the paving).
@export var avoid_layers: Array[TileMapLayer] = []
## Cells also painted in one of these (paving over the grass) stay walkable.
@export var keep_layers: Array[TileMapLayer] = []

var _ready_to_route := false

func _ready() -> void:
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = agent_radius
	polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	polygon.parsed_collision_mask = blocking_layers
	polygon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	polygon.add_outline(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))
	# The scene's tiles and bodies must be in place before parsing.
	await get_tree().process_frame
	var source := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(polygon, source, get_node(source_root))
	for layer in avoid_layers:
		_add_avoided_cells(layer, source)
	NavigationServer2D.bake_from_source_geometry_data_async(polygon, source, func() -> void:
		_on_baked.call_deferred(polygon))

## Each row of painted cells becomes one obstruction rectangle.
func _add_avoided_cells(layer: TileMapLayer, source: NavigationMeshSourceGeometryData2D) -> void:
	var rows := {}
	for cell in layer.get_used_cells():
		if _kept(layer.to_global(layer.map_to_local(cell))):
			continue
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var half := Vector2(layer.tile_set.tile_size) / 2.0
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		for i in xs.size():
			var last: bool = i == xs.size() - 1
			if last or xs[i + 1] != xs[i] + 1:
				var top_left := layer.to_global(layer.map_to_local(Vector2i(start, y))) - half
				var bottom_right := layer.to_global(layer.map_to_local(Vector2i(xs[i], y))) + half
				source.add_obstruction_outline(PackedVector2Array([
					top_left, Vector2(bottom_right.x, top_left.y),
					bottom_right, Vector2(top_left.x, bottom_right.y)]))
				if not last:
					start = xs[i + 1]

func _kept(point: Vector2) -> bool:
	for layer in keep_layers:
		if layer.get_cell_source_id(layer.local_to_map(layer.to_local(point))) != -1:
			return true
	return false

func _on_baked(polygon: NavigationPolygon) -> void:
	navigation_polygon = polygon
	# The map picks the new region up on the next physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ready_to_route = true

## Points from `from` to `to` going round obstacles, both ends exact. Just
## the two ends when there is no route or the bake isn't done.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not _ready_to_route:
		return PackedVector2Array([from, to])
	var path := NavigationServer2D.map_get_path(get_world_2d().navigation_map, from, to, true)
	if path.size() < 2:
		return PackedVector2Array([from, to])
	path[0] = from
	path[path.size() - 1] = to
	return path

## The nearest walkable point (the point itself until the bake is done), for
## spots worked out from someone's position that may fall on a bench.
func closest(point: Vector2) -> Vector2:
	if not _ready_to_route:
		return point
	return NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map, point)

func is_ready_to_route() -> bool:
	return _ready_to_route

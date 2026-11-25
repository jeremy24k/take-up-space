class_name CutsceneNav
extends Node2D

# =========================
# Cutscene navigation
# =========================
## Routes for people moved by a cutscene (tweens, no physics: their
## collisions are often off), so they walk round benches, hedges and the
## fountain instead of straight through them. The walkable area is baked
## once, in the background, from every static collision under source_root
## (tile collisions and StaticBody2D) inside `bounds`. Until it is ready,
## route() returns the straight line.
## Two meshes, each on its own navigation map (nothing else in the scene
## uses them):
## - free: only collisions block. The default, for short moves (Lía going to
##   a curiosity inside a garden, walking up to Alice).
## - paved: also keeps off the painted cells of avoid_layers (the lawns), for
##   people who arrive or leave like passers-by (route(..., true)).

## Area to bake, in global coordinates. Keep it to the walkable map.
@export var bounds: Rect2 = Rect2(0, 0, 1280, 768)
## How far from walls and objects the routes keep (about half a body).
@export var agent_radius: float = 6.0
## Physics layers that block the way.
@export_flags_2d_physics var blocking_layers: int = 1
## Whose collisions count (the scene root by default).
@export var source_root: NodePath = ^".."
## Tile layers whose painted cells paved routes keep off, without blocking
## Alice (e.g. the plaza's lawns: people arriving or leaving stay on the
## paving).
@export var avoid_layers: Array[TileMapLayer] = []
## Cells also painted in one of these (paving over the grass) stay walkable.
@export var keep_layers: Array[TileMapLayer] = []

var _free_map: RID
var _paved_map: RID
var _regions: Array[RID] = []
var _pending_bakes := 2
var _ready_to_route := false

func _ready() -> void:
	_free_map = _new_map()
	_paved_map = _new_map()
	var free_polygon := _new_polygon()
	var paved_polygon := _new_polygon()
	# The scene's tiles and bodies must be in place before parsing.
	await get_tree().process_frame
	var free_source := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(free_polygon, free_source, get_node(source_root))
	var paved_source := NavigationMeshSourceGeometryData2D.new()
	paved_source.merge(free_source)
	for layer in avoid_layers:
		_add_avoided_cells(layer, paved_source)
	_bake(free_polygon, free_source, _free_map)
	_bake(paved_polygon, paved_source, _paved_map)

func _exit_tree() -> void:
	for region in _regions:
		NavigationServer2D.free_rid(region)
	_regions.clear()
	for map in [_free_map, _paved_map]:
		if map.is_valid():
			NavigationServer2D.free_rid(map)
	_free_map = RID()
	_paved_map = RID()

func _new_map() -> RID:
	var map := NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(map, NavigationPolygon.new().cell_size)
	NavigationServer2D.map_set_active(map, true)
	return map

func _new_polygon() -> NavigationPolygon:
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
	return polygon

func _bake(polygon: NavigationPolygon, source: NavigationMeshSourceGeometryData2D, map: RID) -> void:
	NavigationServer2D.bake_from_source_geometry_data_async(polygon, source, func() -> void:
		_on_baked.call_deferred(polygon, map))

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

## On a cell paved routes keep off (a lawn not covered by paving).
func _avoided(point: Vector2) -> bool:
	for layer in avoid_layers:
		if layer.get_cell_source_id(layer.local_to_map(layer.to_local(point))) != -1:
			return not _kept(point)
	return false

func _on_baked(polygon: NavigationPolygon, map: RID) -> void:
	if not map.is_valid():
		return
	var region := NavigationServer2D.region_create()
	NavigationServer2D.region_set_map(region, map)
	NavigationServer2D.region_set_navigation_polygon(region, polygon)
	_regions.append(region)
	_pending_bakes -= 1
	if _pending_bakes > 0:
		return
	# The maps pick the new regions up on the next physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ready_to_route = true

## Points from `from` to `to` going round obstacles, both ends exact. Just
## the two ends when there is no route or the bake isn't done.
## paved_only keeps off the lawns (avoid_layers); when either end is on a
## lawn itself there is no paved way there, so it takes the free route (a
## paved route would go round the whole garden and step over its fence).
func route(from: Vector2, to: Vector2, paved_only := false) -> PackedVector2Array:
	if not _ready_to_route:
		return PackedVector2Array([from, to])
	var map := _free_map
	if paved_only and not _avoided(from) and not _avoided(to):
		map = _paved_map
	var path := NavigationServer2D.map_get_path(map, from, to, true)
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
	return NavigationServer2D.map_get_closest_point(_free_map, point)

func is_ready_to_route() -> bool:
	return _ready_to_route

class_name CharacterXray
extends Node2D

# =========================
# X-ray silhouette
# =========================
## When something tall hides a character (a building, a wall, a tree, the
## glass tower), its silhouette shows on exactly the hidden part, anywhere in
## the game (Diablo / RTS style). One instance per character: the Player
## creates Alice's (xray_silhouette), and a WalkingNPC with xray_silhouette
## on creates its own (Lía, in her dress colour). Below, "she" is whoever it
## follows. How it tells "hidden" apart:
## - A SubViewport sharing the world (World2D) renders a small area around
##   her, at the camera's zoom and aligned pixel for pixel with the screen,
##   WITHOUT her and without the other characters (canvas_cull_mask skips
##   their visibility layer). Where the screen equals that render, she does
##   not show there: something covers her. Scene tints and lights are the
##   same in both renders, so they cancel out.
## - Characters (NPCs, Lía, Toby, Wilson, pigeons) are left out of that
##   render, so where one stands in front of her the two differ and they
##   never count as covering her.
## - Only tall things count: the silhouette shows only while most of her
##   (MIN_COVERAGE) is hidden. Every pixel samples a 6x8 grid over her
##   drawing and counts the hidden points. Railings, hedges, benches,
##   turnstiles or bins hide her legs and part of the body at most (about
##   half); trees, buildings, walls or the glass tower go well over that.
## - An unlit copy of her layers in another SubViewport gives her shape.
## - The overlay is drawn above the whole world right after a
##   BackBufferCopy and paints only her covered pixels.

const VIEW_SIZE := Vector2i(96, 96)
const OVERLAY_Z: int = 4000
## Alice's lavender; set `color` before setup() for someone else.
const COLOR := Color(0.78, 0.7, 1.0, 0.7)
## Visibility layer (bit index) of Alice, the overlay and the characters:
## the "world without them" render leaves it out.
const HIDDEN_LAYER_BIT: int = 19
## Share of her that must be hidden for the silhouette to show (default;
## `min_coverage` per instance, set before setup()).
const MIN_COVERAGE: float = 0.7
## Standing still (Alice and the camera), the extra render runs only every
## this many frames; moving, every frame (or the silhouette would flicker).
const STILL_UPDATE_EVERY: int = 2

const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Her shape (unlit copy of her layers), 1 texel = 1 world pixel.
uniform sampler2D target_ref : filter_nearest;
// The world around her without her and without characters.
uniform sampler2D world_without : filter_nearest;
// Screen pixel where world_without starts, and its size.
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(288.0);
// Screen pixel of target_ref's top-left corner, and the camera zoom.
uniform vec2 ref_origin = vec2(0.0);
uniform float zoom = 3.0;
// Her drawing's bounds, in target_ref pixels: x from, x to, y from, y to.
uniform vec4 body = vec4(40.0, 56.0, 20.0, 50.0);
// Share of her that has to be hidden for the silhouette to show.
uniform float min_coverage = 0.7;
uniform vec4 silhouette_color : source_color = vec4(0.78, 0.7, 1.0, 0.7);
// Below this colour distance the screen "equals" the world without her.
uniform float same = 0.04;
uniform bool debug_mask = false;

bool hidden_at(vec2 screen_pixel, vec2 pixel_size) {
	vec3 seen = texture(screen_tex, screen_pixel * pixel_size).rgb;
	vec3 without = texture(world_without, (screen_pixel - world_origin) / world_size).rgb;
	return distance(seen, without) <= same;
}

void fragment() {
	if (texture(target_ref, UV).a < 0.5) {
		discard;
	}
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	bool hidden = hidden_at(pixel, SCREEN_PIXEL_SIZE);
	// How much of her is hidden? Only tall things hide most of her.
	vec2 ref_size = vec2(textureSize(target_ref, 0));
	float tested = 0.0;
	float covered = 0.0;
	for (int i = 0; i < 6; i++) {
		for (int j = 0; j < 8; j++) {
			vec2 ref_pixel = vec2(mix(body.x, body.y, (float(i) + 0.5) / 6.0), mix(body.z, body.w, (float(j) + 0.5) / 8.0));
			if (texture(target_ref, ref_pixel / ref_size).a < 0.5) {
				continue;
			}
			tested += 1.0;
			if (hidden_at(ref_origin + ref_pixel * zoom, SCREEN_PIXEL_SIZE)) {
				covered += 1.0;
			}
		}
	}
	bool tall = tested > 0.0 && covered >= tested * min_coverage;
	bool show = hidden && tall;
	if (!show && !debug_mask) {
		discard;
	}
	// Debug: red = silhouette, yellow = hidden by something low, green = seen.
	COLOR = debug_mask ? (show ? vec4(1.0, 0.0, 0.0, 0.8) : (hidden ? vec4(1.0, 0.9, 0.0, 0.7) : vec4(0.0, 1.0, 0.0, 0.6))) : silhouette_color;
}
"""

## Set before setup(): the silhouette's colour and how much of her must be
## hidden for it to show.
var color: Color = COLOR
var min_coverage: float = MIN_COVERAGE
## Off: nothing is drawn or rendered (e.g. during a cutscene where it would
## look odd). The scene that owns the character switches it.
var active: bool = true

var _body: AnimatedSprite2D
var _sources: Array[AnimatedSprite2D] = []
var _copies: Array[AnimatedSprite2D] = []
var _ref_viewport: SubViewport
var _world_viewport: SubViewport
var _overlay: Sprite2D
var _material: ShaderMaterial
var _zoom: float = 3.0
var _bounds_cache: Dictionary = {}
var _last_bounds_key: String = ""
var _last_start := Vector2.INF
var _frames_since_update: int = 0

## target: the character; body: its body sprite; layers: sprites drawn over
## it (Alice's outfit), or none.
func setup(target: Node2D, body: AnimatedSprite2D, layers: Array[AnimatedSprite2D]) -> void:
	_body = body
	_sources = [body]
	_sources.append_array(layers)
	var camera := get_viewport().get_camera_2d()
	if camera:
		_zoom = camera.zoom.x

	_ref_viewport = _make_viewport(VIEW_SIZE)
	for source in _sources:
		var copy := AnimatedSprite2D.new()
		copy.sprite_frames = source.sprite_frames
		copy.centered = source.centered
		copy.offset = source.offset
		copy.position = Vector2(VIEW_SIZE) / 2.0 + (source.position if source != body else Vector2.ZERO)
		_ref_viewport.add_child(copy)
		_copies.append(copy)

	_world_viewport = _make_viewport(Vector2i(Vector2(VIEW_SIZE) * _zoom))
	_world_viewport.world_2d = get_viewport().world_2d
	_world_viewport.transparent_bg = false
	_world_viewport.canvas_cull_mask = 0xFFFFFFFF & ~(1 << HIDDEN_LAYER_BIT)
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var holder := Node2D.new()
	holder.z_index = OVERLAY_Z
	holder.z_as_relative = false
	add_child(holder)
	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	holder.add_child(back_buffer)
	_overlay = Sprite2D.new()
	# A blank texture of the same size: the shader reads her shape from
	# target_ref, so if it ever failed to compile, nothing would be drawn
	# (with her copy as the texture, she showed on top of everything).
	var blank := Image.create_empty(VIEW_SIZE.x, VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	_overlay.texture = ImageTexture.create_from_image(blank)
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("silhouette_color", color)
	_material.set_shader_parameter("target_ref", _ref_viewport.get_texture())
	_material.set_shader_parameter("world_without", _world_viewport.get_texture())
	_material.set_shader_parameter("world_size", Vector2(_world_viewport.size))
	_material.set_shader_parameter("zoom", _zoom)
	_material.set_shader_parameter("min_coverage", min_coverage)
	_overlay.material = _material
	holder.add_child(_overlay)

	_hide_from_world_render(target)
	# Characters already in the scene, and the ones that show up later.
	_hide_characters(get_tree().current_scene)
	get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport

# =========================
# Who is left out of the "world without her" render
# =========================
## Moves a node and everything under it to the hidden visibility layer (the
## screen still draws it: its cull mask takes every layer).
func _hide_from_world_render(node: Node) -> void:
	if node is SubViewport:
		return
	if node is CanvasItem:
		(node as CanvasItem).visibility_layer = 1 << HIDDEN_LAYER_BIT
	for child in node.get_children():
		_hide_from_world_render(child)

func _hide_characters(root: Node) -> void:
	if root == null:
		return
	if _is_character(root):
		_hide_from_world_render(root)
		return
	for child in root.get_children():
		_hide_characters(child)

func _is_character(node: Node) -> bool:
	return (node is CharacterBody2D and not node is Player) or node is PigeonFlock

## New nodes under a character (a pigeon a flock spawns, a new NPC).
func _on_node_added(node: Node) -> void:
	if not node is CanvasItem:
		return
	var current := node
	for depth in 4:
		if current == null:
			return
		if _is_character(current):
			(node as CanvasItem).visibility_layer = 1 << HIDDEN_LAYER_BIT
			return
		current = current.get_parent()

# =========================
# Every frame
# =========================
func _process(_delta: float) -> void:
	if _body == null:
		return
	# Hidden, inactive or switched off: nothing to show, nothing to render.
	var showing := active and _body.is_visible_in_tree()
	_overlay.visible = showing
	if not showing:
		return
	for i in _sources.size():
		var source := _sources[i]
		var copy := _copies[i]
		copy.visible = source.visible and _body.is_visible_in_tree()
		if copy.animation != source.animation:
			copy.animation = source.animation
		copy.frame = source.frame
		copy.flip_h = source.flip_h
	var origin := _body.global_position
	_overlay.global_position = origin
	# The same transform as the screen, shifted by a whole number of pixels so
	# its top-left corner falls on the screen pixel `start`: every texel is
	# exactly one screen pixel (same snapping), looked up by screen position.
	var screen_xform := get_viewport().canvas_transform
	var corner := origin - Vector2(VIEW_SIZE) / 2.0
	var ref_origin := screen_xform * corner
	var start := ref_origin.round()
	_frames_since_update += 1
	if start != _last_start or _frames_since_update >= STILL_UPDATE_EVERY:
		_last_start = start
		_frames_since_update = 0
		_world_viewport.canvas_transform = Transform2D(screen_xform.x, screen_xform.y, screen_xform.origin - start)
		_world_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_material.set_shader_parameter("world_origin", start)
	_material.set_shader_parameter("ref_origin", ref_origin)
	_update_bounds()

## Her drawing's bounds in target_ref pixels, for the coverage grid (cached
## per frame of each animation).
func _update_bounds() -> void:
	var key := "%s/%d/%s" % [_body.animation, _body.frame, _body.flip_h]
	if key == _last_bounds_key:
		return
	_last_bounds_key = key
	if not _bounds_cache.has(key):
		_bounds_cache[key] = _body_bounds()
	_material.set_shader_parameter("body", _bounds_cache[key])

func _body_bounds() -> Vector4:
	var texture := _body.sprite_frames.get_frame_texture(_body.animation, _body.frame)
	if texture == null:
		return Vector4.ZERO
	var image := texture.get_image()
	var used := image.get_used_rect()
	var size := Vector2(image.get_size())
	var top_left := Vector2(VIEW_SIZE) / 2.0 + _body.offset - (size / 2.0 if _body.centered else Vector2.ZERO)
	var x_from := top_left.x + used.position.x
	if _body.flip_h:
		x_from = top_left.x + size.x - used.end.x
	return Vector4(x_from, x_from + used.size.x, top_left.y + used.position.y, top_left.y + used.end.y)

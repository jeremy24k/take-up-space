class_name StripSortedSprite
extends AnimatedSprite2D

# =========================
# Strip sorting
# =========================
## A wide animated object that is round or diagonal at the front (the plaza
## fountain is an octagon): one sort point can't be right at every corner,
## so whoever stood in front of a corner was drawn behind it. At runtime
## the sprite is cut into vertical strips, each its own AnimatedSprite2D
## sorted at its own y, playing in step with this node (which keeps the
## animation but no longer draws itself).
## Set y_sort_enabled on this node so the strips sort with their neighbors.
## Frames must be full frames (no trimmed margins), as AsepriteWizard
## exports them by default. centered must be off.

## Width of each strip in pixels.
@export var strip_width: int = 16
## Per strip, left to right: its sort line, in pixels from the top of the
## frame: the highest point (smallest y) of the object's front edge within
## that strip, so anyone whose feet are in front of the edge is drawn in
## front. Missing entries use the last one.
@export var strip_sort_y: PackedFloat32Array = []

var _strips: Array[AnimatedSprite2D] = []

func _ready() -> void:
	if Engine.is_editor_hint() or sprite_frames == null or strip_sort_y.is_empty():
		return
	var size := sprite_frames.get_frame_texture(animation, 0).get_size()
	var count := ceili(size.x / strip_width)
	for i in count:
		var strip := AnimatedSprite2D.new()
		strip.name = "Strip%d" % i
		strip.centered = false
		strip.sprite_frames = _strip_frames(i * strip_width, size)
		var sort_y := strip_sort_y[mini(i, strip_sort_y.size() - 1)]
		# The strip's origin is its sort point; the art goes back up.
		strip.position = Vector2(i * strip_width, offset.y + sort_y)
		strip.offset = Vector2(0, -sort_y)
		add_child(strip)
		_strips.append(strip)
	self_modulate.a = 0.0
	frame_changed.connect(_sync_strips)
	animation_changed.connect(_sync_strips)
	_sync_strips()

## The same animations, each frame cut to the strip starting at x.
func _strip_frames(x: int, size: Vector2) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in sprite_frames.get_animation_names():
		frames.add_animation(anim)
		frames.set_animation_speed(anim, sprite_frames.get_animation_speed(anim))
		frames.set_animation_loop(anim, sprite_frames.get_animation_loop(anim))
		for f in sprite_frames.get_frame_count(anim):
			var source := sprite_frames.get_frame_texture(anim, f)
			var piece := AtlasTexture.new()
			if source is AtlasTexture:
				if source.margin != Rect2():
					push_warning("StripSortedSprite: trimmed frames are not supported (%s)" % name)
				piece.atlas = source.atlas
				piece.region = Rect2(source.region.position + Vector2(x, 0), Vector2(mini(strip_width, int(size.x) - x), size.y))
			else:
				piece.atlas = source
				piece.region = Rect2(Vector2(x, 0), Vector2(mini(strip_width, int(size.x) - x), size.y))
			frames.add_frame(anim, piece, sprite_frames.get_frame_duration(anim, f))
	return frames

## The strips don't play on their own: they show this node's frame.
func _sync_strips() -> void:
	for strip in _strips:
		strip.animation = animation
		strip.frame = frame

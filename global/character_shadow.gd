@tool
class_name CharacterShadow
extends Sprite2D

# =========================
# Shadow configuration
# =========================
## A flat dark ellipse under a character's feet, in the same colour as the
## street's shadow tiles (black, ~29 % opacity), so characters sit on the
## ground. Put it as a child of the character's sprite (Sprite2D or
## AnimatedSprite2D): it draws right behind that sprite (show_behind_parent),
## so y-sorting never puts it on top, and it places itself at the bottom of
## the sprite's frame, whatever offset that instance uses.
const PERSON_TEXTURE: Texture2D = preload("res://global/character_shadow.aseprite")
const SMALL_TEXTURE: Texture2D = preload("res://global/character_shadow_small.aseprite")

## The smaller ellipse, for cats.
@export var small: bool = false:
	set(value):
		small = value
		texture = SMALL_TEXTURE if small else PERSON_TEXTURE
		_place()

## Empty pixels between the bottom of the frame and the character's feet:
## the ellipse is centred on that line, so it peeks out round the shoes.
@export var feet_margin: int = 2:
	set(value):
		feet_margin = value
		_place()

# =========================
# Setup
# =========================
func _ready() -> void:
	texture = SMALL_TEXTURE if small else PERSON_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	show_behind_parent = true
	# Not centred: an odd size (e.g. the 7 in 14×7) would sit on half pixels and blur.
	centered = false
	_place()

# =========================
# Placement
# =========================
## Centred under the parent sprite, on the line of its feet (the bottom of
## its frame minus feet_margin). The sprite's offset moves its picture but
## not its children, so it is added here.
func _place() -> void:
	if not is_inside_tree():
		return
	var sprite := get_parent() as Node2D
	var frame_height := _frame_height(sprite)
	if frame_height <= 0.0:
		return
	var offset_of_parent: Vector2 = sprite.get("offset")
	var bottom := offset_of_parent.y + frame_height / 2.0
	var size := texture.get_size()
	position = Vector2(offset_of_parent.x, bottom - feet_margin).round()
	offset = -(size / 2.0).floor()

func _frame_height(sprite: Node2D) -> float:
	if sprite is Sprite2D:
		var still := sprite as Sprite2D
		if still.texture == null:
			return 0.0
		if still.region_enabled:
			return still.region_rect.size.y / still.vframes
		return still.texture.get_height() / float(still.vframes)
	if sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation):
			return 0.0
		var frame := animated.sprite_frames.get_frame_texture(animated.animation, 0)
		return frame.get_height() if frame else 0.0
	return 0.0

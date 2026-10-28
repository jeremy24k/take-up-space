class_name ThoughtNotice
extends Node2D

# =========================
# Look configuration
# =========================
## Small thought cloud over Alice's head: "something crosses her mind here".
## Shown by ThoughtBox.set_notice() while she stands by a background person;
## Space turns it into the thought in the cloud. Same family as the NPCs' "..."
## bubble (size, dark outline) but lavender, the colour of the thought cloud,
## and with a trail of bubbles instead of a speech tail: it is hers, not theirs.
## It lives in ThoughtBox's screen-space layer (like the cloud's bubbles) and
## follows Alice every frame: in the world, a scene's CanvasModulate (e.g. the
## street's warm SunFilter) would tint it pink and walls could cover it.
const TEXTURE: Texture2D = preload("res://global/thought_notice.aseprite")
## Up and to the right of her head, so the trail points down at it and the
## icon does not sit on the person she faces. World pixels (camera x3).
const BASE_POSITION := Vector2(10, -24)
## Seconds the notice must stay requested before it shows, so it never
## flickers on for a frame or two (ThoughtBox already keeps it off while a
## thought is being prepared or shown).
const SHOW_DELAY: float = 0.12
const POP_TIME: float = 0.14
const HIDE_TIME: float = 0.15
## Pixels it rises at the top of its bob, and seconds per way.
const BOB_HEIGHT: float = 1.0
const BOB_TIME: float = 0.7

## The node it sits over (Alice). Set by ThoughtBox.
var target: Node2D

var _sprite := Sprite2D.new()
var _show_tween: Tween
var _bob_tween: Tween
var _shown: bool = false

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	_sprite.texture = TEXTURE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = BASE_POSITION
	add_child(_sprite)
	hide()

## Copies Alice's on-screen transform (camera zoom included), so the icon
## keeps its world-pixel size and position while drawn in screen space.
func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(target) or not target.is_inside_tree():
		# Alice left with the scene: the next set_shown(true) starts over.
		_shown = false
		hide()
		return
	transform = target.get_global_transform_with_canvas()

# =========================
# Showing and hiding
# =========================
func set_shown(value: bool) -> void:
	if value == _shown:
		return
	_shown = value
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	if value:
		_appear()
	else:
		_disappear()

## Pops out after SHOW_DELAY, unless it is hidden again first (set_shown
## kills this tween).
func _appear() -> void:
	# Asked again mid fade-out: cut the fade instead of leaving it half-drawn.
	hide()
	_show_tween = create_tween()
	_show_tween.tween_interval(SHOW_DELAY)
	_show_tween.tween_callback(_pop)

func _pop() -> void:
	show()
	_process(0.0)
	modulate.a = 1.0
	_sprite.offset = Vector2.ZERO
	_sprite.scale = Vector2.ZERO
	_show_tween = create_tween()
	_show_tween.tween_property(_sprite, "scale", Vector2.ONE, POP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_start_bob()

func _disappear() -> void:
	if not visible:
		return
	_show_tween = create_tween()
	_show_tween.tween_property(self, "modulate:a", 0.0, HIDE_TIME)
	_show_tween.tween_callback(func() -> void:
		hide()
		if _bob_tween and _bob_tween.is_valid():
			_bob_tween.kill())

## Bobs through `offset`, snapped to whole pixels like the NPCs' bubble.
func _start_bob() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_method(_set_bob, 0.0, BOB_HEIGHT, BOB_TIME).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_method(_set_bob, BOB_HEIGHT, 0.0, BOB_TIME).set_trans(Tween.TRANS_SINE)

func _set_bob(amount: float) -> void:
	_sprite.offset.y = -roundf(amount)

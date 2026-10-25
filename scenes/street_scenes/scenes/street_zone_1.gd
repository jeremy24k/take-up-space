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
@onready var interactables: Node2D = $InteractableDetectors
@onready var cat_talk_area: InteractableArea = $MiddleLayer/NPCS/StreetCat/InteractableArea
@onready var player: Player = $MiddleLayer/Player
@onready var camera: Camera2D = $MiddleLayer/Player/Camera2D
@onready var tower_sighting: VisibleOnScreenNotifier2D = $GlassTowerSighting
@onready var shop: Node2D = $InteractableDetectors/Shop

var _cat_met: bool = false

# =========================
# Arrival configuration
# =========================
## The scene opens with Alice saying what she needs, in the dialogue box (it
## is the goal of the whole street, so it must not get lost while walking).
## Played once, after the fade-in.
const ARRIVAL_TIMELINE := "street_arrival"
const ARRIVAL_DELAY: float = 1.0

# =========================
# Glass tower configuration
# =========================
## The first time the tower comes on screen, the camera glides to it for a
## moment and Alice notices it. When the phone girl later says "la torre de
## cristal", the player already knows which building she means.
const TOWER_LINE := "Qué edificio más raro... todo de cristal."
const TOWER_PAN_TIME: float = 0.9
const TOWER_HOLD_TIME: float = 1.4
const TOWER_RETURN_TIME: float = 0.7

# =========================
# Lost reminder configuration
# =========================
## If Alice wanders this long without finding a new clue or getting near the
## shop, she reminds the player that people and signs can help. Never more
## than LOST_REMINDER_MAX times, and the clock restarts with every clue.
const LOST_REMINDER_AFTER: float = 150.0
const LOST_REMINDER_MAX: int = 2
const SHOP_NEAR_DISTANCE: float = 220.0
const LOST_LINES: Array[String] = [
	"Quizá alguien por aquí sepa dónde hay un minimercado...",
	"Podría fijarme mejor en los carteles. O en lo que dice la gente.",
]
## Once she overheard the phone girl, the reminder points at the tower.
const LOST_TOWER_LINE := "Un minimercado junto a la torre de cristal... Quizá al otro lado de la avenida."
const TOWER_CLUE := "overheard_store"

var _lost_time: float = 0.0
var _lost_reminders_shown: int = 0

# =========================
# Clue configuration
# =========================
## InteractableDetectors child -> clue id saved in GameManager when Alice looks at it.
const CLUE_AREAS := {
	"BusStopMap": "bus_stop_map",
	"BusStopGrandma": "grandma_cans",
	"PhoneGirl": "overheard_store",
	"Delivery": "delivery_box",
	"AdColumn": "store_flyer",
}
## InteractableDetectors child -> [clues that unlock it, timeline to play instead].
## Lets a place react to what Alice already learned (e.g. the shop window
## recognises the fruit poster once she has seen it on the delivery box).
const CLUE_REACTIONS := {
	"Shop": [["delivery_box", "store_flyer"], "street_shop_found"],
	"GlassTower": [["overheard_store", "bus_stop_map"], "street_glass_tower_clue"],
}

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	_connect_clues()
	_start_pedestrians()
	cat_talk_area.interacted.connect(_on_cat_interacted.bind(cat_talk_area))
	GameManager.clue_added.connect(func(_clue_id: String) -> void: _lost_time = 0.0)
	if not GameManager.glass_tower_seen:
		tower_sighting.screen_entered.connect(_on_tower_on_screen, CONNECT_ONE_SHOT)
	if not GameManager.street_arrival_seen:
		_play_arrival()

func _process(delta: float) -> void:
	_tick_lost_reminder(delta)

# =========================
# Arrival
# =========================
func _play_arrival() -> void:
	GameManager.street_arrival_seen = true
	player.lock_control()
	await get_tree().create_timer(ARRIVAL_DELAY).timeout
	# Dialogic stops her for the dialogue on its own; the lock was only for
	# the fade-in.
	player.unlock_control()
	Dialogic.start(ARRIVAL_TIMELINE)

# =========================
# First look at the glass tower
# =========================
func _on_tower_on_screen() -> void:
	if GameManager.glass_tower_seen:
		return
	GameManager.glass_tower_seen = true
	# A conversation on screen comes first; the tower waits for it.
	while Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		await Dialogic.timeline_ended
	player.lock_control()

	var to_tower := tower_sighting.global_position - camera.get_screen_center_position()
	var pan := create_tween()
	pan.tween_property(camera, "offset", to_tower, TOWER_PAN_TIME) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var tower_lines: Array[String] = [TOWER_LINE]
	ThoughtBox.say(tower_lines)
	await pan.finished
	await get_tree().create_timer(TOWER_HOLD_TIME).timeout

	var back := create_tween()
	back.tween_property(camera, "offset", Vector2.ZERO, TOWER_RETURN_TIME) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await back.finished
	player.unlock_control()

# =========================
# Lost reminder
# =========================
func _tick_lost_reminder(delta: float) -> void:
	if _lost_reminders_shown >= LOST_REMINDER_MAX or GameManager.leo_greeted:
		return
	# Only time spent actually walking around counts.
	if Dialogic.current_timeline != null or player.is_control_locked:
		return
	if player.global_position.distance_to(shop.global_position) < SHOP_NEAR_DISTANCE:
		_lost_time = 0.0
		return
	_lost_time += delta
	if _lost_time < LOST_REMINDER_AFTER:
		return
	_lost_time = 0.0
	var line := LOST_LINES[mini(_lost_reminders_shown, LOST_LINES.size() - 1)]
	if GameManager.found_clues.has(TOWER_CLUE):
		line = LOST_TOWER_LINE
	_lost_reminders_shown += 1
	var reminder: Array[String] = [line]
	ThoughtBox.say(reminder)

# =========================
# Clues about Leo's store
# =========================
func _connect_clues() -> void:
	for area_name in CLUE_AREAS:
		var area := interactables.get_node_or_null(NodePath(area_name))
		if area == null:
			push_warning("InteractableDetectors/%s not found for its clue" % area_name)
			continue
		area.interacted.connect(GameManager.add_clue.bind(CLUE_AREAS[area_name]))
	# interacted fires right before the area starts its timeline, so a place
	# can still switch to its "I know this" version here.
	for area_name in CLUE_REACTIONS:
		var area := interactables.get_node_or_null(NodePath(area_name))
		if area == null:
			push_warning("InteractableDetectors/%s not found for its clue reaction" % area_name)
			continue
		var required: Array[String] = []
		required.assign(CLUE_REACTIONS[area_name][0])
		var timeline: String = CLUE_REACTIONS[area_name][1]
		area.interacted.connect(func() -> void:
			if GameManager.has_any_clue(required):
				area.timeline_name = timeline)

# =========================
# Pedestrian setup
# =========================
func _start_pedestrians() -> void:
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
## dialogue runs, so it does not walk away mid-conversation. Pedestrians with
## stops_when_talked_to off keep walking, as if they never noticed Alice.
func _on_pedestrian_interacted(pedestrian: WalkingNPC) -> void:
	if not pedestrian.stops_when_talked_to:
		return
	# The sprite keeps running while its NPC is frozen, so it can play a
	# talk animation (the cat meows) and then go back to what it was doing.
	var sprite: AnimatedSprite2D = pedestrian.sprite
	var previous_animation := sprite.animation
	var talks := sprite.sprite_frames.has_animation(pedestrian.talk_animation)
	if talks:
		sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		sprite.play(pedestrian.talk_animation)
	pedestrian.process_mode = Node.PROCESS_MODE_DISABLED
	Dialogic.timeline_ended.connect(func() -> void:
		pedestrian.process_mode = Node.PROCESS_MODE_INHERIT
		if talks:
			sprite.process_mode = Node.PROCESS_MODE_INHERIT
			sprite.play(previous_animation), CONNECT_ONE_SHOT)

# =========================
# Street cat
# =========================
## The first time Alice stops for the cat it reminds her of Wilson; after
## that it only gets a short line.
func _on_cat_interacted(talk_area: InteractableArea) -> void:
	if _cat_met:
		talk_area.timeline_name = "street_cat_again"
	_cat_met = true

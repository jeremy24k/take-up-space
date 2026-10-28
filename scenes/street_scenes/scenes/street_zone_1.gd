extends Node2D

# =========================
# Pedestrian configuration
# =========================
## Per-pedestrian meta while Alice holds it with Space: how many lines are
## still up, and the [animation, flip_h] to walk on with.
const TALK_HOLDS_META := &"talk_holds"
const TALK_RESUME_META := &"talk_resume"

## Every WalkingNPC in NPCS with patrol points set in its inspector (the
## markers live in the PedestrianRoutes folder) walks them back and forth.
@onready var npcs: Node2D = $MiddleLayer/NPCS
@onready var interactables: Node2D = $InteractableDetectors
@onready var cat_talk_area: InteractableArea = $MiddleLayer/NPCS/StreetCat/InteractableArea
@onready var player: Player = $MiddleLayer/Player
@onready var tower_sighting: VisibleOnScreenNotifier2D = $GlassTowerSighting
@onready var shop: Node2D = $InteractableDetectors/Shop

var _cat_met: bool = false

# =========================
# Arguing couple configuration
# =========================
## A couple argues at the foot of the zebra crossing by the café and blocks
## it (CoupleBlocker). Asking them to let her through is an anxiety puzzle;
## backing off is fine too: the crossing to the right goes the same way.
## Where each of them steps to (from where they stand) once she asks.
const COUPLE_SIDE_STEP := {
	# Back and to the left, below the STOP sign: straight left he stood
	# behind its post.
	"CoupleGuyNPC": Vector2(-17, 24),
	"CoupleGirlNPC": Vector2(24, 3),
}
const COUPLE_STEP_TIME: float = 0.5
## "Rompecabezas de la Ansiedad" played from the timelines with
## [signal arg="anxiety_puzzle:<id>"].
const ANXIETY_PUZZLES := {
	"street_couple": preload("res://scenes/street_scenes/puzzles/street_couple.tres"),
	"street_car": preload("res://scenes/street_scenes/puzzles/street_car.tres"),
}

@onready var couple_blocker: CollisionShape2D = $CoupleBlocker/CollisionShape2D
@onready var couple_talk_area: NpcTalkArea = $InteractableDetectors/StreetCouple
## "#!" and "!!" taking turns over their heads, so the fight shows from afar.
@onready var couple_argue_fx: AnimatedSprite2D = $InteractableDetectors/StreetCouple/ArgueFx

# =========================
# Dusty car configuration
# =========================
## A black car parked by the bus stop. Alice, who never looks at herself in
## public, fixes her hair in its dark window; the owner appears out of nowhere
## and "catches" her (anxiety puzzle). She laughs with her, not at her, and
## drives off.
const CAR_OWNER_FADE_TIME: float = 0.3
## Where the owner shows up, from the car sprite's origin (its bottom centre):
## by the driver's door, on the pavement. Relative, so moving the car in the
## editor brings the owner along.
const CAR_OWNER_OFFSET := Vector2(56, -39)
## The car pulls away to the right, along its lane, until it is off screen.
const CAR_DRIVE_DISTANCE: float = 760.0
const CAR_DRIVE_TIME: float = 3.0

@onready var parked_car: Node2D = $MiddleLayer/ParkedCar
@onready var parked_car_body: Sprite2D = $MiddleLayer/ParkedCar/Body
@onready var car_owner: Node2D = $MiddleLayer/NPCS/CarOwnerNPC
@onready var car_area: InteractableArea = $InteractableDetectors/ParkedCar

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
	"Si le preguntara a alguien, ya habría llegado. ...No.",
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
	"PetsShopDoor": "pets_note",
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
	Dialogic.signal_event.connect(_on_dialogic_signal)
	if GameManager.street_couple_cleared:
		_clear_couple(false)
	car_owner.process_mode = Node.PROCESS_MODE_DISABLED
	if GameManager.street_car_gone:
		_remove_car()

func _process(delta: float) -> void:
	_tick_lost_reminder(delta)

func _on_dialogic_signal(argument: Variant) -> void:
	if not argument is String:
		return
	if argument == "couple_step_aside":
		GameManager.street_couple_cleared = true
		_clear_couple(true)
	elif argument == "car_owner_appears":
		_show_car_owner()
	elif argument == "car_drives_away":
		GameManager.street_car_gone = true
		_drive_car_away()
	elif argument.begins_with("anxiety_puzzle:"):
		var data: AnxietyPuzzleData = ANXIETY_PUZZLES.get(argument.get_slice(":", 1))
		if data == null:
			push_warning("Unknown anxiety puzzle '%s'" % argument)
			return
		AnxietyPuzzle.play_from_dialogic(self, data)

# =========================
# Dusty car
# =========================
## "Out of nowhere": she fades in by the driver's door while Alice is busy.
func _show_car_owner() -> void:
	car_owner.process_mode = Node.PROCESS_MODE_INHERIT
	car_owner.global_position = (parked_car_body.global_position + CAR_OWNER_OFFSET).round()
	car_owner.modulate.a = 0.0
	car_owner.show()
	create_tween().tween_property(car_owner, "modulate:a", 1.0, CAR_OWNER_FADE_TIME)

## She gets in (fades out) and the car pulls away.
func _drive_car_away() -> void:
	var owner_out := create_tween()
	owner_out.tween_property(car_owner, "modulate:a", 0.0, CAR_OWNER_FADE_TIME)
	await owner_out.finished
	car_owner.hide()
	var drive := create_tween()
	drive.tween_property(parked_car, "position:x", parked_car.position.x + CAR_DRIVE_DISTANCE, CAR_DRIVE_TIME) 		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await drive.finished
	_remove_car()

## Gone for good, also when Alice comes back to the street later.
func _remove_car() -> void:
	parked_car.hide()
	car_owner.hide()
	car_area.set_deferred("monitoring", false)
	car_area.set_deferred("monitorable", false)
	if car_area.label:
		car_area.label.hide()

# =========================
# Arguing couple
# =========================
## They step to the sides and the crossing is free. Without animation when
## Alice comes back to the street after they already moved.
func _clear_couple(animated: bool) -> void:
	couple_blocker.set_deferred("disabled", true)
	couple_talk_area.set_deferred("monitoring", false)
	couple_talk_area.set_deferred("monitorable", false)
	if couple_talk_area.label:
		couple_talk_area.label.hide()
	couple_talk_area.hint.retire()
	couple_argue_fx.hide()
	for npc_name in COUPLE_SIDE_STEP:
		var npc := npcs.get_node(NodePath(npc_name)) as Node2D
		var target: Vector2 = npc.position + COUPLE_SIDE_STEP[npc_name]
		if animated:
			create_tween().tween_property(npc, "position", target, COUPLE_STEP_TIME) 				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		else:
			npc.position = target

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

	var tower_lines: Array[String] = [TOWER_LINE]
	ThoughtBox.say(tower_lines)
	await player.pan_camera_to(tower_sighting.global_position, TOWER_PAN_TIME)
	await get_tree().create_timer(TOWER_HOLD_TIME).timeout
	await player.reset_camera(TOWER_RETURN_TIME)
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
	for child in npcs.get_children():
		var pedestrian := child as WalkingNPC
		if pedestrian == null or pedestrian.patrol_points.size() < 2:
			continue
		# A conversation (the cat) or a background person's thought.
		var talk_area := pedestrian.get_node_or_null("InteractableArea")
		if talk_area == null:
			talk_area = pedestrian.get_node_or_null("AmbientThought")
		if talk_area:
			talk_area.interacted.connect(_on_pedestrian_interacted.bind(pedestrian, talk_area))
		pedestrian.start_patrol()

# =========================
# Talking to a pedestrian
# =========================
## Freezes the pedestrian (and its walk tween, which is bound to it) while the
## dialogue or thought runs, so it does not walk away mid-line, turned to
## Alice. Walking past her is not enough: they only stop when she reaches out
## (Space). Pedestrians with stops_when_talked_to off keep walking, as if they
## never noticed her.
func _on_pedestrian_interacted(pedestrian: WalkingNPC, talk_area: Area2D) -> void:
	if not pedestrian.stops_when_talked_to:
		return
	# Space again while it is already stopped (the next line) only extends
	# the stop: it walks on when the last line is over, with the walk it had.
	var holds: int = pedestrian.get_meta(TALK_HOLDS_META, 0)
	pedestrian.set_meta(TALK_HOLDS_META, holds + 1)
	var sprite: AnimatedSprite2D = pedestrian.sprite
	var talks := sprite.sprite_frames.has_animation(pedestrian.talk_animation)
	if holds == 0:
		pedestrian.set_meta(TALK_RESUME_META, [sprite.animation, sprite.flip_h])
		# The sprite keeps running while its NPC is frozen, so it can play a
		# talk animation (the cat meows) and then go back to what it was doing.
		if talks:
			sprite.process_mode = Node.PROCESS_MODE_ALWAYS
			sprite.play(pedestrian.talk_animation)
		else:
			pedestrian.face_direction(pedestrian.global_position.direction_to(player.global_position))
		pedestrian.process_mode = Node.PROCESS_MODE_DISABLED
	# A thought waits for its own end: the one it replaces ending (e.g. a floor
	# thought cut off by this Space) must not send the pedestrian on its way.
	var done: Signal = talk_area.remark_finished if talk_area.has_signal("remark_finished") else Dialogic.timeline_ended
	done.connect(func() -> void:
		var left: int = pedestrian.get_meta(TALK_HOLDS_META, 1) - 1
		pedestrian.set_meta(TALK_HOLDS_META, left)
		if left > 0:
			return
		var resume: Array = pedestrian.get_meta(TALK_RESUME_META)
		pedestrian.process_mode = Node.PROCESS_MODE_INHERIT
		if talks:
			sprite.process_mode = Node.PROCESS_MODE_INHERIT
		sprite.flip_h = resume[1]
		sprite.play(resume[0]), CONNECT_ONE_SHOT)

# =========================
# Street cat
# =========================
## The first time Alice stops for the cat it reminds her of Wilson; after
## that it only gets a short line.
func _on_cat_interacted(talk_area: InteractableArea) -> void:
	if _cat_met:
		talk_area.timeline_name = "street_cat_again"
	_cat_met = true

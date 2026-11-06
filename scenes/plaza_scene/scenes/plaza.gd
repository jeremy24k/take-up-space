extends Node2D

# =========================
# Plaza (midgame)
# =========================
## Alice reaches the plaza at dusk, after Leo's store, to take the metro
## home. Lía is crying alone on a bench across the plaza (Twine: "Escena
## Lia"). Alice can go to her, or walk off to the metro (Lía runs after her).
## With Lía holding her sleeve they ask the ice-cream man, then the woman
## with the dog, and end up waiting at the fountain until the mother comes.
## By then the last train is gone: Alice walks to the station knowing it and
## finds the gate down. Then night, and Clara (still to come; for now the
## night interlude leads to demo_end).
## The step she is at lives in GameManager.plaza_stage, so the scene can be
## reloaded at any point of the sequence.

## "Rompecabezas de la Ansiedad" played from the timelines with
## [signal arg="anxiety_puzzle:<id>"].
const ANXIETY_PUZZLES := {
	"plaza_lia": preload("res://scenes/plaza_scene/puzzles/plaza_lia.tres"),
}
## Until Clara's part exists, the night ends the demo here.
const DEMO_END_SCENE := "res://scenes/demo_end/demo_end.tscn"

# =========================
# Alice's pace
# =========================
## How many of the three helpers (ice-cream man, woman with the dog, guy
## with headphones) must give a clue before Alice knows to go to the fountain.
## They can be asked in any order, or skipped.
const LIA_CLUES_NEEDED: int = 2

## Lía holds her sleeve: Alice walks a little slower. Once Lía is gone she
## knows the train has left, and walks to the station with her shoulders down.
const SLEEVE_SPEED_SCALE: float = 0.75
const DEFEATED_SPEED_SCALE: float = 0.8

# =========================
# Lía
# =========================
## Lía stays this far behind Alice, on the side she comes from, and a little
## to one side so Alice's sprite does not cover her.
const LIA_FOLLOW_GAP: float = 24.0
const LIA_SIDE_OFFSET: float = 8.0
## How tightly she closes the gap (like WalkingNPC.follow). A fixed speed
## faster than Alice made her catch up and stop every other frame, and that
## stop-and-go stutter made her look blurry.
const LIA_FOLLOW_STIFFNESS: float = 8.0
## If Alice walks off to the metro, Lía runs after her this fast.
const LIA_CHASE_SPEED: float = 260.0
## Before Alice talks to her she cries for her mother now and then, if Alice
## is near enough to hear it.
const LIA_CRY_LINES: Array[String] = ["¡Mamá...!", "(snif) ¿Mamá?", "¡MAMÁ!"]
const LIA_CRY_EVERY: float = 4.0
const LIA_CRY_HEARING: float = 360.0
## While they look for her mother she asks whatever comes into her head, one
## question every few seconds, never the same twice in a row.
const LIA_QUESTIONS: Array[String] = [
	"¿Por qué llevas auriculares si no escuchas nada?",
	"¿Vives sola?",
	"Tu pelo parece un nido. Me gusta.",
	"¿Wilson es naranja? Yo quiero un perro.",
	"¿Tienes miedo? Yo un poquito.",
	"¿Por qué caminas mirando el suelo?",
	"Mi mamá tiene un vestido rosa. ¿Ya te lo dije?",
	"¿Tú tienes mamá? ¿Dónde está?",
]
const LIA_QUESTION_EVERY := Vector2(11.0, 18.0)

# =========================
# Thoughts and lines
# =========================
const ARRIVAL_LINES: Array[String] = [
	"Llegué. Solo falta bajar al metro y...",
	"...¿Alguien está llorando?",
]
const SUBWAY_WITH_LIA_LINES: Array[String] = [
	"El tren todavía no ha pasado.",
	"Primero, su mamá.",
]
## Once Lía holds her sleeve, and after each clue: where to look next.
const SEARCH_START_LINES: Array[String] = ["Alguien en la plaza tiene que haberla visto."]
const ONE_CLUE_LINES: Array[String] = ["Mejor preguntarle a alguien más, por si acaso."]
const ENOUGH_CLUES_LINES: Array[String] = ["La fuente. Vamos a la fuente."]
## Twine: Transicion_Clara.
const NIGHT_LINES: PackedStringArray = [
	"Alice da la vuelta a la estación cerrada. La noche empieza a caer.",
	"Las calles se ven diferentes sin la luz del sol. O tal vez es ella, que las mira con otros ojos.",
	"Tiene el número de Leo en el bolsillo. Tiene el dibujo de Lía en la mochila.",
	"Tiene hambre. Tiene frío. No sabe dónde va a dormir.",
	"Pero algo en su pecho no es miedo. No del todo.",
	"Camina sin rumbo, buscando algún lugar con luz. Y entonces, escucha una voz.",
	"No llora. Canta.",
]

# =========================
# Sky
# =========================
const SKY_ARRIVAL := Color(1, 0.82, 0.74, 1)
## After waiting with Lía at the fountain.
const SKY_LATE := Color(0.94, 0.64, 0.6, 1)
const SKY_NIGHT := Color(0.42, 0.46, 0.7, 1)
const NIGHT_FALL_TIME: float = 3.0
const TIME_SKIP_FADE: float = 0.8
const MOTHER_WALK_TIME: float = 1.8
## At the fountain Lía stands beside Alice, and her mother stops beside Lía.
const LIA_BESIDE_ALICE := Vector2(22, -2)
const MOTHER_BESIDE_LIA := Vector2(16, 0)
const LEAVING_WALK_TIME: float = 3.0
## Toby keeps to this side of his owner, a little lower (closer to the
## camera): behind her one way, ahead of her on the way back.
const TOBY_LEASH_OFFSET := Vector2(16, 5)
## Played while Lía waits alone, crying for her mother, once it is drawn in
## lia.aseprite. Until then she stands facing the camera.
const LIA_CRY_ANIMATION := "cry"

@onready var player: Player = $MiddleLayer/Player
@onready var lia: WalkingNPC = $MiddleLayer/NPCS/Lia
@onready var lia_talk: InteractableArea = $MiddleLayer/NPCS/Lia/TalkArea
@onready var lia_bark: SpeechBark = $MiddleLayer/NPCS/Lia/Bark
@onready var lia_mom: CharacterBody2D = $MiddleLayer/NPCS/LiaMom
@onready var sun_filter: CanvasModulate = $LightsContainer/SunFilter
@onready var fountain_area: Area2D = $StoryAreas/FountainArea
@onready var subway_area: Area2D = $StoryAreas/SubwayArea
## Who helps look for the mother: talk area -> clue id. Each one has a clue
## timeline (while Alice is with Lía and has not asked them yet) and an idle
## one ("<timeline>_idle") for every other time.
@onready var helpers := {
	$MiddleLayer/NPCS/IceCreamMan/TalkArea: "ice_cream",
	$MiddleLayer/NPCS/DogLady/TalkArea: "dog_lady",
	$MiddleLayer/NPCS/Teen/TalkArea: "teen",
}
const HELPER_TIMELINES := {
	"ice_cream": "plaza_ice_cream",
	"dog_lady": "plaza_dog_lady",
	"teen": "plaza_teen",
}
## The woman with the dog jogs along the top sidewalk (JoggingRoute) with
## Toby beside her, resting 12-15 s at each end; she stops when Alice comes
## close.
@onready var dog_lady: WalkingNPC = $MiddleLayer/NPCS/DogLady
@onready var toby: WalkingNPC = $MiddleLayer/NPCS/Toby
## Background people (AmbientThought only). The daytime crowd (reader,
## grandma, guitarist, couple, girl at the picnic) goes home when the
## afternoon is over; the two strollers keep walking their routes.
@onready var daytime_crowd: Node2D = $MiddleLayer/NPCS/DaytimeCrowd
@onready var strollers: Array[WalkingNPC] = [
	$MiddleLayer/NPCS/StrollerSidewalk,
	$MiddleLayer/NPCS/StrollerWalkway,
]
@onready var mother_start: Marker2D = $StoryPoints/MotherStart
@onready var family_exit: Marker2D = $StoryPoints/FamilyExit

var _lia_following: bool = false
var _lia_still_time: float = 0.0
## Alice's position last frame, to tell whether she is walking.
var _alice_last_position := Vector2.ZERO
## Seconds Lía stands still behind Alice before she stops walking.
const LIA_STOP_DELAY: float = 0.15
var _cry_timer: float = 0.0
var _question_timer: float = 0.0
var _questions_left: Array[String] = []
var _in_cutscene: bool = false
var _subway_thought_shown: bool = false

# =========================
# Setup
# =========================
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_refresh_helpers)
	fountain_area.body_entered.connect(_on_fountain_entered)
	subway_area.body_entered.connect(_on_subway_entered)
	subway_area.body_exited.connect(func(body: Node2D) -> void:
		if body == player:
			_subway_thought_shown = false)
	_question_timer = randf_range(LIA_QUESTION_EVERY.x, LIA_QUESTION_EVERY.y)
	_restore_stage()
	_refresh_helpers()
	_lia_waits_crying()
	dog_lady.start_patrol()
	for stroller in strollers:
		stroller.start_patrol()
	toby.global_position = dog_lady.global_position + TOBY_LEASH_OFFSET
	toby.follow(dog_lady, TOBY_LEASH_OFFSET)

## Puts every character where the current story step needs them.
func _restore_stage() -> void:
	_set_npc_active(lia_mom, false)
	match GameManager.plaza_stage:
		GameManager.PlazaStage.ARRIVED:
			sun_filter.color = SKY_ARRIVAL
			_greet_the_plaza()
		GameManager.PlazaStage.WITH_LIA, GameManager.PlazaStage.KNOWS_FOUNTAIN:
			sun_filter.color = SKY_ARRIVAL
			lia.global_position = player.global_position + Vector2(-LIA_FOLLOW_GAP, 0)
			_start_lia_following()
		GameManager.PlazaStage.LIA_HOME:
			sun_filter.color = SKY_LATE
			_send_crowd_home()
			_set_npc_active(lia, false)
			player.speed_scale = DEFEATED_SPEED_SCALE
		GameManager.PlazaStage.MISSED_TRAIN:
			sun_filter.color = SKY_NIGHT
			_send_crowd_home()
			_set_npc_active(lia, false)

func _greet_the_plaza() -> void:
	await get_tree().create_timer(1.2).timeout
	ThoughtBox.say(ARRIVAL_LINES)

# =========================
# Every frame
# =========================
func _physics_process(delta: float) -> void:
	if GameManager.plaza_stage == GameManager.PlazaStage.ARRIVED and not _in_cutscene:
		_cry_for_mother(delta)
	if _lia_following:
		_follow_alice(delta)
		_ask_something(delta)

func _cry_for_mother(delta: float) -> void:
	_cry_timer -= delta
	if _cry_timer > 0.0 or Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		return
	_cry_timer = LIA_CRY_EVERY
	if lia.global_position.distance_to(player.global_position) <= LIA_CRY_HEARING:
		lia_bark.say(LIA_CRY_LINES.pick_random(), 2.0)

## Lía trails a step behind Alice, on the side she is walking away from.
func _follow_alice(delta: float) -> void:
	var facing := player.last_direction.normalized()
	var behind := -facing * LIA_FOLLOW_GAP + facing.orthogonal() * LIA_SIDE_OFFSET
	var to_target := player.global_position + behind - lia.global_position
	var alice_motion := player.global_position - _alice_last_position
	_alice_last_position = player.global_position
	if to_target.length() < 2.0 and alice_motion.length() <= 0.05:
		# Caught up and Alice stands still: stop walking after a short moment.
		_lia_still_time += delta
		if _lia_still_time >= LIA_STOP_DELAY:
			lia.face_direction(facing)
		return
	_lia_still_time = 0.0
	# Eased, so while Alice walks Lía keeps her exact pace a step behind.
	lia.global_position += to_target * minf(1.0, LIA_FOLLOW_STIFFNESS * delta)
	lia.play_move(to_target if to_target.length() > 1.0 else alice_motion)

func _ask_something(delta: float) -> void:
	if Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		return
	_question_timer -= delta
	if _question_timer > 0.0 or lia_bark.is_showing():
		return
	_question_timer = randf_range(LIA_QUESTION_EVERY.x, LIA_QUESTION_EVERY.y)
	if _questions_left.is_empty():
		_questions_left.assign(LIA_QUESTIONS)
		_questions_left.shuffle()
	lia_bark.say(_questions_left.pop_back())

# =========================
# Dialogic signals
# =========================
func _on_dialogic_signal(argument: Variant) -> void:
	if not argument is String:
		return
	match argument:
		"lia_grabs_sleeve":
			_advance_to(GameManager.PlazaStage.WITH_LIA, SEARCH_START_LINES)
			_start_lia_following()
		"toby_comes":
			_toby_comes()
		"lia_lets_go":
			_lia_plays_with_dog()
		"lia_holds_on":
			_alice_last_position = player.global_position
			_lia_following = true
			_toby_goes_back()
		"time_passes":
			_let_time_pass()
		"lia_mom_arrives":
			_mother_arrives()
		"lia_drawing_given":
			GameManager.add_item("dibujo_lia")
		"lia_leaves":
			_family_leaves()
		_:
			if argument.begins_with("lia_clue:"):
				_add_clue(argument.get_slice(":", 1))
			elif argument.begins_with("anxiety_puzzle:"):
				var data: AnxietyPuzzleData = ANXIETY_PUZZLES.get(argument.get_slice(":", 1))
				if data == null:
					push_warning("Unknown anxiety puzzle '%s'" % argument)
					return
				AnxietyPuzzle.play_from_dialogic(self, data)

## Moves the story on and, once the dialogue is over, reminds Alice (and the
## player) where to look next.
func _advance_to(stage: GameManager.PlazaStage, next_lines: Array[String]) -> void:
	GameManager.plaza_stage = stage
	Dialogic.timeline_ended.connect(func() -> void: ThoughtBox.say(next_lines), CONNECT_ONE_SHOT)

# =========================
# Asking around
# =========================
func _add_clue(clue: String) -> void:
	if not GameManager.lia_clues.has(clue):
		GameManager.lia_clues.append(clue)
	if GameManager.lia_clues.size() >= LIA_CLUES_NEEDED:
		_advance_to(GameManager.PlazaStage.KNOWS_FOUNTAIN, ENOUGH_CLUES_LINES)
	else:
		Dialogic.timeline_ended.connect(func() -> void: ThoughtBox.say(ONE_CLUE_LINES), CONNECT_ONE_SHOT)

## Each helper tells what they know once, while Alice is looking with Lía.
## Before and after that they only have a line or two.
func _refresh_helpers() -> void:
	var searching := GameManager.plaza_stage == GameManager.PlazaStage.WITH_LIA
	for area: InteractableArea in helpers:
		var clue: String = helpers[area]
		var asked := GameManager.lia_clues.has(clue)
		area.timeline_name = HELPER_TIMELINES[clue] + ("" if searching and not asked else "_idle")

## Toby sees them and trots straight up to Alice to lean on her legs
## ([signal arg="toby_comes"]). Lía lets go of the sleeve to play with him
## ("lia_lets_go") and holds on again when Alice calls her ("lia_holds_on");
## then Toby goes back to his owner.
func _toby_comes() -> void:
	toby.stop_following()
	# Glued to Alice's legs: as a solid body he would push her around.
	toby.collision_layer = 0
	toby.collision_mask = 0
	var side := signf(toby.global_position.x - player.global_position.x)
	if side == 0.0:
		side = 1.0
	var at_alice := player.global_position + Vector2(16 * side, -2)
	_face(toby, at_alice)
	await _slide(toby, at_alice, 0.5)
	toby.face_direction(player.global_position - toby.global_position)

func _lia_plays_with_dog() -> void:
	_lia_following = false
	lia_bark.hide_now()
	var side := signf(toby.global_position.x - player.global_position.x)
	if side == 0.0:
		side = 1.0
	var by_toby := toby.global_position + Vector2(8 * side, -12)
	_face(lia, by_toby)
	_slide(lia, by_toby, 0.4)

## Back on the leash: he catches up with his owner by himself.
func _toby_goes_back() -> void:
	toby.collision_mask = 1
	toby.follow(dog_lady, TOBY_LEASH_OFFSET)

# =========================
# Lía holds her sleeve
# =========================
func _start_lia_following() -> void:
	_alice_last_position = player.global_position
	_lia_following = true
	player.speed_scale = SLEEVE_SPEED_SCALE
	# She walks glued to Alice: as a solid body she would shove her around.
	lia.collision_layer = 0
	lia.collision_mask = 0
	_set_area_active(lia_talk, false)

## Twine: Rama_No_Acercarse_Pasa. Alice walks off to the metro without
## talking to her; Lía runs across the plaza and grabs her sleeve.
func _lia_runs_after_alice() -> void:
	_in_cutscene = true
	player.lock_control()
	lia_bark.hide_now()
	_set_area_active(lia_talk, false)
	lia.collision_layer = 0
	lia.collision_mask = 0
	var target := player.global_position + Vector2(-LIA_FOLLOW_GAP, 4)
	await _slide(lia, target, lia.global_position.distance_to(target) / LIA_CHASE_SPEED)
	player.face_direction(player.global_position.direction_to(lia.global_position))
	Dialogic.start("plaza_lia_meet", "chase")
	await Dialogic.timeline_ended
	player.unlock_control()
	_in_cutscene = false

# =========================
# Waiting at the fountain
# =========================
## Twine: Tercera_Decision and what follows, up to the family walking away
## and Alice seeing the time on the fountain's clock.
func _on_fountain_entered(body: Node2D) -> void:
	if body != player or _in_cutscene or GameManager.plaza_stage != GameManager.PlazaStage.KNOWS_FOUNTAIN:
		return
	_in_cutscene = true
	player.lock_control()
	_lia_following = false
	lia_bark.hide_now()
	await _slide(lia, player.global_position + LIA_BESIDE_ALICE, 0.6)
	player.face_direction(player.global_position.direction_to(lia.global_position))

	Dialogic.start("plaza_lia_fountain")
	await Dialogic.timeline_ended

	GameManager.plaza_stage = GameManager.PlazaStage.LIA_HOME
	player.speed_scale = DEFEATED_SPEED_SCALE
	player.unlock_control()
	_in_cutscene = false

## The waiting is cut short: a fade to black and the sky is redder after it.
func _let_time_pass() -> void:
	Dialogic.paused = true
	await FadeTransition.fade_out(TIME_SKIP_FADE)
	sun_filter.color = SKY_LATE
	_send_crowd_home()
	await FadeTransition.fade_in(TIME_SKIP_FADE)
	Dialogic.paused = false

func _mother_arrives() -> void:
	Dialogic.paused = true
	lia_mom.global_position = mother_start.global_position
	_set_npc_active(lia_mom, true)
	lia_mom.collision_layer = 0
	lia_mom.collision_mask = 0
	var stop := lia.global_position + MOTHER_BESIDE_LIA
	lia_mom.sprite.flip_h = stop.x < mother_start.global_position.x
	await _slide(lia_mom, stop, MOTHER_WALK_TIME)
	Dialogic.paused = false

## Lía and her mother walk off together while the goodbye lines go on.
func _family_leaves() -> void:
	var leaving := create_tween().set_parallel(true)
	leaving.tween_property(lia, "global_position", family_exit.global_position, LEAVING_WALK_TIME)
	leaving.tween_property(lia_mom, "global_position", family_exit.global_position + Vector2(10, 2), LEAVING_WALK_TIME)
	lia.play_move(family_exit.global_position - lia.global_position)
	lia_mom.sprite.flip_h = family_exit.global_position.x < lia_mom.global_position.x
	await leaving.finished
	_set_npc_active(lia, false)
	_set_npc_active(lia_mom, false)

# =========================
# The station
# =========================
func _on_subway_entered(body: Node2D) -> void:
	if body != player or _in_cutscene:
		return
	match GameManager.plaza_stage:
		GameManager.PlazaStage.ARRIVED:
			_lia_runs_after_alice()
		GameManager.PlazaStage.WITH_LIA, GameManager.PlazaStage.KNOWS_FOUNTAIN:
			_think_once(SUBWAY_WITH_LIA_LINES)
		GameManager.PlazaStage.LIA_HOME:
			_miss_the_train()

func _think_once(lines: Array[String]) -> void:
	if _subway_thought_shown:
		return
	_subway_thought_shown = true
	ThoughtBox.say(lines)

## Twine: end of Perder_El_Metro. The gate is down; night falls while she
## takes it in, she puts her headphones on and walks off.
func _miss_the_train() -> void:
	_in_cutscene = true
	GameManager.plaza_stage = GameManager.PlazaStage.MISSED_TRAIN
	player.lock_control()
	player.speed_scale = 1.0
	create_tween().tween_property(sun_filter, "color", SKY_NIGHT, NIGHT_FALL_TIME)
	Dialogic.start("plaza_missed_train")
	await Dialogic.timeline_ended
	FadeTransition.transition_with_interlude(DEMO_END_SCENE, NIGHT_LINES)

# =========================
# Helpers
# =========================
## Moves an NPC in a straight line in `duration`. A WalkingNPC (Lía, Toby)
## plays its walk/run cycle and then stands facing the way it went; the
## sheet's characters (Lía's mother) still glide, they have no walk cycle.
func _slide(npc: Node2D, target: Vector2, duration: float) -> void:
	var direction := target - npc.global_position
	if npc is WalkingNPC and direction.length() > 1.0:
		npc.play_move(direction)
	var tween := create_tween()
	tween.tween_property(npc, "global_position", target, duration)
	await tween.finished
	if npc is WalkingNPC and direction.length() > 1.0:
		npc.face_direction(direction)

## Turns an NPC towards target. The sheet's characters face right by default.
func _face(npc: Node2D, target: Vector2) -> void:
	if npc is WalkingNPC:
		npc.face_direction(target - npc.global_position)
	elif absf(target.x - npc.global_position.x) > 1.0:
		npc.sprite.flip_h = target.x < npc.global_position.x

## Lía alone, waiting for her mother: crying if that animation exists.
func _lia_waits_crying() -> void:
	if lia.sprite.sprite_frames.has_animation(LIA_CRY_ANIMATION):
		lia.sprite.play(LIA_CRY_ANIMATION)
	else:
		lia.face_direction(Vector2.DOWN)

## The afternoon is over: the daytime crowd is gone (while the screen is
## dark, or before the scene shows). Their thought notice over Alice goes
## too, in case she was standing by one of them.
func _send_crowd_home() -> void:
	for npc in daytime_crowd.get_children():
		for child in npc.get_children():
			if child is AmbientThought:
				ThoughtBox.set_notice(child, false)
		_set_npc_active(npc, false)

## Hiding is not enough: a hidden NPC still blocks Alice and still answers.
func _set_npc_active(npc: Node2D, is_active: bool) -> void:
	npc.visible = is_active
	npc.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	for child in npc.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not is_active)
		elif child is Area2D:
			_set_area_active(child, is_active)

func _set_area_active(area: Area2D, is_active: bool) -> void:
	area.visible = is_active
	area.set_deferred("monitoring", is_active)
	area.set_deferred("monitorable", is_active)

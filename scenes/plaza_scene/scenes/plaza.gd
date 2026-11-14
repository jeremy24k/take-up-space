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
## How tightly she closes the gap (like WalkingNPC.follow). A fixed speed
## faster than Alice made her catch up and stop every other frame, and that
## stop-and-go stutter made her look blurry.
## Lía follows the path Alice walked (WalkingNPC.follow_trail), this far
## back along it, up to this speed (Alice walks at 75 px/s with the sleeve).
const LIA_FOLLOW_SPEED: float = 130.0
## Lía's body while she follows: only her feet, so she fits wherever Alice
## (feet box 17 x 10) fits.
const LIA_FEET := Vector2(10, 6)
## If Alice walks off to the metro, Lía runs after her this fast.
const LIA_CHASE_SPEED: float = 260.0
## At the metro: how long the camera takes to reach Lía (and come back), how
## far from her Alice stops when she goes over, and Alice's walking speed.
const LIA_FOCUS_TIME: float = 0.9
const LIA_TALK_DISTANCE: float = 22.0
const ALICE_CUTSCENE_SPEED: float = 70.0
## Before Alice talks to her she cries for her mother now and then, if Alice
## is near enough to hear it.
const LIA_CRY_LINES: Array[String] = ["¡Mamá...!", "(snif) ¿Mamá?", "¡MAMÁ!"]
const LIA_CRY_EVERY: float = 4.0
const LIA_CRY_HEARING: float = 360.0
## Lía's crying (a seamless loop) while she waits alone: from her, fading
## with distance (out to LIA_CRY_HEARING), until she stops crying.
const LIA_CRY_SOUND: AudioStream = preload("res://audio/sfx/lia_crying_loop.ogg")
const LIA_CRY_DB: float = -4.0
const LIA_CRY_FADE: float = 1.0
## While a "¡Mamá!" bubble shows, the crying drops this low so they do not
## talk over each other.
const LIA_CRY_DUCK_DB: float = -16.0
## While they look for her mother she asks whatever comes into her head, one
## question every few seconds, never the same twice in a row.
## While she holds the sleeve Lía says something every 20-30 s, from the
## phase of the search she is in (LiaChatter: lia_chatter.gd), and Alice
## answers out loud a moment later.
const LIA_CHATTER_EVERY := Vector2(20.0, 30.0)
const ALICE_REPLY_DELAY: float = 1.4
## Alice's speech bubble hangs this far above her origin.
const ALICE_BARK_OFFSET := Vector2(0, -34)
## Curiosity points: Lía goes to look (at LIA_PIGEON_SPEED), comes back if
## Alice gets this far from her, and waits this long before the next point.
const CURIOSITY_LEAVE_DISTANCE: float = 90.0
const CURIOSITY_COOLDOWN: float = 15.0
## The pigeon moment (see _on_pigeons_approached): its bubbles are the
## "Pigeons" entry of LiaCuriosity; Alice "stays" if she stands still within
## PIGEON_STAY_DISTANCE of Lía for PIGEON_STAY_TIME s; after the bubbles Lía
## waits PIGEON_WAIT s at most.
const PIGEONS_POINT := "Pigeons"
## Alice notices the flock about 70 px away, so "by Lía" is up to 85 px and
## walking on means getting PIGEON_LEAVE_DISTANCE away.
const PIGEON_STAY_DISTANCE: float = 85.0
const PIGEON_LEAVE_DISTANCE: float = 110.0
const PIGEON_STAY_TIME: float = 2.0
const PIGEON_WAIT: float = 8.0
## Lía runs to the pigeons at this speed and stops this far from the flock.
const LIA_PIGEON_SPEED: float = 110.0
const LIA_PIGEON_DISTANCE: float = 18.0

# =========================
# Thoughts and lines
# =========================
const ARRIVAL_LINES: Array[String] = [
	"Llegué. Solo falta bajar al metro y...",
	"...¿Alguien está llorando?",
]
## Alice wants to help but is in a hurry: three thoughts, once each, after
## the arrival ones. [line, distance to Lía, distance to the metro entrance]:
## the first comes when Lía is on screen (distance -1), the others when Alice
## gets that close to Lía or to the stairs, each a while after the previous.
const ARRIVAL_BEATS: Array = [
	["Está sola. ¿Dónde están sus padres?", -1.0, -1.0],
	["Alguien la va a ayudar. Alguien que no tenga un tren que coger.", 160.0, 200.0],
	["...Debería preguntarle qué le pasa. Pero el metro...", 100.0, 130.0],
]
const ARRIVAL_BEAT_GAP: float = 4.0
## Back at the metro during the search: before any clue she still thinks of
## the train; once the search is under way, only of Lía's mother.
const SUBWAY_WITH_LIA_LINES: Array[String] = [
	"El tren todavía no ha pasado.",
	"Primero, su mamá.",
]
const SUBWAY_SEARCHING_LINES: Array[String] = [
	"Aquí no hay nadie con vestido rosa.",
	"Vamos, Lía. Por aquí no es.",
]
## Once Lía holds her sleeve, and after each clue: where to look next.
const SEARCH_START_LINES: Array[String] = [
	"Alguien en la plaza tiene que haberla visto.",
	"Solo hasta encontrar a su mamá. Después, el metro.",
]
const ONE_CLUE_LINES: Array[String] = ["Mejor preguntarle a alguien más, por si acaso."]
const ENOUGH_CLUES_LINES: Array[String] = ["La fuente. Vamos a la fuente."]
## Twine: Transicion_Clara.
const NIGHT_LINES: PackedStringArray = [
	"Alice da la vuelta a la estación cerrada. La noche empieza a caer.",
	"Las calles se ven diferentes sin la luz del sol. O tal vez es ella, que las mira con otros ojos.",
	"Tiene el número de Leo y el dibujo de Lía en el bolsillo.",
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
## When Toby comes to Alice: he stands this far to her side (away from the
## jogger) and Lía, playing with him, this far on the same side.
const TOBY_BESIDE_ALICE: float = 20.0
const LIA_BESIDE_TOBY: float = 38.0
## Played while Lía waits alone, crying for her mother, once it is drawn in
## lia.aseprite. Until then she stands facing the camera.
const LIA_CRY_ANIMATION := "cry"

@onready var player: Player = $MiddleLayer/Player
@onready var lia: WalkingNPC = $MiddleLayer/NPCS/Lia
@onready var lia_talk: InteractableArea = $MiddleLayer/NPCS/Lia/TalkArea
@onready var lia_bark: SpeechBark = $MiddleLayer/NPCS/Lia/Bark
@onready var lia_mom: CharacterBody2D = $MiddleLayer/NPCS/LiaMom
@onready var sun_filter: CanvasModulate = $LightsContainer/SunFilter
## The plaza plays the street music (its SceneAudio); while Lía is with
## Alice her own music plays instead.
@onready var scene_audio: SceneAudio = $SceneAudio
const LIA_MUSIC: AudioStream = preload("res://audio/music/playlists/lia.tres")
const LIA_MUSIC_DB: float = -10.0
@onready var fountain_area: Area2D = $StoryAreas/FountainArea
@onready var subway_area: Area2D = $StoryAreas/SubwayArea
## Who helps look for the mother: talk area -> clue id. Each one has three
## timelines: the clue one (while searching with Lía and not asked yet),
## "<timeline>_extra" (an optional full conversation once Alice already knows
## about the fountain, if she never asked them; it gives no clue) and
## "<timeline>_idle" (a line or two for every other time).
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
## Map edges on the three crosswalks (BoundaryArea). Before meeting Lía,
## Alice's only goal is the metro entrance on this side of the street, so
## she turns back there; they open once Lía takes her sleeve.
@onready var crosswalks: Node2D = $MapBoundaries/Crosswalks
## Things Lía wants to look at while she holds the sleeve (CuriosityPoint).
@onready var curiosity_points: Node2D = $CuriosityPoints
@onready var mother_start: Marker2D = $StoryPoints/MotherStart
@onready var family_exit: Marker2D = $StoryPoints/FamilyExit

var _lia_following: bool = false
var _cry_timer: float = 0.0
var _chatter_timer: float = 0.0
## Lines of the current phase not said yet, and which phase that is.
var _chatter_left: Array = []
var _chatter_phase: Array = []
var _alice_bark: SpeechBark
var _lia_cry_player: AudioStreamPlayer2D
var _lia_crying: bool = false
var _cry_tween: Tween
## The pigeon flock Lía is watching during her pigeon moment.
var _watched_flock: PigeonFlock
## The curiosity point Lía is looking at (null when she holds the sleeve).
var _exploring: CuriosityPoint
var _curiosity_cooldown: float = 0.0
## The pigeon moment: how long Alice has stood still by Lía, how long Lía
## still waits after her bubbles, and where Alice was last frame.
var _pigeon_stay_time: float = 0.0
var _pigeon_wait_left: float = INF
var _alice_last_position := Vector2.ZERO
var _in_cutscene: bool = false
## Next ARRIVAL_BEATS entry and seconds since the last one.
var _arrival_beat: int = 0
var _since_arrival_beat: float = 0.0
var _greeted: bool = false
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
	_chatter_timer = randf_range(LIA_CHATTER_EVERY.x, LIA_CHATTER_EVERY.y)
	_alice_bark = SpeechBark.new()
	_alice_bark.position = ALICE_BARK_OFFSET
	player.add_child(_alice_bark)
	for flock in get_tree().get_nodes_in_group(&"pigeon_flock"):
		flock.player_approached.connect(_on_pigeons_approached.bind(flock))
	_shrink_lia_body()
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
	if GameManager.plaza_stage != GameManager.PlazaStage.ARRIVED:
		_open_crosswalks()
	match GameManager.plaza_stage:
		GameManager.PlazaStage.ARRIVED:
			sun_filter.color = SKY_ARRIVAL
			_greet_the_plaza()
			_lia_starts_crying()
			lia_talk.interacted.connect(_lia_stops_crying)
		GameManager.PlazaStage.WITH_LIA, GameManager.PlazaStage.KNOWS_FOUNTAIN:
			sun_filter.color = SKY_ARRIVAL
			SoundManager.set_music(LIA_MUSIC, LIA_MUSIC_DB)
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

## The crying loop starts at a random point, so it never sounds the same.
func _lia_starts_crying() -> void:
	_lia_cry_player = AudioStreamPlayer2D.new()
	_lia_cry_player.stream = LIA_CRY_SOUND
	_lia_cry_player.bus = &"SFX"
	_lia_cry_player.volume_db = LIA_CRY_DB
	_lia_cry_player.max_distance = LIA_CRY_HEARING
	lia.add_child(_lia_cry_player)
	_lia_cry_player.play(randf() * LIA_CRY_SOUND.get_length())
	_lia_crying = true

## Talking to her, Alice walking up, or Lía running over: the crying fades.
func _lia_stops_crying() -> void:
	if not _lia_crying:
		return
	_lia_crying = false
	if _cry_tween:
		_cry_tween.kill()
	_cry_tween = create_tween()
	_cry_tween.tween_property(_lia_cry_player, "volume_db", -60.0, LIA_CRY_FADE)
	_cry_tween.tween_callback(_lia_cry_player.stop)

## Under a "¡Mamá!" bubble the crying drops, then comes back.
func _duck_crying(duration: float) -> void:
	if not _lia_crying:
		return
	if _cry_tween:
		_cry_tween.kill()
	_cry_tween = create_tween()
	_cry_tween.tween_property(_lia_cry_player, "volume_db", LIA_CRY_DUCK_DB, 0.25)
	_cry_tween.tween_interval(duration)
	_cry_tween.tween_property(_lia_cry_player, "volume_db", LIA_CRY_DB, 0.6)

func _greet_the_plaza() -> void:
	await get_tree().create_timer(1.2).timeout
	ThoughtBox.say(ARRIVAL_LINES)
	_greeted = true

## The ARRIVAL_BEATS thoughts, in order, while Alice has not met Lía yet.
func _think_about_lia(delta: float) -> void:
	_since_arrival_beat += delta
	if not _greeted or _arrival_beat >= ARRIVAL_BEATS.size():
		return
	if Dialogic.current_timeline != null or _since_arrival_beat < ARRIVAL_BEAT_GAP:
		return
	var beat: Array = ARRIVAL_BEATS[_arrival_beat]
	var near: bool
	if beat[1] < 0.0:
		var on_screen := get_viewport().get_canvas_transform() * lia.global_position
		near = get_viewport().get_visible_rect().has_point(on_screen)
	else:
		near = player.global_position.distance_to(lia.global_position) < beat[1] 			or player.global_position.distance_to(subway_area.global_position) < beat[2]
	if not near:
		return
	var line: Array[String] = [beat[0]]
	ThoughtBox.say(line)
	_arrival_beat += 1
	_since_arrival_beat = 0.0

# =========================
# Every frame
# =========================
func _physics_process(delta: float) -> void:
	if GameManager.plaza_stage == GameManager.PlazaStage.ARRIVED and not _in_cutscene:
		_cry_for_mother(delta)
		_think_about_lia(delta)
	if _lia_following:
		_chatter(delta)
		_notice_curiosities(delta)
	elif _exploring != null:
		_watch_alice_while_exploring()
	elif _watched_flock != null and not _in_cutscene:
		_watch_alice_by_the_pigeons(delta)

func _cry_for_mother(delta: float) -> void:
	_cry_timer -= delta
	if _cry_timer > 0.0 or Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		return
	_cry_timer = LIA_CRY_EVERY
	if lia.global_position.distance_to(player.global_position) <= LIA_CRY_HEARING:
		_duck_crying(2.0)
		lia_bark.say(LIA_CRY_LINES.pick_random(), 2.0)

## Lía's bubbles while she walks along (LiaChatter), each with Alice's
## answer out loud a moment later. Never over a conversation or a thought.
func _chatter(delta: float) -> void:
	if Dialogic.current_timeline != null:
		return
	_chatter_timer -= delta
	if _chatter_timer > 0.0 or lia_bark.is_showing() or _alice_bark.is_showing():
		return
	_chatter_timer = randf_range(LIA_CHATTER_EVERY.x, LIA_CHATTER_EVERY.y)
	var phase := LiaChatter.for_clues(GameManager.lia_clues.size())
	if phase != _chatter_phase or _chatter_left.is_empty():
		_chatter_phase = phase
		_chatter_left = phase.duplicate()
		_chatter_left.shuffle()
	var exchange: Array = _chatter_left.pop_back()
	lia_bark.say(exchange[0])
	var answer: String = exchange[1]
	if answer.is_empty():
		return
	await get_tree().create_timer(ALICE_REPLY_DELAY).timeout
	if _lia_following:
		_alice_bark.say(answer)

# =========================
# Dialogic signals
# =========================
func _on_dialogic_signal(argument: Variant) -> void:
	if not argument is String:
		return
	match argument:
		"lia_grabs_sleeve":
			_open_crosswalks()
			SoundManager.set_music(LIA_MUSIC, LIA_MUSIC_DB)
			_advance_to(GameManager.PlazaStage.WITH_LIA, SEARCH_START_LINES)
			_start_lia_following()
		"focus_on_lia":
			_focus_on_lia()
		"alice_goes_to_lia":
			_alice_goes_to_lia()
		"alice_turns_away":
			_alice_turns_away()
		"lia_comes_to_alice":
			_lia_comes_to_alice()
		"toby_comes":
			_toby_comes()
		"lia_lets_go":
			_lia_plays_with_dog()
		"lia_holds_on":
			_lia_takes_sleeve()
			_toby_goes_back()
		"time_passes":
			_let_time_pass()
		"lia_mom_arrives":
			_mother_arrives()
		"pigeons_fly":
			if is_instance_valid(_watched_flock):
				_watched_flock.fly_away_from(lia.global_position)
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
				_play_puzzle(data)

## The puzzle at the metro is the moment Alice answers Lía: her crying
## stops as soon as it is over, whatever the answer.
func _play_puzzle(data: AnxietyPuzzleData) -> void:
	await AnxietyPuzzle.play_from_dialogic(self, data)
	_lia_stops_crying()

## Moves the story on and, once the dialogue is over, reminds Alice (and the
## player) where to look next.
func _advance_to(stage: GameManager.PlazaStage, next_lines: Array[String]) -> void:
	# The story only moves forward (a late clue must never bring back the
	# fountain once Lía went home).
	if stage <= GameManager.plaza_stage:
		return
	GameManager.plaza_stage = stage
	Dialogic.timeline_ended.connect(func() -> void: ThoughtBox.say(next_lines), CONNECT_ONE_SHOT)

# =========================
# Asking around
# =========================
func _add_clue(clue: String) -> void:
	# Clues only count while searching. The third helper, asked once Alice
	# already knows about the fountain (their full talk, with its "we already
	# know" variant), gives no clue and no clue thought: just marked as heard
	# so they go to their idle line.
	if GameManager.plaza_stage != GameManager.PlazaStage.WITH_LIA:
		if not GameManager.lia_extras.has(clue):
			GameManager.lia_extras.append(clue)
		return
	if not GameManager.lia_clues.has(clue):
		GameManager.lia_clues.append(clue)
	if GameManager.lia_clues.size() >= LIA_CLUES_NEEDED:
		_advance_to(GameManager.PlazaStage.KNOWS_FOUNTAIN, ENOUGH_CLUES_LINES)
	else:
		Dialogic.timeline_ended.connect(func() -> void: ThoughtBox.say(ONE_CLUE_LINES), CONNECT_ONE_SHOT)

## Each helper tells what they know once, while Alice is looking with Lía.
## Once she knows about the fountain (KNOWS_FOUNTAIN), the ones who already
## helped offer their "<timeline>_extra" goodbye once, and the one she never
## asked offers their full talk (it has a variant for "we already know about
## the fountain" and gives no clue: _add_clue). Once Lía went home
## (LIA_HOME, MISSED_TRAIN) all three use "<timeline>_after", without Lía.
## Before Lía, they only have a line or two ("_idle").
func _refresh_helpers() -> void:
	for area: InteractableArea in helpers:
		var clue: String = helpers[area]
		var asked := GameManager.lia_clues.has(clue)
		var suffix := "_idle"
		match GameManager.plaza_stage:
			GameManager.PlazaStage.LIA_HOME, GameManager.PlazaStage.MISSED_TRAIN:
				suffix = "_after"
			GameManager.PlazaStage.WITH_LIA:
				if not asked:
					suffix = ""
			GameManager.PlazaStage.KNOWS_FOUNTAIN:
				# Both talks end marking the helper in lia_extras: the extra
				# with [signal arg="lia_extra:<clue>"], the full one through
				# _add_clue.
				if not GameManager.lia_extras.has(clue):
					suffix = "_extra" if asked else ""
		area.timeline_name = HELPER_TIMELINES[clue] + suffix

## Toby sees them and trots straight up to Alice to lean on her legs
## ([signal arg="toby_comes"]). Lía lets go of the sleeve to play with him
## ("lia_lets_go") and holds on again when Alice calls her ("lia_holds_on");
## then Toby goes back to his owner.
func _toby_comes() -> void:
	toby.stop_following()
	# Glued to Alice's legs: as a solid body he would push her around.
	toby.collision_layer = 0
	toby.collision_mask = 0
	var at_alice := player.global_position + Vector2(TOBY_BESIDE_ALICE * _away_from_jogger(), 2)
	_face(toby, at_alice)
	await _slide(toby, at_alice, 0.5)
	toby.face_direction(player.global_position - toby.global_position)

func _lia_plays_with_dog() -> void:
	_lia_lets_go_sleeve()
	lia_bark.hide_now()
	var by_toby := player.global_position + Vector2(LIA_BESIDE_TOBY * _away_from_jogger(), 2)
	_face(lia, by_toby)
	await _slide(lia, by_toby, 0.4)
	_face(lia, toby.global_position)

## In a row, so nobody covers anybody: the jogger on one side of Alice,
## Toby at Alice's legs on the other side and Lía beyond Toby. +1 or -1.
func _away_from_jogger() -> float:
	var side := signf(player.global_position.x - dog_lady.global_position.x)
	return side if side != 0.0 else 1.0

## Back on the leash: he catches up with his owner by himself.
func _toby_goes_back() -> void:
	toby.collision_mask = 1
	toby.follow(dog_lady, TOBY_LEASH_OFFSET)

# =========================
# Lía's curiosity
# =========================
## Optional, once per point, never in the bottom box: with Lía on her
## sleeve, the first time Alice walks near a CuriosityPoint Lía lets go,
## runs over, says a line or two in her bubble (LiaCuriosity) and Alice
## answers in hers. Alice can wait or walk on: if she gets
## CURIOSITY_LEAVE_DISTANCE away, or a conversation starts, Lía runs back
## to the sleeve. Then nothing for CURIOSITY_COOLDOWN s.
func _notice_curiosities(delta: float) -> void:
	_curiosity_cooldown -= delta
	if _curiosity_cooldown > 0.0 or _in_cutscene or Dialogic.current_timeline != null:
		return
	for point: CuriosityPoint in curiosity_points.get_children():
		if GameManager.lia_curiosities_seen.has(point.name):
			continue
		if player.global_position.distance_to(point.global_position) < point.trigger_radius:
			_lia_explores(point)
			return

func _lia_explores(point: CuriosityPoint) -> void:
	GameManager.lia_curiosities_seen.append(point.name)
	_exploring = point
	_lia_lets_go_sleeve()
	lia_bark.hide_now()
	_alice_bark.hide_now()
	player.speed_scale = 1.0
	var spot := point.global_position + point.global_position.direction_to(lia.global_position) * point.look_distance
	await _slide(lia, spot, lia.global_position.distance_to(spot) / LIA_PIGEON_SPEED)
	if _exploring != point:
		return
	_face(lia, point.global_position)
	var lines: Dictionary = LiaCuriosity.for_point(point.name)
	for line: String in lines["lia"]:
		if _exploring != point:
			return
		await lia_bark.say(line)
	var answer: String = lines["alice"]
	if _exploring != point:
		return
	if not answer.is_empty():
		_alice_bark.say(answer)
		await get_tree().create_timer(ALICE_REPLY_DELAY).timeout
	var last: String = lines["lia_after"]
	if not last.is_empty() and _exploring == point:
		await get_tree().create_timer(1.2).timeout
		if _exploring == point:
			await lia_bark.say(last)
	_lia_comes_back()

## Alice walked off, or a conversation started: Lía runs back to her.
func _watch_alice_while_exploring() -> void:
	var talking := Dialogic.current_timeline != null and not ThoughtBox.is_showing()
	if talking or player.global_position.distance_to(lia.global_position) > CURIOSITY_LEAVE_DISTANCE:
		lia_bark.hide_now()
		_lia_comes_back()

func _lia_comes_back() -> void:
	if _exploring == null:
		return
	_exploring = null
	_curiosity_cooldown = CURIOSITY_COOLDOWN
	# A cutscene (the fountain) took over meanwhile: it places her itself.
	if _in_cutscene:
		return
	_lia_takes_sleeve()
	player.speed_scale = SLEEVE_SPEED_SCALE

# =========================
# Lía and the pigeons
# =========================
## Optional, once per game (GameManager.lia_pigeons_seen, set as soon as it
## starts). With Lía on her sleeve, the first time Alice walks up to a pigeon
## flock, Lía lets go and runs over (the flock is kept calm so Alice does
## not scare it), and it starts like a curiosity: bubbles, Alice is free.
## - If Alice STAYS (still, within PIGEON_STAY_DISTANCE of Lía, for
##   PIGEON_STAY_TIME s), the box scene plays: Alice is held,
##   plaza_lia_pigeons, the pigeons take off ("pigeons_fly", or at the end)
##   and Lía comes back to the sleeve.
## - If she walks off (PIGEON_LEAVE_DISTANCE) or a talk starts, Lía says
##   her "coming!" line, runs back to the sleeve and the flock is normal
##   again (Alice can scare it later like any other).
## - If neither happens for PIGEON_WAIT s after the bubbles, Lía comes back
##   on her own, the same way.
func _on_pigeons_approached(flock: PigeonFlock) -> void:
	if GameManager.lia_pigeons_seen or not _lia_following or _in_cutscene:
		return
	# Never on top of another curiosity, or right after one.
	if _exploring != null or _curiosity_cooldown > 0.0:
		return
	if Dialogic.current_timeline != null and not ThoughtBox.is_showing():
		return
	flock.calm = true
	_lia_watches_pigeons(flock)

func _lia_watches_pigeons(flock: PigeonFlock) -> void:
	GameManager.lia_pigeons_seen = true
	_watched_flock = flock
	_pigeon_stay_time = 0.0
	_pigeon_wait_left = INF
	_alice_last_position = player.global_position
	_lia_lets_go_sleeve()
	lia_bark.hide_now()
	_alice_bark.hide_now()
	player.speed_scale = 1.0
	var spot := flock.global_position + flock.global_position.direction_to(player.global_position) * LIA_PIGEON_DISTANCE
	await _slide(lia, spot, lia.global_position.distance_to(spot) / LIA_PIGEON_SPEED)
	if _watched_flock != flock or _in_cutscene:
		return
	_face(lia, flock.global_position)
	var lines: Dictionary = LiaCuriosity.for_point(PIGEONS_POINT)
	for line: String in lines["lia"]:
		if _watched_flock != flock or _in_cutscene:
			return
		await lia_bark.say(line)
	var answer: String = lines["alice"]
	if _watched_flock != flock or _in_cutscene:
		return
	if not answer.is_empty():
		await _alice_bark.say(answer)
	if _watched_flock == flock and not _in_cutscene:
		_pigeon_wait_left = PIGEON_WAIT

## Every frame while Lía watches the pigeons (before the box scene).
func _watch_alice_by_the_pigeons(delta: float) -> void:
	var talking := Dialogic.current_timeline != null and not ThoughtBox.is_showing()
	var distance := player.global_position.distance_to(lia.global_position)
	if talking or distance > PIGEON_LEAVE_DISTANCE:
		_lia_leaves_the_pigeons(true)
		return
	var moved := player.global_position.distance_to(_alice_last_position)
	_alice_last_position = player.global_position
	# Still = not moving and not trying to (walking into a wall is not staying).
	# It only counts once Lía and Alice are done talking (the wait has started).
	var trying := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO
	var talked := _pigeon_wait_left != INF
	if talked and moved < 0.1 and not trying and distance <= PIGEON_STAY_DISTANCE:
		_pigeon_stay_time += delta
		if _pigeon_stay_time >= PIGEON_STAY_TIME:
			_pigeons_up_close()
			return
	else:
		_pigeon_stay_time = 0.0
	_pigeon_wait_left -= delta
	if _pigeon_wait_left <= 0.0:
		_lia_leaves_the_pigeons(false)

## Alice stayed: the scene in the box.
func _pigeons_up_close() -> void:
	var flock := _watched_flock
	_in_cutscene = true
	player.lock_control()
	lia_bark.hide_now()
	_alice_bark.hide_now()
	player.face_direction(player.global_position.direction_to(lia.global_position))
	Dialogic.start("plaza_lia_pigeons")
	await Dialogic.timeline_ended
	if is_instance_valid(flock):
		flock.fly_away_from(lia.global_position)
	_watched_flock = null
	_curiosity_cooldown = CURIOSITY_COOLDOWN
	# Back to the sleeve: the trail follow brings her round to Alice.
	_lia_takes_sleeve()
	player.speed_scale = SLEEVE_SPEED_SCALE
	player.unlock_control()
	_in_cutscene = false

## Alice walked on (or waited somewhere else): Lía runs back to the sleeve,
## saying her line if she has to run after her, and the pigeons are just
## pigeons again.
func _lia_leaves_the_pigeons(calling: bool) -> void:
	var flock := _watched_flock
	_watched_flock = null
	if is_instance_valid(flock):
		flock.calm = false
	_curiosity_cooldown = CURIOSITY_COOLDOWN
	_alice_bark.hide_now()
	if calling:
		var line: String = LiaCuriosity.for_point(PIGEONS_POINT)["lia_after"]
		if not line.is_empty():
			lia_bark.say(line)
	_lia_takes_sleeve()
	player.speed_scale = SLEEVE_SPEED_SCALE

# =========================
# Lía holds her sleeve
# =========================
func _start_lia_following() -> void:
	_lia_stops_crying()
	_lia_takes_sleeve()
	player.speed_scale = SLEEVE_SPEED_SCALE
	_set_area_active(lia_talk, false)

## Lía holds the sleeve: she walks Alice's trail (not solid, so she never
## shoves her, but she does bump into walls and lamp posts).
func _lia_takes_sleeve() -> void:
	_lia_following = true
	lia.follow_trail(player, LIA_FOLLOW_GAP, LIA_FOLLOW_SPEED)

## Lía lets go (a cutscene, Toby, something caught her eye).
func _lia_lets_go_sleeve() -> void:
	_lia_following = false
	lia.stop_trail()

## Alice reaches the metro without having talked to Lía (Twine: the girl
## keeps crying, Alice cannot stop looking at her). The camera goes to Lía
## and plaza_lia_meet starts at "metro": the anxiety puzzle decides between
## going to her ("ask"), walking off ("leave": she runs after Alice) and
## freezing (silence: she comes over). The movement happens on the
## timeline's signals (_on_dialogic_signal) while Dialogic is paused.
func _lia_at_the_metro() -> void:
	_in_cutscene = true
	player.lock_control()
	lia_bark.hide_now()
	_set_area_active(lia_talk, false)
	lia.collision_layer = 0
	lia.collision_mask = 0
	player.face_direction(player.global_position.direction_to(lia.global_position))
	Dialogic.start("plaza_lia_meet", "metro")
	await Dialogic.timeline_ended
	await player.reset_camera(LIA_FOCUS_TIME)
	player.unlock_control()
	_in_cutscene = false

## "focus_on_lia": the camera glides over to her while she cries.
func _focus_on_lia() -> void:
	Dialogic.paused = true
	await player.pan_camera_to(lia.global_position + Vector2(0, -8), LIA_FOCUS_TIME)
	Dialogic.paused = false

## "alice_goes_to_lia": Alice walks up to her (Rama_Acercarse).
func _alice_goes_to_lia() -> void:
	_lia_stops_crying()
	Dialogic.paused = true
	# Not awaited: the camera comes back while she walks.
	player.reset_camera(LIA_FOCUS_TIME)
	var from_lia := lia.global_position.direction_to(player.global_position)
	var target := lia.global_position + from_lia * LIA_TALK_DISTANCE
	await _walk_player(target)
	player.face_direction(player.global_position.direction_to(lia.global_position))
	lia.face_direction(lia.global_position.direction_to(player.global_position))
	Dialogic.paused = false

## "alice_turns_away": she turns her back on Lía, towards the stairs down.
func _alice_turns_away() -> void:
	Dialogic.paused = true
	await player.reset_camera(LIA_FOCUS_TIME)
	player.face_direction(player.global_position.direction_to(subway_area.global_position))
	Dialogic.paused = false

## "lia_comes_to_alice": Lía runs over and stops beside Alice (she chases
## her when Alice walks off, she jumps up when Alice just stands there).
func _lia_comes_to_alice() -> void:
	_lia_stops_crying()
	Dialogic.paused = true
	player.reset_camera(LIA_FOCUS_TIME)
	var side := signf(lia.global_position.x - player.global_position.x)
	if side == 0.0:
		side = -1.0
	var target := player.global_position + Vector2(LIA_FOLLOW_GAP * side, 4)
	await _slide(lia, target, lia.global_position.distance_to(target) / LIA_CHASE_SPEED)
	lia.face_direction(lia.global_position.direction_to(player.global_position))
	player.face_direction(player.global_position.direction_to(lia.global_position))
	Dialogic.paused = false

## Walks Alice in a straight line during a cutscene (she is locked).
func _walk_player(target: Vector2) -> void:
	var direction := target - player.global_position
	if direction.length() < 1.0:
		return
	var suffix := player.get_direction_suffix(direction)
	player.play_animation("walk_" + suffix, "idle_" + suffix)
	var tween := create_tween()
	tween.tween_property(player, "global_position", target, direction.length() / ALICE_CUTSCENE_SPEED)
	await tween.finished
	player.face_direction(direction)

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
	_exploring = null
	if is_instance_valid(_watched_flock):
		_watched_flock.calm = false
	_watched_flock = null
	_lia_lets_go_sleeve()
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
	# Lía is gone: back to the street music.
	SoundManager.set_music(scene_audio.music, scene_audio.music_volume_db)

# =========================
# The station
# =========================
func _on_subway_entered(body: Node2D) -> void:
	if body != player or _in_cutscene:
		return
	match GameManager.plaza_stage:
		GameManager.PlazaStage.ARRIVED:
			_lia_at_the_metro()
		GameManager.PlazaStage.WITH_LIA, GameManager.PlazaStage.KNOWS_FOUNTAIN:
			_think_once(SUBWAY_WITH_LIA_LINES if GameManager.lia_clues.is_empty() else SUBWAY_SEARCHING_LINES)
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

## Lía's collision box becomes just her feet, like Alice's, so following the
## trail she fits through the same gaps. Built here, not in the scene: an
## override on the template's CollisionShape2D would need Editable Children.
func _shrink_lia_body() -> void:
	var body := lia.get_node("CollisionShape2D") as CollisionShape2D
	var feet := RectangleShape2D.new()
	feet.size = LIA_FEET
	body.shape = feet
	body.position = Vector2(0, 3)

## Alice can cross the street to the plaza (to ask around with Lía).
func _open_crosswalks() -> void:
	for boundary in crosswalks.get_children():
		_set_area_active(boundary, false)

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

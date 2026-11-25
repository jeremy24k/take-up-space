extends Node2D

# =========================
# Plaza metro platform
# =========================
## The metro platform under the plaza. Alice comes down here after handing
## Lía over to her mother (plaza.gd sends her in LIA_HOME).
##
## Flow:
##   1. She walks in by herself down the stairs from the left (FromPlaza is
##      a SpawnPoint with walk_in) while the train is already coming in: the
##      player gets control a moment later, long before the doors open, and
##      it looks like she can still make it.
##   2. The doors open and the train waits for her, however long she takes.
##      Only when she reaches the platform edge in front of them
##      (CutscenePoints/AliceSeesDoors) does she stop, and the doors close in
##      her face: she almost made it. It is never a fail state: she always
##      misses it.
##   3. Control is back right after «No, no, no...», as the train pulls
##      away; her thoughts after the train keep showing while she walks,
##      and the empty platform stays silent until she walks back to the
##      stairs.
##   4. Walking back, as she nears the stairs (CutscenePoints/HearClaraZone),
##      she hears Clara singing up in the plaza (ClaraVoice, positional:
##      louder near the stairs) and turns towards it.
##   5. Walking up the stairs (ExitToPlaza, walk_off_screen) takes the
##      control away: Alice walks on by herself off the left edge of the map
##      while the camera stays put; on its walked_out the interlude ends the
##      demo.
## Passengers: whoever is under MiddleLayer/Passengers gets off the train
## through the central doors once the doors are open AND Alice is coming up
## to the platform (CutscenePoints/PassengersCue, the top of the passage);
## they walk their route (PassengerRoutes/<same name>) out of the station,
## past Alice. Their pace adapts to hers: a slow Alice sees the calm base
## schedule; a fast one makes it speed up so the last passenger is off just
## as she reaches the doors, which then close at once. She never stands in
## front of open doors waiting.
## The way down is one-way: ExitToPlaza stays off until Clara's voice, so
## she cannot run back up mid-cutscene, and from then on it ends the demo.
## plaza_stage arrives as LIA_HOME and becomes MISSED_TRAIN as the doors close.
##
## Every place comes from a Marker2D or a node of the scene, never from fixed
## coordinates: the room is going to be redesigned.

## Shown when the scene ends, before demo_end.
const DEMO_END_SCENE := "res://scenes/demo_end/demo_end.tscn"

# =========================
# Texts (Guion, narrative/final_demo_metro.md)
# =========================
## Alice's thought as the train comes in.
const TRAIN_ARRIVING_LINES: Array[String] = [
	"¡El tren!",
	"Si corro, llego.",
]
## When the doors close in front of her.
const DOORS_CLOSING_LINES: Array[String] = [
	"No, no, no...",
]
## While the train pulls away, with control already back. The
## second line recalls the prologue (she fell asleep on the train).
const TRAIN_GONE_LINES: Array[String] = [
	"Por un segundo.",
	"¿Y ahora qué, Alice?",
	"Tendré que subir a la calle y buscar otra forma de llegar a casa.",
	"Y ya debe estar anocheciendo...",
]
## Nudges while the train waits with its doors open and Alice dawdles or
## heads back (see _update_hurry): one thought each time, in order, never
## repeated (Guion, approved by the user).
const HURRY_LINES: Array = [
	["El tren... ¡rápido!"],
	["Deja de perder el tiempo, Alice."],
	["Voy a perder el tren si no me apresuro."],
	["Las puertas siguen abiertas. Muévete, Alice."],
	["¿Qué estás haciendo, Alice? ¡El tren!"],
]
## When she hears Clara singing up in the plaza.
const HEARS_CLARA_LINES: Array[String] = [
	"¿Alguien está cantando?",
	"Viene de arriba.",
]
## The interlude when she walks up the stairs; it tells the nightfall, so
## the platform never turns to night. Lines between «» are her thoughts.
const ENDING_LINES: PackedStringArray = [
	"Alice sube las escaleras de la estación. Afuera, ya es de noche.",
	"La plaza se ve diferente sin la luz del sol. O tal vez es ella, que la mira con otros ojos.",
	"Tiene el número de Leo y el dibujo de Lía en el bolsillo.",
	"Tiene hambre. Tiene frío. No sabe dónde va a dormir.",
	"«Pero ayudé a alguien. Eso hice.»",
	"Y algo en su pecho no es miedo. No del todo.",
	"La voz sigue ahí, en algún lugar de la plaza. Alice la sigue.",
	"No llora. Canta.",
]

# =========================
# Timing and sounds
# =========================
## How close to AliceSeesDoors she gets before the doors close in her face.
## Small on purpose: she has to really reach the platform edge. There is no
## time-out: the stairs are closed until later, so the only way is forward.
const DOORS_CLOSE_DISTANCE: float = 40.0
## The beat she stands still before the doors close, so the player sees it.
const BEFORE_CLOSING_TIME: float = 0.4
const CAMERA_PAN_TIME: float = 1.0
const CAMERA_RETURN_TIME: float = 0.8
## The camera frames the train's stop plus this, to show the doors (same
## framing as metro_stations.gd).
const TRAIN_VIEW_OFFSET := Vector2(0, 40)
## Clara's voice fades in instead of starting cold.
const CLARA_FADE_IN_TIME: float = 3.0
## With a voice, it plays alone this long before Alice's thought.
const CLARA_VOICE_LEAD_TIME: float = 1.5
## Passengers getting off walk a little slower than Alice, and fade in at
## the door and out at the end of their route.
const PASSENGER_SPEED: float = 38.0
const PASSENGER_FADE_TIME: float = 0.4
## Going through a door at the end of the route (route metadata door_sound):
## a quick fade at the door, with the door's sound there.
const PASSENGER_DOOR_FADE_TIME: float = 0.2
const DOOR_SOUND := preload("res://audio/sfx/door_open.ogg")
const DOOR_SOUND_VOLUME_DB: float = -8.0
## Two passengers reaching the door close together share one door sound.
const DOOR_SOUND_MIN_GAP: float = 0.8
## Each passenger stands a moment in the doorway before walking off, so the
## player reads them stepping out of the train.
const PASSENGER_DOOR_PAUSE: float = 0.9
## Adaptive pace: the getting-off schedule runs on its own clock, sped up so
## the last one is off PASSENGER_ETA_MARGIN seconds before Alice can reach
## the doors (estimated from her distance, at her walking speed). Never
## slower than the base schedule, never more than MAX_PASSENGER_PACE times
## faster; past that, reaching the doors makes everyone step off at once.
const PASSENGER_ETA_MARGIN: float = 0.4
const MAX_PASSENGER_PACE: float = 4.0
## Where she goes through the grates to the platform's upper part (the only
## gap), to estimate her path to the doors from below.
const PLATFORM_GAP := Vector2(624, 422)
## Hurry thoughts: she counts as stalling if she has not got this much closer
## to the platform for HURRY_STALL_TIME seconds, or as heading back once she
## is HURRY_BACKTRACK px further than her closest. At least HURRY_MIN_GAP
## seconds between two thoughts.
const HURRY_STALL_TIME: float = 8.0
const HURRY_PROGRESS_STEP: float = 16.0
const HURRY_BACKTRACK: float = 160.0
const HURRY_MIN_GAP: float = 10.0
const TRAIN_ARRIVAL_SOUND := preload("res://audio/sfx/train_arrival.ogg")
const TRAIN_CHIME_SOUND := preload("res://audio/sfx/train_chime.ogg")

# =========================
# Nodes
# =========================
@onready var player: Player = $MiddleLayer/Player
@onready var metro_train = $MiddleLayer/MetroTrain
@onready var alice_sees_doors: Marker2D = $CutscenePoints/AliceSeesDoors
## Near the foot of the stairs: walking back into it, she hears Clara.
@onready var hear_clara_zone: Area2D = $CutscenePoints/HearClaraZone
@onready var exit_to_plaza: ExitArea = $ExitToPlaza
## Clara singing up in the plaza. No stream yet (the user will make the song
## later); with no stream the cutscene plays the same, in silence.
@onready var clara_voice: AudioStreamPlayer2D = $ClaraVoice
## WalkingNPCs that get off the train; each one's route is the Marker2Ds of
## PassengerRoutes/<its name>, in order (first = the door it comes out of).
@onready var passengers: Node2D = $MiddleLayer/Passengers
@onready var passenger_routes: Node2D = $PassengerRoutes
## A strip across the platform: from here on the train's doors are in view.
@onready var passengers_cue: Area2D = $CutscenePoints/PassengersCue

var _doors_open: bool = false
var _train_missed: bool = false
var _heard_clara: bool = false
## While the cloud after the train (TRAIN_GONE_LINES) is still on: Clara's
## moment waits for it, so it never cuts the hint about going back up.
var _train_gone_thinking: bool = false
var _alice_near_platform: bool = false
var _passengers_released: bool = false
## Passengers still inside the train: the doors wait for them.
var _passengers_aboard: int = 0
## When (engine msec) the last door sound played.
var _last_door_sound_msec: int = -100000
## Hurry thoughts: the next one to say, her closest distance to the
## platform so far, how long she has not got closer, and the time since
## the last thought.
var _hurry_index: int = 0
var _hurry_best_distance: float = INF
var _hurry_stall: float = 0.0
var _hurry_since_last: float = INF
## The getting-off clock (base-schedule seconds), its current speed, and
## when (on that clock) the last passenger steps off.
var _alight_clock: float = 0.0
var _passenger_pace: float = 1.0
var _last_alight_time: float = 0.0

# =========================
# Setup
# =========================
func _ready() -> void:
	_place_at_spawn_point()
	metro_train.doors_opened.connect(_on_doors_opened)
	metro_train.doors_closed.connect(SoundManager.play_sfx.bind(TRAIN_CHIME_SOUND))
	_set_exit_enabled(false)
	hear_clara_zone.body_entered.connect(_on_hear_clara_zone_entered)
	passengers_cue.body_entered.connect(_on_passengers_cue_entered)
	_hide_passengers()
	_train_arrives()

## Alice arrives at the Marker2D under SpawnPoints that the previous scene
## asked for (GameManager.take_spawn_point()); by default, FromPlaza, where
## she walks in down the stairs (SpawnPoint.walk_in). Not awaited: the train
## is already on its way in meanwhile.
func _place_at_spawn_point() -> void:
	var point_name := GameManager.take_spawn_point()
	if point_name.is_empty():
		point_name = "FromPlaza"
	var point := get_node_or_null("SpawnPoints/" + point_name) as Marker2D
	if point:
		SpawnPoint.arrive(player, point, Vector2.RIGHT)

# =========================
# The train comes in
# =========================
## Step 1: it comes in while she is still at the stairs. The player is free.
func _train_arrives() -> void:
	SoundManager.play_sfx(TRAIN_ARRIVAL_SOUND)
	metro_train.enter_in_station()
	ThoughtBox.say(TRAIN_ARRIVING_LINES)

func _on_doors_opened() -> void:
	SoundManager.play_sfx(TRAIN_CHIME_SOUND)
	_doors_open = true
	_try_release_passengers()

## Step 2 trigger: she reaches the platform edge in front of the doors. If
## someone is still getting off, they all step off right now: she never
## waits in front of open doors.
func _process(delta: float) -> void:
	if _passengers_released and _passengers_aboard > 0:
		_advance_alight_clock(delta)
	if not _doors_open or _train_missed:
		return
	if not _alice_near_platform:
		_update_hurry(delta)
	if player.global_position.distance_to(alice_sees_doors.global_position) <= DOORS_CLOSE_DISTANCE:
		if _passengers_aboard > 0:
			_alight_clock = _last_alight_time
			return
		_miss_the_train()

# =========================
# Hurry thoughts
# =========================
## While the doors are open and she has not reached the platform yet
## (PassengersCue): if she stalls or heads back, the next HURRY_LINES
## thought. A player going straight there never sees one. Her progress is
## her distance to PassengersCue, the foot of the only way up: the corridor
## runs straight to it from the stairs.
func _update_hurry(delta: float) -> void:
	_hurry_since_last += delta
	if _hurry_index >= HURRY_LINES.size():
		return
	var distance := player.global_position.distance_to(passengers_cue.global_position)
	if distance < _hurry_best_distance - HURRY_PROGRESS_STEP or _hurry_best_distance == INF:
		_hurry_best_distance = distance
		_hurry_stall = 0.0
	else:
		_hurry_stall += delta
	var stalled := _hurry_stall >= HURRY_STALL_TIME
	var heading_back := distance > _hurry_best_distance + HURRY_BACKTRACK
	if not (stalled or heading_back):
		return
	if _hurry_since_last < HURRY_MIN_GAP or ThoughtBox.is_showing() or Dialogic.current_timeline != null:
		return
	var lines: Array[String] = []
	lines.assign(HURRY_LINES[_hurry_index])
	_hurry_index += 1
	_hurry_since_last = 0.0
	# A fresh start: the next one needs a new stall or a new step back.
	_hurry_stall = 0.0
	_hurry_best_distance = distance
	ThoughtBox.say(lines)

# =========================
# Passengers
# =========================
## Inside the train until they get off: hidden and never solid, so they
## cannot block Alice (walk_path keeps them non-solid while they walk).
func _hide_passengers() -> void:
	for npc in passengers.get_children():
		if npc is WalkingNPC:
			npc.hide()
			npc.collision_layer = 0
			if passenger_routes.has_node(NodePath(npc.name)):
				_passengers_aboard += 1

func _on_passengers_cue_entered(body: Node2D) -> void:
	if body == player:
		_alice_near_platform = true
		_try_release_passengers()

## They get off once the doors are open and Alice is coming up, whichever
## happens last. Each passenger with a route gets off; one without a route
## stays hidden.
func _try_release_passengers() -> void:
	if _passengers_released or not _doors_open or not _alice_near_platform:
		return
	_passengers_released = true
	_alight_clock = 0.0
	_last_alight_time = 0.0
	for npc in passengers.get_children():
		var route := passenger_routes.get_node_or_null(NodePath(npc.name))
		if npc is WalkingNPC and route:
			var delay: float = route.get_meta("start_delay", 0.0)
			_last_alight_time = maxf(_last_alight_time, delay + PASSENGER_FADE_TIME + PASSENGER_DOOR_PAUSE)
			_walk_passenger(npc, route)

## Runs the getting-off clock, fast enough for the last one to be off
## before Alice gets to the doors.
func _advance_alight_clock(delta: float) -> void:
	var remaining := _last_alight_time - _alight_clock
	var eta := _alice_eta_to_doors() - PASSENGER_ETA_MARGIN
	_passenger_pace = clampf(remaining / maxf(eta, 0.05), 1.0, MAX_PASSENGER_PACE)
	_alight_clock += delta * _passenger_pace

## Seconds Alice needs to reach the doors' trigger at full walking speed,
## through the gap in the grates if she is still below them.
func _alice_eta_to_doors() -> float:
	var target := alice_sees_doors.global_position
	var here := player.global_position
	var path := 0.0
	if here.y > PLATFORM_GAP.y:
		path = here.distance_to(PLATFORM_GAP) + PLATFORM_GAP.distance_to(target)
	else:
		path = here.distance_to(target)
	path = maxf(path - DOORS_CLOSE_DISTANCE, 0.0)
	return path / Player.SPEED

## Waits until the getting-off clock reaches `time`.
func _wait_alight_clock(time: float) -> void:
	while _alight_clock < time:
		await get_tree().process_frame

## Appears at the door (the route's first point) at its start_delay (on the
## getting-off clock), stands there a moment, walks the rest of the route and
## fades out at the end. Its fade, pause and walk follow the current pace.
func _walk_passenger(npc: WalkingNPC, route: Node) -> void:
	var points: Array[Vector2] = []
	for point in route.get_children():
		if point is Marker2D:
			points.append(point.global_position)
	if points.size() < 2:
		return
	var delay: float = route.get_meta("start_delay", 0.0)
	await _wait_alight_clock(delay)
	npc.global_position = points[0]
	npc.modulate.a = 0.0
	npc.show()
	npc.face_direction(points[1] - points[0])
	var fade_in := create_tween()
	fade_in.tween_property(npc, "modulate:a", 1.0, PASSENGER_FADE_TIME / _passenger_pace)
	await _wait_alight_clock(delay + PASSENGER_FADE_TIME + PASSENGER_DOOR_PAUSE)
	if fade_in.is_running():
		fade_in.kill()
		npc.modulate.a = 1.0
	# Off the train: the doors no longer wait for this one.
	_passengers_aboard -= 1
	await npc.walk_path(points.slice(1), PASSENGER_SPEED * minf(_passenger_pace, 2.5))
	npc.collision_layer = 0
	# Through a door: a quick fade there, with its sound. Off the map's edge:
	# the route ends out of view, so the fade is never seen.
	var through_door: bool = route.get_meta("door_sound", false)
	if through_door:
		_play_door_sound(points[-1])
	var fade := PASSENGER_DOOR_FADE_TIME if through_door else PASSENGER_FADE_TIME
	await create_tween().tween_property(npc, "modulate:a", 0.0, fade).finished
	npc.queue_free()

## The door's sound where the passenger goes through, at a moderate level.
## Skipped if another passenger just went through the same way.
func _play_door_sound(at: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_door_sound_msec < int(DOOR_SOUND_MIN_GAP * 1000.0):
		return
	_last_door_sound_msec = now
	var sound := AudioStreamPlayer2D.new()
	sound.stream = DOOR_SOUND
	sound.bus = &"SFX"
	sound.volume_db = DOOR_SOUND_VOLUME_DB
	sound.global_position = at
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

# =========================
# Missing the train
# =========================
## Step 2: she stops, the doors close in front of her, the train leaves.
func _miss_the_train() -> void:
	_train_missed = true
	_doors_open = false
	# The plaza's story moves on here (plaza.gd leaves LIA_HOME on the way
	# down); this scene never reads it back.
	GameManager.plaza_stage = GameManager.PlazaStage.MISSED_TRAIN
	player.lock_control()
	player.face_direction(_train_point() - player.global_position)
	# The camera follows Alice and the tracks may be off screen: frame the
	# doors so the player sees them close, wherever she is.
	await player.pan_camera_to(_train_point() + TRAIN_VIEW_OFFSET, CAMERA_PAN_TIME)
	await get_tree().create_timer(BEFORE_CLOSING_TIME).timeout
	# close_doors() emits doors_closed at once and pulls away 1 s later
	# (leave_station() plays the departure rumble), while her thought stays.
	metro_train.close_doors()
	await ThoughtBox.say(DOORS_CLOSING_LINES)
	# Control comes back as soon as the doors have shut in her face (the
	# train is pulling away by itself, with its sound); the camera glides
	# back to her meanwhile. Her next thoughts play in the cloud while she
	# already walks: thoughts never stop her.
	player.reset_camera(CAMERA_RETURN_TIME)
	player.unlock_control()
	_train_gone_thinking = true
	await ThoughtBox.say(TRAIN_GONE_LINES)
	_train_gone_thinking = false

## Where the train's doors are, to face them: the train's stop at its height.
func _train_point() -> Vector2:
	return Vector2(metro_train.station_position_x, metro_train.global_position.y)

# =========================
# Clara's voice
# =========================
## Step 4 trigger: back near the stairs, once the train is gone. Before
## that, the zone does nothing (she walks through it on her way in).
func _on_hear_clara_zone_entered(body: Node2D) -> void:
	if body != player or not _train_missed or _heard_clara:
		return
	_heard_clara = true
	while _train_gone_thinking:
		await get_tree().process_frame
	player.lock_control()
	await _hear_clara()
	_lead_exit_to_demo_end()
	player.unlock_control()

## Step 4: Clara singing from the plaza; Alice turns towards the stairs.
func _hear_clara() -> void:
	if clara_voice.stream:
		var target_db := clara_voice.volume_db
		clara_voice.volume_db = -60.0
		clara_voice.play()
		create_tween().tween_property(clara_voice, "volume_db", target_db, CLARA_FADE_IN_TIME)
	# She turns at once; with a voice, it plays alone a moment before the cloud.
	player.face_direction(clara_voice.global_position - player.global_position)
	if clara_voice.playing:
		await get_tree().create_timer(CLARA_VOICE_LEAD_TIME).timeout
	await ThoughtBox.say(HEARS_CLARA_LINES)

# =========================
# Ending
# =========================
## Step 5: from now on the stairs end the demo. ExitArea walks her off the
## map (walk_off_screen); with no next_scene_path the ending is ours.
func _lead_exit_to_demo_end() -> void:
	exit_to_plaza.walked_out.connect(_on_exit_walked_out, CONNECT_ONE_SHOT)
	_set_exit_enabled(true)

func _set_exit_enabled(enabled: bool) -> void:
	exit_to_plaza.set_deferred("monitoring", enabled)

func _on_exit_walked_out() -> void:
	FadeTransition.transition_with_interlude(DEMO_END_SCENE, ENDING_LINES, exit_to_plaza.fade_duration)

extends Node2D

# =========================
# Scene configuration
# =========================
## Shown after Alice leaves the store at the end of the conversation.
const PLAZA_SCENE := "res://scenes/plaza_scene/scenes/plaza.tscn"
## Her walk out of the store, told on the black screen of the transition
## (FadeTransition interlude; lines between «» are her thoughts).
const REFLECTION_GAVE_NUMBER: PackedStringArray = [
	"Afuera, la calle sigue siendo desconocida. Pero Alice sabe hacia dónde ir.",
	"Aprieta el ticket con el número de Leo.",
	"«Le di mi número. ¿Qué hice?»",
	"Siente una mezcla de pánico y algo que no sabe nombrar.",
	"Pero sonríe. Nadie la ve, pero sonríe.",
]
const REFLECTION_KEPT_NUMBER: PackedStringArray = [
	"Afuera, la calle sigue siendo desconocida. Pero Alice sabe hacia dónde ir.",
	"Mira el ticket con el número de Leo.",
	"«No me atreví a darle el mío.»",
	"Siente un pequeño peso en el pecho. Pero también que hizo algo que nunca había hecho antes.",
	"«La próxima vez.»",
]
const REFLECTION_END: PackedStringArray = [
	"Guarda el papel con cuidado en la mochila y camina hacia la plaza, como Leo le indicó.",
	"Está un poco menos perdida que antes. Pero todavía no está en casa.",
	"Camina derecho un buen rato, como Leo le indicó. La calle se ensancha, los edificios se abren.",
	"Cuando llega a la plaza, el sol ya empieza a bajar.",
]
## Time to let the fade-in finish before Leo greets her.
const GREETING_DELAY: float = 1.0
## Leo's normal pose: looking at his counter. He only faces the door to wave.
const LEO_IDLE := "idle_side"
## "Rompecabezas de la Ansiedad" played from the timelines with
## [signal arg="anxiety_puzzle:<id>"]. The result goes to {anxiety_result}.
const ANXIETY_PUZZLES := {
	"leo_are_you_ok": preload("res://scenes/leo_store_scene/puzzles/leo_are_you_ok.tres"),
	"leo_number": preload("res://scenes/leo_store_scene/puzzles/leo_number.tres"),
}
## Shelves where Alice looks for the cat food and does not find it
## (InteractableDetectors child -> timeline). The tuna is only on TunaShelf.
const SEARCH_SHELVES := {
	"DrinksShelf": "leo_store_shelf_drinks",
	"PantryShelf": "leo_store_shelf_pantry",
	"CannedShelf": "leo_store_shelf_canned",
	"SnacksShelf": "leo_store_shelf_snacks",
	"CleaningShelf": "leo_store_shelf_cleaning",
}

@onready var player: Player = $MiddleLayer/Player
@onready var leo_sprite: AnimatedSprite2D = $MiddleLayer/NPCS/Leo/AnimatedSprite2D
@onready var leo_counter: InteractableArea = $InteractableDetectors/LeoCounter
@onready var tuna_shelf: InteractableArea = $InteractableDetectors/TunaShelf
@onready var interactables: Node2D = $InteractableDetectors
@onready var exit_to_street: SceneTransitionArea = $InteractableDetectors/ExitToStreet
@onready var crush_thought: ThoughtTrigger = $ThoughtTriggers/CrushThought

## Trying to leave before paying for Wilson's food (user's lines).
const LEAVE_REFUSAL_LINES: Array[String] = [
	"No puedo irme ahora.",
	"Tengo que encontrar la comida de Wilson.",
	"Sé que estás nerviosa, Alice, pero tenemos que hacer esto.",
]
## Pixels she steps back into the store.
const LEAVE_REFUSAL_STEP: float = 16.0

var _refusing: bool = false
var _last_refusal: String = ""

# =========================
# Lifecycle
# =========================
## Flow: Leo greets her -> walking into the aisles she thinks he is cute ->
## she searches the shelves for the tuna -> the conversation at the counter -> Leo says goodbye at the door -> demo end.
## Each step is saved in GameManager, so leaving and coming back resumes it.
func _ready() -> void:
	# The shop door's bell, as she comes in.
	SoundManager.play_sfx("shop_bell")
	Dialogic.signal_event.connect(_on_dialogic_signal)
	# interacted fires right before the area starts its timeline, so each
	# area can still pick the version that matches the current step.
	leo_counter.interacted.connect(_on_counter_interacted)
	tuna_shelf.interacted.connect(_on_shelf_interacted)
	_connect_search_shelves()
	exit_to_street.blocked_interaction.connect(_on_exit_blocked)
	# The door never lets her straight out: before paying for Wilson's food
	# she talks herself out of leaving; after, Leo says goodbye.
	exit_to_street.is_locked = true
	# The crush thought is a floor line on the way into the aisles. It plays
	# once in the whole game, not once per visit to the store.
	if GameManager.leo_crush_thought_shown:
		crush_thought.set_deferred("monitoring", false)
	else:
		crush_thought.body_entered.connect(_on_crush_line_crossed)

	_play_leo_idle()
	if not GameManager.leo_greeted:
		_play_greeting()

# =========================
# Greeting
# =========================
func _play_greeting() -> void:
	player.lock_control()
	await get_tree().create_timer(GREETING_DELAY).timeout
	player.unlock_control()
	Dialogic.start("leo_store_greeting")

func _play_leo_idle() -> void:
	if leo_sprite.sprite_frames.has_animation(LEO_IDLE):
		leo_sprite.play(LEO_IDLE)
	else:
		leo_sprite.play("idle_front")

## Leo keeps waving through the greeting, until Alice turns away to the shelves.
func _wave() -> void:
	if leo_sprite.sprite_frames.has_animation("wave"):
		leo_sprite.play("wave")

# =========================
# Interactions
# =========================
func _on_counter_interacted() -> void:
	if GameManager.leo_talk_done:
		leo_counter.timeline_name = "leo_store_after"
	elif GameManager.leo_has_tuna:
		leo_counter.timeline_name = "leo_store_checkout"
	else:
		leo_counter.timeline_name = "leo_store_counter_early"

func _on_shelf_interacted() -> void:
	if GameManager.leo_has_tuna:
		tuna_shelf.timeline_name = "leo_store_tuna_again"
	else:
		tuna_shelf.timeline_name = "leo_store_tuna"

## Before the tuna each shelf has its own "not here" moment; once Alice has
## the can they all just remind her she already found it.
func _connect_search_shelves() -> void:
	for shelf_name in SEARCH_SHELVES:
		var shelf := interactables.get_node_or_null(NodePath(shelf_name)) as InteractableArea
		if shelf == null:
			push_warning("InteractableDetectors/%s not found" % shelf_name)
			continue
		var search_timeline: String = SEARCH_SHELVES[shelf_name]
		shelf.interacted.connect(func() -> void:
			shelf.timeline_name = "leo_store_shelf_done" if GameManager.leo_has_tuna else search_timeline)

func _on_dialogic_signal(argument: String) -> void:
	match argument:
		"leo_wave":
			_wave()
		"leo_wave_end":
			_play_leo_idle()
		"leo_greeted":
			_play_leo_idle()
		"leo_talk_done":
			pass
		_:
			if argument.begins_with("anxiety_puzzle:"):
				_play_anxiety_puzzle(argument.get_slice(":", 1))

# =========================
# Anxiety puzzle
# =========================
func _play_anxiety_puzzle(puzzle_id: String) -> void:
	var data: AnxietyPuzzleData = ANXIETY_PUZZLES.get(puzzle_id)
	if data == null:
		push_warning("Unknown anxiety puzzle '%s'" % puzzle_id)
		return
	AnxietyPuzzle.play_from_dialogic(self, data)

func _on_crush_line_crossed(body: Node2D) -> void:
	if body is Player:
		GameManager.leo_crush_thought_shown = true

# =========================
# Leaving the store
# =========================
func _on_exit_blocked() -> void:
	if not GameManager.leo_talk_done:
		_refuse_to_leave()
		return
	Dialogic.timeline_ended.connect(_leave_store, CONNECT_ONE_SHOT)
	Dialogic.start("leo_store_farewell")

## Not without Wilson's food: a thought in the cloud and a step back into the
## store, like a map edge. The line changes every time (never the last one).
func _refuse_to_leave() -> void:
	if _refusing:
		return
	_refusing = true
	var choices := LEAVE_REFUSAL_LINES.filter(func(line: String) -> bool:
		return line != _last_refusal)
	_last_refusal = choices.pick_random()
	var lines: Array[String] = [_last_refusal]
	ThoughtBox.say(lines)
	player.lock_control()
	player.play_animation("walk_back", "idle_back")
	var step := create_tween()
	step.tween_property(player, "global_position", player.global_position + Vector2.UP * LEAVE_REFUSAL_STEP, 0.35)
	await step.finished
	player.face_direction(Vector2.UP)
	player.update_interaction_detector_position()
	player.unlock_control()
	_refusing = false

func _leave_store() -> void:
	player.lock_control()
	var reflection := REFLECTION_GAVE_NUMBER if GameManager.leo_gave_number else REFLECTION_KEPT_NUMBER
	# She walks into the plaza from the street (plaza SpawnPoints/FromStreet).
	GameManager.spawn_point = "FromStreet"
	FadeTransition.transition_with_interlude(PLAZA_SCENE, reflection + REFLECTION_END,
		exit_to_street.fade_duration)

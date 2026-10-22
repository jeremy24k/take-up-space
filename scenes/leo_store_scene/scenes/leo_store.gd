extends Node2D

# =========================
# Scene configuration
# =========================
## Shown after Alice leaves the store at the end of the conversation.
const DEMO_END_SCENE := "res://scenes/demo_end/demo_end.tscn"
## Time to let the fade-in finish before Leo greets her.
const GREETING_DELAY: float = 1.0
## Leo's normal pose: looking at his counter. He only faces the door to wave.
const LEO_IDLE := "idle_side"
## "Rompecabezas de la Ansiedad" played from the timelines with
## [signal arg="anxiety_puzzle:<id>"]. The result goes to {anxiety_result}.
const ANXIETY_PUZZLE_SCENE := preload("res://global/anxiety_puzzle/anxiety_puzzle.tscn")
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

# =========================
# Lifecycle
# =========================
## Flow: Leo greets her -> walking into the aisles she thinks he is cute ->
## she searches the shelves for the tuna -> the conversation at the counter -> Leo says goodbye at the door -> demo end.
## Each step is saved in GameManager, so leaving and coming back resumes it.
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	# interacted fires right before the area starts its timeline, so each
	# area can still pick the version that matches the current step.
	leo_counter.interacted.connect(_on_counter_interacted)
	tuna_shelf.interacted.connect(_on_shelf_interacted)
	_connect_search_shelves()
	exit_to_street.blocked_interaction.connect(_on_exit_blocked)
	# Once they talked, leaving goes through Leo's goodbye instead of the street.
	exit_to_street.is_locked = GameManager.leo_talk_done
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
			exit_to_street.is_locked = true
		_:
			if argument.begins_with("anxiety_puzzle:"):
				_play_anxiety_puzzle(argument.get_slice(":", 1))

# =========================
# Anxiety puzzle
# =========================
## Pausing Dialogic here, inside the signal event, keeps it from running the
## next event (the if on {anxiety_result}) until the puzzle has an answer.
func _play_anxiety_puzzle(puzzle_id: String) -> void:
	var data: AnxietyPuzzleData = ANXIETY_PUZZLES.get(puzzle_id)
	if data == null:
		push_warning("Unknown anxiety puzzle '%s'" % puzzle_id)
		return
	Dialogic.paused = true
	var puzzle := ANXIETY_PUZZLE_SCENE.instantiate() as AnxietyPuzzle
	add_child(puzzle)
	var result := await puzzle.run(data)
	Dialogic.VAR.set_variable("anxiety_result", result)
	Dialogic.paused = false

func _on_crush_line_crossed(body: Node2D) -> void:
	if body is Player:
		GameManager.leo_crush_thought_shown = true

# =========================
# Leaving the store
# =========================
func _on_exit_blocked() -> void:
	Dialogic.timeline_ended.connect(_leave_store, CONNECT_ONE_SHOT)
	Dialogic.start("leo_store_farewell")

func _leave_store() -> void:
	player.lock_control()
	FadeTransition.transition_to_scene(DEMO_END_SCENE, exit_to_street.fade_duration)

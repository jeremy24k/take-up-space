extends Node

# =========================
# Quest state
# =========================
# Door used to enter the train interior.
var target_door_id: int = 1

# True after Alice checks the backpack.
var prep_items_unlocked: bool = false

# False once she realizes she left her phone on the train.
var has_phone: bool = true

# Bathroom mirror: she has looked at herself once ("Tienes ojeras"), and she
# has rehearsed in front of it before leaving (the door waits for this).
var mirror_seen: bool = false
var mirror_practice_done: bool = false

@export var quest_step: int = 0
var collected_items: Array[String] = []  # List of collected item IDs

var missing_prep_items: Array[String] = [  # Items needed before the quest can start
	"alice_wallet",
	"alice_headphones",
	"alice_shoes",
]

var wilson: Wilson = null

# =========================
# Street clues
# =========================
# IDs of the clues about Leo's store Alice has already seen (e.g. "delivery").
var found_clues: Array[String] = []
## Street beats that play only once, even if Alice comes back from Leo's store.
var street_arrival_seen: bool = false
var glass_tower_seen: bool = false
## The arguing couple stepped aside: the zebra crossing by the café stays free.
var street_couple_cleared: bool = false
## Times Alice chose to wait at the couple: each wait overhears a new bit of
## their fight (street_couple.dtl branches on it).
var street_couple_waits: int = 0
## The dusty car's owner drove off with Alice's cat drawing: the car is gone.
var street_car_gone: bool = false

# =========================
# Plaza (midgame)
# =========================
## Where Alice is in the plaza's story (plaza.gd drives it):
## ARRIVED: she just got there; Lía cries on a bench across the plaza.
## WITH_LIA: Lía holds her sleeve; they ask around the plaza (the ice-cream
## man, the woman with the dog, the guy with headphones, in any order).
## KNOWS_FOUNTAIN: enough clues point to the fountain.
## LIA_HOME: Lía is back with her mother; the last train has already left.
## MISSED_TRAIN: the gate is down. Night.
enum PlazaStage { ARRIVED, WITH_LIA, KNOWS_FOUNTAIN, LIA_HOME, MISSED_TRAIN }
var plaza_stage: PlazaStage = PlazaStage.ARRIVED
## Trust Alice builds with Lía through her choices. Saved for later scenes.
var lia_confidence: int = 0
## True if Alice went to Lía on her own (instead of Lía coming after her).
var lia_approached_first: bool = false
## True if Alice walked off towards the metro and Lía ran after her.
var lia_tried_to_leave: bool = false
## Who already gave a clue about Lía's mother ("ice_cream", "dog_lady", "teen").
var lia_clues: Array[String] = []
## Helpers already talked to once Alice knows about the fountain (their
## goodbye "_extra" talk, or the full talk of the one she never asked):
## [signal arg="lia_extra:<clue id>"] or a late lia_clue (plaza.gd).
var lia_extras: Array[String] = []
## Alice has her two clues and is on her way to the fountain. Read by the
## helpers' timelines ({GameManager.lia_knows_fountain}) for their variant.
var lia_knows_fountain: bool:
	get:
		return plaza_stage == PlazaStage.KNOWS_FOUNTAIN
## True once Lía stopped to watch the pigeons (it happens only once).
var lia_pigeons_seen: bool = false
## Curiosity points Lía already went to look at (CuriosityPoint names).
var lia_curiosities_seen: Array[String] = []
## Whether Alice talked to a plaza helper with Lía (they gave their clue, or
## their talk once she knew about the fountain). The getters are for the
## timelines: {GameManager.lia_met_ice_cream} and so on.
func lia_has_met(helper: String) -> bool:
	return lia_clues.has(helper) or lia_extras.has(helper)
var lia_met_ice_cream: bool:
	get:
		return lia_has_met("ice_cream")
var lia_met_dog_lady: bool:
	get:
		return lia_has_met("dog_lady")
var lia_met_teen: bool:
	get:
		return lia_has_met("teen")
## True if Alice shouted at the boy with headphones (Lía teases her about it).
var lia_teen_loud: bool = false
## "feliz" or "agridulce": how well Alice held up until the mother came.
var lia_outcome: String = "feliz"

# Emitted the first time each clue is found (the street's "lost" reminder
# restarts its clock on it).
signal clue_added(clue_id: String)

func add_clue(clue_id: String) -> void:
	if not found_clues.has(clue_id):
		found_clues.append(clue_id)
		clue_added.emit(clue_id)

func has_any_clue(clue_ids: Array[String]) -> bool:
	for clue_id in clue_ids:
		if found_clues.has(clue_id):
			return true
	return false

# =========================
# Seen object types
# =========================
# RemarkInteractable group ids (e.g. "vending") Alice has already looked at,
# in any scene. The first one of a type gets its full scene, the rest a
# one-line remark ("Otra máquina...").
var seen_object_groups: Array[String] = []

func has_seen_group(group_id: String) -> bool:
	return seen_object_groups.has(group_id)

func mark_group_seen(group_id: String) -> void:
	if not seen_object_groups.has(group_id):
		seen_object_groups.append(group_id)

# =========================
# Leo's store
# =========================
var leo_greeted: bool = false
var leo_crush_thought_shown: bool = false
var leo_has_tuna: bool = false
var leo_talk_done: bool = false
## Trust Alice builds with Leo through her choices. Saved for later scenes.
var leo_confidence: int = 0
## True if Alice asked for Leo's number herself instead of waiting for him.
var leo_alice_took_initiative: bool = false
## True if Alice gave Leo her own number.
var leo_gave_number: bool = false
## True once Alice told Leo her cat is called Wilson.
var leo_knows_wilson: bool = false

# Emitted every time the quest step changes.
signal quest_step_changed(new_step: int)

# =========================
# Setup
# =========================
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)

# =========================
# New game
# =========================
## Not state: a live node and a computed text.
const NOT_RESET: PackedStringArray = ["wilson", "missing_prep_text"]

## Puts every piece of state back to how a new game starts (the demo end's
## "Empezar de nuevo"). The defaults come from a fresh copy of this script
## (Script.get_property_default_value only knows @export ones), so a variable
## added later is reset too without touching this.
func reset() -> void:
	var fresh: Node = get_script().new()
	for property in get_script().get_script_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or property.name in NOT_RESET:
			continue
		var value: Variant = fresh.get(property.name)
		if value is Array or value is Dictionary:
			value = value.duplicate(true)
		set(property.name, value)
	fresh.free()
	quest_step_changed.emit(quest_step)
	outfit_changed.emit()

# =========================
# Dialogic event handling
# =========================
func _on_dialogic_signal(argument: String) -> void:
	match argument:
		"step_1":
			if quest_step < 1:
				set_quest_step(1)
		"step_2":
			if quest_step == 1:
				set_quest_step(2)
		"step_3":
			if quest_step == 2:
				set_quest_step(3)
		"prep_items_unlocked":
			prep_items_unlocked = true
		"no_phone":
			has_phone = false
		"mirror_seen":
			mirror_seen = true
		"mirror_practice_done":
			mirror_practice_done = true
		"step_4":
			if quest_step == 3 and has_all_prep_items():  # All required items collected
				set_quest_step(4)
		"leo_greeted":
			leo_greeted = true
		"leo_tuna_taken":
			leo_has_tuna = true
		"leo_took_initiative":
			leo_alice_took_initiative = true
		"leo_number":
			add_item("leo_number")
		"leo_gave_number":
			leo_gave_number = true
		"leo_knows_wilson":
			leo_knows_wilson = true
		"leo_talk_done":
			leo_talk_done = true
		"couple_waited":
			street_couple_waits += 1
		"lia_approached_first":
			lia_approached_first = true
		"lia_tried_to_leave":
			lia_tried_to_leave = true
		"lia_bittersweet":
			lia_outcome = "agridulce"
		"lia_teen_loud":
			lia_teen_loud = true
		"headphones_on":
			set_headphones_on_head(true)
		"headphones_off":
			set_headphones_on_head(false)
		_:
			# "leo_confidence:<amount>", e.g. "leo_confidence:-1".
			if argument.begins_with("leo_confidence:"):
				leo_confidence += int(argument.get_slice(":", 1))
			elif argument.begins_with("lia_confidence:"):
				lia_confidence += int(argument.get_slice(":", 1))
			elif argument.begins_with("lia_extra:"):
				var helper := argument.get_slice(":", 1)
				if not lia_extras.has(helper):
					lia_extras.append(helper)

# =========================
# Quest progression
# =========================
func set_quest_step(new_step: int) -> void:
	quest_step = new_step
	quest_step_changed.emit(quest_step)
	print("Quest step: ", quest_step)

# =========================
# Item collection
# =========================
func add_item(item_id: String) -> void:
	if not collected_items.has(item_id):
		collected_items.append(item_id)
		print("Item added to GameManager: ", item_id)
		print("Missing items: ", get_missing_items_count())
		outfit_changed.emit()

# =========================
# Outfit
# =========================
## What Alice wears follows what she picked up (shoes, backpack, headphones).
## The headphones hang around her neck, and only go on her head at specific
## moments: she puts them on to sleep on the train and takes them off when she
## gets off, lost. Dialogic: [signal arg="headphones_on"] / "headphones_off".
var headphones_on_head: bool = false

## Emitted when anything Alice wears changes; the Player redraws its layers.
signal outfit_changed

func set_headphones_on_head(on_head: bool) -> void:
	if headphones_on_head == on_head:
		return
	headphones_on_head = on_head
	outfit_changed.emit()

func is_item_collected(item_id: String) -> bool:
	return collected_items.has(item_id)

func are_prep_items_unlocked() -> bool:
	return prep_items_unlocked

# =========================
# Quest validation
# =========================
func has_all_prep_items() -> bool:
	for item_id in missing_prep_items:
		if not is_item_collected(item_id):
			return false
	return true

## What Alice still lacks to leave, in words for the blocked front door
## (alice_cant_leave_yet.dtl: {GameManager.missing_prep_text}). Before she
## opens the backpack she only knows she needs the backpack; after, the items
## still missing ("la cartera y los zapatos"). In the player's language.
var missing_prep_text: String:
	get:
		var names: Array[String] = []
		if not prep_items_unlocked:
			names.append(_prep_item_name("alice_backpack"))
		else:
			for item_id in missing_prep_items:
				if not is_item_collected(item_id):
					names.append(_prep_item_name(item_id))
		if names.size() <= 1:
			return "".join(names)
		return "%s %s %s" % [", ".join(names.slice(0, -1)), tr("y"), names[-1]]

func _prep_item_name(item_id: String) -> String:
	match item_id:
		"alice_backpack":
			return tr("la mochila")
		"alice_wallet":
			return tr("la cartera")
		"alice_headphones":
			return tr("los auriculares")
		"alice_shoes":
			return tr("los zapatos")
	return item_id

## Counts only the prep items still missing. The backpack (and any other item)
## also lands in collected_items, so subtracting sizes went negative.
func get_missing_items_count() -> int:
	var missing: int = 0
	for item_id in missing_prep_items:
		if not is_item_collected(item_id):
			missing += 1
	return missing
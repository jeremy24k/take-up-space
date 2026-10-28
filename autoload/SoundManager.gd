extends Node

# =========================
# Sound configuration
# =========================
## Plays the game's music, ambience and sound effects, each on its own bus
## (Music, Ambience, SFX: default_bus_layout.tres). Every scene says what
## plays in it with a SceneAudio node; this autoload outlives the scene
## changes, so one scene's sound fades into the next instead of cutting off.
const FADE_TIME: float = 1.5
const SILENT_DB: float = -60.0
## Effects a Dialogic timeline can play with [signal arg="sfx:<name>"].
const SFX := {
	"meow": preload("res://audio/sfx/meow.ogg"),
	"door_open": preload("res://audio/sfx/door_open.ogg"),
	"shop_bell": preload("res://audio/sfx/shop_bell.ogg"),
	"train_chime": preload("res://audio/sfx/train_chime.ogg"),
}
const SFX_SIGNAL_PREFIX := "sfx:"
## Muffled ("under water"): music and ambience lose their highs through the
## low-pass filter on their buses and drop a little, so Alice's own body
## (heartbeat, breathing on the SFX bus) is what she hears.
const MUFFLED_BUSES: Array[StringName] = [&"Music", &"Ambience"]
const MUFFLED_CUTOFF_HZ: float = 500.0
const OPEN_CUTOFF_HZ: float = 20000.0
const MUFFLED_DUCK_DB: float = -6.0
const MUFFLE_TIME: float = 0.6

## Two players per channel: the old stream fades out on one while the new
## one fades in on the other.
var _music: Array[AudioStreamPlayer] = []
var _ambience: Array[AudioStreamPlayer] = []
var _fades := {}
var _bus_volumes := {}
var _muffle_tween: Tween

# =========================
# Setup
# =========================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		_music.append(_make_player(&"Music"))
		_ambience.append(_make_player(&"Ambience"))
	Dialogic.signal_event.connect(_on_dialogic_signal)
	for bus in MUFFLED_BUSES:
		var index := AudioServer.get_bus_index(bus)
		_bus_volumes[bus] = AudioServer.get_bus_volume_db(index)

func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player

# =========================
# Public API
# =========================
## Fades to this music (null = silence). The same stream keeps playing
## where it was, only its volume changes.
func set_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	_crossfade(_music, stream, volume_db)

## Same as set_music, for the background sound of a place.
func set_ambience(stream: AudioStream, volume_db: float = 0.0) -> void:
	_crossfade(_ambience, stream, volume_db)

## Plays a short sound once: a stream, or a name from SFX. Returns its player
## (freed by itself when the sound ends) for callers that want to fade it.
func play_sfx(sound: Variant, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream = SFX.get(sound) if sound is String else sound
	if stream == null:
		push_warning("SoundManager: unknown sound '%s'" % sound)
		return null
	var player := _make_player(&"SFX")
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	player.play()
	return player

## Muffles music and ambience (true) or brings them back (false). Used while
## Alice is caught in an anxiety puzzle.
func set_muffled(is_muffled: bool) -> void:
	if _muffle_tween:
		_muffle_tween.kill()
	_muffle_tween = create_tween().set_parallel(true)
	for bus in MUFFLED_BUSES:
		var index := AudioServer.get_bus_index(bus)
		var filter := AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
		if filter:
			_muffle_tween.tween_property(filter, "cutoff_hz",
				MUFFLED_CUTOFF_HZ if is_muffled else OPEN_CUTOFF_HZ, MUFFLE_TIME)
		var base: float = _bus_volumes[bus]
		_muffle_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(index, db),
			AudioServer.get_bus_volume_db(index),
			base + MUFFLED_DUCK_DB if is_muffled else base, MUFFLE_TIME)

# =========================
# Cross-fade
# =========================
func _crossfade(pair: Array[AudioStreamPlayer], stream: AudioStream, volume_db: float) -> void:
	var current := pair[0]
	if stream != null and current.playing and current.stream == stream:
		_fade(current, volume_db)
		return
	if current.playing:
		_fade(current, SILENT_DB, true)
	# The other player takes over; it may still be fading out an older stream.
	pair.reverse()
	if stream == null:
		return
	var next := pair[0]
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_fade(next, volume_db)

func _fade(player: AudioStreamPlayer, to_db: float, stop_after := false) -> void:
	var previous: Tween = _fades.get(player)
	if previous:
		previous.kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, FADE_TIME)
	if stop_after:
		tween.tween_callback(player.stop)
	_fades[player] = tween

# =========================
# Dialogic
# =========================
func _on_dialogic_signal(argument: Variant) -> void:
	if argument is String and argument.begins_with(SFX_SIGNAL_PREFIX):
		play_sfx(argument.trim_prefix(SFX_SIGNAL_PREFIX))

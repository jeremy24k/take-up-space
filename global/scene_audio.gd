class_name SceneAudio
extends Node

# =========================
# Scene sound
# =========================
## What sounds in this scene: put one SceneAudio in each playable scene and
## pick the streams in the inspector. On entering the scene, SoundManager
## fades from the previous scene's sound to these. An empty slot means
## silence: the previous music or ambience fades out. A scene without a
## SceneAudio leaves whatever was playing.
@export var ambience: AudioStream
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var ambience_volume_db: float = 0.0
@export var music: AudioStream
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var music_volume_db: float = 0.0

func _ready() -> void:
	SoundManager.set_ambience(ambience, ambience_volume_db)
	SoundManager.set_music(music, music_volume_db)

extends Node

# =========================
# Forced exit (macOS crash workaround)
# =========================
## Godot 4.7 crashes on macOS (signal 11 inside NSApplication terminate) when
## the game closes after any scene with a TileMapDual has been loaded. The
## crash is in the addon/engine teardown, not in the game, so on macOS every
## way out of the game skips that teardown and ends the process directly.
## There is nothing to save, so nothing is lost. Other platforms quit normally.
## See DOCS.md, "Cosas pendientes".

# =========================
# Setup
# =========================
func _ready() -> void:
	# Cmd+Q and the window's close button arrive as a close request; handle it
	# here instead of letting Godot run its normal (crashing) shutdown.
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

# =========================
# Public API
# =========================
## Closes the game. Use this instead of get_tree().quit().
func quit_game() -> void:
	if OS.get_name() == "macOS":
		OS.kill(OS.get_process_id())
	else:
		get_tree().quit()

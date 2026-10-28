class_name RemarkPool
extends Resource

# =========================
# Shared remark lines
# =========================
## Short lines shared by many RemarkInteractables (e.g. every ambient NPC).
## One is picked at random, never the same one twice in a row.
@export var lines: Array[String] = []

var _last_index: int = -1

func pick_line() -> String:
	if lines.is_empty():
		return ""
	if lines.size() == 1:
		return lines[0]
	var index: int
	if _last_index < 0:
		index = randi() % lines.size()
	else:
		# Pick among the others by skipping over the last line.
		index = randi() % (lines.size() - 1)
		if index >= _last_index:
			index += 1
	_last_index = index
	return lines[index]

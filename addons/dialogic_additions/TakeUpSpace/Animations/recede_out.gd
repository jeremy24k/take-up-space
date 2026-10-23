extends DialogicAnimation

# =========================
# Recede out
# =========================
## Alice's portrait leaving: it dims to a cool grey, shrinks a little towards
## her feet and fades, so going from talking to thinking feels like a change
## of focus instead of a cut. Default leave animation of the project
## (dialogic/animations/leave_default).
const DIM_COLOR := Color(0.62, 0.62, 0.74, 0.0)
const END_SCALE: float = 0.96
const SINK: float = 6.0

func animate() -> void:
	var modulation_property := get_modulation_property()
	var tween := (node.create_tween() as Tween).set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, modulation_property, DIM_COLOR, time)
	tween.tween_property(node, "scale", base_scale * END_SCALE, time)
	tween.tween_property(node, "position", base_position + Vector2(0, SINK), time)
	await tween.finished
	finished_once.emit()

func _get_named_variations() -> Dictionary:
	return {
		"recede out": {"reversed": true, "type": AnimationType.OUT},
	}

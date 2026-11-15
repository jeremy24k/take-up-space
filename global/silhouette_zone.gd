class_name SilhouetteZone
extends Area2D

# =========================
# Silhouette zone
# =========================
## Covers the ground behind something tall that hides Alice completely (the
## glass tower): while she walks there, her silhouette shows through it
## (Player.set_silhouette). Draw the shape only over the part she is hidden
## in, not where she passes in front.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.set_silhouette(true)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.set_silhouette(false)

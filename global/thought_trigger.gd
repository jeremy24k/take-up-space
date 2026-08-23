class_name ThoughtTrigger
extends Area2D

@export var thought_text: String = "I'm thinking..."
@export var thought_lines: Array[String] = []
@export var display_duration: float = 2.5
@export var trigger_once: bool = true

@onready var label_template: Label = $Label

func _ready() -> void:
	label_template.hide()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		show_thought(body)

		if trigger_once:
			set_deferred("monitoring", false)
			# Nota: No destruimos el Area2D inmediatamente si queremos que el script termine limpiamente, 
			# o si usas trigger_once puedes simplemente desactivar el monitoreo.

func show_thought(player_node: CharacterBody2D) -> void:
	var lines: Array[String] = []
	if thought_lines.is_empty():
		lines.append(thought_text)
	else:
		lines = thought_lines
	_play_thought_sequence(player_node, lines)

func _play_thought_sequence(player_node: CharacterBody2D, lines: Array[String]) -> void:
	# 1. Si ya hay un pensamiento activo en Alice, lo eliminamos
	if player_node.has_node("ThoughtBubble"):
		player_node.get_node("ThoughtBubble").queue_free()

	# Create one bubble and reuse it for every line.
	var new_label: Label = label_template.duplicate() as Label
	new_label.name = "ThoughtBubble"
	
	# Add the copy directly as a child of Alice.
	player_node.add_child(new_label)
	
	# 3. Configuración de tamaño y envolvente
	var max_width: float = 110.0
	new_label.custom_minimum_size = Vector2(max_width, 0.0)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Forzamos el cálculo de dimensiones reales según el número de líneas
	new_label.reset_size()
	
	# 4. Posicionamiento dinámico hacia ARRIBA
	# Le restamos new_label.size.y para que la parte INFERIOR del texto quede siempre sobre la cabeza
	var base_height_above_head: float = 24.0 # Ajusta la altura deseada sobre el personaje
	new_label.position = Vector2(-max_width / 2.0, -new_label.size.y - base_height_above_head)
	
	# Show each line in order using the same bubble.
	for line in lines:
		if line.is_empty():
			continue

		new_label.text = line
		new_label.reset_size()
		new_label.position = Vector2(-max_width / 2.0, -new_label.size.y - base_height_above_head)
		new_label.show()
		new_label.modulate.a = 0.0

		var tween := player_node.create_tween()
		tween.tween_property(new_label, "modulate:a", 1.0, 0.3)
		tween.tween_interval(display_duration)
		tween.tween_property(new_label, "modulate:a", 0.0, 0.4)
		await tween.finished

	new_label.queue_free()

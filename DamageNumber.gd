extends Node2D

var velocity = Vector2(0, -60)
var lifetime = 0.8

func setup(amount, pos):
	global_position = pos
	$Label.text = str(amount)
	$Label.add_color_override("font_color", Color(1, 0.3, 0.3))

func _process(delta):
	position += velocity * delta
	lifetime -= delta
	modulate.a = lifetime / 0.8  # плавно исчезает
	if lifetime <= 0:
		queue_free()

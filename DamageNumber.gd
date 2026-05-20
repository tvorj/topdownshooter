extends Node2D

const SCALE_FACTOR = 2.8
const POP_SCALE = Vector2(3.4, 3.4)
const POP_DURATION = 0.12

var velocity = Vector2(0, -80)
var lifetime = 1.2
var max_lifetime = 1.2
var age = 0.0


func setup(amount, pos):
	global_position = pos
	$Label.text = str(amount)
	$Label.add_color_override("font_color", Color(1, 0.25, 0.25))
	$Label.add_color_override("font_color_shadow", Color(0, 0, 0, 0.85))
	$Label.add_constant_override("shadow_offset_x", 2)
	$Label.add_constant_override("shadow_offset_y", 2)
	$Label.add_constant_override("shadow_as_outline", 1)
	$Label.rect_scale = Vector2(SCALE_FACTOR, SCALE_FACTOR)
	call_deferred("_center_pivot")


func _center_pivot():
	if not is_inside_tree():
		return
	var size = $Label.get_minimum_size()
	$Label.rect_pivot_offset = size / 2.0
	$Label.rect_position = -size / 2.0


func _process(delta):
	age += delta
	position += velocity * delta

	# Quick scale pop at the start, then settle.
	if age < POP_DURATION:
		var t = age / POP_DURATION
		var s = POP_SCALE.linear_interpolate(Vector2(SCALE_FACTOR, SCALE_FACTOR), t)
		$Label.rect_scale = s

	lifetime -= delta
	modulate.a = clamp(lifetime / max_lifetime, 0.0, 1.0)
	if lifetime <= 0:
		queue_free()

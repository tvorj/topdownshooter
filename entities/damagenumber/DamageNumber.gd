extends Node2D

const SETTLE_SCALE = 1.5
const POP_SCALE = 1.95
const POP_DURATION = 0.12
const HOLD_TIME = 0.7   # full alpha duration
const FADE_TIME = 0.4   # fade-out duration

const HP_COLOR = Color(1.0, 0.32, 0.32, 1)
const ARMOR_COLOR = Color(0.78, 0.82, 0.88, 1)

var velocity = Vector2(0, -90)
var age = 0.0


func setup(amount, pos, hit_armor_only = false):
	global_position = pos
	var label = $Label
	label.text = str(amount)
	label.add_color_override("font_color", ARMOR_COLOR if hit_armor_only else HP_COLOR)
	label.add_color_override("font_color_shadow", Color(0, 0, 0, 1.0))
	label.add_constant_override("shadow_offset_x", 2)
	label.add_constant_override("shadow_offset_y", 2)
	label.add_constant_override("shadow_as_outline", 1)

	# Center the label on the Node2D origin so scale pivots around the hit point.
	label.rect_size = Vector2(80, 24)
	label.rect_position = Vector2(-40, -12)
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER

	scale = Vector2(POP_SCALE, POP_SCALE)
	modulate.a = 1.0


func _process(delta):
	age += delta
	position += velocity * delta

	# Scale pop at the start, then settle.
	if age < POP_DURATION:
		var t = age / POP_DURATION
		var s = lerp(POP_SCALE, SETTLE_SCALE, t)
		scale = Vector2(s, s)
	else:
		scale = Vector2(SETTLE_SCALE, SETTLE_SCALE)

	# Hold full alpha, then fade out at the end.
	if age < HOLD_TIME:
		modulate.a = 1.0
	elif age < HOLD_TIME + FADE_TIME:
		modulate.a = 1.0 - (age - HOLD_TIME) / FADE_TIME
	else:
		queue_free()

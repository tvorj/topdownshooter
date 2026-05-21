extends Area2D

const _SND_PICKUP = preload("res://assets/audio/ammopickup.ogg")

export var ammo_amount = 6
export var life_time = 20.0
export var bob_speed = 4.0
export var bob_height = 4.0

onready var tween = $Tween
onready var polygon = $Polygon2D
onready var collision_shape = $CollisionShape2D

var base_position = Vector2.ZERO
var age = 0.0
var picked = false


func _ready():
	print("AmmoPickup ready at: ", global_position)

	add_to_group("ammo_pickup")

	monitoring = true
	monitorable = true

	z_index = 50

	if polygon:
		polygon.z_index = 50
		polygon.visible = true
		polygon.color = Color(1, 0.8, 0.1, 1)

	if collision_shape:
		collision_shape.disabled = false

	if not is_connected("body_entered", self, "_on_AmmoPickup_body_entered"):
		connect("body_entered", self, "_on_AmmoPickup_body_entered")

	base_position = global_position

	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0

	tween.interpolate_property(
		self,
		"scale",
		Vector2(0.2, 0.2),
		Vector2(1.0, 1.0),
		0.25,
		Tween.TRANS_BACK,
		Tween.EASE_OUT
	)

	tween.interpolate_property(
		self,
		"modulate:a",
		0.0,
		1.0,
		0.25,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)

	tween.start()


func _process(delta):
	if picked:
		return

	age += delta

	global_position.y = base_position.y + sin(age * bob_speed) * bob_height

	if age >= life_time:
		despawn()


func _on_AmmoPickup_body_entered(body):
	print("AmmoPickup touched by: ", body.name)

	if picked:
		return

	if body.has_method("add_ammo"):
		var was_added = body.add_ammo(ammo_amount)

		print("Ammo added result: ", was_added)

		if was_added:
			pickup()
	else:
		print("Body has no add_ammo method")


func pickup():
	picked = true
	print("AmmoPickup collected")
	_play_pickup_sound()
	tween.stop_all()

	tween.interpolate_property(
		self,
		"scale",
		scale,
		Vector2(1.4, 1.4),
		0.12,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)

	tween.interpolate_property(
		self,
		"modulate:a",
		modulate.a,
		0.0,
		0.12,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)

	tween.start()

	yield(tween, "tween_all_completed")
	queue_free()


func _play_pickup_sound():
	var snd = AudioStreamPlayer.new()
	snd.stream = _SND_PICKUP
	snd.stream.loop = false
	snd.volume_db = -6.0
	get_parent().add_child(snd)
	snd.play()
	snd.connect("finished", snd, "queue_free")


func despawn():
	picked = true
	print("AmmoPickup despawned")

	tween.stop_all()

	tween.interpolate_property(
		self,
		"scale",
		scale,
		Vector2(0.2, 0.2),
		0.2,
		Tween.TRANS_SINE,
		Tween.EASE_IN
	)

	tween.interpolate_property(
		self,
		"modulate:a",
		modulate.a,
		0.0,
		0.2,
		Tween.TRANS_SINE,
		Tween.EASE_IN
	)

	tween.start()

	yield(tween, "tween_all_completed")
	queue_free()

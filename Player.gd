extends KinematicBody2D

export(PackedScene) var BulletScene
export var speed = 200
export var hp = 30

onready var aim = $Aim

func _physics_process(delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1

	direction = direction.normalized()
	move_and_slide(direction * speed)

func _process(delta):
	aim.look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("click"):
		shoot()

func shoot():
	print("shoot called!")  # проверка что функция вызывается
	if BulletScene == null:
		print("BulletScene не назначена!")
		return
	var bullet = BulletScene.instance()
	get_parent().add_child(bullet)
	bullet.global_position = aim.global_position
	var dir = (get_global_mouse_position() - bullet.global_position).normalized()
	bullet.direction = dir
	bullet.owner_node = self

func take_damage(amount):
	hp -= amount
	print("Player HP: ", hp)

	if hp <= 0:
		die()

func die():
	print("Player died")
	get_tree().reload_current_scene()
	
#func shoot():
#	var bullet = BulletScene.instance()
#	get_parent().add_child(bullet)
#
#	bullet.global_position = aim.global_position
#
#	var dir = (get_global_mouse_position() - bullet.global_position).normalized()
#	bullet.direction = dir

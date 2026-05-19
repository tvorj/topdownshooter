extends KinematicBody2D

export(PackedScene) var BulletScene
export var speed = 200
export var hp = 30
export(PackedScene) var DamageNumberScene
export var vision_distance = 400
export var vision_angle = 120
var aim_angle = 0.0

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
	update()
	aim.look_at(get_global_mouse_position())
	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
	aim_angle = mouse_dir.angle()
	
	# Скрываем врагов вне FOV
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.visible = can_see(enemy)
	
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

	if DamageNumberScene:
		var dmg = DamageNumberScene.instance()
		get_parent().add_child(dmg)
		dmg.setup(amount, global_position)
	
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

func _draw():
	var half_angle = deg2rad(vision_angle / 2)
	var points = [Vector2.ZERO]
	
	var steps = 20
	for i in range(steps + 1):
		var angle = aim_angle - half_angle + (half_angle * 2 / steps) * i
		points.append(Vector2.RIGHT.rotated(angle) * vision_distance)
	
	points.append(Vector2.ZERO)
	draw_colored_polygon(PoolVector2Array(points), Color(1, 1, 0, 0.1))
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(aim_angle - half_angle) * vision_distance, Color(1, 1, 0, 0.3), 1.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(aim_angle + half_angle) * vision_distance, Color(1, 1, 0, 0.3), 1.0)

func can_see(target) -> bool:
	var to_target = target.global_position - global_position
	
	# Проверяем дистанцию
	if to_target.length() > vision_distance:
		return false
	
	# Проверяем угол
	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
	var angle_to_target = rad2deg(mouse_dir.angle_to(to_target.normalized()))
	if abs(angle_to_target) > vision_angle / 2:
		return false
	
	# Проверяем стены
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(global_position, target.global_position, [self])
	if result and result.collider != target:
		return false
	
	return true

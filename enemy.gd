extends KinematicBody2D

export var speed = 80
export var hp = 3

export var vision_distance = 500
export var vision_angle = 103

export(PackedScene) var BulletScene
export var shoot_cooldown = 1.0
export var attack_distance = 350
export(PackedScene) var DamageNumberScene

var player = null
var shoot_timer = 0.0

# AI movement
export var patrol_speed = 45
export var search_speed = 65
export var change_direction_time = 1.5
export var search_duration = 3.0

enum EnemyState {
	PATROL,
	CHASE,
	SEARCH
}

var state = EnemyState.PATROL

var patrol_direction = Vector2.RIGHT
var patrol_timer = 0.0

var last_seen_position = Vector2.ZERO
var search_timer = 0.0

func _ready():
	randomize()
	choose_new_patrol_direction()

	var players = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found in group 'player'")

func _physics_process(delta):
	update()

	if player == null:
		return

	shoot_timer -= delta

	var sees_player = can_see_player()

	if sees_player:
		state = EnemyState.CHASE
		last_seen_position = player.global_position
		search_timer = search_duration
	elif state == EnemyState.CHASE:
		state = EnemyState.SEARCH

	match state:
		EnemyState.PATROL:
			patrol(delta)

		EnemyState.CHASE:
			chase_and_attack()

		EnemyState.SEARCH:
			search_player(delta)

func shoot_at_player():
	if BulletScene == null:
		print("Enemy BulletScene не назначена!")
		return

	var bullet = BulletScene.instance()
	get_parent().add_child(bullet)

	bullet.global_position = global_position
	bullet.direction = (player.global_position - global_position).normalized()
	bullet.damage = 1
	bullet.owner_node = self

func patrol(delta):
	patrol_timer -= delta

	if patrol_timer <= 0:
		choose_new_patrol_direction()

	look_at(global_position + patrol_direction)

	move_and_slide(patrol_direction * patrol_speed)

	if get_slide_count() > 0:
		choose_new_patrol_direction()

func choose_new_patrol_direction():
	var angle = rand_range(0, PI * 2)
	patrol_direction = Vector2(cos(angle), sin(angle)).normalized()
	patrol_timer = change_direction_time

func chase_and_attack():
	look_at(player.global_position)

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > attack_distance:
		var direction = (player.global_position - global_position).normalized()
		move_and_slide(direction * speed)
	else:
		if shoot_timer <= 0:
			shoot_at_player()
			shoot_timer = shoot_cooldown

func search_player(delta):
	search_timer -= delta

	var direction_to_last_seen = last_seen_position - global_position

	if direction_to_last_seen.length() > 10:
		var direction = direction_to_last_seen.normalized()
		look_at(last_seen_position)
		move_and_slide(direction * search_speed)
	else:
		# Дошёл до последней позиции игрока и осматривается
		rotation += delta * 2.5

	if search_timer <= 0:
		state = EnemyState.PATROL
		choose_new_patrol_direction()


func can_see_player() -> bool:
	var to_player = player.global_position - global_position

	if to_player.length() > vision_distance:
		return false

	var forward = Vector2.RIGHT.rotated(rotation)
	var angle_to_player = rad2deg(forward.angle_to(to_player.normalized()))

	if abs(angle_to_player) > vision_angle / 2:
		return false

	# Проверяем нет ли стены между врагом и игроком
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(
	global_position,
	player.global_position,
	[self],
	0b1
)

	if result and result.collider != player:
		return false  # луч попал в стену

	return true

func take_damage(amount):
	hp -= amount

	if DamageNumberScene:
		var dmg = DamageNumberScene.instance()
		get_parent().add_child(dmg)
		dmg.setup(amount, global_position)

	if hp <= 0:
		queue_free()

func _draw():
	var half_angle = deg2rad(vision_angle / 2)
	var points = [Vector2.ZERO]
	
	# Рисуем конус из линий
	var steps = 20
	for i in range(steps + 1):
		var angle = -half_angle + (half_angle * 2 / steps) * i
		points.append(Vector2.RIGHT.rotated(angle) * vision_distance)
	
	points.append(Vector2.ZERO)
	
	# Рисуем заливку конуса
	draw_colored_polygon(PoolVector2Array(points), Color(1, 0, 0, 0.15))
	
	# Рисуем границы конуса
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(-half_angle) * vision_distance, Color(1, 0, 0, 0.5), 1.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(half_angle) * vision_distance, Color(1, 0, 0, 0.5), 1.0)

extends KinematicBody2D

export var speed = 80
export var hp = 3

export var vision_distance = 5000
export var vision_angle = 45

export(PackedScene) var BulletScene
export var shoot_cooldown = 1.0

const _SND_SHOOT = preload("res://assets/audio/pistolshot.wav")
var _snd_shoot = null
export var attack_distance = 350
export var preferred_min_distance = 230.0
export var preferred_max_distance = 330.0
export var strafe_speed = 70.0
export var strafe_change_interval = 1.2
export(PackedScene) var DamageNumberScene

var player = null
var shoot_timer = 0.0
var _fov_points := PoolVector2Array()

# AI movement
export var search_speed = 65
export var stuck_check_interval = 0.5
export var stuck_distance_threshold = 10.0
export var avoid_duration = 0.8

var _last_position = Vector2.ZERO
var _stuck_timer = 0.0
var _avoid_timer = 0.0
var _avoid_dir = Vector2.ZERO

var _strafe_dir = 1
var _strafe_timer = 0.0
var _alerted = false
var is_blinded = false

var _wander_dir = Vector2.ZERO
var _wander_timer = 0.0

var show_fov = false

func _ready():
	randomize()
	_last_position = global_position
	_stuck_timer = stuck_check_interval
	_snd_shoot = AudioStreamPlayer.new()
	_snd_shoot.stream = _SND_SHOOT
	_snd_shoot.volume_db = -18.0
	_snd_shoot.pitch_scale = 0.9
	call_deferred("add_child", _snd_shoot)

	var players = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found in group 'player'")

func _physics_process(delta):
	_update_fov_polygon()
	update()

	if player == null:
		return

	shoot_timer -= delta
	_strafe_timer -= delta

	if is_blinded:
		wander(delta)
		return
	if can_see_player():
		_alerted = true
		chase_and_attack(delta)
	elif _alerted:
		seek_player(delta)
	else:
		wander(delta)


func seek_player(delta):
	var to_player = player.global_position - global_position
	if to_player.length() < 5:
		return

	var primary_dir = to_player.normalized()
	look_at(player.global_position)

	var move_dir = primary_dir
	if _avoid_timer > 0:
		_avoid_timer -= delta
		move_dir = _avoid_dir

	move_and_slide(move_dir * search_speed)

	# Stuck detection — if barely moved, try a perpendicular slide direction.
	_stuck_timer -= delta
	if _stuck_timer <= 0:
		_stuck_timer = stuck_check_interval
		var moved = global_position.distance_to(_last_position)
		if moved < stuck_distance_threshold and _avoid_timer <= 0:
			var perp_left = primary_dir.rotated(PI / 2)
			var perp_right = primary_dir.rotated(-PI / 2)
			if randf() < 0.5:
				_avoid_dir = perp_left
			else:
				_avoid_dir = perp_right
			_avoid_timer = avoid_duration
		_last_position = global_position

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
	if _snd_shoot:
		_snd_shoot.play()

func chase_and_attack(delta):
	look_at(player.global_position)

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	if dist < 1.0:
		return
	var forward_dir = to_player.normalized()
	var move = Vector2.ZERO

	# Keep inside the engagement band — too far: close in; too close: back off.
	if dist > preferred_max_distance:
		move += forward_dir * speed
	elif dist < preferred_min_distance:
		move -= forward_dir * speed

	# Pick a strafe direction occasionally so the enemy isn't a stationary target.
	if _strafe_timer <= 0:
		_strafe_dir = 1 if randf() < 0.5 else -1
		_strafe_timer = strafe_change_interval + rand_range(-0.4, 0.4)
	var perpendicular = forward_dir.rotated(PI / 2.0)
	move += perpendicular * strafe_speed * _strafe_dir

	move_and_slide(move)

	# If the strafe pushed us into a wall, flip direction so we don't grind on it.
	if get_slide_count() > 0:
		_strafe_dir *= -1
		_strafe_timer = strafe_change_interval

	if shoot_timer <= 0:
		shoot_at_player()
		shoot_timer = shoot_cooldown

func wander(delta):
	_wander_timer -= delta
	if _wander_timer <= 0.0 or get_slide_count() > 0:
		_wander_timer = rand_range(1.2, 2.8)
		var angle = rand_range(0.0, TAU)
		_wander_dir = Vector2(cos(angle), sin(angle))
	rotation = lerp_angle(rotation, _wander_dir.angle(), delta * 3.0)
	move_and_slide(_wander_dir * search_speed * 0.55)


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

	# Wake the enemy — snap to face the attacker and stay in active-engage mode.
	if player:
		look_at(player.global_position)
		_alerted = true
		_avoid_timer = 0.0

	if DamageNumberScene:
		var dmg = DamageNumberScene.instance()
		get_parent().add_child(dmg)
		dmg.setup(amount, global_position)

	if hp <= 0:
		queue_free()

func _update_fov_polygon():
	var half_angle = deg2rad(vision_angle / 2.0)
	var steps = 24
	var space_state = get_world_2d().direct_space_state

	var exclude = [self]
	for p in get_tree().get_nodes_in_group("player"):
		exclude.append(p)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self:
			exclude.append(e)

	var pts = PoolVector2Array([Vector2.ZERO])
	for i in range(steps + 1):
		var local_angle = -half_angle + (half_angle * 2.0 / steps) * i
		var world_dir = Vector2.RIGHT.rotated(rotation + local_angle)
		var world_end = global_position + world_dir * vision_distance
		var hit = space_state.intersect_ray(global_position, world_end, exclude)
		if hit:
			pts.append((hit.position - global_position).rotated(-rotation))
		else:
			pts.append(Vector2.RIGHT.rotated(local_angle) * vision_distance)
	pts.append(Vector2.ZERO)
	_fov_points = pts


func _draw():
	if not show_fov:
		return
	if _fov_points.size() < 3:
		return
	draw_colored_polygon(_fov_points, Color(1, 0, 0, 0.15))
	draw_line(Vector2.ZERO, _fov_points[1], Color(1, 0, 0, 0.5), 1.0)
	draw_line(Vector2.ZERO, _fov_points[_fov_points.size() - 2], Color(1, 0, 0, 0.5), 1.0)

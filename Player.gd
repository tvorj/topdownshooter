extends KinematicBody2D

# --- Scenes ---
export(PackedScene) var BulletScene
export(PackedScene) var DamageNumberScene

# --- Player stats ---
export var speed = 200
export var hp = 30

# --- Vision ---
export var vision_distance = 400
export var vision_angle = 120
export var hide_enemies_outside_vision = true

# --- Weapon / ammo ---
export var magazine_size = 6
export var reserve_ammo = 24
export var max_reserve_ammo = 36
export var reload_time = 1.2
export var shoot_cooldown = 0.25

var current_ammo = 0
var is_reloading = false
var reload_timer = 0.0
var shoot_timer = 0.0

# --- State ---
var is_dead = false

# --- Nodes ---
onready var aim = $Aim
onready var hp_label = get_node_or_null("../UI/HpLabel")
onready var ammo_label = get_node_or_null("../UI/AmmoLabel")


func _ready():
	current_ammo = magazine_size
	update_hp_ui()
	update_ammo_ui()
	update()


func _physics_process(delta):
	if is_dead:
		return

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
	if is_dead:
		return

	look_at(get_global_mouse_position())
	update()
	update_enemy_visibility()

	shoot_timer -= delta

	if is_reloading:
		reload_timer -= delta

		if reload_timer <= 0:
			finish_reload()

		update_ammo_ui()
		return

	if Input.is_key_pressed(KEY_R):
		start_reload()

	if Input.is_action_just_pressed("click") and shoot_timer <= 0:
		try_shoot()


# --- UI ---

func update_hp_ui():
	if hp_label:
		hp_label.text = "HP: " + str(hp)


func update_ammo_ui():
	if ammo_label:
		if is_reloading:
			ammo_label.text = "Ammo: Reloading..."
		else:
			ammo_label.text = "Ammo: " + str(current_ammo) + " / " + str(reserve_ammo)


# --- Shooting / reload ---

func try_shoot():
	if is_dead:
		return

	if is_reloading:
		return

	if current_ammo <= 0:
		start_reload()
		return

	shoot()

	current_ammo -= 1
	shoot_timer = shoot_cooldown
	update_ammo_ui()


func shoot():
	if BulletScene == null:
		print("Player BulletScene не назначена!")
		return

	var bullet = BulletScene.instance()
	get_parent().add_child(bullet)

	var shoot_position = global_position

	if aim:
		shoot_position = aim.global_position

	var shoot_direction = (get_global_mouse_position() - shoot_position).normalized()

	bullet.global_position = shoot_position
	bullet.direction = shoot_direction
	bullet.owner_node = self


func start_reload():
	if is_dead:
		return

	if is_reloading:
		return

	if current_ammo == magazine_size:
		return

	if reserve_ammo <= 0:
		return

	is_reloading = true
	reload_timer = reload_time
	update_ammo_ui()


func finish_reload():
	var needed_ammo = magazine_size - current_ammo
	var ammo_to_load = min(needed_ammo, reserve_ammo)

	current_ammo += ammo_to_load
	reserve_ammo -= ammo_to_load

	is_reloading = false
	update_ammo_ui()


func add_ammo(amount) -> bool:
	if reserve_ammo >= max_reserve_ammo:
		return false

	reserve_ammo += amount

	if reserve_ammo > max_reserve_ammo:
		reserve_ammo = max_reserve_ammo

	update_ammo_ui()
	return true
	


# --- Damage / death ---

func take_damage(amount):
	if is_dead:
		return

	hp -= amount

	if hp < 0:
		hp = 0

	update_hp_ui()

	print("Player HP: ", hp)

	if DamageNumberScene:
		var dmg = DamageNumberScene.instance()
		get_parent().add_child(dmg)
		dmg.setup(amount, global_position)

	if hp <= 0:
		die()


func die():
	if is_dead:
		return

	is_dead = true
	print("Player died")

	var lose_label = get_node_or_null("../UI/LoseLabel")
	if lose_label:
		lose_label.visible = true

	var world = get_parent()
	if world and world.has_method("on_player_died"):
		world.on_player_died()

	set_physics_process(false)


# --- Vision / FOV ---

func _draw():
	var half_angle = deg2rad(vision_angle / 2)
	var points = [Vector2.ZERO]

	var steps = 20

	for i in range(steps + 1):
		var angle = -half_angle + (half_angle * 2 / steps) * i
		points.append(Vector2.RIGHT.rotated(angle) * vision_distance)

	points.append(Vector2.ZERO)

	draw_colored_polygon(PoolVector2Array(points), Color(1, 1, 0, 0.1))
	draw_line(
		Vector2.ZERO,
		Vector2.RIGHT.rotated(-half_angle) * vision_distance,
		Color(1, 1, 0, 0.3),
		1.0
	)
	draw_line(
		Vector2.ZERO,
		Vector2.RIGHT.rotated(half_angle) * vision_distance,
		Color(1, 1, 0, 0.3),
		1.0
	)

func update_enemy_visibility():
	if not hide_enemies_outside_vision:
		return

	var enemies = get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		if enemy == null:
			continue

		enemy.visible = can_see(enemy)

func can_see(target) -> bool:
	if target == null:
		return false

	var to_target = target.global_position - global_position

	if to_target.length() > vision_distance:
		return false

	var forward = Vector2.RIGHT.rotated(rotation)
	var angle_to_target = rad2deg(forward.angle_to(to_target.normalized()))

	if abs(angle_to_target) > vision_angle / 2:
		return false

	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(
		global_position,
		target.global_position,
		[self]
	)

	if result and result.collider != target:
		return false

	return true

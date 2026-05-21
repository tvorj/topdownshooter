extends KinematicBody2D

# --- Scenes ---
export(PackedScene) var BulletScene
export(PackedScene) var DamageNumberScene

# --- Audio ---
const _SND_SHOOT  = preload("res://assets/audio/pistolshot.wav")
const _SND_RELOAD = preload("res://assets/audio/pistolreload.wav")
const _SND_HIT    = preload("res://assets/audio/enemyhitplayer.ogg")
var _snd_shoot = null
var _snd_reload = null
var _snd_hit = null

# --- Player stats ---
export var speed = 200
export var hp = 10
export var max_hp = 10
export var armor = 0
export var max_armor = 5

# --- Vision ---
export var vision_distance = 5000
export var vision_angle = 15
export var infinite_vision = true
export var hide_enemies_outside_vision = true

# --- Weapon / ammo ---
export var magazine_size = 6
export var reserve_ammo = 24
export var max_reserve_ammo = 36
export var reload_time = 2.34
export var shoot_cooldown = 0.25

var current_ammo = 0
var is_reloading = false
var reload_timer = 0.0
var shoot_timer = 0.0

# --- State ---
var is_dead = false
var _fov_points := PoolVector2Array()

# --- Scan ability (E) ---
const ABILITY_DURATION = 5.0
const ABILITY_COOLDOWN = 10.0
var ability_active = false
var ability_timer = 0.0
var ability_cooldown_timer = 0.0
var _ability_key_was_pressed = false

# --- Blind ability (Q) ---
const ABILITY2_DURATION = 5.0
const ABILITY2_COOLDOWN = 10.0
var ability2_active = false
var ability2_timer = 0.0
var ability2_cooldown_timer = 0.0
var _ability2_key_was_pressed = false
var _ability2_saved = []

# --- Stats ---
var stats = {
	"start_ms": 0,
	"shots": 0,
	"hits": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"kills": 0,
}

# --- Nodes ---
onready var aim = $Aim
onready var hp_text = get_node_or_null("../UI/Hud/HpRow/HpText")
onready var hp_bar_fill = get_node_or_null("../UI/Hud/HpRow/HpBarBg/HpBarFill")
onready var ammo_text = get_node_or_null("../UI/Hud/AmmoRow/AmmoText")
onready var ammo_icons = get_node_or_null("../UI/Hud/AmmoRow/AmmoIcons")
onready var armor_text = get_node_or_null("../UI/Hud/ArmorRow/ArmorText")
onready var armor_bar_fill = get_node_or_null("../UI/Hud/ArmorRow/ArmorBarBg/ArmorBarFill")
onready var armor_row = get_node_or_null("../UI/Hud/ArmorRow")
onready var hud_root = get_node_or_null("../UI/Hud")
onready var hud_divider = get_node_or_null("../UI/Hud/RowDivider")
onready var hud_ammo_row = get_node_or_null("../UI/Hud/AmmoRow")

# --- Network sync ---
puppet var puppet_pos = Vector2.ZERO
puppet var puppet_rot = 0.0


func _is_local():
	return not GameState.is_pvp() or is_network_master()


var _x_was_pressed = false

func _ready():
	current_ammo = magazine_size
	puppet_pos = global_position
	puppet_rot = rotation
	stats.start_ms = OS.get_ticks_msec()
	_snd_shoot = AudioStreamPlayer.new()
	_snd_shoot.stream = _SND_SHOOT
	_snd_shoot.volume_db = -6.0
	call_deferred("add_child", _snd_shoot)
	_snd_reload = AudioStreamPlayer.new()
	_snd_reload.stream = _SND_RELOAD
	_snd_reload.volume_db = -6.0
	call_deferred("add_child", _snd_reload)
	_snd_hit = AudioStreamPlayer.new()
	_snd_hit.stream = _SND_HIT
	_snd_hit.volume_db = -4.0
	call_deferred("add_child", _snd_hit)
	if _is_local():
		update_hp_ui()
		update_ammo_ui()
		update_armor_ui()
	update()


func _physics_process(delta):
	if GameState.is_pvp() and not is_network_master():
		global_position = global_position.linear_interpolate(puppet_pos, 0.3)
		return

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

	if GameState.is_pvp():
		rset_unreliable("puppet_pos", global_position)


func _process(delta):
	if GameState.is_pvp() and not is_network_master():
		rotation = puppet_rot
		update()
		return

	if is_dead:
		return

	look_at(get_global_mouse_position())

	if ability_active:
		ability_timer -= delta
		if ability_timer <= 0.0:
			ability_active = false
			ability_cooldown_timer = ABILITY_COOLDOWN
	elif ability_cooldown_timer > 0.0:
		ability_cooldown_timer -= delta
	var e_now = Input.is_key_pressed(KEY_E)
	if e_now and not _ability_key_was_pressed and not ability_active and ability_cooldown_timer <= 0.0:
		ability_active = true
		ability_timer = ABILITY_DURATION
	_ability_key_was_pressed = e_now

	if ability2_active:
		ability2_timer -= delta
		if ability2_timer <= 0.0:
			ability2_active = false
			ability2_cooldown_timer = ABILITY2_COOLDOWN
			_ability2_restore()
	elif ability2_cooldown_timer > 0.0:
		ability2_cooldown_timer -= delta
	var q_now = Input.is_key_pressed(KEY_Q)
	if q_now and not _ability2_key_was_pressed and not ability2_active and ability2_cooldown_timer <= 0.0:
		ability2_active = true
		ability2_timer = ABILITY2_DURATION
		_ability2_apply()
	_ability2_key_was_pressed = q_now

	_update_fov_polygon()
	update()
	update_enemy_visibility()

	if GameState.is_pvp():
		rset_unreliable("puppet_rot", rotation)

	shoot_timer -= delta

	if is_reloading:
		reload_timer -= delta

		if reload_timer <= 0:
			finish_reload()

		update_ammo_ui()
		return

	if Input.is_key_pressed(KEY_R):
		start_reload()

	var x_now = Input.is_key_pressed(KEY_X)
	if x_now and not _x_was_pressed:
		suicide()
	_x_was_pressed = x_now

	if Input.is_action_just_pressed("click") and shoot_timer <= 0:
		try_shoot()


# --- UI ---

const HP_COLOR_HIGH = Color(0.298, 0.788, 0.345, 1)
const HP_COLOR_MID = Color(1.0, 0.749, 0.196, 1)
const HP_COLOR_LOW = Color(1.0, 0.298, 0.298, 1)
const AMMO_COLOR_FULL = Color(1.0, 0.65, 0.243, 1)
const AMMO_COLOR_EMPTY = Color(0.2, 0.22, 0.27, 1)
const ARMOR_COLOR = Color(0.345, 0.65, 1.0, 1)

func update_hp_ui():
	if not _is_local():
		return
	var ratio = clamp(float(hp) / float(max(max_hp, 1)), 0.0, 1.0)
	if hp_text:
		hp_text.text = str(hp) + " / " + str(max_hp)
	if hp_bar_fill:
		hp_bar_fill.anchor_right = ratio
		hp_bar_fill.margin_right = 0
		if ratio > 0.5:
			hp_bar_fill.color = HP_COLOR_HIGH
		elif ratio > 0.25:
			hp_bar_fill.color = HP_COLOR_MID
		else:
			hp_bar_fill.color = HP_COLOR_LOW


func update_armor_ui():
	if not _is_local():
		return
	var ratio = clamp(float(armor) / float(max(max_armor, 1)), 0.0, 1.0)
	if armor_text:
		armor_text.text = str(armor) + " / " + str(max_armor)
	if armor_bar_fill:
		armor_bar_fill.anchor_right = ratio
		armor_bar_fill.margin_right = 0
		armor_bar_fill.color = ARMOR_COLOR
	_refresh_armor_row_visibility()


func _refresh_armor_row_visibility():
	var has_armor = armor > 0
	if armor_row:
		armor_row.visible = has_armor
	if has_armor:
		if hud_divider:
			hud_divider.margin_top = 90.0
			hud_divider.margin_bottom = 91.0
		if hud_ammo_row:
			hud_ammo_row.margin_top = 100.0
			hud_ammo_row.margin_bottom = 128.0
		if hud_root:
			hud_root.margin_bottom = 168.0
	else:
		if hud_divider:
			hud_divider.margin_top = 52.0
			hud_divider.margin_bottom = 53.0
		if hud_ammo_row:
			hud_ammo_row.margin_top = 62.0
			hud_ammo_row.margin_bottom = 90.0
		if hud_root:
			hud_root.margin_bottom = 130.0


func update_ammo_ui():
	if not _is_local():
		return
	if ammo_text:
		if is_reloading:
			ammo_text.text = "Reloading..."
		else:
			ammo_text.text = str(current_ammo) + " / " + str(reserve_ammo)
	if ammo_icons:
		var bullets = ammo_icons.get_children()
		for i in range(bullets.size()):
			if is_reloading:
				bullets[i].color = AMMO_COLOR_EMPTY
			elif i < current_ammo:
				bullets[i].color = AMMO_COLOR_FULL
			else:
				bullets[i].color = AMMO_COLOR_EMPTY


# --- Shooting / reload ---

func try_shoot():
	if is_dead:
		return

	if is_reloading:
		return

	if current_ammo <= 0:
		start_reload()
		return

	var shoot_position = global_position
	if aim:
		shoot_position = aim.global_position
	var shoot_direction = (get_global_mouse_position() - shoot_position).normalized()

	_spawn_bullet_local(shoot_position, shoot_direction)
	if GameState.is_pvp():
		rpc("net_spawn_bullet", shoot_position, shoot_direction)
	if _snd_shoot:
		_snd_shoot.play()
	current_ammo -= 1
	shoot_timer = shoot_cooldown
	stats.shots += 1
	update_ammo_ui()


func _on_my_bullet_hit(amount, body):
	if not _is_local():
		return
	stats.hits += 1
	stats.damage_dealt += amount
	if body and is_instance_valid(body) and "is_dead" in body and body.is_dead:
		stats.kills += 1


func get_stats_summary() -> Dictionary:
	var elapsed_s = (OS.get_ticks_msec() - stats.start_ms) / 1000.0
	var accuracy = 0.0
	if stats.shots > 0:
		accuracy = float(stats.hits) / float(stats.shots) * 100.0
	return {
		"time_s": elapsed_s,
		"shots": stats.shots,
		"hits": stats.hits,
		"accuracy": accuracy,
		"damage_dealt": stats.damage_dealt,
		"damage_taken": stats.damage_taken,
		"kills": stats.kills,
	}


remote func net_spawn_bullet(pos, dir):
	_spawn_bullet_local(pos, dir)


func _spawn_bullet_local(pos, dir):
	if BulletScene == null:
		return
	var bullet = BulletScene.instance()
	get_parent().add_child(bullet)
	bullet.global_position = pos
	bullet.direction = dir
	bullet.damage = 2
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
	if _snd_reload:
		_snd_reload.play()
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


func add_health(amount) -> bool:
	if is_dead:
		return false
	if hp >= max_hp:
		return false

	if GameState.is_pvp():
		if not get_tree().is_network_server():
			return false

	var new_hp = hp + amount
	if new_hp > max_hp:
		new_hp = max_hp

	if GameState.is_pvp():
		_apply_armor_hp(armor, new_hp, 0)
		rpc("sync_armor_hp", armor, new_hp, 0)
	else:
		hp = new_hp
		update_hp_ui()

	return true


func add_armor(amount) -> bool:
	if is_dead:
		return false
	if armor >= max_armor:
		return false

	if GameState.is_pvp():
		if not get_tree().is_network_server():
			return false

	var new_armor = armor + amount
	if new_armor > max_armor:
		new_armor = max_armor

	if GameState.is_pvp():
		_apply_armor_hp(new_armor, hp, 0)
		rpc("sync_armor_hp", new_armor, hp, 0)
	else:
		armor = new_armor
		update_armor_ui()

	return true


# --- Damage / death ---

func take_damage(amount):
	if is_dead:
		return

	if GameState.is_pvp():
		if not get_tree().is_network_server():
			return
		var soak = min(armor, amount)
		var new_armor = armor - soak
		var dmg_through = amount - soak
		var new_hp = hp - dmg_through
		if new_hp < 0:
			new_hp = 0
		_apply_armor_hp(new_armor, new_hp, amount)
		rpc("sync_armor_hp", new_armor, new_hp, amount)
	else:
		var soak = min(armor, amount)
		var new_armor = armor - soak
		var dmg_through = amount - soak
		var new_hp = hp - dmg_through
		if new_hp < 0:
			new_hp = 0
		_apply_armor_hp(new_armor, new_hp, amount)


remote func sync_armor_hp(new_armor, new_hp, amount):
	_apply_armor_hp(new_armor, new_hp, amount)


func _apply_armor_hp(new_armor, new_hp, amount):
	if is_dead:
		return
	var old_armor = armor
	var old_hp = hp
	if amount > 0 and _is_local():
		stats.damage_taken += amount
		if _snd_hit:
			_snd_hit.play()
	armor = new_armor
	hp = new_hp
	update_hp_ui()
	update_armor_ui()
	if DamageNumberScene and amount > 0:
		var hp_lost = old_hp - new_hp
		var armor_used = old_armor - new_armor
		var hit_armor_only = hp_lost <= 0 and armor_used > 0
		var dmg = DamageNumberScene.instance()
		get_parent().add_child(dmg)
		dmg.setup(amount, global_position, hit_armor_only)
	if hp <= 0:
		die()


func suicide():
	if is_dead:
		return
	if not _is_local():
		return
	if GameState.is_pvp() and not get_tree().is_network_server():
		rpc_id(1, "net_suicide")
	else:
		take_damage(hp + armor + 999)


remote func net_suicide():
	if get_tree().is_network_server():
		take_damage(hp + armor + 999)


func die():
	if is_dead:
		return

	is_dead = true
	if ability2_active:
		ability2_active = false
		_ability2_restore()

	var world = get_parent()
	if world and world.has_method("on_player_died"):
		world.on_player_died(self)

	set_physics_process(false)


# --- Blind ability helpers ---

func _ability2_apply():
	_ability2_saved = []
	for t in get_tree().get_nodes_in_group("enemy"):
		if t.get("vision_angle") == null:
			continue
		_ability2_saved.append({
			"node": t,
			"vision_angle": t.vision_angle,
			"vision_distance": t.vision_distance,
			"is_blinded": true,
		})
		t.vision_angle = int(t.vision_angle * 0.35)
		t.vision_distance = 80
		t.is_blinded = true
	for p in get_tree().get_nodes_in_group("player"):
		if p == self:
			continue
		_ability2_saved.append({
			"node": p,
			"vision_angle": p.vision_angle,
			"vision_distance": p.vision_distance,
			"infinite_vision": p.infinite_vision,
		})
		p.vision_angle = int(p.vision_angle * 0.35)
		p.vision_distance = int(p.vision_distance * 0.15)
		p.infinite_vision = false


func _ability2_restore():
	for entry in _ability2_saved:
		var t = entry.node
		if not is_instance_valid(t):
			continue
		t.vision_angle = entry.vision_angle
		t.vision_distance = entry.vision_distance
		if entry.has("infinite_vision"):
			t.infinite_vision = entry.infinite_vision
		if entry.has("is_blinded"):
			t.is_blinded = false
	_ability2_saved = []


# --- Vision / FOV ---

func _update_fov_polygon():
	if not _is_local():
		_fov_points = PoolVector2Array()
		return

	var eff_angle = 360.0 if ability_active else float(vision_angle)
	var half_angle = deg2rad(eff_angle / 2.0)
	var steps = 60 if ability_active else 30
	var space_state = get_world_2d().direct_space_state

	var exclude = [self]
	for e in get_tree().get_nodes_in_group("enemy"):
		exclude.append(e)
	for p in get_tree().get_nodes_in_group("player"):
		if p != self:
			exclude.append(p)

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
	if not _is_local() or _fov_points.size() < 3:
		return

	var n = _fov_points.size()
	var steps = n - 3
	var eff_angle = 360.0 if ability_active else float(vision_angle)
	var half_a = deg2rad(eff_angle / 2.0)
	var R = 6000.0
	var dark = Color(0.01, 0.03, 0.07, 0.88)

	if not ability_active:
		# Behind the player
		draw_colored_polygon(PoolVector2Array([
			Vector2(-R, -R), Vector2(-R, R), Vector2(0.0, R), Vector2(0.0, -R)
		]), dark)
		# Above the cone
		draw_colored_polygon(PoolVector2Array([
			Vector2(0.0, -R), Vector2(R, -R),
			Vector2.RIGHT.rotated(-half_a) * R, Vector2.ZERO
		]), dark)
		# Below the cone
		draw_colored_polygon(PoolVector2Array([
			Vector2.ZERO,
			Vector2.RIGHT.rotated(half_a) * R,
			Vector2(R, R), Vector2(0.0, R)
		]), dark)

	# Beyond wall hits — one trapezoid per ray pair
	for i in range(1, n - 2):
		var a1 = -half_a + (half_a * 2.0 / steps) * (i - 1)
		var a2 = -half_a + (half_a * 2.0 / steps) * i
		var p1 = _fov_points[i]
		var p2 = _fov_points[i + 1]
		var p3 = Vector2.RIGHT.rotated(a2) * R
		var p4 = Vector2.RIGHT.rotated(a1) * R
		var cross = (p2 - p1).cross(p4 - p1)
		if abs(cross) < 1.0:
			continue
		draw_colored_polygon(PoolVector2Array([p1, p2, p3, p4]), dark)

	# Warm overlay
	if _fov_points.size() >= 4:
		draw_colored_polygon(_fov_points, Color(1.0, 0.95, 0.8, 0.18))
	if not ability_active:
		draw_line(Vector2.ZERO, _fov_points[1], Color(1.0, 0.95, 0.8, 0.55), 1.5)
		draw_line(Vector2.ZERO, _fov_points[n - 2], Color(1.0, 0.95, 0.8, 0.55), 1.5)


func update_enemy_visibility():
	var targets
	if GameState.is_pvp():
		targets = get_tree().get_nodes_in_group("player")
	else:
		targets = get_tree().get_nodes_in_group("enemy")

	for t in targets:
		if t == null or t == self:
			continue

		# Visibility uses STRICT cone + LOS (no infinite_vision cheat).
		var in_fov = is_strictly_in_fov(t) and _has_line_of_sight(t)
		if hide_enemies_outside_vision:
			t.visible = in_fov

		if "show_fov" in t:
			t.show_fov = in_fov
			if t.has_method("update"):
				t.update()


func _has_line_of_sight(target):
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(global_position, target.global_position, [self])
	if result and result.collider != target:
		return false
	return true


const TARGET_BODY_RADIUS_ENEMY = 16.0
const TARGET_BODY_RADIUS_PLAYER = 18.0

func is_strictly_in_fov(target) -> bool:
	if target == null:
		return false
	var to_target = target.global_position - global_position
	var dist = to_target.length()
	if dist == 0:
		return true
	if dist <= PERIPHERAL_RADIUS:
		return true
	if dist > vision_distance:
		return false
	if ability_active:
		return true
	var forward = Vector2.RIGHT.rotated(rotation)
	var angle_to_target = rad2deg(forward.angle_to(to_target.normalized()))
	var body_radius = _target_body_radius(target)
	var angular_half_width = rad2deg(atan2(body_radius, dist))
	return abs(angle_to_target) <= vision_angle / 2.0 + angular_half_width


func _target_body_radius(target) -> float:
	if target and target.is_in_group("enemy"):
		return TARGET_BODY_RADIUS_ENEMY
	return TARGET_BODY_RADIUS_PLAYER


const PERIPHERAL_RADIUS = 90.0

func can_see(target) -> bool:
	if target == null:
		return false

	var to_target = target.global_position - global_position
	var dist = to_target.length()

	if dist == 0:
		return true

	# Anyone within peripheral radius is visible regardless of cone angle.
	# Skips the cone check; we still check line of sight (a wall can block).
	var inside_peripheral = dist <= PERIPHERAL_RADIUS

	if not infinite_vision and not inside_peripheral:
		if dist > vision_distance:
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

extends Node2D

const PlayerScene = preload("res://entities/player/Player.tscn")
const EnemyScene = preload("res://entities/enemy/enemy.tscn")

const SPAWN_SINGLE  = Vector2(208, 784)
const SPAWN_HOST    = Vector2(208, 784)
const SPAWN_CLIENT  = Vector2(2352, 784)
const ENEMY_SPAWNS  = [Vector2(2352, 272), Vector2(2352, 1296), Vector2(1104, 784)]

const COLOR_WIN = Color(0.298, 0.788, 0.345, 1)
const COLOR_LOSE = Color(1.0, 0.298, 0.298, 1)
const COLOR_CARD_BG = Color(0.082, 0.094, 0.125, 1)
const COLOR_CARD_BORDER = Color(0.176, 0.192, 0.243, 1)
const COLOR_ACCENT = Color(1.0, 0.65, 0.243, 1)
const COLOR_BTN_BG = Color(0.114, 0.125, 0.16, 1)
const COLOR_BTN_HOVER = Color(0.157, 0.176, 0.227, 1)
const COLOR_BTN_PRESSED = Color(0.078, 0.086, 0.114, 1)
const COLOR_BTN_BORDER = Color(0.235, 0.247, 0.298, 1)
const COLOR_PRIMARY_BG = Color(0.78, 0.45, 0.16, 1)
const COLOR_PRIMARY_HOVER = Color(0.92, 0.55, 0.2, 1)

onready var game_over_screen = get_node_or_null("UI/GameOverScreen")
onready var game_over_card = get_node_or_null("UI/GameOverScreen/Center/Card")
onready var game_over_title = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/Title")
onready var play_again_btn = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/ButtonRow/PlayAgainBtn")
onready var main_menu_btn = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/ButtonRow/MainMenuBtn")

onready var stat_time = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/StatsVBox/TimeRow/Value")
onready var stat_kills = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/StatsVBox/KillsRow/Value")
onready var stat_shots = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/StatsVBox/ShotsRow/Value")
onready var stat_accuracy = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/StatsVBox/AccuracyRow/Value")
onready var stat_damage_dealt = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/StatsVBox/DamageDealtRow/Value")
onready var stat_damage_taken = get_node_or_null("UI/GameOverScreen/Center/Card/Margin/VBox/StatsVBox/DamageTakenRow/Value")
onready var hud_bg = get_node_or_null("UI/Hud/HudBg")
onready var blur_overlay = get_node_or_null("UI/GameOverScreen/BlurOverlay")

var game_over = false
var initial_enemy_count = 0


func _ready():
	_style_game_over_screen()
	_style_hud()
	_build_map()
	if GameState.is_pvp():
		NetworkManager.connect("opponent_left", self, "_on_opponent_left")
		_setup_pvp()
	else:
		_setup_single()


func _setup_single():
	var p = PlayerScene.instance()
	p.name = "Player"
	p.position = SPAWN_SINGLE
	add_child(p)
	_attach_camera(p)
	for pos in ENEMY_SPAWNS:
		var e = EnemyScene.instance()
		e.position = pos
		add_child(e)
	initial_enemy_count = ENEMY_SPAWNS.size()


func _setup_pvp():
	var host_id = 1
	var my_id = get_tree().get_network_unique_id()
	var peers = get_tree().get_network_connected_peers()
	var client_id = my_id if not get_tree().is_network_server() else peers[0]
	_spawn_networked_player(host_id, SPAWN_HOST)
	_spawn_networked_player(client_id, SPAWN_CLIENT)
	var local_node = get_node_or_null(str(my_id))
	if local_node:
		_attach_camera(local_node)


func _spawn_networked_player(peer_id, pos):
	var p = PlayerScene.instance()
	p.name = str(peer_id)
	p.position = pos
	add_child(p)
	p.set_network_master(peer_id)


func _attach_camera(player_node):
	var cam = Camera2D.new()
	cam.current = true
	cam.drag_margin_h_enabled = true
	cam.drag_margin_v_enabled = true
	cam.drag_margin_left = 0.15
	cam.drag_margin_right = 0.15
	cam.drag_margin_top = 0.15
	cam.drag_margin_bottom = 0.15
	cam.smoothing_enabled = true
	cam.smoothing_speed = 7.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 80 * 32
	cam.limit_bottom = 50 * 32
	player_node.add_child(cam)


func _process(delta):
	if game_over:
		if Input.is_key_pressed(KEY_R):
			_restart()
		return

	if not GameState.is_pvp():
		var enemies = get_tree().get_nodes_in_group("enemy")
		if enemies.size() == 0:
			on_player_won()


func _restart():
	if GameState.is_pvp():
		NetworkManager.leave()
		GameState.mode = GameState.Mode.SINGLE
		get_tree().change_scene("res://ui/MainMenu.tscn")
	else:
		get_tree().reload_current_scene()


func _go_to_menu():
	NetworkManager.leave()
	GameState.mode = GameState.Mode.SINGLE
	get_tree().change_scene("res://ui/MainMenu.tscn")


func on_player_died(player_node = null):
	if game_over:
		return
	game_over = true

	if GameState.is_pvp():
		var local_died = (player_node != null and player_node.is_network_master())
		_show_game_over(not local_died)
	else:
		_show_game_over(false)
	freeze_world()


func on_player_won():
	if game_over:
		return
	game_over = true
	_show_game_over(true)
	freeze_world()


func freeze_world():
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	for p in get_tree().get_nodes_in_group("player"):
		p.set_physics_process(false)
		p.set_process(false)
	for pk in get_tree().get_nodes_in_group("ammo_pickup"):
		pk.set_process(false)
	for pk in get_tree().get_nodes_in_group("health_pickup"):
		pk.set_process(false)
	for pk in get_tree().get_nodes_in_group("armor_pickup"):
		pk.set_process(false)


func stop_enemies():
	freeze_world()


func _on_opponent_left():
	if game_over:
		return
	game_over = true
	_show_game_over(true)
	freeze_world()


# --- Game-over screen ---

func _find_local_player():
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("_is_local") and p._is_local():
			return p
	return null


func _show_game_over(is_win):
	if game_over_screen == null:
		return

	if game_over_title:
		game_over_title.text = "VICTORY" if is_win else "DEFEATED"
		game_over_title.add_color_override("font_color", COLOR_WIN if is_win else COLOR_LOSE)

	var local_player = _find_local_player()
	var s = local_player.get_stats_summary() if local_player else null

	var kills_text = "0"
	if local_player:
		if GameState.is_pvp():
			kills_text = "1" if is_win else "0"
		else:
			var remaining = get_tree().get_nodes_in_group("enemy").size()
			kills_text = str(max(initial_enemy_count - remaining, 0))

	if s != null:
		if stat_time:
			stat_time.text = _format_time(s.time_s)
		if stat_kills:
			stat_kills.text = kills_text
		if stat_shots:
			stat_shots.text = str(s.shots) + " (" + str(s.hits) + " hit)"
		if stat_accuracy:
			stat_accuracy.text = "%.0f%%" % s.accuracy
		if stat_damage_dealt:
			stat_damage_dealt.text = str(s.damage_dealt)
		if stat_damage_taken:
			stat_damage_taken.text = str(s.damage_taken)

	game_over_screen.visible = true


func _format_time(seconds_float):
	var total = int(seconds_float)
	var m = total / 60
	var s = total % 60
	return str(m) + ":" + ("0" + str(s) if s < 10 else str(s))


func _on_PlayAgainBtn_pressed():
	_restart()


func _on_MainMenuBtn_pressed():
	_go_to_menu()


# --- Map builder ---

func _build_map():
	var tm = $TileMap
	tm.clear()

	var W = 80
	var H = 50

	# Outer border
	_wall_rect(tm, 0, 0, W - 1, 0)
	_wall_rect(tm, 0, H - 1, W - 1, H - 1)
	_wall_rect(tm, 0, 0, 0, H - 1)
	_wall_rect(tm, W - 1, 0, W - 1, H - 1)

	# Left base divider — passage open at y=20..30
	_wall_rect(tm, 12, 1, 12, 19)
	_wall_rect(tm, 12, 31, 12, 48)

	# Right base divider — passage open at y=20..30
	_wall_rect(tm, 67, 1, 67, 19)
	_wall_rect(tm, 67, 31, 67, 48)

	# --- Inner horizontal walls creating 3 lanes ---
	# Top separator (gap at x=23..26 and x=53..56)
	_wall_rect(tm, 13, 17, 22, 17)
	_wall_rect(tm, 27, 17, 52, 17)
	_wall_rect(tm, 57, 17, 66, 17)
	# Bottom separator (mirror)
	_wall_rect(tm, 13, 32, 22, 32)
	_wall_rect(tm, 27, 32, 52, 32)
	_wall_rect(tm, 57, 32, 66, 32)

	# --- Top lane covers (y=1..16) ---
	# Top-left L (opens bottom-right)
	_wall_rect(tm, 22, 5, 22, 14)
	_wall_rect(tm, 22, 5, 27, 5)
	# Top-right L (opens bottom-left)
	_wall_rect(tm, 57, 5, 57, 14)
	_wall_rect(tm, 52, 5, 57, 5)
	# Top center box
	_wall_rect(tm, 37, 7, 42, 10)

	# --- Bottom lane covers (y=33..48, mirror) ---
	_wall_rect(tm, 22, 35, 22, 44)
	_wall_rect(tm, 22, 44, 27, 44)
	_wall_rect(tm, 57, 35, 57, 44)
	_wall_rect(tm, 52, 44, 57, 44)
	_wall_rect(tm, 37, 39, 42, 42)

	# --- Mid lane covers (y=18..31) ---
	# Mid-left L
	_wall_rect(tm, 24, 20, 24, 29)
	_wall_rect(tm, 24, 20, 29, 20)
	# Mid-right L (mirror)
	_wall_rect(tm, 55, 20, 55, 29)
	_wall_rect(tm, 50, 20, 55, 20)
	# Center large pillar
	_wall_rect(tm, 36, 22, 43, 27)
	# Mid inner covers flanking pillar
	_wall_rect(tm, 32, 24, 33, 25)
	_wall_rect(tm, 46, 24, 47, 25)


func _wall_rect(tm, x1, y1, x2, y2):
	for x in range(x1, x2 + 1):
		for y in range(y1, y2 + 1):
			tm.set_cell(x, y, 0)


# --- Styling ---

func _style_hud():
	if hud_bg == null:
		return
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0588, 0.0667, 0.0941, 0.85)
	sb.border_color = Color(0.176, 0.192, 0.243, 1)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	hud_bg.add_stylebox_override("panel", sb)


func _style_game_over_screen():
	if game_over_card:
		_apply_card_style(game_over_card)
	if play_again_btn:
		_style_button(play_again_btn, true)
	if main_menu_btn:
		_style_button(main_menu_btn, false)
	_apply_blur_shader()


func _apply_blur_shader():
	if blur_overlay == null:
		return
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;

uniform float blur_radius : hint_range(0.0, 16.0) = 4.5;
uniform float darken : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 col = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.0);
			col += textureLod(SCREEN_TEXTURE, SCREEN_UV + vec2(float(x), float(y)) * px, 0.0).rgb * w;
			total += w;
		}
	}
	col /= total;
	col *= darken;
	COLOR = vec4(col, 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	blur_overlay.material = mat


func _apply_card_style(panel):
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_BG
	sb.border_color = COLOR_CARD_BORDER
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	panel.add_stylebox_override("panel", sb)


func _make_btn_style(bg_color, border_color):
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _style_button(btn, primary):
	var bg = COLOR_PRIMARY_BG if primary else COLOR_BTN_BG
	var hover = COLOR_PRIMARY_HOVER if primary else COLOR_BTN_HOVER
	var border = COLOR_PRIMARY_BG if primary else COLOR_BTN_BORDER
	btn.add_stylebox_override("normal", _make_btn_style(bg, border))
	btn.add_stylebox_override("hover", _make_btn_style(hover, border))
	btn.add_stylebox_override("pressed", _make_btn_style(COLOR_BTN_PRESSED, border))
	btn.add_stylebox_override("focus", _make_btn_style(bg, COLOR_ACCENT))
	btn.add_color_override("font_color", Color(0.95, 0.96, 0.98))
	btn.add_color_override("font_color_hover", Color(1, 1, 1))
	btn.add_color_override("font_color_pressed", Color(0.85, 0.86, 0.9))

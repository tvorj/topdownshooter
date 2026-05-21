extends Control

const COLOR_ACCENT = Color(1.0, 0.65, 0.243)
const COLOR_ACTIVE = Color(0.3, 0.88, 1.0)
const COLOR_COOLDOWN = Color(0.2, 0.22, 0.3)

const SLOT = 60.0
const GAP = 10.0

var player = null

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta):
	if player == null or not is_instance_valid(player):
		for p in get_tree().get_nodes_in_group("player"):
			if not GameState.is_pvp() or p.is_network_master():
				player = p
				break
	update()

func _draw():
	if player == null or not is_instance_valid(player):
		return
	_draw_slot(Vector2.ZERO, "E", false,
		player.ability_active, player.ability_timer, player.ABILITY_DURATION,
		player.ability_cooldown_timer, player.ABILITY_COOLDOWN)
	_draw_slot(Vector2(SLOT + GAP, 0), "Q", true,
		player.ability2_active, player.ability2_timer, player.ABILITY2_DURATION,
		player.ability2_cooldown_timer, player.ABILITY2_COOLDOWN)


func _draw_slot(pos, key, is_blind, is_active, timer, duration, cooldown, max_cooldown):
	var on_cd = cooldown > 0.0
	var s = SLOT
	var cx = pos.x + s * 0.5
	var cy = pos.y + s * 0.5

	var accent: Color
	if is_active:   accent = COLOR_ACTIVE
	elif on_cd:     accent = COLOR_COOLDOWN
	else:           accent = COLOR_ACCENT

	# Background
	var bg: Color
	if is_active:   bg = Color(0.04, 0.12, 0.18, 0.96)
	elif on_cd:     bg = Color(0.04, 0.05, 0.07, 0.95)
	else:           bg = Color(0.06, 0.08, 0.12, 0.93)
	draw_rect(Rect2(pos, Vector2(s, s)), bg)

	# Fill bar rising from bottom (time remaining)
	if is_active:
		var ratio = clamp(timer / duration, 0.0, 1.0)
		var fh = (s - 4.0) * ratio
		draw_rect(Rect2(pos + Vector2(2, s - 2 - fh), Vector2(s - 4, fh)), Color(0.3, 0.88, 1.0, 0.18))
	elif on_cd:
		var ratio = clamp(cooldown / max_cooldown, 0.0, 1.0)
		var fh = (s - 4.0) * ratio
		draw_rect(Rect2(pos + Vector2(2, s - 2 - fh), Vector2(s - 4, fh)), Color(0.22, 0.24, 0.34, 0.35))

	# Border
	draw_rect(Rect2(pos, Vector2(s, s)), accent, false, 2.0)
	if is_active:
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(s - 2, s - 2)), Color(0.3, 0.88, 1.0, 0.08), false, 1.0)

	# Gloss top strip
	draw_line(pos + Vector2(3, 2), pos + Vector2(s - 3, 2), Color(1, 1, 1, 0.07), 2.0)

	# Key badge (top-left corner)
	var badge = Rect2(pos + Vector2(4, 4), Vector2(16, 14))
	draw_rect(badge, Color(0, 0, 0, 0.5))
	draw_rect(badge, accent * Color(1, 1, 1, 0.65), false, 1.0)
	var font = get_font("font", "Label")
	var ks = font.get_string_size(key)
	var key_col = Color(0.5, 0.53, 0.62) if on_cd and not is_active else Color(1, 1, 1, 0.92)
	draw_string(font, pos + Vector2(4 + (16 - ks.x) * 0.5, 16), key, key_col)

	# Ability symbol (center, shifted down a bit from key badge)
	var sym_y = cy + 5.0
	var sym_alpha = 0.45 if on_cd else 0.82
	var sym_col = Color(accent.r, accent.g, accent.b, sym_alpha)

	if is_blind:
		# Q — crossed circle (blind)
		draw_arc(Vector2(cx, sym_y), 11.0, 0, TAU, 22, sym_col, 1.5)
		draw_line(Vector2(cx - 8, sym_y - 8), Vector2(cx + 8, sym_y + 8), sym_col, 1.5)
		draw_line(Vector2(cx + 8, sym_y - 8), Vector2(cx - 8, sym_y + 8), sym_col, 1.5)
	else:
		# E — circle with radiating lines (scan)
		draw_arc(Vector2(cx, sym_y), 7.0, 0, TAU, 20, sym_col, 1.5)
		for i in range(6):
			var a = i * TAU / 6.0
			var r0 = Vector2(cx + cos(a) * 10.5, sym_y + sin(a) * 10.5)
			var r1 = Vector2(cx + cos(a) * 14.5, sym_y + sin(a) * 14.5)
			draw_line(r0, r1, sym_col, 1.5)

	# Countdown text (bottom of slot)
	if is_active or on_cd:
		var t_val = timer if is_active else cooldown
		var t_str = str(int(ceil(t_val))) + "s"
		var ts = font.get_string_size(t_str)
		var t_col = COLOR_ACTIVE if is_active else Color(0.4, 0.43, 0.52, 0.9)
		draw_string(font, pos + Vector2((s - ts.x) * 0.5, s - 6), t_str, t_col)

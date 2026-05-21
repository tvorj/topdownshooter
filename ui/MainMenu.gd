extends Control

const COLOR_ACCENT = Color(1.0, 0.65, 0.243)
const COLOR_BTN_BG = Color(0.114, 0.125, 0.16)
const COLOR_BTN_HOVER = Color(0.157, 0.176, 0.227)
const COLOR_BTN_PRESSED = Color(0.078, 0.086, 0.114)
const COLOR_BTN_BORDER = Color(0.235, 0.247, 0.298)
const COLOR_PRIMARY_BG = Color(0.78, 0.45, 0.16)
const COLOR_PRIMARY_HOVER = Color(0.92, 0.55, 0.2)
const COLOR_CARD_BG = Color(0.082, 0.094, 0.125)
const COLOR_CARD_BORDER = Color(0.176, 0.192, 0.243)
const COLOR_INPUT_BG = Color(0.039, 0.047, 0.067)

onready var card = $Center/Card
onready var ip_edit = $Center/Card/Margin/VBox/IdleContent/IPEdit
onready var status_label = $Center/Card/Margin/VBox/ConnectingContent/StatusLabel
onready var error_label = $Center/Card/Margin/VBox/ErrorLabel
onready var idle_content = $Center/Card/Margin/VBox/IdleContent
onready var connecting_content = $Center/Card/Margin/VBox/ConnectingContent
onready var single_btn = $Center/Card/Margin/VBox/IdleContent/SingleBtn
onready var host_btn = $Center/Card/Margin/VBox/IdleContent/HostBtn
onready var join_btn = $Center/Card/Margin/VBox/IdleContent/JoinBtn
onready var quit_btn = $Center/Card/Margin/VBox/IdleContent/QuitBtn
onready var cancel_btn = $Center/Card/Margin/VBox/ConnectingContent/CancelBtn
onready var title_label = $Center/Card/Margin/VBox/Title
onready var connecting_title = $Center/Card/Margin/VBox/ConnectingContent/ConnectingTitle
onready var tracer_layer = $Tracers
onready var spinner = $Center/Card/Margin/VBox/ConnectingContent/SpinnerHolder/Spinner

const TRACER_COLOR = Color(1.0, 0.65, 0.243, 0.65)
const BG_LINE_COLOR = Color(1.0, 0.65, 0.243, 0.08)
const BG_LINE_COUNT = 7
var _tracers = []
var _bg_lines = []
var _tracer_timer = 0.0
var _spinner_angle = 0.0
var _dot_timer = 0.0
var _connect_base_msg = ""

func _ready():
	randomize()
	NetworkManager.connect("join_failed", self, "_on_join_failed")
	NetworkManager.connect("game_started", self, "_on_game_started")
	NetworkManager.leave()
	_style_card(card)
	_style_input(ip_edit)
	_style_button(single_btn, true)
	_style_button(host_btn, false)
	_style_button(join_btn, false)
	_style_button(quit_btn, false, true)
	_style_button(cancel_btn, false, true)
	for b in [single_btn, host_btn, join_btn, quit_btn, cancel_btn]:
		_add_hover_scale(b)
	call_deferred("_scale_titles")
	call_deferred("_spawn_background_lines")
	_show_idle()


func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if ip_edit and ip_edit.has_focus():
			if not ip_edit.get_global_rect().has_point(event.global_position):
				ip_edit.release_focus()
	elif event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		if ip_edit and ip_edit.has_focus():
			ip_edit.release_focus()


func _process(delta):
	_update_bg_lines(delta)
	_update_tracers(delta)
	_maybe_spawn_tracer(delta)
	if connecting_content.visible:
		_spinner_angle += delta * 360.0
		if spinner:
			spinner.rect_rotation = _spinner_angle
		_dot_timer += delta
		if _dot_timer >= 0.4:
			_dot_timer = 0.0
			var dots = int((OS.get_ticks_msec() / 400) % 4)
			if _connect_base_msg != "":
				status_label.text = _connect_base_msg + ".".repeat(dots)


# --- Background horizontal scrolling lines ---

func _spawn_background_lines():
	if tracer_layer == null:
		return
	var vp = get_viewport_rect().size
	for i in range(BG_LINE_COUNT):
		var line = ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.rect_size = Vector2(vp.x, 1)
		line.color = BG_LINE_COLOR
		tracer_layer.add_child(line)
		var y = (vp.y / float(BG_LINE_COUNT)) * i + rand_range(-30, 30)
		line.rect_position = Vector2(0, y)
		_bg_lines.append({
			"node": line,
			"speed": rand_range(25.0, 60.0),
		})


func _update_bg_lines(delta):
	var vp = get_viewport_rect().size
	for line in _bg_lines:
		line.node.rect_position.y += line.speed * delta
		if line.node.rect_position.y > vp.y:
			line.node.rect_position.y = -1
			line.node.rect_size.x = vp.x


# --- Tracers (angled bullets streaking across screen) ---

func _maybe_spawn_tracer(delta):
	_tracer_timer -= delta
	if _tracer_timer > 0:
		return
	_tracer_timer = rand_range(0.12, 0.45)
	_spawn_tracer()


func _spawn_tracer():
	if tracer_layer == null:
		return
	var vp = get_viewport_rect().size
	var t = ColorRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var length = rand_range(70, 150)
	t.rect_size = Vector2(length, 3)
	t.color = TRACER_COLOR
	t.rect_pivot_offset = Vector2(length / 2.0, 1.5)

	var from_left = randi() % 2 == 0
	var tilt = rand_range(-25.0, 25.0)
	var angle_deg = tilt if from_left else (180.0 - tilt)
	t.rect_rotation = angle_deg

	var dir = Vector2.RIGHT.rotated(deg2rad(angle_deg))
	var speed = rand_range(900, 1600)
	var y = rand_range(vp.y * 0.18, vp.y * 0.88)
	var x = -length if from_left else vp.x + length
	t.rect_position = Vector2(x, y) - t.rect_pivot_offset

	tracer_layer.add_child(t)
	_tracers.append({"node": t, "vel": dir * speed, "len": length})


func _update_tracers(delta):
	var vp = get_viewport_rect().size
	var dead = []
	for t in _tracers:
		t.node.rect_position += t.vel * delta
		var c = t.node.rect_position + t.node.rect_pivot_offset
		if c.x > vp.x + t.len or c.x < -t.len or c.y > vp.y + 200 or c.y < -200:
			t.node.queue_free()
			dead.append(t)
	for td in dead:
		_tracers.erase(td)


# --- Hover scale ---

func _add_hover_scale(btn):
	btn.rect_pivot_offset = btn.rect_size / 2.0
	btn.connect("mouse_entered", self, "_on_btn_hover", [btn, true])
	btn.connect("mouse_exited", self, "_on_btn_hover", [btn, false])
	btn.connect("resized", self, "_on_btn_resized", [btn])


func _on_btn_resized(btn):
	btn.rect_pivot_offset = btn.rect_size / 2.0


func _on_btn_hover(btn, entered):
	var target_scale = Vector2(1.04, 1.04) if entered else Vector2.ONE
	btn.rect_scale = target_scale

func _scale_titles():
	_scale_label(title_label, 1.8)
	_scale_label(connecting_title, 1.4)

func _scale_label(label, factor):
	label.rect_pivot_offset = Vector2(label.rect_size.x / 2.0, 0)
	label.rect_scale = Vector2(factor, factor)
	label.rect_min_size = Vector2(0, label.get_minimum_size().y * factor)

func _style_card(panel):
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
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 12
	panel.add_stylebox_override("panel", sb)

func _style_input(line_edit):
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_INPUT_BG
	sb.border_color = COLOR_BTN_BORDER
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	line_edit.add_stylebox_override("normal", sb)
	var sb_focus = sb.duplicate()
	sb_focus.border_color = COLOR_ACCENT
	line_edit.add_stylebox_override("focus", sb_focus)
	line_edit.add_color_override("font_color", Color(0.9, 0.92, 0.95))
	line_edit.add_color_override("cursor_color", COLOR_ACCENT)
	line_edit.add_color_override("font_color_selected", Color(1, 1, 1))
	line_edit.add_color_override("selection_color", COLOR_ACCENT * Color(1, 1, 1, 0.4))

func _style_button(btn, primary, danger = false):
	var bg = COLOR_PRIMARY_BG if primary else COLOR_BTN_BG
	var hover = COLOR_PRIMARY_HOVER if primary else COLOR_BTN_HOVER
	var border = COLOR_PRIMARY_BG if primary else COLOR_BTN_BORDER
	if danger:
		border = Color(0.6, 0.25, 0.25)
	var normal = _make_btn_style(bg, border)
	var hover_sb = _make_btn_style(hover, border)
	var pressed_sb = _make_btn_style(COLOR_BTN_PRESSED, border)
	var disabled_sb = _make_btn_style(Color(0.08, 0.09, 0.11), COLOR_BTN_BORDER)
	btn.add_stylebox_override("normal", normal)
	btn.add_stylebox_override("hover", hover_sb)
	btn.add_stylebox_override("pressed", pressed_sb)
	btn.add_stylebox_override("disabled", disabled_sb)
	btn.add_stylebox_override("focus", _make_btn_style(bg, COLOR_ACCENT))
	btn.add_color_override("font_color", Color(0.95, 0.96, 0.98))
	btn.add_color_override("font_color_hover", Color(1, 1, 1))
	btn.add_color_override("font_color_pressed", Color(0.85, 0.86, 0.9))
	btn.add_color_override("font_color_disabled", Color(0.4, 0.42, 0.48))

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

func _show_idle():
	idle_content.visible = true
	connecting_content.visible = false
	error_label.text = ""
	_connect_base_msg = ""

func _show_connecting(msg):
	idle_content.visible = false
	connecting_content.visible = true
	_connect_base_msg = msg
	status_label.text = msg
	error_label.text = ""

func _show_error(msg):
	idle_content.visible = true
	connecting_content.visible = false
	error_label.text = msg

func _on_SingleBtn_pressed():
	GameState.mode = GameState.Mode.SINGLE
	get_tree().change_scene("res://world/World.tscn")

func _on_HostBtn_pressed():
	if not NetworkManager.host():
		_show_error("Failed to start server")
		return
	_show_connecting("Hosting on port " + str(GameState.PORT) + "\nwaiting for opponent...")

func _on_JoinBtn_pressed():
	var ip = ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	if not NetworkManager.join(ip):
		_show_error("Failed to connect to " + ip)
		return
	_show_connecting("Connecting to " + ip + "...")

func _on_CancelBtn_pressed():
	NetworkManager.leave()
	GameState.mode = GameState.Mode.SINGLE
	_show_idle()

func _on_QuitBtn_pressed():
	get_tree().quit()

func _on_join_failed():
	if not connecting_content.visible:
		return
	_show_error("Connection failed")

func _on_game_started():
	pass

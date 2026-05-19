extends Node2D

onready var win_label = get_node_or_null("UI/WinLabel")
onready var lose_label = get_node_or_null("UI/LoseLabel")

var game_over = false

func _process(delta):
	if game_over:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	var enemies = get_tree().get_nodes_in_group("enemy")

	if enemies.size() == 0:
		on_player_won()


func on_player_died():
	if game_over:
		return

	game_over = true

	if lose_label:
		lose_label.visible = true

	stop_enemies()


func on_player_won():
	if game_over:
		return

	game_over = true

	if win_label:
		win_label.visible = true

	stop_enemies()


func stop_enemies():
	var enemies = get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)

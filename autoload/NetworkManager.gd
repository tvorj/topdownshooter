extends Node

signal opponent_left
signal join_failed
signal game_started

var peer = null

func _ready():
	get_tree().connect("network_peer_connected", self , "_on_peer_connected")
	get_tree().connect("network_peer_disconnected", self , "_on_peer_disconnected")
	get_tree().connect("connected_to_server", self , "_on_connected_to_server")
	get_tree().connect("connection_failed", self , "_on_connection_failed")
	get_tree().connect("server_disconnected", self , "_on_server_disconnected")

func host():
	leave()
	peer = NetworkedMultiplayerENet.new()
	var err = peer.create_server(GameState.PORT, GameState.MAX_PEERS)
	if err != OK:
		emit_signal("join_failed")
		return false
	get_tree().network_peer = peer
	GameState.mode = GameState.Mode.PVP_HOST
	return true

func join(ip):
	leave()
	peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(ip, GameState.PORT)
	if err != OK:
		emit_signal("join_failed")
		return false
	get_tree().network_peer = peer
	GameState.mode = GameState.Mode.PVP_CLIENT
	GameState.host_ip = ip
	return true

func leave():
	if peer != null:
		peer.close_connection()
		peer = null
	get_tree().network_peer = null

func _on_peer_connected(id):
	if get_tree().is_network_server():
		rpc_id(id, "start_game")
		call_deferred("_start_world")

remote func start_game():
	call_deferred("_start_world")

func _start_world():
	emit_signal("game_started")
	get_tree().change_scene("res://world/World.tscn")

func _on_peer_disconnected(id):
	emit_signal("opponent_left")

func _on_connected_to_server():
	pass

func _on_connection_failed():
	leave()
	emit_signal("join_failed")

func _on_server_disconnected():
	emit_signal("opponent_left")

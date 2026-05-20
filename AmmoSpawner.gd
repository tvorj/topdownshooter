extends Node2D

export(PackedScene) var AmmoPickupScene
export var spawn_interval = 6.0
export var max_pickups = 3
export var spawn_on_start = true

onready var spawn_points_root = get_node_or_null("../AmmoSpawnPoints")

var spawn_timer = 0.0


func _ready():
	randomize()

	print("AmmoSpawner ready")

	if AmmoPickupScene == null:
		print("ERROR: AmmoPickupScene не назначена!")
	else:
		print("AmmoPickupScene assigned")

	if spawn_points_root == null:
		print("ERROR: AmmoSpawnPoints не найден!")
	else:
		print("AmmoSpawnPoints found: ", spawn_points_root.name)
		print("Spawn points count: ", spawn_points_root.get_child_count())

	if spawn_on_start:
		try_spawn_pickup()

	spawn_timer = spawn_interval


func _process(delta):
	if AmmoPickupScene == null:
		return

	if spawn_points_root == null:
		return

	spawn_timer -= delta

	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		try_spawn_pickup()


func try_spawn_pickup():
	print("Trying to spawn ammo pickup")

	if AmmoPickupScene == null:
		print("Cannot spawn: AmmoPickupScene is null")
		return

	if spawn_points_root == null:
		print("Cannot spawn: AmmoSpawnPoints is null")
		return

	var existing_pickups = get_tree().get_nodes_in_group("ammo_pickup")
	print("Existing pickups: ", existing_pickups.size())

	if existing_pickups.size() >= max_pickups:
		print("Cannot spawn: max pickups reached")
		return

	var points = spawn_points_root.get_children()
	print("Available spawn points: ", points.size())

	if points.size() == 0:
		print("Cannot spawn: no spawn points")
		return

	var point = points[randi() % points.size()]
	print("Selected spawn point: ", point.name, " at ", point.global_position)

	var pickup = AmmoPickupScene.instance()
	get_parent().add_child(pickup)

	pickup.global_position = point.global_position

	if pickup.has_method("set_spawn_position"):
		pickup.set_spawn_position(point.global_position)

	print("Ammo pickup spawned at: ", pickup.global_position)

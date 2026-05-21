extends Node2D

export(PackedScene) var ArmorPickupScene
export var spawn_interval = 12.0
export var max_pickups = 2
export var spawn_on_start = true
export var occupied_radius = 24.0

onready var spawn_points_root = get_node_or_null("../ArmorSpawnPoints")

var spawn_timer = 0.0


func _ready():
	randomize()
	spawn_timer = rand_range(0.5, spawn_interval)


func _process(delta):
	if ArmorPickupScene == null or spawn_points_root == null:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		try_spawn_pickup()


func try_spawn_pickup():
	if ArmorPickupScene == null or spawn_points_root == null:
		return

	var existing = get_tree().get_nodes_in_group("armor_pickup")
	if existing.size() >= max_pickups:
		return

	var points = spawn_points_root.get_children()
	if points.size() == 0:
		return

	var free_points = []
	for sp in points:
		var taken = false
		for p in existing:
			if p.global_position.distance_to(sp.global_position) < occupied_radius:
				taken = true
				break
		if not taken:
			free_points.append(sp)

	if free_points.size() == 0:
		return

	var point = free_points[randi() % free_points.size()]
	var pickup = ArmorPickupScene.instance()
	pickup.position = point.global_position
	get_parent().add_child(pickup)
	if pickup.has_method("set_spawn_position"):
		pickup.set_spawn_position(point.global_position)

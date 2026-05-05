extends KinematicBody2D

var speed = 80
var hp = 3
var player = null

func _ready():
	# Ищем игрока на сцене по имени группы
	player = get_tree().get_nodes_in_group("player")[0]

func _physics_process(delta):
	if player == null:
		return
	
	# Идём в сторону игрока
	var direction = (player.global_position - global_position).normalized()
	move_and_slide(direction * speed)
	
	# Смотрим на игрока
	look_at(player.global_position)

func take_damage(amount):
	hp -= amount
	if hp <= 0:
		queue_free()  # Удаляем врага

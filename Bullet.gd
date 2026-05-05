extends Area2D

var speed = 600
var direction = Vector2.ZERO
var damage = 1
var lifetime = 3.0

func _process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_Bullet_body_entered(body):
	# Если попали во врага — наносим урон
	print("пуля попала в: ", body.name)
	if body.name == "Player":
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()  # Пуля исчезает при любом попадании

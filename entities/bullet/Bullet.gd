extends Area2D

var speed = 600
var direction = Vector2.ZERO
var damage = 2
var lifetime = 3.0
var owner_node = null

func _process(delta):
	position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_Bullet_body_entered(body):
	if body == owner_node:
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
		if owner_node and is_instance_valid(owner_node) and owner_node.has_method("_on_my_bullet_hit"):
			owner_node._on_my_bullet_hit(damage, body)

	queue_free()

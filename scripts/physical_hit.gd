extends AnimatedSprite2D

func strike(attacker_pos: Vector2, defender_pos: Vector2) -> void:
	global_position = defender_pos
	var direction: Vector2 = defender_pos - attacker_pos
	rotation = direction.angle()
	play("default")
	animation_finished.connect(queue_free)

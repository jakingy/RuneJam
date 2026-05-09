extends AnimatedSprite2D

func launch_elemental_attack(start_pos: Vector2, end_pos: Vector2, element: String) -> void:
	global_position = start_pos
	var flight_animation = element + "_flight"
	var impact_animation = element + "_impact"
	
	if sprite_frames.has_animation(flight_animation):
		play(flight_animation)
	else:
		push_warning("Flight animation '%s' not found!" % flight_animation)
	look_at(end_pos)
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): _on_impact(impact_animation))

func _on_impact(impact_animation: String) -> void:
	rotation = 0.0
	if sprite_frames.has_animation(impact_animation):
		play(impact_animation)
		animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

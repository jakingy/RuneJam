extends Node2D

signal hovered
signal hovered_off

func _ready() -> void:
	get_parent().connect_card_signal(self)
	$Name.text = "Knight"
	to_front()

func flip() -> void:
	if self.get_node("CardImageFront").visible:
		to_back()
	else:
		to_front()

func to_front() -> void:
	self.get_node("CardImageFront").visible = true
	self.get_node("CardImageBack").visible = false
	$Name.visible = false
	
func to_back() -> void:
	self.get_node("CardImageFront").visible = false
	self.get_node("CardImageBack").visible = true
	$Name.visible = true
	
func animate_to_position(pos: Vector2) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "position", pos, 0.1)

func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_shape_exited(shape_idx: int) -> void:
	emit_signal("hovered_off", self)

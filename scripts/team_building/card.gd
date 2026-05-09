extends Node2D

signal hovered
signal hovered_off

var noun
var adjectives
var tier
var max_health
var physical_attack
var physical_defense
var magic_attack
var magic_defense
var speed
var holder

var the_card: Card

func _ready() -> void:
	get_parent().connect_card_signal(self)
	to_front()
	
func set_attribute(card: Card):
	noun = card.get_noun_str()
	tier = card.get_total_tier()
	max_health = card.get_max_health()
	physical_attack = card.get_physical_attack()
	physical_defense = card.get_physical_defence()
	magic_attack = card.get_magic_attack()
	magic_defense = card.get_magic_defence()
	speed = card.get_speed()
	the_card = card
	update_labels()
	
func update_labels():
	$Name.text = noun
	$Tier.text = str(tier)
	$MaxHealth.text = "H: " + str(max_health)
	$PhysicAttack.text = "P.A: " + str(physical_attack)
	$PhysicDefense.text = "P.D: " + str(physical_defense)
	$MagicAttack.text = "M.A: " + str(magic_attack)
	$MagicDefense.text = "M.D: " + str(magic_defense)
	$Speed.text = "S: " + str(speed)

func flip() -> void:
	if self.get_node("CardImageFront").visible:
		to_back()
	else:
		to_front()

func to_front() -> void:
	self.get_node("CardImageFront").visible = true
	self.get_node("CardImageBack").visible = false
	$Name.visible = false
	$Name.visible = false
	$Tier.visible = false
	$MaxHealth.visible = false
	$PhysicAttack.visible = false
	$PhysicDefense.visible = false
	$MagicAttack.visible = false
	$MagicDefense.visible = false
	$Speed.visible = false
	
func to_back() -> void:
	self.get_node("CardImageFront").visible = false
	self.get_node("CardImageBack").visible = true
	$Name.visible = true
	$Name.visible = true
	$Tier.visible = true
	$MaxHealth.visible = true
	$PhysicAttack.visible = true
	$PhysicDefense.visible = true
	$MagicAttack.visible = true
	$MagicDefense.visible = true
	$Speed.visible = true
	
func animate_to_position(pos: Vector2) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "position", pos, 0.1)

func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_shape_exited(shape_idx: int) -> void:
	emit_signal("hovered_off", self)

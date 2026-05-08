class_name Noun
extends Resource

@export var max_health: float
@export var physical_attack: float
@export var physical_defence: float
@export var magic_attack: float
@export var magic_defence: float
@export var speed: float

func _init(p_max_health: float = 100, p_physical_attack: float = 10, p_physical_defence: float = 10,
	p_magic_attack: float = 10, p_magic_defence: float = 10, p_speed: float = 10):
	max_health = p_max_health
	physical_attack = p_physical_attack
	physical_defence = p_physical_defence
	magic_attack = p_magic_attack
	magic_defence = p_magic_defence
	speed = p_speed	

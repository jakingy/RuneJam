class_name Adjective
extends Resource

@export var max_health_multiplier: float
@export var physical_attack_multiplier: float
@export var physical_defence_multiplier: float
@export var magic_attack_multiplier: float
@export var magic_defence_multiplier: float
@export var speed_multiplier: float

func _init(p_max_health_multiplier: float = 1, p_physical_attack_multiplier: float = 1,p_physical_defence_multiplier: float = 1,
	p_magic_attack_multiplier: float = 1, p_magic_defence_multiplier: float = 1, p_speed_multiplier: float = 1):
	max_health_multiplier = p_max_health_multiplier
	physical_attack_multiplier = p_physical_attack_multiplier
	physical_defence_multiplier = p_physical_defence_multiplier
	magic_attack_multiplier = p_magic_attack_multiplier
	magic_defence_multiplier = p_magic_defence_multiplier
	speed_multiplier = p_speed_multiplier

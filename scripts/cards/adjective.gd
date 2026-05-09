class_name Adjective
extends Resource

@export var word: String
@export var tier: int
@export var max_health_multiplier_shape: float
@export var physical_attack_multiplier_shape: float
@export var physical_defence_multiplier_shape: float
@export var magic_attack_multiplier_shape: float
@export var magic_defence_multiplier_shape: float
@export var speed_multiplier_shape: float

func _init(p_word: String = "", p_tier: int = 0, p_max_health_multiplier_shape: float = 0,
	p_physical_attack_multiplier_shape: float = 0, p_physical_defence_multiplier_shape: float = 0,
	p_magic_attack_multiplier_shape: float = 0, p_magic_defence_multiplier_shape: float = 0,
	p_speed_multiplier_shape: float = 0):
	word = p_word
	tier = p_tier
	max_health_multiplier_shape = p_max_health_multiplier_shape
	physical_attack_multiplier_shape = p_physical_attack_multiplier_shape
	physical_defence_multiplier_shape = p_physical_defence_multiplier_shape
	magic_attack_multiplier_shape = p_magic_attack_multiplier_shape
	magic_defence_multiplier_shape = p_magic_defence_multiplier_shape
	speed_multiplier_shape = p_speed_multiplier_shape

func get_word() -> String:
	return word
	
func get_tier() -> int:
	return tier

func get_max_health_multiplier() -> float:
	return 6 * tier * max_health_multiplier_shape

func get_physical_attack_multiplier() -> float:
	return 6 * tier * physical_attack_multiplier_shape

func get_physical_defence_multiplier() -> float:
	return 6 * tier * physical_defence_multiplier_shape

func get_magic_attack_multiplier() -> float:
	return 6 * tier * magic_attack_multiplier_shape

func get_magic_defence_multiplier() -> float:
	return 6 * tier * magic_defence_multiplier_shape

func get_speed_multiplier() -> float:
	return 6 * tier * speed_multiplier_shape

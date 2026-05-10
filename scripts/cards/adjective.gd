class_name Adjective
extends Resource

@export var words: String
@export var tier: float
@export var max_health_bias_weight: float
@export var physical_attack_bias_weight: float
@export var physical_defence_bias_weight: float
@export var magic_attack_bias_weight: float
@export var magic_defence_bias_weight: float
@export var speed_bias_weight: float

func _init(p_words: String = "", p_tier: float = 0, p_max_health_bias_weight: float = 0,
	p_physical_attack_bias_weight: float = 0, p_physical_defence_bias_weight: float = 0,
	p_magic_attack_bias_weight: float = 0, p_magic_defence_bias_weight: float = 0,
	p_speed_bias_weight: float = 0):
	words = p_words
	tier = p_tier
	max_health_bias_weight = p_max_health_bias_weight
	physical_attack_bias_weight = p_physical_attack_bias_weight
	physical_defence_bias_weight = p_physical_defence_bias_weight
	magic_attack_bias_weight = p_magic_attack_bias_weight
	magic_defence_bias_weight = p_magic_defence_bias_weight
	speed_bias_weight = p_speed_bias_weight

func get_words() -> String:
	return words
	
func get_tier() -> float:
	return tier

func get_max_health_bias() -> float:
	return 60 * tier * max_health_bias_weight

func get_physical_attack_bias() -> float:
	return 6 * tier * physical_attack_bias_weight

func get_physical_defence_bias() -> float:
	return 6 * tier * physical_defence_bias_weight

func get_magic_attack_bias() -> float:
	return 6 * tier * magic_attack_bias_weight

func get_magic_defence_bias() -> float:
	return 6 * tier * magic_defence_bias_weight

func get_speed_bias() -> float:
	return 6 * tier * speed_bias_weight

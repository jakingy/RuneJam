class_name Adjective
extends Resource

@export var word: String
@export var tier: float
@export var max_health_multiplier_weight: float
@export var physical_attack_multiplier_weight: float
@export var physical_defence_multiplier_weight: float
@export var magic_attack_multiplier_weight: float
@export var magic_defence_multiplier_weight: float
@export var speed_multiplier_weight: float

func _init(p_word: String = "", p_tier: float = 0, p_max_health_multiplier_weight: float = 0,
	p_physical_attack_multiplier_weight: float = 0, p_physical_defence_multiplier_weight: float = 0,
	p_magic_attack_multiplier_weight: float = 0, p_magic_defence_multiplier_weight: float = 0,
	p_speed_multiplier_weight: float = 0):
	word = p_word
	tier = p_tier
	max_health_multiplier_weight = p_max_health_multiplier_weight
	physical_attack_multiplier_weight = p_physical_attack_multiplier_weight
	physical_defence_multiplier_weight = p_physical_defence_multiplier_weight
	magic_attack_multiplier_weight = p_magic_attack_multiplier_weight
	magic_defence_multiplier_weight = p_magic_defence_multiplier_weight
	speed_multiplier_weight = p_speed_multiplier_weight

func normalise() -> void:
	var sum: float = max_health_multiplier_weight + physical_attack_multiplier_weight + physical_defence_multiplier_weight \
	+ magic_attack_multiplier_weight + magic_defence_multiplier_weight + speed_multiplier_weight
	max_health_multiplier_weight /= sum
	physical_attack_multiplier_weight /= sum
	physical_defence_multiplier_weight /= sum
	magic_attack_multiplier_weight /= sum
	magic_defence_multiplier_weight /= sum
	speed_multiplier_weight /= sum

func get_word() -> String:
	return word
	
func get_tier() -> float:
	return tier

func get_max_health_multiplier() -> float:
	return 6 * tier * max_health_multiplier_weight

func get_physical_attack_multiplier() -> float:
	return 6 * tier * physical_attack_multiplier_weight

func get_physical_defence_multiplier() -> float:
	return 6 * tier * physical_defence_multiplier_weight

func get_magic_attack_multiplier() -> float:
	return 6 * tier * magic_attack_multiplier_weight

func get_magic_defence_multiplier() -> float:
	return 6 * tier * magic_defence_multiplier_weight

func get_speed_multiplier() -> float:
	return 6 * tier * speed_multiplier_weight

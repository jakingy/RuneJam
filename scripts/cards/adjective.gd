class_name Adjective
extends Resource

@export var words: String
@export var tier: float
@export var max_health_multiplier_weight: float
@export var physical_attack_multiplier_weight: float
@export var physical_defence_multiplier_weight: float
@export var magic_attack_multiplier_weight: float
@export var magic_defence_multiplier_weight: float
@export var speed_multiplier_weight: float

func _init(p_words: String = "", p_tier: float = 0, p_max_health_multiplier_weight: float = 0,
	p_physical_attack_multiplier_weight: float = 0, p_physical_defence_multiplier_weight: float = 0,
	p_magic_attack_multiplier_weight: float = 0, p_magic_defence_multiplier_weight: float = 0,
	p_speed_multiplier_weight: float = 0):
	words = p_words
	tier = p_tier
	max_health_multiplier_weight = p_max_health_multiplier_weight
	physical_attack_multiplier_weight = p_physical_attack_multiplier_weight
	physical_defence_multiplier_weight = p_physical_defence_multiplier_weight
	magic_attack_multiplier_weight = p_magic_attack_multiplier_weight
	magic_defence_multiplier_weight = p_magic_defence_multiplier_weight
	speed_multiplier_weight = p_speed_multiplier_weight

func normalise() -> void:
	return
	var sum: float = max_health_multiplier_weight + physical_attack_multiplier_weight + physical_defence_multiplier_weight \
	+ magic_attack_multiplier_weight + magic_defence_multiplier_weight + speed_multiplier_weight
	max_health_multiplier_weight /= sum
	physical_attack_multiplier_weight /= sum
	physical_defence_multiplier_weight /= sum
	magic_attack_multiplier_weight /= sum
	magic_defence_multiplier_weight /= sum
	speed_multiplier_weight /= sum

func get_words() -> String:
	return words
	
func get_tier() -> float:
	return tier

func get_max_health_multiplier() -> float:
	return 1.5 ** (log(tier + 1) * max_health_multiplier_weight)

func get_physical_attack_multiplier() -> float:
	return 1.5 ** (log(tier + 1) * physical_attack_multiplier_weight)

func get_physical_defence_multiplier() -> float:
	return 1.5 ** (log(tier + 1) * physical_defence_multiplier_weight)

func get_magic_attack_multiplier() -> float:
	return 1.5 ** (log(tier + 1) * magic_attack_multiplier_weight)

func get_magic_defence_multiplier() -> float:
	return 1.5 ** (log(tier + 1) * magic_defence_multiplier_weight)

func get_speed_multiplier() -> float:
	return 1.5 ** (log(tier + 1) * speed_multiplier_weight)

class_name Noun
extends Resource

@export var words: String
@export var tier: float
@export var element: String
@export var max_health_weight: float
@export var physical_attack_weight: float
@export var physical_defence_weight: float
@export var magic_attack_weight: float
@export var magic_defence_weight: float
@export var speed_weight: float

func _init(p_words: String = "", p_tier: float = 0, p_element: String = "", p_max_health_weight: float = 0, p_physical_attack_weight: float = 0,
	p_physical_defence_weight: float = 0, p_magic_attack_weight: float = 0, p_magic_defence_weight: float = 0, p_speed_weight: float = 0):
	words = p_words
	tier = p_tier
	element = p_element
	max_health_weight = p_max_health_weight
	physical_attack_weight = p_physical_attack_weight
	physical_defence_weight = p_physical_defence_weight
	magic_attack_weight = p_magic_attack_weight
	magic_defence_weight = p_magic_defence_weight
	speed_weight = p_speed_weight

func normalise() -> void:
	var sum: float = max_health_weight + physical_attack_weight + physical_defence_weight \
	+ magic_attack_weight + magic_defence_weight + speed_weight
	max_health_weight /= sum
	physical_attack_weight /= sum
	physical_defence_weight /= sum
	magic_attack_weight /= sum
	magic_defence_weight /= sum
	speed_weight /= sum

func get_words() -> String:
	return words

func get_tier() -> float:
	return tier

func get_max_health() -> float:
	return 600 * tier * max_health_weight

func get_physical_attack() -> float:
	return 80 * tier * physical_attack_weight

func get_physical_defence() -> float:
	return 20 * tier * physical_defence_weight

func get_magic_attack() -> float:
	return 80 * tier * magic_attack_weight

func get_magic_defence() -> float:
	return 20 * tier * magic_defence_weight

func get_speed() -> float:
	return 60 * tier * speed_weight

class_name Noun
extends Resource

@export var word: String
@export var tier: int
@export var max_health_shape: float
@export var physical_attack_shape: float
@export var physical_defence_shape: float
@export var magic_attack_shape: float
@export var magic_defence_shape: float
@export var speed_shape: float

func _init(p_word: String = "", p_tier: int = 0, p_max_health_shape: float = 0, p_physical_attack_shape: float = 0,
	p_physical_defence_shape: float = 0, p_magic_attack_shape: float = 0, p_magic_defence_shape: float = 0, p_speed_shape: float = 0):
	word = p_word
	tier = p_tier
	max_health_shape = p_max_health_shape
	physical_attack_shape = p_physical_attack_shape
	physical_defence_shape = p_physical_defence_shape
	magic_attack_shape = p_magic_attack_shape
	magic_defence_shape = p_magic_defence_shape
	speed_shape = p_speed_shape

func get_word() -> String:
	return word

func get_tier() -> int:
	return tier

func get_max_health() -> float:
	return 600 * tier * max_health_shape

func get_physical_attack() -> float:
	return 60 * tier * physical_attack_shape

func get_physical_defence() -> float:
	return 60 * tier * physical_defence_shape

func get_magic_attack() -> float:
	return 60 * tier * magic_attack_shape

func get_magic_defence() -> float:
	return 60 * tier * magic_defence_shape

func get_speed() -> float:
	return 60 * tier * speed_shape

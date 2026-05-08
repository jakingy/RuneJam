class_name Card
extends Resource

@export var noun: Noun
@export var adjectives: Array[Adjective]

func _init(p_noun: Noun = null, p_adjectives: Array[Adjective] = []):
	noun = p_noun
	adjectives = p_adjectives

func get_max_health() -> int:
	if not noun:
		return 0
	
	var val = noun.max_health
	for adj in adjectives:
		val *= adj.max_health_multiplier
	return val

func get_physical_attack() -> int:
	if not noun:
		return 0
	
	var val = noun.physical_attack
	for adj in adjectives:
		val *= adj.physical_attack_multiplier
	return val

func get_physical_defence() -> int:
	if not noun:
		return 0
	
	var val = noun.physical_defence
	for adj in adjectives:
		val *= adj.physical_defence_multiplier	
	return val

func get_magic_attack() -> int:
	if not noun:
		return 0
	
	var val = noun.magic_attack
	for adj in adjectives:
		val *= adj.magic_attack_multiplier
	return val
	
func get_magic_defence() -> int:
	if not noun:
		return 0
	
	var val = noun.magic_defence
	for adj in adjectives:
		val *= adj.magic_defence_multiplier
	return val
	
func get_speed() -> int:
	if not noun:
		return 0
	
	var val = noun.speed
	for adj in adjectives:
		val *= adj.speed_multiplier
	return val

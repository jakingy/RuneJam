class_name Card
extends Resource

@export var noun: Noun
@export var adjectives: Array[Adjective]

func _init(p_noun: Noun = null, p_adjectives: Array[Adjective] = []):
	noun = p_noun
	adjectives = p_adjectives

func get_name_str() -> String:
	var 	name: String = noun.get_word()
	for adj in adjectives:
		name += " " + adj.get_word()
	return name
	
func get_total_tier() -> String:
	var val = noun.get_tier()
	for adj in adjectives:
		val += adj.get_tier()
	return val

func get_max_health() -> int:
	var val = noun.get_max_health()
	for adj in adjectives:
		val *= adj.get_max_health_multiplier()
	return val

func get_physical_attack() -> int:
	var val = noun.get_physical_attack()
	for adj in adjectives:
		val *= adj.get_physical_attack_multiplier()
	return val

func get_physical_defence() -> int:
	var val = noun.get_physical_defence()
	for adj in adjectives:
		val *= adj.get_physical_defence_multiplier()
	return val

func get_magic_attack() -> int:
	var val = noun.get_magic_attack()
	for adj in adjectives:
		val *= adj.get_magic_attack_multiplier()
	return val
	
func get_magic_defence() -> int:
	var val = noun.get_magic_defence()
	for adj in adjectives:
		val *= adj.get_magic_defence_multiplier()
	return val
	
func get_speed() -> int:
	var val = noun.get_speed()
	for adj in adjectives:
		val *= adj.get_speed_multiplier()
	return val

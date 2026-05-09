extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var nouns: Array[Noun] = CardsManager.get_base_nouns()
	
	for noun in nouns:
		print(noun.get_words() + " - Tier " + str(noun.get_tier()))
		print("health: " + str(noun.get_max_health()))
		print("phys dmg: " + str(noun.get_physical_attack()))
		print("phys def: " + str(noun.get_physical_defence()))
		print("magic dmg: " + str(noun.get_magic_attack()))
		print("magic def: " + str(noun.get_magic_defence()))
		print("speed: " + str(noun.get_speed()))
		print()

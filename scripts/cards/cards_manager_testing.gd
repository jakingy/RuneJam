extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var adjs: Array[Adjective] = CardsManager.get_base_adjectives()
	
	print(len(adjs))
	for adj in adjs:
		if adj.get_tier() >= 2:
			continue
		print(adj.get_words())
		print(adj.get_tier())
		print(adj.get_max_health_multiplier())
		print(adj.get_physical_attack_multiplier())
		print(adj.get_physical_defence_multiplier())
		print(adj.get_magic_attack_multiplier())
		print(adj.get_magic_defence_multiplier())
		print(adj.get_speed_multiplier())
		print()

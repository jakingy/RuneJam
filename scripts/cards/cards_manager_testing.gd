extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var a: Array[Adjective] = CardsManager.get_base_adjectives()
	var ea: Adjective = await CardsManager.fuse_adjectives(a[0], a[1])
	
	print(ea.word, ea.tier, ea.max_health_multiplier_weight)

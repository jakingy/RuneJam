extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var adjs: Array[Adjective] = CardsManager.get_base_adjectives()
	var nouns: Array[Noun] = CardsManager.get_base_nouns()
	
	var c: Card = CardsManager.create_card(nouns[0], adjs)
	
	print(c.get_name_str())

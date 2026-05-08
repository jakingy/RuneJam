extends Node

func get_base_nouns() -> Array[Noun]:
	return []

func get_base_adjectives() -> Array[Adjective]:
	return []

func fuse_nouns(noun1: Noun, noun2: Noun) -> Noun:
	return null

func fuse_adjectives(adj1: Adjective, adj2: Adjective) -> Adjective:
	return null 

func create_card(noun: Noun = null, adjectives: Array[Adjective] = []) -> Card:
	return null

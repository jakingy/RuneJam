extends Node

func get_base_nouns() -> Array[Noun]:
	var base_nouns: Array[Noun] = []
	
	var path = "res://resources/nouns/"
	var dir = DirAccess.open(path)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = path + file_name
			var noun_res = load(full_path)
			
			if noun_res is Noun:
				base_nouns.append(noun_res)
		
		file_name = dir.get_next()
	return base_nouns

func get_base_adjectives() -> Array[Adjective]:
	return []

func fuse_nouns(noun1: Noun, noun2: Noun) -> Noun:
	return null

func fuse_adjectives(adj1: Adjective, adj2: Adjective) -> Adjective:
	return null 

func create_card(noun: Noun = null, adjectives: Array[Adjective] = []) -> Card:
	return Card.new(noun, adjectives)

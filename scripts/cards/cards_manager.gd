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
				noun_res.normalise()
				base_nouns.append(noun_res)
		
		file_name = dir.get_next()
	return base_nouns

func get_base_adjectives() -> Array[Adjective]:
	var base_adjs: Array[Adjective] = []
	
	var path = "res://resources/adjectives/"
	var dir = DirAccess.open(path)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = path + file_name
			var adj_res = load(full_path)
			
			if adj_res is Adjective:
				adj_res.normalise()
				base_adjs.append(adj_res)
		
		file_name = dir.get_next()
	return base_adjs

func fuse_nouns(noun1: Noun, noun2: Noun) -> Noun:
	return Noun.new (
		await PromptAPI.fuse_nouns([noun1.get_word(), noun2.get_word()]),
		(noun1.tier ** 2 + noun2.tier ** 2) ** 0.5,
		(noun1.max_health_weight + noun2.max_health_weight) / 2,
		(noun1.physical_attack_weight + noun2.physical_attack_weight) / 2,
		(noun1.physical_defence_weight + noun2.physical_defence_weight) / 2,
		(noun1.magic_attack_weight + noun2.magic_attack_weight) / 2,
		(noun1.magic_defence_weight + noun2.magic_defence_weight) / 2,
		(noun1.speed_weight + noun2.speed_weight) / 2
	)

func fuse_adjectives(adj1: Adjective, adj2: Adjective) -> Adjective:
	return Adjective.new (
		await PromptAPI.fuse_adjectives([adj1.get_word(), adj2.get_word()]),
		(adj1.tier ** 2 + adj2.tier ** 2) ** 0.5,
		(adj1.max_health_multiplier_weight + adj2.max_health_multiplier_weight) / 2,
		(adj1.physical_attack_multiplier_weight + adj2.physical_attack_multiplier_weight) / 2,
		(adj1.physical_defence_multiplier_weight + adj2.physical_defence_multiplier_weight) / 2,
		(adj1.magic_attack_multiplier_weight + adj2.magic_attack_multiplier_weight) / 2,
		(adj1.magic_defence_multiplier_weight + adj2.magic_defence_multiplier_weight) / 2,
		(adj1.speed_multiplier_weight + adj2.speed_multiplier_weight) / 2
	)

func create_card(noun: Noun = null, adjectives: Array[Adjective] = []) -> Card:
	return Card.new(noun, adjectives)

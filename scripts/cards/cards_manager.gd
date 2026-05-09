extends Node

var nouns_deck: Array[Noun];
var adjectives_deck: Array[Adjective];
var player_cards: Array[Card] = [];

func compute_attack_damage(attacker: Card, defender: Card, is_magic: bool) -> float:
	var dmg: float = 0;
	if !is_magic:
		dmg = attacker.get_physical_attack() - defender.get_physical_defence()
	else:
		dmg = attacker.get_magic_attack() - defender.get_magic_defence()
	var element_multipliers: Dictionary[String, float] = {
		"fire -> ice" = 1.5,
		"water -> fire" = 1.5,
		"lightning -> water" = 1.5,
		"fire -> plant" = 1.5,
		"light -> dark" = 1.5,
		"dark -> plant" = 1.5,
		"plant -> water" = 1.5,
		"ice -> earth" = 1.5,
		"air -> lightning" = 1.5
	}
	var matchup_str: String = attacker.get_element() + " -> " + defender.get_element()
	if matchup_str in element_multipliers:
		dmg *= element_multipliers[matchup_str]
	return dmg

func add_card_to_player_cards(card: Card) -> void:
	player_cards.append(card);
	
func get_player_cards() -> Array[Card]:
	return player_cards

func init_deck() -> void:
	"""Draws all base nouns and adjectives to their respective decks"""
	nouns_deck = get_base_nouns()
	adjectives_deck = get_base_adjectives()

func draw_nouns(num: int = 3, min_tier: float = 1) -> Array[Noun]:
	var drawn: Array[Noun] = []
	
	for i in range(num):
		var weights: Array[float] = []
		var elems: Array[Noun] = []
		for noun in nouns_deck:
			if noun.get_tier() >= min_tier:
				elems.append(noun)
				weights.append(1 / (noun.tier ** 2))
				
		var drawn_noun: Noun = pick_random_weighted(elems, weights)
		nouns_deck.remove_at(nouns_deck.find(drawn_noun))
		drawn.append(drawn_noun)
	
	return drawn

func draw_adjectives(num: int = 3, min_tier: float = 1) -> Array[Adjective]:
	var drawn: Array[Adjective] = []
	
	for i in range(num):
		var weights: Array[float] = []
		var elems: Array[Adjective] = []
		for adj in adjectives_deck:
			if adj.get_tier() >= min_tier:
				elems.append(adj)
				weights.append(1 / (adj.tier ** 2))
				
		var drawn_adj: Adjective = pick_random_weighted(elems, weights)
		adjectives_deck.remove_at(adjectives_deck.find(drawn_adj))
		drawn.append(drawn_adj)
	
	return drawn
	
func pick_random_weighted(a: Array, w: Array[float]):
	var sum_of_weights: float = 0
	for elem in w:
		sum_of_weights += elem
	
	var thres: float = randf() * sum_of_weights
	var cw: float = 0
	for i in range(len(a)):
		cw += w[i]
		if cw > thres:
			return a[i]

func get_base_nouns() -> Array[Noun]:
	var base_nouns: Array[Noun] = []
	
	var path = "res://words/nouns/"
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
	
	var path = "res://words/adjectives/"
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
	var new_noun: Noun = Noun.new (
		await PromptAPI.fuse_nouns([noun1.get_words(), noun2.get_words()]),
		max(noun1.tier, noun2.tier),
		noun1.get_element() if noun1.get_tier() > noun2.get_tier() else noun2.get_element(),
		(noun1.max_health_weight + noun2.max_health_weight) / 2,
		(noun1.physical_attack_weight + noun2.physical_attack_weight) / 2,
		(noun1.physical_defence_weight + noun2.physical_defence_weight) / 2,
		(noun1.magic_attack_weight + noun2.magic_attack_weight) / 2,
		(noun1.magic_defence_weight + noun2.magic_defence_weight) / 2,
		(noun1.speed_weight + noun2.speed_weight) / 2
	)
	new_noun.normalise()
	return new_noun

func fuse_adjectives(adj1: Adjective, adj2: Adjective) -> Adjective:
	var new_adj: Adjective = Adjective.new (
		await PromptAPI.fuse_adjectives([adj1.get_words(), adj2.get_words()]),
		max(adj1.tier, adj2.tier),
		(adj1.max_health_multiplier_weight + adj2.max_health_multiplier_weight) / 2,
		(adj1.physical_attack_multiplier_weight + adj2.physical_attack_multiplier_weight) / 2,
		(adj1.physical_defence_multiplier_weight + adj2.physical_defence_multiplier_weight) / 2,
		(adj1.magic_attack_multiplier_weight + adj2.magic_attack_multiplier_weight) / 2,
		(adj1.magic_defence_multiplier_weight + adj2.magic_defence_multiplier_weight) / 2,
		(adj1.speed_multiplier_weight + adj2.speed_multiplier_weight) / 2
	)
	new_adj.normalise()
	return new_adj

func create_card(noun: Noun = null, adjectives: Array[Adjective] = []) -> Card:
	return Card.new(noun, adjectives)

extends Node2D

const CARD_SCENE_PATH = "res://scenes/team_building/card.tscn"
const BATTLE_SCENE_PATH = "res://scenes/battle.tscn"

var card_node_scene
var turn_count = 0
var bot_hand_ref
var usr_hand_ref
var card_scene
var bot_deck: Array[Card] = []
var noun_turn_count = 3
var adj_turn_count = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bot_hand_ref = $BotHand
	usr_hand_ref = $Hand
	card_scene = preload(CARD_SCENE_PATH)
	card_node_scene = preload(CARD_SCENE_PATH)
	CardsManager.init_deck()
	var cards: Array[Card] = []
	var base_nouns: Array[Noun] = CardsManager.draw_nouns()
	for noun in base_nouns:
		cards.append(Card.new(noun))
	$Deck.spawn_cards(cards)
		
	base_nouns = CardsManager.draw_nouns()
	for noun in base_nouns:
		bot_deck.append(Card.new(noun))
		
	noun_turn_count -= 1
		


func connect_signal(card_manager):
	card_manager.connect("submit_turn", on_user_submit_turn)
	
func on_user_submit_turn():
	if turn_count < 8:
		turn_count += 1
		bot_move()
	if turn_count == 8:
		$Deck.empty_deck()
		print('Done phrase')
		var next_scene_resource = load(BATTLE_SCENE_PATH)
		var next_scene = next_scene_resource.instantiate()

		# Pass your custom data
		next_scene.starting_characters = get_user_team() + get_bot_team()
		
		print(next_scene.starting_characters)

		# 1. Cache the tree before we delete anything!
		var tree = get_tree() 
		var root = tree.root
		var current_scene = tree.current_scene

		# 2. Remove the old scene
		root.remove_child(current_scene)
		current_scene.queue_free()

		# 3. Add the new scene and update current_scene using the cached 'tree' variable
		root.add_child(next_scene)
		tree.current_scene = next_scene
		return
	$Deck.empty_deck()
	bot_deck.clear()
	if adj_turn_count > 0 and (randi_range(1, 2) == 1 or noun_turn_count == 0):
		adj_turn_count -= 1
		var cards: Array[Card] = []
		var base_adjs: Array[Adjective] = CardsManager.draw_adjectives()
		print(base_adjs)
		for adj in base_adjs:
			cards.append(Card.new(Noun.new('Effect'), [adj]))
		$Deck.spawn_cards(cards)
		
		base_adjs = CardsManager.draw_adjectives()
		for adj in base_adjs:
			bot_deck.append(Card.new(Noun.new('Effect'), [adj]))
	else:
		noun_turn_count -= 1
		var cards: Array[Card] = []
		var base_nouns: Array[Noun] = CardsManager.draw_nouns()
		for noun in base_nouns:
			cards.append(Card.new(noun))
		$Deck.spawn_cards(cards)
			
		base_nouns = CardsManager.draw_nouns()
		for noun in base_nouns:
			bot_deck.append(Card.new(noun))

func bot_move():
	if bot_deck[0].get_noun_str() == "Effect":
		var idx = randi_range(0, bot_hand_ref.cards.size() - 1)
		bot_hand_ref.cards[idx].the_card.add_adjective(bot_deck[0].adjectives[0])
		bot_hand_ref.cards[idx].set_attribute(bot_hand_ref.cards[idx].the_card)
	else:
		add_to_bot_hand(bot_deck[0])

func add_to_bot_hand(card: Card):
	var card_node = card_scene.instantiate()
	$CardManager.add_child(card_node)
	card_node.z_index = 3
	card_node.set_attribute(card)
	card_node.name = "card"
	card_node.holder = self
	bot_hand_ref.add_card(card_node)

func get_user_team() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for i in range(usr_hand_ref.cards.size()):
		var card: Card = usr_hand_ref.cards[i].the_card
		res.append(convert_card_to_llm_schema(card, "team_a", "Team A", i + 1))
	return res
	
func get_bot_team() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for i in range(bot_hand_ref.cards.size()):
		var card: Card = bot_hand_ref.cards[i].the_card
		res.append(convert_card_to_llm_schema(card, "team_b", "Team B", i + 1))
	return res

func convert_card_to_llm_schema(card: Card, team: String, team_name: String, id: int):
	var res: Dictionary = {}
	res["id"] = team + "_unit_" + str(id)
	res["display_name"] = card.get_name_str()
	res["nouns"] = [card.get_noun_str()]
	res["adjectives"] = card.get_adjectives_str()
	res["elements"] = [card.get_element()]
	res["side"] = team_name
	res["max hp"] = card.get_max_health()
	res["hp"] = card.get_max_health()
	res["physical_attack"] = card.get_physical_attack()
	res["physical_defence"] = card.get_physical_defence()
	res["magic_power"] = card.get_magic_attack()
	res["magic_defence"] = card.get_magic_defence()
	res["speed"] = card.get_speed()
	res["size"] = card.get_total_tier()
	return res
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

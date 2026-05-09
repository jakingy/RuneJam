extends Node2D

const CARD_SCENE_PATH = "res://scenes/team_building/card.tscn"

var card_node_scene
var turn_count = 0
var bot_hand_ref
var card_scene
var bot_deck: Array[Card] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bot_hand_ref = $BotHand
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
		


func connect_signal(card_manager):
	card_manager.connect("submit_turn", on_user_submit_turn)
	
func on_user_submit_turn():
	if turn_count < 3:
		turn_count += 1
		bot_move()
	if turn_count == 3:
		$Deck.empty_deck()
		print('Done phrase')
		return
	$Deck.empty_deck()
	bot_deck.clear()
	if randi_range(1, 2) == 1:
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
	card_node.set_attribute(card)
	card_node.name = "card"
	card_node.holder = self
	bot_hand_ref.add_card(card_node)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

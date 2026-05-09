extends Node2D

const CARD_SCENE_PATH = "res://scenes/team_building/card.tscn"

var card_node_scene
var turn_count = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	card_node_scene = preload(CARD_SCENE_PATH)
	var cards: Array[Card] = []
	CardsManager.init_deck()
	var base_nouns: Array[Noun] = CardsManager.draw_nouns()
	#print(base_nouns)
	for i in range(base_nouns.size()):
		cards.append(Card.new(base_nouns[i]))
	$Deck.spawn_cards(cards)


func connect_signal(card_manager):
	card_manager.connect("submit_turn", on_user_submit_turn)
	
func on_user_submit_turn():
	if turn_count < 3:
		turn_count += 1
	if turn_count == 3:
		$Deck.empty_deck()
		print('Done phrase')
		return
	$Deck.empty_deck()
	var cards: Array[Card] = []
	var base_adjs: Array[Adjective] = CardsManager.draw_adjectives()
	print(base_adjs)
	for i in range(base_adjs.size()):
		cards.append(Card.new(Noun.new('Effect'), [base_adjs[i]]))
	$Deck.spawn_cards(cards)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

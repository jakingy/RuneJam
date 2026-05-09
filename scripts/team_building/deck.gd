extends Node2D

const CARD_SCENE_PATH = "res://scenes/team_building/card.tscn"
const CARD_WIDTH = 260
const SCREEN_WIDTH = 1920
const SCREEN_HEIGHT = 1080

var card_scene
var cards: Array[Node2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	card_scene = preload(CARD_SCENE_PATH)
	#spawn_test_cards()

func spawn_test_cards() -> void:
	for i in range(5):
		var card = card_scene.instantiate()
		$"../CardManager".add_child(card)
		card.name = "card"
		add_card(card)
		
func spawn_cards(cards: Array[Card]):
	for i in range(cards.size()):
		var card = card_scene.instantiate()
		$"../CardManager".add_child(card)
		card.set_attribute(cards[i])
		card.name = "card"
		card.holder = self
		add_card(card)
		
func empty_deck():
	for card in cards:
		$"../CardManager".remove_child(card)
	cards = []
	update()
	
func add_card(card: Node2D) -> void:
	if not card in cards:
		cards.insert(0, card)
		update()
	
func update() -> void:
	for i in range(cards.size()):
		var new_pos = Vector2(calculate_card_position(i), $Area2D/CollisionShape2D.global_position.y)
		var card = cards[i]
		card.animate_to_position(new_pos)

func calculate_card_position(idx: int):
	var total_width = (cards.size() - 1) * CARD_WIDTH
	var center_screen_x = SCREEN_WIDTH / 2
	var x = center_screen_x + idx * CARD_WIDTH - total_width / 2
	return x
	
func remove(card: Node2D):
	cards.erase(card)
	update()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends Node2D

const CARD_WIDTH = 260
const SCREEN_WIDTH = 1920
const SCREEN_HEIGHT = 1080

var cards: Array[Node2D] = []
var hand_y

func _ready() -> void:
	hand_y = $Area2D/CollisionShape2D.shape.size.y

func add_card(card: Node2D) -> void:
	cards.insert(0, card)
	update()
	
func update() -> void:
	for i in range(cards.size()):
		var new_pos = Vector2(calculate_card_position(i), hand_y)
		var card = cards[i]
		card.animate_to_position(new_pos)

func calculate_card_position(idx: int):
	var total_width = (cards.size() - 1) * CARD_WIDTH
	var center_screen_x = SCREEN_WIDTH / 2
	var x = center_screen_x + idx * CARD_WIDTH - total_width / 2
	return x
	



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends Node2D

signal submit_turn

var card_being_dragged: Node2D
var is_hovering_on_card: bool = false

var hand_ref

func _ready() -> void:
	hand_ref = $"../Hand"
	get_parent().connect_signal(self)

func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = mouse_pos

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card: Node2D = raycast_check_for_card()
			if card and card.holder.name == "Deck":
				#print(card.holder.name)
				start_drag(card)
		else:
			if card_being_dragged:
				finish_drag()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if !event.pressed:
			var card: Node2D = raycast_check_for_card()
			if card:
				flip_card(card)

func start_drag(card: Node2D):
	card.z_index = 3
	card_being_dragged = card
	card.scale = Vector2(1.0, 1.0)
	
func finish_drag():
	card_being_dragged.scale = Vector2(1.05, 1.05)
	card_being_dragged.z_index = 1
	var hand = raycast_check_for_hand()
	var card = raycast_check_for_another_card(card_being_dragged)
	if card:
		print(card)
		var combined = await combine_card(card, card_being_dragged)
		if combined:
			card_being_dragged.holder.cards.erase(card_being_dragged)
			self.remove_child(card_being_dragged)
			if hand and hand.name == "Hand":
				emit_signal("submit_turn")
				return
		
	if hand and hand.name == "Hand" and card_being_dragged.noun != "Effect":
		card_being_dragged.scale = Vector2(1.0, 1.0)
		hand.add_card(card_being_dragged)
		card_being_dragged.holder.cards.erase(card_being_dragged)
		card_being_dragged.holder = hand
		emit_signal("submit_turn")
	else:
		card_being_dragged.holder.update()
	card_being_dragged = null
	
func flip_card(card: Node2D):
	var tween: Tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card, "scale:x", 0.5, 0.5 / 2);
	tween.tween_callback(card.flip)
	tween.tween_property(card, "scale:x", 1.0, 0.5 / 2)
	
func connect_card_signal(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)
	

func on_hovered_over_card(card):
	if !is_hovering_on_card:
		highlight_card(card, true)
		is_hovering_on_card = true
	
func on_hovered_off_card(card):
	if !card_being_dragged:
		highlight_card(card, false)
		var new_card_hovered = raycast_check_for_card()
		if new_card_hovered:
			highlight_card(new_card_hovered, true)
		else:
			is_hovering_on_card = false
	
func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(2.05, 2.05)
		card.z_index = 2
	else:
		card.scale = Vector2(1.0, 1.0)
		card.z_index = 1

func raycast_check_for_card():
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var parameters: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1
	var result: Array[Dictionary] = space_state.intersect_point(parameters)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	else:
		return null
		
func raycast_check_for_another_card(exclude: Node2D):
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var parameters: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1
	var result: Array[Dictionary] = space_state.intersect_point(parameters)
	if result.size() > 0:
		for item in result:
			if item.collider.get_parent() != exclude:
				return item.collider.get_parent()
		return null
	else:
		return null
		
func raycast_check_for_hand():
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var parameters: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 2
	var result: Array[Dictionary] = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	else:
		return null
		
func get_card_with_highest_z_index(arr: Array[Dictionary]):
	var res: Node2D = arr[0].collider.get_parent()
	for i in range(1, arr.size()):
		var current_card = arr[i].collider.get_parent()
		if current_card.z_index > res.z_index:
			res = current_card
	return res
	
func combine_card(card: Node2D, card_dragged: Node2D) -> bool:
	var type1 = 1 if card.the_card.get_noun_str() != "Effect" else 0
	var type2 = 1 if card_dragged.the_card.get_noun_str() != "Effect" else 0
	if type1 == type2:
		# fuse
		if card.holder.name == "Hand" or card.holder.name == "BotHand":
			return false
		if type1 == 1:
			# fuse noun
			var new_noun = await CardsManager.fuse_nouns(card.the_card.noun, card_dragged.the_card.noun)
			var new_card = Card.new(new_noun)
			card.set_attribute(new_card)
		else:
			# fuse adj
			var new_adj = await CardsManager.fuse_adjectives(card.the_card.adjectives[0], card_dragged.the_card.adjectives[0])
			var new_card = Card.new(Noun.new("Effect"), [new_adj])
			card.set_attribute(new_card)
	else:
		print("debug " + card_dragged.the_card.adjectives[0].get_words())
		for adj in card_dragged.the_card.adjectives:
			card.the_card.add_adjective(adj)
		card.set_attribute(card.the_card)
	return true

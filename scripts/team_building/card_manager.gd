extends Node2D

var card_being_dragged: Node2D
var is_hovering_on_card: bool = false

var hand_ref

func _ready() -> void:
	hand_ref = $"../Hand"

func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = mouse_pos

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card: Node2D = raycast_check_for_card()
			start_drag(card)
		else:
			if card_being_dragged:
				finish_drag()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if !event.pressed:
			var card: Node2D = raycast_check_for_card()
			flip_card(card)

func start_drag(card: Node2D):
	card_being_dragged = card
	card.scale = Vector2(1.0, 1.0)
	
func finish_drag():
	card_being_dragged.scale = Vector2(1.05, 1.05)
	var hand = raycast_check_for_hand()
	if hand:
		hand.add_card(card_being_dragged)
		card_being_dragged.scale = Vector2(1.0, 1.0)
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
		card.scale = Vector2(1.05, 1.05)
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
		
func raycast_check_for_hand():
	print('ok')
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

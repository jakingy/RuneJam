extends Node2D

@onready var map_image: TextureRect = $".."
@onready var marker_container: Node2D = $MarkerContainer

var marker_scene: PackedScene = preload("res://scenes/map_marker.tscn")

var grid_size_x: int = 16
var grid_size_y: int = 16

func get_pixel_position_from_grid(grid_x: int, grid_y: int) -> Vector2:
	var total_width: float = map_image.size.x
	var total_height: float = map_image.size.y

	var cell_width: float = total_width / grid_size_x
	var cell_height: float = total_width / grid_size_y
	
	var pixel_x: float = (float(grid_x) * cell_width) + (cell_width / 2.0)
	var pixel_y: float = (float(grid_y) * cell_height) + (cell_height / 2.0)
	
	return Vector2(pixel_x, pixel_y)

func spawn_character(character: Dictionary) -> void:
	var char_marker: MapMarker = marker_scene.instantiate() as MapMarker
	var character_x: int = character["x"]
	var character_y: int = character["y"]
	var character_z: int = character["z"]
	if char_marker == null:
		push_error("Failed to instantiate MapMarker :(")
		return
	
	marker_container.add_child(char_marker)
	if character["side"] == "Team A":
		char_marker.set_ring_color(Color.BLUE)
	elif character["side"] == "Team B":
		char_marker.set_ring_color(Color.RED)
	elif character["side"] == "Neutral":
		char_marker.set_ring_color(Color.YELLOW)
	char_marker.position = get_pixel_position_from_grid(character_x, character_y)
	char_marker.set_health(character["hp"], character["max_hp"])
	# char_marker.apply_elevation(character_z)

func spawn_object(object: Dictionary) -> void:
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character: Dictionary = {
		"max_hp": 100,
		"hp": 67,
		"side": "Team A",
		"x": 8,
		"y": 8,
		"z": 9,
	}
	call_deferred("spawn_character", character)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

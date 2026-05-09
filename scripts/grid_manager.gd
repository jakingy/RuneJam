extends Node2D

@onready var map_image: TextureRect = $"../MapImage"
@onready var makrker_container: Node2D = $MarkerContainer

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
	pass

func spawn_object(object: Dictionary) -> void:
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

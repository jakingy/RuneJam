extends Node2D

var character_display_scene = preload("res://scenes/character_display.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var c_display = character_display_scene.instantiate()
	add_child(c_display)
	
	var adjs: Array[String] = ["armoured", "infernal"]
	
	c_display.display_character("dragon", adjs)

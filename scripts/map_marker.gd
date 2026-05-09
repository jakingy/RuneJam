class_name MapMarker
extends Node2D

@onready var portrait: Sprite2D = $Visual/Portrait
@onready var placeholder: Label = $Visual/Placeholder
@onready var health_ring: TextureProgressBar = $Visual/HealthRing

var target_portrait_size: float = 85.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#placeholder.show()
	# portrait.hide()
	pass

func apply_dynamic_portrait(new_texture: Texture2D):
	portrait.texture = new_texture
	var actual_size = new_texture.get_size()
	var scale_factor = target_portrait_size / actual_size.x
	portrait.scale = Vector2(scale_factor, scale_factor)
	
	placeholder.hide()
	portrait.show()

func set_health(current_hp: int, max_hp: int) -> void:
	health_ring.max_value = max_hp
	health_ring.value = current_hp

func set_ring_color(new_color: Color) -> void:
	health_ring.tint_progress = new_color

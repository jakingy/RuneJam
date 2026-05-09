class_name MapMarker
extends Node2D

@onready var portrait: Sprite2D = $Visual/Portrait
@onready var placeholder: Label = $Visual/Placeholder
@onready var health_ring: TextureProgressBar = $Visual/HealthRing
@onready var character_display: PanelContainer = $Visual/CharacterDisplay
var health_tween: Tween

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

func take_damage(damage_amount: int) -> void:
	var target_health: int = clampi(int(health_ring.value) - damage_amount, 0, int(health_ring.max_value))
	if health_tween and health_tween.is_valid():
		health_tween.kill()
	
	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	health_tween.tween_property(health_ring, "value", target_health, 0.4)

func set_ring_color(new_color: Color) -> void:
	health_ring.tint_progress = new_color

func request_portrait(noun: String, adjs: Array[String]) -> void:
	if character_display.has_method("display_character"):
		character_display.display_character(noun, adjs)
	else:
		print("Character display is missing display character method!")

class_name MapMarker
extends Node2D

@onready var portrait: Sprite2D = $Visual/Portrait
@onready var placeholder: Label = $Visual/Placeholder
@onready var health_ring: TextureProgressBar = $Visual/HealthRing
@onready var character_display: PanelContainer = $Visual/CharacterDisplay
@onready var visual: Node2D = $Visual
@onready var shadow: Panel = $Shadow

var explosion_scene: PackedScene = preload("res://scenes/exploding_effect.tscn")
var smoke_scene: PackedScene = preload("res://scenes/landing_smoke.tscn")
var health_tween: Tween

var elevation_tween: Tween
var current_z: int = 0
var pixels_per_elevation_level: float = 10.0

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
	
	if target_health <= 0:
		health_tween.finished.connect(_die)

func _die() -> void:
	var explosion: AnimatedSprite2D = explosion_scene.instantiate() as AnimatedSprite2D
	get_parent().add_child(explosion)
	explosion.global_position = visual.global_position
	queue_free()

func apply_elevation(target_z: int) -> void:
	var target_y_offset: float = float(target_z) * -pixels_per_elevation_level
	if current_z == 0 && target_z > 0:
		_spawn_smoke()
	var prev_z = current_z
	current_z = target_z
	if elevation_tween and elevation_tween.is_valid():
		elevation_tween.kill()
	
	elevation_tween = create_tween()
	elevation_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elevation_tween.tween_property(visual, "position:y", target_y_offset, 0.4)
	
	var target_shadow_scale: float = clampf(1.0 - (float(target_z) * 0.05), 0.9, 1.0)
	var target_shadow_alpha: float = clampf(0.5 - (float(target_z) * 0.05), 0.7, 1.0)
	elevation_tween.parallel().tween_property(shadow, "scale", Vector2(target_shadow_scale, target_shadow_scale), 0.4)
	elevation_tween.parallel().tween_property(shadow, "modulate:a", target_shadow_alpha, 0.4)
	
	if prev_z > 0 and target_z == 0:
		elevation_tween.finished.connect(_spawn_smoke)

func _spawn_smoke() -> void:
	var smoke: AnimatedSprite2D = smoke_scene.instantiate() as AnimatedSprite2D
	if smoke != null:
		get_parent().add_child(smoke)
		smoke.global_position = global_position

func set_ring_color(new_color: Color) -> void:
	health_ring.tint_progress = new_color

func request_portrait(noun: String, adjs: Array[String]) -> void:
	if character_display.has_method("display_character"):
		character_display.display_character(noun, adjs)
	else:
		print("Character display is missing display character method!")

extends Node2D
class_name GridManager

@export var grid_size_x: int = 16
@export var grid_size_y: int = 16
@export var marker_scene: PackedScene = preload("res://scenes/map_marker.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
@export var physical_scene: PackedScene = preload("res://scenes/physical_hit.tscn")
@export var spawn_debug_markers: bool = false
@export var movement_time: float = 0.5
@export var attack_impact_delay: float = 0.4
@export var effect_sfx_base_dir: String = "res://assets/sfx/effects"
@export var cast_sfx_volume_db: float = -8.0
@export var impact_sfx_volume_db: float = -7.0
@export var sfx_pitch_min: float = 0.96
@export var sfx_pitch_max: float = 1.04
@export var enable_character_tooltips: bool = true
@export var tooltip_radius_px: float = 34.0
@export var hp_delta_float_time: float = 0.85

@onready var map_image: TextureRect = $".."
@onready var marker_container: Node2D = $MarkerContainer

var _last_game_state: Dictionary = {}
var _attached_children: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _missing_sfx_reported: Dictionary = {}
var _tooltip_panel: PanelContainer = null
var _tooltip_label: RichTextLabel = null
var _current_tooltip_entity_id = ""

const TEAM_A_COLOR := Color.BLUE
const TEAM_B_COLOR := Color.RED
const NEUTRAL_COLOR := Color.YELLOW

const ELEMENT_EFFECTS := [
	"fire",
	"ice",
	"lightning",
	"water",
	"plant",
	"earth",
	"light",
	"dark",
	"air",
]

const ACTION_EFFECTS := ["hit", "move"]
const ALL_EFFECTS := ["fire", "ice", "lightning", "water", "plant", "earth", "light", "dark", "air", "hit", "move"]


func _ready() -> void:
	if not is_instance_valid(marker_container):
		push_error("GridManager requires a child MarkerContainer node.")
		return

	_ensure_tooltip_nodes.call_deferred()

	if spawn_debug_markers:
		_spawn_debug_markers()


func _process(_delta: float) -> void:
	if enable_character_tooltips:
		_update_hover_tooltip()


# ─────────────────────────────────────────────────────────────
# Map texture
# ─────────────────────────────────────────────────────────────

func set_map_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	map_image.texture = texture


# ─────────────────────────────────────────────────────────────
# Grid / position helpers
# ─────────────────────────────────────────────────────────────

func get_pixel_position_from_grid(grid_x: int, grid_y: int) -> Vector2:
	var clamped_x: int = clampi(grid_x, 0, grid_size_x - 1)
	var clamped_y: int = clampi(grid_y, 0, grid_size_y - 1)

	var total_width: float = map_image.size.x
	var total_height: float = map_image.size.y

	var cell_width: float = total_width / float(grid_size_x)
	var cell_height: float = total_height / float(grid_size_y)

	var pixel_x: float = (float(clamped_x) * cell_width) + (cell_width / 2.0)
	var pixel_y: float = (float(clamped_y) * cell_height) + (cell_height / 2.0)

	return Vector2(pixel_x, pixel_y)


func get_global_pixel_position_from_grid(grid_x: int, grid_y: int) -> Vector2:
	return map_image.global_position + get_pixel_position_from_grid(grid_x, grid_y)


func _entity_grid_position(entity: Dictionary) -> Vector3i:
	return Vector3i(
		int(entity.get("x", 0)),
		int(entity.get("y", 0)),
		int(entity.get("z", 0))
	)


func _marker_for_id(entity_id: String) -> MapMarker:
	if entity_id.is_empty():
		return null
	return marker_container.get_node_or_null(entity_id) as MapMarker


func _marker_visual_global_position(marker: MapMarker) -> Vector2:
	if marker == null:
		return Vector2.ZERO
	if "visual" in marker and marker.visual != null:
		return marker.visual.global_position
	return marker.global_position


# ─────────────────────────────────────────────────────────────
# Full redraw / token lifecycle API expected by battle.gd
# ─────────────────────────────────────────────────────────────

func redraw_tokens(game_state: Dictionary) -> void:
	_last_game_state = game_state.duplicate(true)

	var wanted_ids: Dictionary = {}

	var characters: Array = _array_from(game_state.get("characters", []))
	for character_variant in characters:
		if not (character_variant is Dictionary):
			continue

		var character: Dictionary = character_variant
		var character_id = str(character.get("id", ""))
		if character_id.is_empty():
			continue

		if _entity_should_be_hidden(character):
			remove_token(character_id)
			continue

		wanted_ids[character_id] = true
		spawn_character(character)

	var objects: Array = _array_from(game_state.get("objects", []))
	for object_variant in objects:
		if not (object_variant is Dictionary):
			continue

		var object_data: Dictionary = object_variant
		var object_id = str(object_data.get("id", ""))
		if object_id.is_empty():
			continue

		wanted_ids[object_id] = true
		spawn_object(object_data)

	for child in marker_container.get_children():
		if child is MapMarker and not wanted_ids.has(child.name):
			_remove_marker(child.name, true)

	_sync_all_attachments_from_state(game_state)


func spawn_token(entity: Dictionary) -> void:
	if entity.is_empty():
		return

	var entity_id: String = str(entity.get("id", ""))
	if entity_id.is_empty():
		return

	if _entity_should_be_hidden(entity):
		remove_token(entity_id)
		return

	if _is_character_entity(entity):
		spawn_character(entity)
	else:
		spawn_object(entity)


func remove_token(entity_id: String) -> void:
	_remove_marker(entity_id, true)


func redraw_token(entity_id: String, game_state: Dictionary) -> void:
	_last_game_state = game_state.duplicate(true)

	var entity: Dictionary = _find_entity_in_game_state(entity_id, game_state)
	if entity.is_empty() or _entity_should_be_hidden(entity):
		remove_token(entity_id)
		return

	var marker: MapMarker = _marker_for_id(entity_id)
	if marker == null:
		spawn_token(entity)
		return

	_update_marker_from_entity(marker, entity, false)
	_sync_single_attachment_from_entity(entity)


func move_token(entity_id: String, x: int, y: int, z: int = 0) -> void:
	var marker: MapMarker = _marker_for_id(entity_id)
	if marker == null:
		var entity: Dictionary = _find_entity_in_game_state(entity_id, _last_game_state)
		if not entity.is_empty():
			spawn_token(entity)
			marker = _marker_for_id(entity_id)

	if marker == null:
		push_warning("Tried to move marker, but ID was not found: %s" % entity_id)
		return

	var target_pixel_pos: Vector2 = get_pixel_position_from_grid(x, y)
	var move_tween: Tween = create_tween()
	move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(marker, "position", target_pixel_pos, movement_time)
	_apply_marker_elevation(marker, z)
	_update_attached_children_positions(entity_id)


# ─────────────────────────────────────────────────────────────
# Character / object spawning
# ─────────────────────────────────────────────────────────────

func spawn_character(character: Dictionary) -> void:
	var character_id: String = str(character.get("id", ""))
	if character_id.is_empty():
		push_warning("Cannot spawn character with empty id.")
		return

	var existing: MapMarker = _marker_for_id(character_id)
	if existing != null:
		_update_marker_from_entity(existing, character, false)
		return

	var marker: MapMarker = _instantiate_marker(character_id)
	if marker == null:
		return

	_update_marker_from_entity(marker, character, true)


func spawn_object(object_data: Dictionary) -> void:
	var object_id: String = str(object_data.get("id", ""))
	if object_id.is_empty():
		push_warning("Cannot spawn object with empty id.")
		return

	var existing: MapMarker = _marker_for_id(object_id)
	if existing != null:
		_update_marker_from_entity(existing, object_data, false)
		return

	var marker: MapMarker = _instantiate_marker(object_id)
	if marker == null:
		return

	_update_marker_from_entity(marker, object_data, true)


func remove_character(character_id: String) -> void:
	_remove_marker(character_id, true)


func _instantiate_marker(entity_id: String) -> MapMarker:
	if marker_scene == null:
		push_error("marker_scene is not assigned.")
		return null

	var marker: MapMarker = marker_scene.instantiate() as MapMarker
	if marker == null:
		push_error("Failed to instantiate MapMarker.")
		return null

	marker.name = entity_id
	marker_container.add_child(marker)
	return marker


func _remove_marker(entity_id: String, animate: bool) -> void:
	var marker: MapMarker = _marker_for_id(entity_id)
	if marker == null:
		push_warning("Could not remove marker '%s': not on board." % entity_id)
		return

	_detach_children_of_parent(entity_id)
	_attached_children.erase(entity_id)

	if animate and marker.has_method("_die"):
		marker._die()
	else:
		marker.queue_free()


func _clear_markers() -> void:
	for child in marker_container.get_children():
		child.queue_free()
	_attached_children.clear()


# ─────────────────────────────────────────────────────────────
# Marker updates
# ─────────────────────────────────────────────────────────────

func _update_marker_from_entity(marker: MapMarker, entity: Dictionary, request_portrait_if_new: bool) -> void:
	var side: String = _entity_side(entity)
	_set_marker_ring_color(marker, side)
	marker.set_meta("entity_id", str(entity.get("id", "")))
	marker.set_meta("entity_snapshot", entity.duplicate(true))

	var pos: Vector3i = _entity_grid_position(entity)
	marker.position = get_pixel_position_from_grid(pos.x, pos.y)
	_apply_marker_elevation(marker, pos.z)

	if _is_character_entity(entity):
		_update_character_marker(marker, entity, request_portrait_if_new)
	else:
		_update_object_marker(marker, entity, request_portrait_if_new)


func _update_character_marker(marker: MapMarker, character: Dictionary, request_portrait_if_new: bool) -> void:
	var hp: int = int(character.get("hp", 0))
	var max_hp: int = maxi(1, int(character.get("max_hp", 1)))
	_set_marker_health(marker, hp, max_hp)

	if request_portrait_if_new:
		var noun: String = _entity_portrait_noun(character)
		var adjectives: Array[String] = _string_array_typed(character.get("adjectives", []))
		_request_marker_portrait(marker, noun, adjectives)


func _update_object_marker(marker: MapMarker, object_data: Dictionary, request_portrait_if_new: bool) -> void:
	# Objects do not use battle HP unless your object schema later adds it.
	_set_marker_health(marker, 10000, 10000)

	if request_portrait_if_new:
		var noun: String = str(object_data.get("name", object_data.get("id", "object")))
		var adjectives: Array[String] = []
		_request_marker_portrait(marker, noun, adjectives)


func _set_marker_ring_color(marker: MapMarker, side: String) -> void:
	if marker == null or not marker.has_method("set_ring_color"):
		return

	match side:
		"Team A":
			marker.set_ring_color(TEAM_A_COLOR)
		"Team B":
			marker.set_ring_color(TEAM_B_COLOR)
		_:
			marker.set_ring_color(NEUTRAL_COLOR)


func _set_marker_health(marker: MapMarker, hp: int, max_hp: int) -> void:
	if marker != null and marker.has_method("set_health"):
		marker.set_health(hp, max_hp)


func _request_marker_portrait(marker: MapMarker, noun: String, adjectives: Array[String]) -> void:
	if marker != null and marker.has_method("request_portrait"):
		marker.request_portrait(noun, adjectives)


func _apply_marker_elevation(marker: MapMarker, z: int) -> void:
	if marker != null and marker.has_method("apply_elevation"):
		marker.apply_elevation(z)


# ─────────────────────────────────────────────────────────────
# Movement helpers
# ─────────────────────────────────────────────────────────────

func move_characters_simultaneously(moves: Array) -> void:
	var board_tween: Tween = create_tween()
	board_tween.set_parallel(true)
	board_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	for move_variant in moves:
		if not (move_variant is Dictionary):
			continue

		var move: Dictionary = move_variant
		var target_id: String = str(move.get("id", ""))
		var target_grid_x: int = int(move.get("x", 0))
		var target_grid_y: int = int(move.get("y", 0))
		var target_grid_z: int = int(move.get("z", 0))
		var marker: MapMarker = _marker_for_id(target_id)

		if marker != null:
			var target_pixel_pos: Vector2 = get_pixel_position_from_grid(target_grid_x, target_grid_y)
			board_tween.tween_property(marker, "position", target_pixel_pos, movement_time)
			_apply_marker_elevation(marker, target_grid_z)
		else:
			push_warning("Tried to move marker, but ID was not found: %s" % target_id)


func move_character(character: Dictionary, target_x: int, target_y: int) -> void:
	move_token(str(character.get("id", "")), target_x, target_y, int(character.get("z", 0)))


# ─────────────────────────────────────────────────────────────
# Attacks / effects
# ─────────────────────────────────────────────────────────────

func trigger_attack(source_id: String, target_ids: Array, effect: String = "hit", hp_delta: int = 0) -> void:
	var resolved_effect = _normalize_effect_type(effect)
	if not source_id.is_empty():
		_play_effect_sfx(resolved_effect, "cast")

	for target_id_variant in target_ids:
		var target_id: String = str(target_id_variant)
		if target_id.is_empty():
			continue

		if _is_element_effect(resolved_effect):
			await do_elemental_attack_characters(source_id, target_id, resolved_effect)
		else:
			await do_physical_attack_characters(source_id, target_id)

		_play_effect_sfx(resolved_effect, "impact")

		if hp_delta != 0:
			show_hp_delta(target_id, hp_delta)


func trigger_effect_at(x: int, y: int, z: int, effect: String) -> void:
	var target_pos: Vector2 = get_pixel_position_from_grid(x, y)

	if _is_element_effect(effect):
		# Location-only elemental effect. If there is no source, show a local pulse/fallback.
		show_location_effect(target_pos, effect, z)
	else:
		show_location_effect(target_pos, effect, z)


func do_elemental_attack_characters(source_id: String, target_id: String, element: String) -> void:
	var attacker: MapMarker = _marker_for_id(source_id)
	var defender: MapMarker = _marker_for_id(target_id)

	if attacker == null:
		push_warning("Attack failed: attacker '%s' is missing." % source_id)
		return
	if defender == null:
		push_warning("Attack failed: defender '%s' is missing." % target_id)
		return

	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)

	var start_pos: Vector2 = _marker_visual_global_position(attacker)
	var end_pos: Vector2 = _marker_visual_global_position(defender)

	if projectile.has_method("launch_elemental_attack"):
		projectile.launch_elemental_attack(start_pos, end_pos, element)

	await get_tree().create_timer(attack_impact_delay).timeout


func do_elemental_attack_location(source_id: String, target_pos: Vector2, element: String) -> void:
	var attacker: MapMarker = _marker_for_id(source_id)
	if attacker == null:
		push_warning("Attack failed: attacker '%s' is missing." % source_id)
		return

	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)

	var start_pos: Vector2 = _marker_visual_global_position(attacker)
	if projectile.has_method("launch_elemental_attack"):
		projectile.launch_elemental_attack(start_pos, target_pos, element)

	await get_tree().create_timer(attack_impact_delay).timeout


func do_physical_attack_characters(source_id: String, target_id: String) -> void:
	var attacker: MapMarker = _marker_for_id(source_id)
	var defender: MapMarker = _marker_for_id(target_id)

	if attacker == null:
		push_warning("Attack failed: attacker '%s' is missing." % source_id)
		return
	if defender == null:
		push_warning("Attack failed: defender '%s' is missing." % target_id)
		return

	var slash = physical_scene.instantiate()
	get_parent().add_child(slash)

	var start_pos: Vector2 = _marker_visual_global_position(attacker)
	var end_pos: Vector2 = _marker_visual_global_position(defender)

	if slash.has_method("strike"):
		slash.strike(start_pos, end_pos)

	await get_tree().create_timer(attack_impact_delay).timeout


func show_hp_delta(entity_id: String, hp_delta: int) -> void:
	var marker: MapMarker = _marker_for_id(entity_id)
	if marker == null:
		return

	if marker.has_method("show_hp_delta"):
		marker.show_hp_delta(hp_delta)
		return

	_spawn_hp_delta_label(marker, hp_delta)


func show_location_effect(pixel_pos: Vector2, effect: String, z: int = 0) -> void:
	print("TODO map.show_location_effect: pos=%s effect=%s z=%d" % [pixel_pos, effect, z])


# ─────────────────────────────────────────────────────────────
# Attachments
# ─────────────────────────────────────────────────────────────

func attach_tokens(child_id: String, parent_id: String, attachment_mode: String) -> void:
	var child: MapMarker = _marker_for_id(child_id)
	var parent: MapMarker = _marker_for_id(parent_id)

	if child == null or parent == null:
		return

	_attached_children[child_id] = {
		"parent_id": parent_id,
		"attachment_mode": attachment_mode,
	}

	child.position = parent.position + _attachment_offset(attachment_mode)
	child.z_index = parent.z_index + 1

	if child.has_method("set_attached_visual_state"):
		child.set_attached_visual_state(parent_id, attachment_mode)


func detach_token(child_id: String) -> void:
	var child: MapMarker = _marker_for_id(child_id)
	_attached_children.erase(child_id)

	if child == null:
		return

	child.z_index = 0
	if child.has_method("clear_attached_visual_state"):
		child.clear_attached_visual_state()


func _sync_all_attachments_from_state(game_state: Dictionary) -> void:
	var characters: Array = _array_from(game_state.get("characters", []))
	for character in characters:
		if character is Dictionary:
			_sync_single_attachment_from_entity(character)

	var objects: Array = _array_from(game_state.get("objects", []))
	for object_data in objects:
		if object_data is Dictionary:
			_sync_single_attachment_from_entity(object_data)


func _sync_single_attachment_from_entity(entity: Dictionary) -> void:
	var child_id: String = str(entity.get("id", ""))
	var parent_id: String = str(entity.get("attached_to_character_id", ""))
	var mode: String = str(entity.get("attachment_mode", ""))

	if child_id.is_empty():
		return

	if parent_id.is_empty() or mode.is_empty():
		detach_token(child_id)
		return

	attach_tokens(child_id, parent_id, mode)


func _update_attached_children_positions(parent_id: String) -> void:
	var parent: MapMarker = _marker_for_id(parent_id)
	if parent == null:
		return

	for child_id_variant in _attached_children.keys():
		var child_id: String = str(child_id_variant)
		var attachment_data: Dictionary = _attached_children.get(child_id, {})
		if str(attachment_data.get("parent_id", "")) != parent_id:
			continue

		var child: MapMarker = _marker_for_id(child_id)
		if child == null:
			continue

		var mode: String = str(attachment_data.get("attachment_mode", ""))
		child.position = parent.position + _attachment_offset(mode)
		child.z_index = parent.z_index + 1


func _detach_children_of_parent(parent_id: String) -> void:
	var to_detach: Array[String] = []
	for child_id_variant in _attached_children.keys():
		var child_id: String = str(child_id_variant)
		var attachment_data: Dictionary = _attached_children.get(child_id, {})
		if str(attachment_data.get("parent_id", "")) == parent_id:
			to_detach.append(child_id)

	for child_id in to_detach:
		detach_token(child_id)


func _attachment_offset(attachment_mode: String) -> Vector2:
	match attachment_mode:
		"mounted":
			return Vector2(0, -20)
		"equipped":
			return Vector2(16, 0)
		"carried":
			return Vector2(-16, 0)
		"in_inventory":
			return Vector2(0, 14)
		"stashed":
			return Vector2(0, 22)
		_:
			return Vector2.ZERO


# ─────────────────────────────────────────────────────────────
# Battlefield feature stubs
# ─────────────────────────────────────────────────────────────

func spawn_battlefield_feature(feature: Dictionary) -> void:
	# Future: draw zones, hazards, effects, terrain overlays.
	print("TODO map.spawn_battlefield_feature: ", feature.get("id", ""))


func remove_battlefield_feature(feature_id: String) -> void:
	print("TODO map.remove_battlefield_feature: ", feature_id)


func redraw_battlefield_features(game_state: Dictionary = {}) -> void:
	print("TODO map.redraw_battlefield_features")



# ─────────────────────────────────────────────────────────────
# SFX, HP delta labels, and tooltips
# ─────────────────────────────────────────────────────────────

func _normalize_effect_type(effect: String) -> String:
	var key = effect.strip_edges().to_lower()
	if ALL_EFFECTS.has(key):
		return key
	return "hit"


func _effect_sfx_candidate_paths(effect: String, phase: String) -> Array[String]:
	var key = _normalize_effect_type(effect)
	var p = phase.strip_edges().to_lower()
	return [
		"%s/%s-%s.wav" % [effect_sfx_base_dir, key, p],
		"%s/%s_%s.wav" % [effect_sfx_base_dir, key, p],
		"%s/%s-%s.ogg" % [effect_sfx_base_dir, key, p],
		"%s/%s_%s.ogg" % [effect_sfx_base_dir, key, p],
		"%s/%s-%s.mp3" % [effect_sfx_base_dir, key, p],
		"%s/%s_%s.mp3" % [effect_sfx_base_dir, key, p],
	]


func _get_cached_sfx(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _sfx_cache.has(path):
		return _sfx_cache[path]
	if not ResourceLoader.exists(path):
		if not _missing_sfx_reported.has(path):
			_missing_sfx_reported[path] = true
		return null
	var stream = load(path) as AudioStream
	if stream == null:
		return null
	_sfx_cache[path] = stream
	return stream


func _play_effect_sfx(effect: String, phase: String) -> void:
	for path in _effect_sfx_candidate_paths(effect, phase):
		var stream = _get_cached_sfx(path)
		if stream == null:
			continue
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = cast_sfx_volume_db if phase == "cast" else impact_sfx_volume_db
		player.pitch_scale = randf_range(sfx_pitch_min, sfx_pitch_max)
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
		return


func _spawn_hp_delta_label(marker: MapMarker, hp_delta: int) -> void:
	if marker == null:
		return

	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%+d" % hp_delta

	# MapMarker is a Node2D in this project, not a Control, so do not type-check it as Control.
	# Use a stable visual marker size for the floating HP label.
	var marker_size = Vector2(56.0, 56.0)
	var circle_diameter = maxf(marker_size.x, marker_size.y)
	if circle_diameter <= 0.0:
		circle_diameter = 56.0

	label.add_theme_font_size_override("font_size", int(clampf(circle_diameter * 0.32, 16.0, 26.0)))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_color_override("font_color", Color(0.44, 1.0, 0.65) if hp_delta > 0 else Color(1.0, 0.56, 0.52))
	label.position = Vector2((marker_size.x * 0.5) - 16.0, -6.0)
	label.z_index = 20
	label.scale = Vector2.ONE * 0.72
	marker.add_child(label)

	var tween = marker.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 22.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "scale", Vector2.ONE * 1.04, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)


func _ensure_tooltip_nodes() -> void:
	if not enable_character_tooltips or not is_instance_valid(map_image):
		return
	if is_instance_valid(_tooltip_panel):
		return

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "CharacterTooltip"
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.z_as_relative = false
	_tooltip_panel.z_index = 4095
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.04, 0.025, 0.92)
	style.border_color = Color(0.85, 0.66, 0.28, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(230.0, 0.0)
	_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_tooltip_label.add_theme_color_override("default_color", Color(0.94, 0.86, 0.68, 1.0))
	_tooltip_panel.add_child(_tooltip_label)
	map_image.add_child(_tooltip_panel)


func _update_hover_tooltip() -> void:
	if not is_instance_valid(_tooltip_panel) or not is_instance_valid(_tooltip_label) or not is_instance_valid(map_image):
		return

	var mouse_pos = map_image.get_local_mouse_position()
	if mouse_pos.x < 0.0 or mouse_pos.y < 0.0 or mouse_pos.x > map_image.size.x or mouse_pos.y > map_image.size.y:
		_hide_tooltip()
		return

	var best_marker: MapMarker = null
	var best_dist = tooltip_radius_px
	for child in marker_container.get_children():
		if not (child is MapMarker):
			continue
		var marker: MapMarker = child
		var dist = marker.position.distance_to(mouse_pos)
		if dist <= best_dist:
			best_dist = dist
			best_marker = marker

	if best_marker == null:
		_hide_tooltip()
		return

	var entity_id = str(best_marker.get_meta("entity_id", best_marker.name))
	var entity = _find_entity_in_game_state(entity_id, _last_game_state)
	if entity.is_empty():
		_hide_tooltip()
		return

	if _current_tooltip_entity_id != entity_id:
		_current_tooltip_entity_id = entity_id
		_tooltip_label.text = _tooltip_bbcode_for_entity(entity)

	_tooltip_panel.visible = true
	_tooltip_panel.position = _clamped_tooltip_position(mouse_pos + Vector2(18.0, 18.0))


func _hide_tooltip() -> void:
	_current_tooltip_entity_id = ""
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.visible = false


func _clamped_tooltip_position(pos: Vector2) -> Vector2:
	var panel_size = _tooltip_panel.size
	var max_x = maxf(0.0, map_image.size.x - panel_size.x - 8.0)
	var max_y = maxf(0.0, map_image.size.y - panel_size.y - 8.0)
	return Vector2(clampf(pos.x, 8.0, max_x), clampf(pos.y, 8.0, max_y))


func _tooltip_bbcode_for_entity(entity: Dictionary) -> String:
	var name = str(entity.get("display_name", entity.get("name", entity.get("id", "Unknown"))))
	var side = _entity_side(entity)
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % _escape_bbcode(name))
	lines.append("[color=#d6ba73]%s[/color]" % _escape_bbcode(side))

	if _is_character_entity(entity):
		lines.append("HP: %d / %d" % [int(entity.get("hp", 0)), int(entity.get("max_hp", 1))])
		lines.append("ATK %d  DEF %d  MAG %d  MDEF %d  SPD %d" % [
			int(entity.get("physical_attack", 0)),
			int(entity.get("physical_defence", 0)),
			int(entity.get("magic_power", 0)),
			int(entity.get("magic_defence", 0)),
			int(entity.get("speed", 0)),
		])
		var elements = _array_from(entity.get("elements", []))
		if not elements.is_empty():
			lines.append("Elements: %s" % _escape_bbcode(", ".join(_string_array_typed(elements))))
		var statuses = _array_from(entity.get("status_effects", []))
		if not statuses.is_empty():
			lines.append("Status: %s" % _escape_bbcode(", ".join(_string_array_typed(statuses))))
		var notes = _array_from(entity.get("important_notes", []))
		if not notes.is_empty():
			lines.append("[i]%s[/i]" % _escape_bbcode(str(notes[0])))
	else:
		var state = _array_from(entity.get("state", []))
		if not state.is_empty():
			lines.append("State: %s" % _escape_bbcode(", ".join(_string_array_typed(state))))

	return "\n".join(lines)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

func _find_entity_in_game_state(entity_id: String, game_state: Dictionary) -> Dictionary:
	var characters: Array = _array_from(game_state.get("characters", []))
	for character in characters:
		if character is Dictionary and str(character.get("id", "")) == entity_id:
			return character

	var objects: Array = _array_from(game_state.get("objects", []))
	for object_data in objects:
		if object_data is Dictionary and str(object_data.get("id", "")) == entity_id:
			return object_data

	return {}


func _is_character_entity(entity: Dictionary) -> bool:
	return entity.has("hp") and entity.has("max_hp")


func _entity_should_be_hidden(entity: Dictionary) -> bool:
	if _is_character_entity(entity):
		return int(entity.get("hp", 0)) <= 0
	return false


func _entity_side(entity: Dictionary) -> String:
	if entity.has("side"):
		return str(entity.get("side", "Neutral"))
	return str(entity.get("controller", "Neutral"))


func _entity_portrait_noun(entity: Dictionary) -> String:
	var nouns: Array = _array_from(entity.get("nouns", []))
	if not nouns.is_empty():
		return str(nouns[0])
	if entity.has("name"):
		return str(entity.get("name", "unit"))
	return str(entity.get("display_name", "unit"))


func _is_element_effect(effect: String) -> bool:
	return ELEMENT_EFFECTS.has(effect.strip_edges().to_lower())


func _array_from(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _string_array_typed(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text: String = str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


func _spawn_debug_markers() -> void:
	var character_a: Dictionary = {
		"id": "a",
		"max_hp": 100,
		"hp": 67,
		"side": "Team A",
		"x": 8,
		"y": 8,
		"z": 0,
		"nouns": ["paladin"],
		"adjectives": ["holy", "ugly", "red armor"],
	}

	var character_b: Dictionary = {
		"id": "b",
		"max_hp": 100,
		"hp": 100,
		"side": "Team B",
		"x": 3,
		"y": 3,
		"z": 0,
		"nouns": ["murloc"],
		"adjectives": ["powerful", "muscular", "tiny head"],
	}

	call_deferred("spawn_character", character_a)
	call_deferred("spawn_character", character_b)

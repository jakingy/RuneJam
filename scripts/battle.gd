extends Node

const MODEL = "gpt-5.4-mini"
const NARRATOR_MODEL = "gpt-5.5"
const COST_JUDGE_REASONING_EFFORT = "medium"
const NARRATOR_REASONING_EFFORT = "low"

const STARTING_PROBABILITY = 15
const ROUND_INCOME = 3
const MAP_WIDTH = 16
const MAP_HEIGHT = 16
const BATTLE_STYLE = "dramatic fantasy arena battle"

const COST_VERDICT_HISTORY_MAX = 24
const COST_VERDICT_HISTORY_CONTEXT_LIMIT = 4
const POWER_MULTIPLIER_VERDICT_HISTORY_MAX = 48
const POWER_MULTIPLIER_VERDICT_HISTORY_CONTEXT_LIMIT = 6
const COST_VERDICT_MIN_TOKEN_LENGTH = 4

const ATTACK_DAMAGE_RUNTIME_MULTIPLIER = 2.0
const NON_HP_INTENT_SCALAR = 0.15
const DEFENCE_FORMULA_NUMERATOR = 120.0
const DEFENCE_FORMULA_STAT_SCALE = 5.0

const TEXT_EFFECT_TYPES = [
	"",
	"fire",
	"ice",
	"lightning",
	"water",
	"plant",
	"earth",
	"light",
	"dark",
	"air",
	"hit",
	"move",
]

const ELEMENT_TYPES = [
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

const STRING_ARRAY_CHANGE_FIELDS = {
	"status_effects": true,
	"important_notes": true,
	"elements": true,
	"nouns": true,
	"adjectives": true,
	"state": true,
	"environmental_notes": true,
	"ongoing_effects": true,
	"other_important_notes": true,
	"recent_round_history": true,
}

const COMPUTED_NUMERIC_CHARACTER_FIELDS = {
	"hp": true,
	"max_hp": true,
	"physical_attack": true,
	"physical_defence": true,
	"magic_power": true,
	"magic_defence": true,
	"speed": true,
	"size": true,
}

const ELEMENTAL_DEFAULT_MULTIPLIER = 1.0
const ELEMENTAL_INTERACTION_MAP = {
	"fire": {"plant": 1.25, "ice": 1.2, "water": 0.8},
	"ice": {"water": 1.15, "plant": 1.1, "fire": 0.8},
	"lightning": {"water": 1.35, "air": 1.1, "earth": 0.75},
	"water": {"fire": 1.25, "earth": 1.05, "lightning": 0.8},
	"plant": {"earth": 1.1, "water": 1.1, "fire": 0.75},
	"earth": {"lightning": 1.25, "fire": 1.05, "air": 0.85},
	"light": {"dark": 1.3},
	"dark": {"light": 1.2},
	"air": {"earth": 1.1, "plant": 1.05},
}

@export var starting_characters: Array[Dictionary] = []
@export var initialization_constraints: Dictionary = {}

@export_group("Initialiser TTS")
@export var enable_initialiser_tts: bool = false
# Leave voice_id empty to randomly use one of the old initializer narrator voices.
@export var elevenlabs_voice_id: String = ""
@export var elevenlabs_initializer_voice_ids: Array[String] = [
	"UmQN7jS1Ee8B1czsUtQh",
	"flHkNRp1BlvT73UL6gyz",
]
# Old battle-script live-streaming settings. Use PCM for AudioStreamGenerator playback.
@export var elevenlabs_model_id: String = "eleven_flash_v2_5"
@export var elevenlabs_output_format: String = "pcm_24000"
@export var elevenlabs_voice_speed: float = 1.15
@export var initialiser_tts_cache_dir: String = "user://generated_audio/initialiser"
@export var initialiser_tts_volume_db: float = -6.0
@export var initialiser_tts_mix_rate: float = 24000.0
@export var initialiser_tts_buffer_length: float = 0.6

@onready var manuscript: VBoxContainer = $UILayer/MainLayout/BattleLayout/WritingColumn/Manuscript
@onready var map_manager: Node = $UILayer/MainLayout/BattleLayout/MapColumn/Map/MapImage/GridManager

var current_phase = "idle"
var game_state: Dictionary = {}

var last_team_a_action = ""
var last_cost_result: Dictionary = {}
var round_team_b_action = ""
var round_team_b_cost_result: Dictionary = {}

var _round_cost_verdict_cache: Dictionary = {}
var _cost_verdict_history: Array = []
var _power_multiplier_verdict_history: Array = []

var _streaming_narrator_content: RichTextLabel = null
var _streaming_narrator_thinking: PanelContainer = null
var _queued_fragment_apply_count = 0
var _streamed_any_fragments = false
var _finished_fragment_keys: Dictionary = {}
var _streamed_fragments_for_history: Array = []

var _speculative_request_id = 0
var _speculative_narrator_input: Dictionary = {}
var _speculative_running = false
var _speculative_done = false
var _speculative_live = false
var _speculative_result: Dictionary = {}
var _speculative_error = ""
var _speculative_fragment_items: Array = []

var _team_b_request_id = 0
var _team_b_running = false
var _team_b_done = false
var _team_b_error = ""
var _team_b_state_key = ""

var _team_b_cost_running = false
var _team_b_cost_done = false
var _team_b_cost_error = ""
var _team_b_cost_state_key = ""
var _team_b_cost_action = ""

var CHARACTER_SCHEMA: Dictionary
var OBJECT_SCHEMA: Dictionary
var BATTLEFIELD_FEATURE_SCHEMA: Dictionary
var BATTLEFIELD_SCHEMA: Dictionary
var GAME_STATE_SCHEMA: Dictionary
var COST_OUTPUT_SCHEMA: Dictionary
var TEAM_B_OUTPUT_SCHEMA: Dictionary
var INITIALIZER_OUTPUT_SCHEMA: Dictionary
var NARRATOR_OUTPUT_SCHEMA: Dictionary

var _initialiser_tts_request_id = 0
var _initialiser_tts_player: AudioStreamPlayer = null
var _initialiser_tts_playback: AudioStreamGeneratorPlayback = null
var _initialiser_tts_pending_frames: Array = []
var _initialiser_tts_pcm_remainder: PackedByteArray = PackedByteArray()
var _selected_initialiser_tts_voice_id: String = ""

signal player_prob_changed(cur: int)
signal opp_prob_changed(cur: int)

var player_prob: int = 0
var opp_prob: int = 0
@onready var battle_ui = $UILayer/MainLayout/TopBar/BattleUI


func _ready() -> void:
	player_prob_changed.connect(battle_ui.upd_player_prob)
	opp_prob_changed.connect(battle_ui.upd_opp_prob)
	player_prob_changed.emit(player_prob)
	opp_prob_changed.emit(opp_prob)
	_build_schemas()
	_connect_manuscript()
	_start_new_game.call_deferred()


func _process(_delta: float) -> void:
	_drain_initialiser_tts_frames()


func _connect_manuscript() -> void:
	if manuscript.has_signal("action_submitted"):
		manuscript.action_submitted.connect(_on_action_submitted)
	if manuscript.has_signal("action_text_changed"):
		manuscript.action_text_changed.connect(_on_action_text_changed)



# Schemas


func _build_schemas() -> void:
	CHARACTER_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"id": {"type": "string"},
			"display_name": {"type": "string", "minLength": 1},
			"nouns": {"type": "array", "items": {"type": "string", "minLength": 1}, "minItems": 1},
			"adjectives": {"type": "array", "items": {"type": "string"}},
			"elements": {"type": "array", "items": {"type": "string", "enum": ELEMENT_TYPES}},
			"side": {"type": "string", "enum": ["Team A", "Team B", "Neutral"]},
			"max_hp": {"type": "integer", "minimum": 1, "maximum": 999},
			"hp": {"type": "integer", "minimum": 0, "maximum": 999},
			"physical_attack": {"type": "integer", "minimum": 0, "maximum": 999},
			"physical_defence": {"type": "integer", "minimum": 0, "maximum": 999},
			"magic_power": {"type": "integer", "minimum": 0, "maximum": 999},
			"magic_defence": {"type": "integer", "minimum": 0, "maximum": 999},
			"speed": {"type": "integer", "minimum": 0, "maximum": 999},
			"size": {"type": "integer", "minimum": 0, "maximum": 99},
			"status_effects": {"type": "array", "items": {"type": "string"}},
			"important_notes": {"type": "array", "items": {"type": "string"}},
			"attached_to_character_id": {"type": ["string", "null"]},
			"attachment_mode": {"type": ["string", "null"], "enum": ["carried", "equipped", "mounted", "in_inventory", "stashed", "", null]},
			"x": {"type": "integer", "minimum": 0, "maximum": MAP_WIDTH - 1},
			"y": {"type": "integer", "minimum": 0, "maximum": MAP_HEIGHT - 1},
			"z": {"type": "integer", "minimum": 0, "maximum": 99},
			"position_label": {"type": "string"},
		},
		"required": ["id", "display_name", "nouns", "adjectives", "elements", "side", "max_hp", "hp", "physical_attack", "physical_defence", "magic_power", "magic_defence", "speed", "size", "status_effects", "important_notes", "attached_to_character_id", "attachment_mode", "x", "y", "z", "position_label"],
	}

	OBJECT_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"id": {"type": "string"},
			"name": {"type": "string"},
			"controller": {"type": "string", "enum": ["Team A", "Team B", "Neutral"]},
			"attached_to_character_id": {"type": ["string", "null"]},
			"attachment_mode": {"type": ["string", "null"], "enum": ["carried", "equipped", "mounted", "in_inventory", "stashed", "", null]},
			"state": {"type": "array", "items": {"type": "string"}},
			"x": {"type": "integer", "minimum": 0, "maximum": MAP_WIDTH - 1},
			"y": {"type": "integer", "minimum": 0, "maximum": MAP_HEIGHT - 1},
			"z": {"type": "integer", "minimum": 0, "maximum": 99},
			"size": {"type": "integer", "minimum": 1, "maximum": 16},
			"location_label": {"type": "string"},
		},
		"required": ["id", "name", "controller", "attached_to_character_id", "attachment_mode", "state", "x", "y", "z", "size", "location_label"],
	}

	BATTLEFIELD_FEATURE_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"id": {"type": "string"},
			"name": {"type": "string"},
			"feature_kind": {"type": "string", "enum": ["hazard", "zone", "terrain_feature", "effect"]},
			"controller": {"type": "string", "enum": ["Team A", "Team B", "Neutral"]},
			"state": {"type": "array", "items": {"type": "string"}},
			"x": {"type": "integer", "minimum": 0, "maximum": MAP_WIDTH - 1},
			"y": {"type": "integer", "minimum": 0, "maximum": MAP_HEIGHT - 1},
			"z": {"type": "integer", "minimum": 0, "maximum": 99},
			"width": {"type": "integer", "minimum": 1, "maximum": MAP_WIDTH},
			"height": {"type": "integer", "minimum": 1, "maximum": MAP_HEIGHT},
			"location_label": {"type": "string"},
		},
		"required": ["id", "name", "feature_kind", "controller", "state", "x", "y", "z", "width", "height", "location_label"],
	}

	BATTLEFIELD_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"terrain": {"type": "string"},
			"visibility": {"type": "string"},
			"battlefield_features": {"type": "array", "items": BATTLEFIELD_FEATURE_SCHEMA},
			"environmental_notes": {"type": "array", "items": {"type": "string"}},
		},
		"required": ["terrain", "visibility", "battlefield_features", "environmental_notes"],
	}

	GAME_STATE_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"round_number": {"type": "integer", "minimum": 1},
			"phase": {"type": "string", "enum": ["round_planning", "round_resolution"]},
			"winner": {"type": "string", "enum": ["Team A", "Team B", "Draw", "None"]},
			"team_a_probability": {"type": "integer", "minimum": 0},
			"team_b_probability": {"type": "integer", "minimum": 0},
			"map_width": {"type": "integer", "const": MAP_WIDTH},
			"map_height": {"type": "integer", "const": MAP_HEIGHT},
			"map_name": {"type": "string"},
			"visual_theme": {"type": "string"},
			"characters": {"type": "array", "items": CHARACTER_SCHEMA},
			"objects": {"type": "array", "items": OBJECT_SCHEMA},
			"battlefield": BATTLEFIELD_SCHEMA,
			"ongoing_effects": {"type": "array", "items": {"type": "string"}},
			"recent_round_history": {"type": "array", "items": {"type": "string"}},
			"battle_conclusion": {"type": "string"},
			"other_important_notes": {"type": "array", "items": {"type": "string"}},
		},
		"required": ["round_number", "phase", "winner", "team_a_probability", "team_b_probability", "map_width", "map_height", "map_name", "visual_theme", "characters", "objects", "battlefield", "ongoing_effects", "recent_round_history", "battle_conclusion", "other_important_notes"],
	}

	COST_OUTPUT_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"short_player_summary": {"type": "string"},
			"probability_cost": {"type": "integer", "minimum": 0, "maximum": 999},
			"cost_band": {"type": "string", "enum": ["trivial", "easy", "grounded", "strained", "borderline", "rule-breaking"]},
			"status": {"type": "string", "enum": ["playable", "ambiguous", "illegal"]},
			"cheaper_alternative": {"type": "string"},
		},
		"required": ["short_player_summary", "probability_cost", "cost_band", "status", "cheaper_alternative"],
	}

	TEAM_B_OUTPUT_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {"proposed_action": {"type": "string"}},
		"required": ["proposed_action"],
	}

	var delta_change_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"field": {"type": "string"},
			"mode": {"type": "string", "enum": ["set", "add", "subtract", "append_unique", "remove_items"]},
			"value_source": {"type": "string", "enum": ["manual", "intent"]},
			"string_value": {"type": ["string", "null"]},
			"int_value": {"type": ["integer", "null"], "minimum": -999, "maximum": 999},
			"string_list_value": {"type": "array", "items": {"type": "string"}},
			"bool_value": {"type": "boolean"},
		},
		"required": ["field", "mode", "value_source", "string_value", "int_value", "string_list_value", "bool_value"],
	}

	var source_metadata_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"source_kind": {"type": "string", "enum": ["", "character", "object", "battlefield_feature", "status_effect", "environment", "system"]},
			"source_id": {"type": ["string", "null"]},
		},
		"required": ["source_kind", "source_id"],
	}

	var target_area_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"x": {"type": "integer", "minimum": 0, "maximum": MAP_WIDTH - 1},
			"y": {"type": "integer", "minimum": 0, "maximum": MAP_HEIGHT - 1},
			"z": {"type": "integer", "minimum": 0, "maximum": 99},
			"radius": {"type": "integer", "minimum": 0, "maximum": MAP_WIDTH},
		},
		"required": ["x", "y", "z", "radius"],
	}

	var targeting_metadata_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"targeting_kind": {"type": "string", "enum": ["none", "self", "explicit_targets", "area", "environment"]},
			"target_ids": {"type": "array", "items": {"type": "string"}},
			"target_area": {"type": ["object", "null"], "properties": target_area_schema["properties"], "required": target_area_schema["required"], "additionalProperties": false},
		},
		"required": ["targeting_kind", "target_ids", "target_area"],
	}

	var mechanics_metadata_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"action_kind": {"type": "string", "enum": ["", "attack", "defend", "move", "support", "control", "create", "status", "environment", "other"]},
			"physical_or_magic": {"type": "string", "enum": ["", "physical", "magic"]},
			"elements": {"type": "array", "items": {"type": "string", "enum": ELEMENT_TYPES}},
			"power_multiplier": {"type": "number", "minimum": 0.0, "maximum": 12.0},
		},
		"required": ["action_kind", "physical_or_magic", "elements", "power_multiplier"],
	}

	var game_state_delta_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"op": {"type": "string", "enum": ["update_character", "update_object", "update_battlefield_feature", "update_battlefield", "update_state"]},
			"id": {"type": "string"},
			"source_id": {"type": "string"},
			"power_multiplier_override": {"type": ["number", "null"], "minimum": 0.0, "maximum": 12.0},
			"changes": {"type": "array", "items": delta_change_schema},
		},
		"required": ["op", "id", "source_id", "power_multiplier_override", "changes"],
	}

	var effect_attributes_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"text_effect": {"type": "string", "enum": TEXT_EFFECT_TYPES},
			"update_reasoning": {"type": "string"},
			"narrator_speed": {"type": "integer", "minimum": 0, "maximum": 4},
			"source": {"type": ["object", "null"], "properties": source_metadata_schema["properties"], "required": source_metadata_schema["required"], "additionalProperties": false},
			"targeting": {"type": ["object", "null"], "properties": targeting_metadata_schema["properties"], "required": targeting_metadata_schema["required"], "additionalProperties": false},
			"mechanics": {"type": ["object", "null"], "properties": mechanics_metadata_schema["properties"], "required": mechanics_metadata_schema["required"], "additionalProperties": false},
			"game_state_delta": {"type": "array", "items": game_state_delta_schema},
			"created_characters": {"type": "array", "items": CHARACTER_SCHEMA},
			"created_objects": {"type": "array", "items": OBJECT_SCHEMA},
			"created_battlefield_features": {"type": "array", "items": BATTLEFIELD_FEATURE_SCHEMA},
			"removed_character_ids": {"type": "array", "items": {"type": "string"}},
			"removed_object_ids": {"type": "array", "items": {"type": "string"}},
			"removed_battlefield_feature_ids": {"type": "array", "items": {"type": "string"}},
		},
		"required": ["text_effect", "update_reasoning", "narrator_speed", "source", "targeting", "mechanics", "game_state_delta", "created_characters", "created_objects", "created_battlefield_features", "removed_character_ids", "removed_object_ids", "removed_battlefield_feature_ids"],
	}

	var story_fragment_schema = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"text": {"type": "string", "minLength": 1},
			"effect_attributes": {"type": ["object", "null"], "properties": effect_attributes_schema["properties"], "required": effect_attributes_schema["required"], "additionalProperties": false},
		},
		"required": ["text", "effect_attributes"],
	}

	NARRATOR_OUTPUT_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"story": {"type": "string"},
			"story_fragments": {"type": "array", "items": story_fragment_schema},
			"round_history_line": {"type": "string"},
			"battle_evaluation": {"type": "integer", "minimum": -10, "maximum": 10},
		},
		"required": ["story", "story_fragments", "round_history_line", "battle_evaluation"],
	}

	INITIALIZER_OUTPUT_SCHEMA = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"opening_scene": {"type": "string"},
			"initialized_game_state": GAME_STATE_SCHEMA,
		},
		"required": ["opening_scene", "initialized_game_state"],
	}



# Initializer input


func _build_initializer_input(characters_without_positions: Array = starting_characters) -> Dictionary:
	return {
		"characters": _build_initializer_characters(characters_without_positions),
		"starting_probability": STARTING_PROBABILITY,
		"battle_style": BATTLE_STYLE,
		"map_width": MAP_WIDTH,
		"map_height": MAP_HEIGHT,
		"initialization_constraints": _merged_initialization_constraints(),
	}


func _build_initializer_characters(raw_characters: Array) -> Array:
	var source: Array = raw_characters
	if source.is_empty():
		source = _dummy_starting_characters_without_positions()

	var result: Array = []
	for index in range(source.size()):
		if not (source[index] is Dictionary):
			continue
		var raw: Dictionary = source[index]
		var character: Dictionary = raw.duplicate(true)
		var fallback_id = "unit_%d" % [index + 1]

		character["id"] = _canonical_character_id(str(character.get("id", fallback_id)))
		character["display_name"] = str(character.get("display_name", character["id"]))
		character["nouns"] = _string_array(character.get("nouns", []))
		character["adjectives"] = _string_array(character.get("adjectives", []))
		character["elements"] = _filtered_elements(character.get("elements", []))
		character["side"] = _normalized_side(str(character.get("side", "Neutral")))
		character["max_hp"] = int(round(float(character.get("max_hp", 100))))
		character["hp"] = int(round(float(character.get("hp", character["max_hp"]))))
		character["physical_attack"] = int(round(float(character.get("physical_attack", 10))))
		character["physical_defence"] = int(round(float(character.get("physical_defence", 10))))
		character["magic_power"] = int(round(float(character.get("magic_power", 10))))
		character["magic_defence"] = int(round(float(character.get("magic_defence", 10))))
		character["speed"] = int(round(float(character.get("speed", 10))))
		character["size"] = int(round(float(character.get("size", 2))))
		character["status_effects"] = _string_array(character.get("status_effects", []))
		character["important_notes"] = _string_array(character.get("important_notes", []))
		character["attached_to_character_id"] = character.get("attached_to_character_id", null)
		character["attachment_mode"] = character.get("attachment_mode", null)
		character["x"] = int(character.get("x", 0))
		character["y"] = int(character.get("y", 0))
		character["z"] = int(character.get("z", 0))
		character["position_label"] = str(character.get("position_label", "unplaced"))
		result.append(character)

	return result


func _dummy_starting_characters_without_positions() -> Array:
	return [
		{
			"id": "team_a_unit_1",
			"display_name": "blazing iron knight",
			"nouns": ["knight"],
			"adjectives": ["blazing", "iron"],
			"elements": ["fire", "earth"],
			"side": "Team A",
			"max_hp": 120,
			"hp": 120,
			"physical_attack": 14,
			"physical_defence": 15,
			"magic_power": 6,
			"magic_defence": 8,
			"speed": 7,
			"size": 2,
		},
		{
			"id": "team_b_unit_1",
			"display_name": "icy shadow wolf",
			"nouns": ["wolf"],
			"adjectives": ["icy", "shadow"],
			"elements": ["ice", "dark"],
			"side": "Team B",
			"max_hp": 95,
			"hp": 95,
			"physical_attack": 13,
			"physical_defence": 8,
			"magic_power": 7,
			"magic_defence": 7,
			"speed": 15,
			"size": 2,
		},
	]


func _merged_initialization_constraints() -> Dictionary:
	var result = {
		"preserve_characters_exactly": true,
		"stats_are_already_rounded_to_integers": true,
		"use_reduced_elements_only": true,
		"allowed_elements": ELEMENT_TYPES,
	}
	for key in initialization_constraints.keys():
		result[key] = initialization_constraints[key]
	return result



# Main game flow


func _start_new_game() -> void:
	current_phase = "initializing"
	manuscript.disable_input("Creating battlefield.")
	var thinking = manuscript.add_thinking_message("init")

	var initializer_input: Dictionary = _build_initializer_input()
	var result: Dictionary = await _call_initializer(initializer_input)
	manuscript.remove_msg(thinking)

	if result.has("error"):
		manuscript.add_system_message("Initializer error: %s" % str(result["error"]))
		return

	var data: Dictionary = result["result"]
	var repaired_state: Dictionary = _repair_initialized_state_characters(data.get("initialized_game_state", {}), initializer_input.get("characters", []), MAP_WIDTH, MAP_HEIGHT)
	game_state = _normalize_game_state(repaired_state)
	game_state["phase"] = "round_planning"
	_round_cost_verdict_cache = {}
	_make_map_image_async(game_state)
	var opening_scene = str(data.get("opening_scene", "The battle begins."))
	_start_initialiser_tts(opening_scene)
	manuscript.add_narrator_message(opening_scene)
	redraw_tokens()
	_sync_token_attachments()
	_start_round()
	
func _make_map_image_async(game_state: Dictionary) -> void:
	var map_image := await PromptAPI.make_map_image(game_state) # TODO USE MAP IMAGE GENERATION FEED TO MAP
	map_manager.set_map_texture(map_image)

func _start_round() -> void:
	current_phase = "awaiting_action"
	last_team_a_action = ""
	last_cost_result = {}
	round_team_b_action = ""
	round_team_b_cost_result = {}
	_round_cost_verdict_cache = {}
	_invalidate_speculative_narrator()

	game_state["phase"] = "round_planning"
	redraw_tokens()
	_sync_token_attachments()

	_start_team_b_prefetch()

	manuscript.enable_input("Enter your action.")
	manuscript.focus_input()


func _on_action_submitted(text: String) -> void:
	var action = text.strip_edges()
	if action.is_empty():
		return

	match current_phase:
		"awaiting_action":
			_price_team_a(action)
		"awaiting_confirm":
			_handle_confirmation(action)
		_:
			pass


func _on_action_text_changed(_text: String) -> void:
	pass


func _price_team_a(action_text: String) -> void:
	current_phase = "pricing_team_a"
	last_team_a_action = action_text
	manuscript.clear_input()
	manuscript.disable_input("Judging action.")
	manuscript.add_team_a_message(action_text)

	_maybe_start_speculative_narrator(action_text)

	var cached_cost: Dictionary = _get_cached_round_cost_verdict("Team A", action_text)
	if not cached_cost.is_empty():
		last_cost_result = cached_cost
		_handle_team_a_cost_result()
		return

	var thinking = manuscript.add_thinking_message("cost")
	var result: Dictionary = await _call_cost_judge("Team A", action_text)
	manuscript.remove_msg(thinking)

	if result.has("error"):
		manuscript.add_system_message("Cost judge error: %s" % str(result["error"]))
		_start_round()
		return

	last_cost_result = result["result"]
	_store_round_cost_verdict("Team A", action_text, last_cost_result)
	_record_cost_verdict("Team A", action_text, last_cost_result)
	_handle_team_a_cost_result()


func _handle_team_a_cost_result() -> void:
	var cost = int(last_cost_result.get("probability_cost", 999))
	var band = str(last_cost_result.get("cost_band", ""))
	var summary = str(last_cost_result.get("short_player_summary", ""))
	var status = str(last_cost_result.get("status", "illegal"))
	var available = int(game_state.get("team_a_probability", 0))

	manuscript.add_cost_message(cost, band, summary)

	if status != "playable":
		current_phase = "awaiting_action"
		manuscript.add_system_message("That action is not playable. %s" % str(last_cost_result.get("cheaper_alternative", "")))
		manuscript.enable_input("Enter a different action.")
		manuscript.focus_input()
		return

	if cost > available:
		current_phase = "awaiting_action"
		manuscript.add_system_message("Not enough probability. You have %d and this costs %d. %s" % [available, cost, str(last_cost_result.get("cheaper_alternative", ""))])
		manuscript.enable_input("Enter a cheaper action.")
		manuscript.focus_input()
		return

	current_phase = "awaiting_confirm"
	manuscript.enable_input("Type y to play, or edit to revise.")
	manuscript.focus_input()


func _handle_confirmation(text: String) -> void:
	var cmd = text.strip_edges().to_lower()
	manuscript.clear_input()

	if cmd == "y" or cmd == "yes":
		_confirm_team_a_action()
		return

	if cmd == "edit" or cmd == "e":
		current_phase = "awaiting_action"
		manuscript.set_input_text(last_team_a_action)
		manuscript.enable_input("Edit your action.")
		manuscript.focus_input()
		return

	manuscript.enable_input("Type y to play, or edit to revise.")
	manuscript.focus_input()


func _confirm_team_a_action() -> void:
	current_phase = "processing"
	manuscript.disable_input("Resolving round.")

	var cost = int(last_cost_result.get("probability_cost", 0))
	adjust_prob(-cost, true)
	game_state["team_a_probability"] = maxi(0, int(game_state.get("team_a_probability", 0)) - cost)
	_resolve_round()


func _resolve_round() -> void:
	var team_b_result: Dictionary = await _get_team_b_action_result()
	if team_b_result.has("error"):
		manuscript.add_system_message("Team B error: %s" % str(team_b_result["error"]))
		_start_round()
		return

	round_team_b_action = str(team_b_result.get("result", {}).get("proposed_action", round_team_b_action))
	if round_team_b_action.strip_edges().is_empty():
		round_team_b_action = "Team B takes a guarded stance."

	var team_b_cost: Dictionary = await _get_team_b_cost_result(round_team_b_action)
	if team_b_cost.has("error"):
		round_team_b_cost_result = _fallback_team_b_cost()
	else:
		round_team_b_cost_result = team_b_cost.get("result", team_b_cost)

	_apply_team_b_affordability_fallback()

	var tb_cost = int(round_team_b_cost_result.get("probability_cost", 1))
	adjust_prob(-tb_cost, false)
	game_state["team_b_probability"] = maxi(0, int(game_state.get("team_b_probability", 0)) - tb_cost)

	manuscript.add_team_b_message(round_team_b_action)
	manuscript.add_cost_message(tb_cost, str(round_team_b_cost_result.get("cost_band", "easy")), str(round_team_b_cost_result.get("short_player_summary", "Team B acts.")))

	var narrator_input: Dictionary = _build_narrator_input(last_team_a_action, round_team_b_action)
	if not _has_matching_speculative_narrator(narrator_input):
		_start_speculative_narrator(narrator_input)

	var narrator_result: Dictionary = await _resolve_narrator(narrator_input)
	if narrator_result.has("error"):
		manuscript.add_system_message("Narrator error: %s" % str(narrator_result["error"]))
		_start_round()
		return

	await _finish_narrator_round(narrator_result["result"])


func _apply_team_b_affordability_fallback() -> void:
	var tb_available = int(game_state.get("team_b_probability", 0))
	var tb_cost = int(round_team_b_cost_result.get("probability_cost", 999))
	var tb_status = str(round_team_b_cost_result.get("status", "illegal"))

	if tb_status == "playable" and tb_cost <= tb_available:
		return

	var fallback_result = _team_b_cost_fallback(
		round_team_b_cost_result,
		tb_available
	)

	round_team_b_action = str(
		fallback_result.get(
			"action",
			"Team B takes a simple guarded stance."
		)
	)

	var fallback_cost_variant = fallback_result.get("cost", _fallback_team_b_cost())
	if fallback_cost_variant is Dictionary:
		round_team_b_cost_result = fallback_cost_variant
	else:
		round_team_b_cost_result = _fallback_team_b_cost()

	_store_round_cost_verdict("Team B", round_team_b_action, round_team_b_cost_result)
	_record_cost_verdict("Team B", round_team_b_action, round_team_b_cost_result)

	# Team B action changed, so any speculative narrator for the old action is stale.
	_invalidate_speculative_narrator()
	_maybe_start_speculative_narrator(last_team_a_action)


func _finish_narrator_round(narrator_data: Dictionary) -> void:
	if not _streamed_any_fragments:
		var final_fragments: Array = _normalize_story_fragments(narrator_data.get("story_fragments", []))
		for fragment in final_fragments:
			_append_story_fragment(fragment)

	while _queued_fragment_apply_count > 0:
		await get_tree().create_timer(0.03).timeout

	_finish_live_narrator_stream()

	var final_history_fragments: Array = _streamed_fragments_for_history
	if final_history_fragments.is_empty():
		final_history_fragments = _normalize_story_fragments(narrator_data.get("story_fragments", []))
	_record_power_multiplier_verdicts(last_team_a_action, round_team_b_action, final_history_fragments)

	var history_line = str(narrator_data.get("round_history_line", "")).strip_edges()
	if not history_line.is_empty():
		var history: Array = game_state.get("recent_round_history", [])
		history.append(history_line)
		game_state["recent_round_history"] = history

	game_state["round_number"] = int(game_state.get("round_number", 1)) + 1
	game_state["phase"] = "round_planning"
	_apply_round_income()
	redraw_tokens()
	_sync_token_attachments()

	var winner = str(game_state.get("winner", "None"))
	if winner != "None":
		_enter_post_game(winner)
	else:
		_start_round()


func _apply_round_income() -> void:
	game_state["team_a_probability"] = int(game_state.get("team_a_probability", 0)) + ROUND_INCOME
	game_state["team_b_probability"] = int(game_state.get("team_b_probability", 0)) + ROUND_INCOME
	adjust_prob(ROUND_INCOME, true)
	adjust_prob(ROUND_INCOME, false)


func _enter_post_game(winner: String) -> void:
	current_phase = "post_game"
	manuscript.add_system_message("Game Over! Winner: %s" % winner)
	manuscript.disable_input("Game ended.")



# Team B prefetch: action + cost


func _start_team_b_prefetch() -> void:
	_team_b_request_id += 1
	var request_id = _team_b_request_id
	_team_b_running = true
	_team_b_done = false
	_team_b_error = ""
	_team_b_state_key = _team_b_prefetch_key()
	_team_b_cost_running = false
	_team_b_cost_done = false
	_team_b_cost_error = ""
	_team_b_cost_state_key = ""
	_team_b_cost_action = ""
	_run_team_b_prefetch(request_id, game_state.duplicate(true))


func _run_team_b_prefetch(request_id: int, state_snapshot: Dictionary) -> void:
	var previous_state: Dictionary = game_state
	var previous_last_action = last_team_a_action
	game_state = state_snapshot
	last_team_a_action = ""
	var result: Dictionary = await _call_team_b_action()
	game_state = previous_state
	last_team_a_action = previous_last_action

	if request_id != _team_b_request_id:
		return

	_team_b_running = false
	_team_b_done = true
	if result.has("error"):
		_team_b_error = str(result["error"])
		return

	round_team_b_action = str(result.get("result", {}).get("proposed_action", ""))
	_maybe_start_speculative_narrator()
	_start_team_b_cost_prefetch(state_snapshot, round_team_b_action)


func _start_team_b_cost_prefetch(state_snapshot: Dictionary, action_text: String) -> void:
	if action_text.strip_edges().is_empty():
		return
	_team_b_cost_running = true
	_team_b_cost_done = false
	_team_b_cost_error = ""
	_team_b_cost_state_key = _team_b_prefetch_key_for_state(state_snapshot)
	_team_b_cost_action = action_text
	_run_team_b_cost_prefetch(_team_b_request_id, state_snapshot, action_text)


func _run_team_b_cost_prefetch(request_id: int, state_snapshot: Dictionary, action_text: String) -> void:
	var previous_state: Dictionary = game_state
	game_state = state_snapshot
	var result: Dictionary = await _call_cost_judge("Team B", action_text)
	game_state = previous_state

	if request_id != _team_b_request_id:
		return

	_team_b_cost_running = false
	_team_b_cost_done = true
	if result.has("error"):
		_team_b_cost_error = str(result["error"])
		return

	round_team_b_cost_result = result["result"]
	_store_round_cost_verdict("Team B", action_text, round_team_b_cost_result)
	_record_cost_verdict("Team B", action_text, round_team_b_cost_result)


func _get_team_b_action_result() -> Dictionary:
	var current_key = _team_b_prefetch_key()
	if _team_b_state_key == current_key:
		while _team_b_running:
			await get_tree().create_timer(0.03).timeout
		if _team_b_done:
			if not _team_b_error.is_empty():
				return {"error": _team_b_error}
			return {"result": {"proposed_action": round_team_b_action}}
	return await _call_team_b_action()


func _get_team_b_cost_result(action_text: String) -> Dictionary:
	var current_key = _team_b_prefetch_key()
	if _team_b_cost_state_key == current_key and _canonical_round_cost_action(_team_b_cost_action) == _canonical_round_cost_action(action_text):
		while _team_b_cost_running:
			await get_tree().create_timer(0.03).timeout
		if _team_b_cost_done:
			if not _team_b_cost_error.is_empty():
				return {"error": _team_b_cost_error}
			return {"result": round_team_b_cost_result}

	var cached: Dictionary = _get_cached_round_cost_verdict("Team B", action_text)
	if not cached.is_empty():
		return {"result": cached}
	var result: Dictionary = await _call_cost_judge("Team B", action_text)
	if not result.has("error"):
		_store_round_cost_verdict("Team B", action_text, result["result"])
		_record_cost_verdict("Team B", action_text, result["result"])
	return result


func _team_b_prefetch_key() -> String:
	return _team_b_prefetch_key_for_state(game_state)


func _team_b_prefetch_key_for_state(state: Dictionary) -> String:
	return JSON.stringify({
		"game_state": state,
		"team_b_probability": int(state.get("team_b_probability", 0)),
	})



# Speculative narrator + streaming


func _build_narrator_input(team_a_action: String, team_b_action: String) -> Dictionary:
	return {
		"recent_power_multiplier_verdict_history": _select_power_multiplier_verdict_history(team_a_action, team_b_action),
		"team_a_action": team_a_action,
		"team_b_action": team_b_action,
		"game_state": game_state.duplicate(true),
		"allowed_text_effects": TEXT_EFFECT_TYPES,
		"allowed_elements": ELEMENT_TYPES,
		"streaming_contract": {
			"display_story_from": "story_fragments",
			"ignore_story_field_for_display": true,
			"apply_deltas_after_fragment_finishes_typing": true,
		},
	}


func _maybe_start_speculative_narrator(team_a_action: String = "") -> void:
	var resolved_team_a_action = team_a_action.strip_edges()
	if resolved_team_a_action.is_empty():
		resolved_team_a_action = last_team_a_action.strip_edges()
	if resolved_team_a_action.is_empty():
		return
	if round_team_b_action.strip_edges().is_empty():
		return
	var narrator_input: Dictionary = _build_narrator_input(resolved_team_a_action, round_team_b_action)
	if _has_matching_speculative_narrator(narrator_input):
		return
	_start_speculative_narrator(narrator_input)


func _start_speculative_narrator(narrator_input: Dictionary) -> void:
	_speculative_request_id += 1
	var request_id = _speculative_request_id
	_speculative_narrator_input = narrator_input.duplicate(true)
	_speculative_running = true
	_speculative_done = false
	_speculative_live = false
	_speculative_result = {}
	_speculative_error = ""
	_speculative_fragment_items = []
	_run_speculative_narrator(request_id, narrator_input.duplicate(true))


func _run_speculative_narrator(request_id: int, narrator_input: Dictionary) -> void:
	var result: Dictionary = await _call_narrator_resolution(narrator_input, _on_speculative_narrator_stream_field)
	if request_id != _speculative_request_id:
		return
	_speculative_running = false
	_speculative_done = true
	if result.has("error"):
		_speculative_error = str(result["error"])
	else:
		_speculative_result = result


func _resolve_narrator(narrator_input: Dictionary) -> Dictionary:
	if _has_matching_speculative_narrator(narrator_input):
		_activate_speculative_narrator_stream()
		return await _await_speculative_narrator_result(narrator_input)
	_begin_live_narrator_stream()
	return await _call_narrator_resolution(narrator_input, _on_live_narrator_stream_field)


func _has_matching_speculative_narrator(narrator_input: Dictionary) -> bool:
	return (_speculative_running or _speculative_done) and JSON.stringify(narrator_input) == JSON.stringify(_speculative_narrator_input)


func _activate_speculative_narrator_stream() -> void:
	_speculative_live = true
	_begin_live_narrator_stream()
	for fragment in _speculative_fragment_items:
		_append_story_fragment(fragment)


func _await_speculative_narrator_result(narrator_input: Dictionary) -> Dictionary:
	while _has_matching_speculative_narrator(narrator_input) and not _speculative_done:
		await get_tree().create_timer(0.03).timeout
	if not _speculative_error.is_empty():
		return {"error": _speculative_error}
	return _speculative_result


func _invalidate_speculative_narrator() -> void:
	_speculative_request_id += 1
	_speculative_narrator_input = {}
	_speculative_running = false
	_speculative_done = false
	_speculative_live = false
	_speculative_result = {}
	_speculative_error = ""
	_speculative_fragment_items = []


func _on_speculative_narrator_stream_field(field_name: String, text: String) -> void:
	if field_name != "story_fragments_item":
		return
	var fragment: Dictionary = _parse_story_fragment_stream_item(text)
	if fragment.is_empty():
		return
	_speculative_fragment_items.append(fragment)
	if _speculative_live:
		_append_story_fragment(fragment)


func _begin_live_narrator_stream() -> void:
	if is_instance_valid(_streaming_narrator_content):
		return
	_streaming_narrator_thinking = manuscript.add_thinking_message("narrator")
	_streaming_narrator_content = manuscript.add_streaming_narrator_message()
	_queued_fragment_apply_count = 0
	_streamed_any_fragments = false
	_finished_fragment_keys = {}
	_streamed_fragments_for_history = []


func _finish_live_narrator_stream() -> void:
	if is_instance_valid(_streaming_narrator_thinking):
		manuscript.remove_msg(_streaming_narrator_thinking)
	_streaming_narrator_thinking = null
	_streaming_narrator_content = null


func _on_live_narrator_stream_field(field_name: String, text: String) -> void:
	if field_name != "story_fragments_item":
		return
	var fragment: Dictionary = _parse_story_fragment_stream_item(text)
	if not fragment.is_empty():
		_append_story_fragment(fragment)


func _append_story_fragment(fragment: Dictionary) -> void:
	var text = str(fragment.get("text", ""))
	if text.is_empty():
		return
	if not is_instance_valid(_streaming_narrator_content):
		_begin_live_narrator_stream()

	_streamed_any_fragments = true
	_streamed_fragments_for_history.append(fragment.duplicate(true))

	var attrs: Dictionary = _fragment_attrs(fragment)
	var effect = str(attrs.get("text_effect", "")).strip_edges().to_lower()
	if not TEXT_EFFECT_TYPES.has(effect):
		effect = ""
	var preset: Dictionary = _story_fragment_preset(effect)
	var delay = _story_fragment_delay_override(attrs)
	var fragment_to_apply: Dictionary = fragment.duplicate(true)
	var fragment_key = _fragment_key(fragment_to_apply)
	_queued_fragment_apply_count += 1

	manuscript.append_typewriter_preset(
		_streaming_narrator_content,
		text,
		preset,
		true,
		delay,
		func() -> void:
			_apply_fragment_when_text_ready(fragment_key, fragment_to_apply)
	)


func _apply_fragment_when_text_ready(fragment_key: String, fragment: Dictionary) -> void:
	if _finished_fragment_keys.has(fragment_key):
		_queued_fragment_apply_count = maxi(0, _queued_fragment_apply_count - 1)
		return
	_finished_fragment_keys[fragment_key] = true
	_apply_single_story_fragment(fragment)
	_sync_token_attachments()
	_queued_fragment_apply_count = maxi(0, _queued_fragment_apply_count - 1)


func _fragment_key(fragment: Dictionary) -> String:
	return JSON.stringify(fragment)


func _fragment_attrs(fragment: Dictionary) -> Dictionary:
	var attrs_variant: Variant = fragment.get("effect_attributes", null)
	if attrs_variant is Dictionary:
		return attrs_variant
	return {}


func _story_fragment_preset(effect: String) -> Dictionary:
	if effect.is_empty():
		return TextEffects.writing_narrator()
	return TextEffects.semantic(effect)


func _story_fragment_delay_override(attrs: Dictionary) -> float:
	var speed_variant: Variant = attrs.get("narrator_speed", null)
	if not (speed_variant is int or speed_variant is float):
		return -1.0
	match clampi(int(round(float(speed_variant))), 0, 4):
		0:
			return 0.0086
		1:
			return 0.0067
		2:
			return 0.0054
		3:
			return 0.0039
		4:
			return 0.0029
		_:
			return -1.0


func _parse_story_fragment_stream_item(text: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func _normalize_story_fragments(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result



# Fragment application + intent deltas


func _apply_single_story_fragment(fragment: Dictionary) -> void:
	var fragment_data: Dictionary = _flatten_fragment_for_runtime(fragment)
	if fragment_data.is_empty():
		return

	fragment_data["_visual_events"] = []

	_apply_created_entities(fragment_data)
	_apply_removed_entities(fragment_data)

	var ops: Array = fragment_data.get("game_state_delta", [])
	for op_variant in ops:
		if op_variant is Dictionary:
			_apply_game_state_delta(op_variant, fragment_data)

	_apply_fragment_visual_stubs(fragment_data)


func _flatten_fragment_for_runtime(fragment: Dictionary) -> Dictionary:
	var attrs: Dictionary = _fragment_attrs(fragment)
	if attrs.is_empty():
		return {}

	var source: Dictionary = {}
	if attrs.get("source", null) is Dictionary:
		source = attrs.get("source", {})

	var targeting: Dictionary = {}
	if attrs.get("targeting", null) is Dictionary:
		targeting = attrs.get("targeting", {})

	var mechanics: Dictionary = {}
	if attrs.get("mechanics", null) is Dictionary:
		mechanics = attrs.get("mechanics", {})

	return {
		"text": str(fragment.get("text", "")),
		"text_effect": str(attrs.get("text_effect", "")),
		"update_reasoning": str(attrs.get("update_reasoning", "")),
		"narrator_speed": int(attrs.get("narrator_speed", 2)),
		"source_kind": str(source.get("source_kind", "")),
		"source_id": _canonical_character_id(str(source.get("source_id", attrs.get("source_id", "")) if source.get("source_id", null) != null else "")),
		"targeting_kind": str(targeting.get("targeting_kind", "none")),
		"target_ids": targeting.get("target_ids", attrs.get("target_ids", [])),
		"target_area": targeting.get("target_area", null),
		"action_kind": str(mechanics.get("action_kind", "")),
		"physical_or_magic": str(mechanics.get("physical_or_magic", "")),
		"elements": _filtered_elements(mechanics.get("elements", [])),
		"power_multiplier": _normalize_power_multiplier(mechanics.get("power_multiplier", 1.0)),
		"game_state_delta": attrs.get("game_state_delta", []),
		"created_characters": attrs.get("created_characters", []),
		"created_objects": attrs.get("created_objects", []),
		"created_battlefield_features": attrs.get("created_battlefield_features", []),
		"removed_character_ids": attrs.get("removed_character_ids", []),
		"removed_object_ids": attrs.get("removed_object_ids", []),
		"removed_battlefield_feature_ids": attrs.get("removed_battlefield_feature_ids", []),
	}


func _fragment_data_for_op(fragment_data: Dictionary, op_data: Dictionary) -> Dictionary:
	var scoped: Dictionary = fragment_data.duplicate(true)
	var op_source = str(op_data.get("source_id", "")).strip_edges()
	if not op_source.is_empty():
		scoped["source_id"] = _canonical_character_id(op_source)
	var op_power: Variant = op_data.get("power_multiplier_override", null)
	if op_power is int or op_power is float:
		scoped["power_multiplier"] = _normalize_power_multiplier(op_power)
	return scoped


func _apply_created_entities(fragment_data: Dictionary) -> void:
	for character_variant in fragment_data.get("created_characters", []):
		var character = _normalize_character_state(character_variant)
		if character.is_empty():
			continue
		character["id"] = _generate_unique_runtime_id(_existing_ids(game_state.get("characters", [])), str(character.get("id", "")), "character")
		game_state["characters"].append(character)
		spawn_token(character)

	for object_variant in fragment_data.get("created_objects", []):
		var object_data = _normalize_object_state(object_variant)
		if object_data.is_empty():
			continue
		object_data["id"] = _generate_unique_runtime_id(_existing_ids(game_state.get("objects", [])), str(object_data.get("id", "")), "object")
		game_state["objects"].append(object_data)
		spawn_token(object_data)

	for feature_variant in fragment_data.get("created_battlefield_features", []):
		var feature = _normalize_battlefield_feature_state(feature_variant)
		if feature.is_empty():
			continue
		var battlefield: Dictionary = game_state.get("battlefield", {})
		feature["id"] = _generate_unique_runtime_id(_existing_ids(battlefield.get("battlefield_features", [])), str(feature.get("id", "")), "feature")
		battlefield["battlefield_features"].append(feature)
		game_state["battlefield"] = battlefield
		spawn_battlefield_feature(feature)


func _apply_removed_entities(fragment_data: Dictionary) -> void:
	for id_variant in fragment_data.get("removed_character_ids", []):
		var id = _canonical_character_id(str(id_variant))
		_remove_entity_by_id(game_state.get("characters", []), id)
		remove_token(id)

	for id_variant in fragment_data.get("removed_object_ids", []):
		var id = str(id_variant)
		_remove_entity_by_id(game_state.get("objects", []), id)
		remove_token(id)

	for id_variant in fragment_data.get("removed_battlefield_feature_ids", []):
		var id = str(id_variant)
		var battlefield: Dictionary = game_state.get("battlefield", {})
		_remove_entity_by_id(battlefield.get("battlefield_features", []), id)
		game_state["battlefield"] = battlefield
		remove_battlefield_feature(id)


func _apply_game_state_delta(op_data: Dictionary, fragment_data: Dictionary) -> void:
	var op_fragment_data: Dictionary = _fragment_data_for_op(fragment_data, op_data)
	var op_name = str(op_data.get("op", "")).strip_edges().to_lower()
	var changes: Array = op_data.get("changes", []) if op_data.get("changes", []) is Array else []

	match op_name:
		"update_character":
			var characters: Array = game_state.get("characters", [])
			var char_id = _resolve_character_id(characters, str(op_data.get("id", "")))
			var char_index = _find_entity_index_by_id(characters, char_id)
			if char_index == -1:
				return
			var current_character: Dictionary = characters[char_index]
			if not _entity_is_within_fragment_area("update_character", char_id, current_character, op_fragment_data):
				return
			var next_character: Dictionary = current_character.duplicate(true)
			for change_variant in changes:
				if change_variant is Dictionary:
					next_character = _apply_character_change_entry(next_character, change_variant, op_fragment_data, game_state)
			characters[char_index] = _normalize_character_state(next_character)
			game_state["characters"] = characters
			_update_token_from_entity(characters[char_index])

		"update_object":
			var objects: Array = game_state.get("objects", [])
			var object_id = str(op_data.get("id", ""))
			var object_index = _find_entity_index_by_id(objects, object_id)
			if object_index == -1:
				return
			var current_object: Dictionary = objects[object_index]
			if not _entity_is_within_fragment_area("update_object", object_id, current_object, op_fragment_data):
				return
			var next_object: Dictionary = current_object.duplicate(true)
			for change_variant in changes:
				if change_variant is Dictionary:
					next_object = _apply_generic_change_entry(next_object, change_variant)
			objects[object_index] = _normalize_object_state(next_object)
			game_state["objects"] = objects
			_update_token_from_entity(objects[object_index])

		"update_battlefield_feature":
			var battlefield: Dictionary = game_state.get("battlefield", {})
			var features: Array = battlefield.get("battlefield_features", [])
			var feature_id = str(op_data.get("id", ""))
			var feature_index = _find_entity_index_by_id(features, feature_id)
			if feature_index == -1:
				return
			var current_feature: Dictionary = features[feature_index]
			if not _entity_is_within_fragment_area("update_battlefield_feature", feature_id, current_feature, op_fragment_data):
				return
			var next_feature: Dictionary = current_feature.duplicate(true)
			for change_variant in changes:
				if change_variant is Dictionary:
					next_feature = _apply_generic_change_entry(next_feature, change_variant)
			features[feature_index] = _normalize_battlefield_feature_state(next_feature)
			battlefield["battlefield_features"] = features
			game_state["battlefield"] = battlefield
			redraw_battlefield_features()

		"update_battlefield":
			var battlefield2: Dictionary = game_state.get("battlefield", {}).duplicate(true)
			for change_variant in changes:
				if change_variant is Dictionary:
					battlefield2 = _apply_generic_change_entry(battlefield2, change_variant)
			game_state["battlefield"] = battlefield2
			redraw_battlefield_features()

		"update_state":
			for change_variant in changes:
				if change_variant is Dictionary:
					game_state = _apply_generic_change_entry(game_state, change_variant)
			redraw_tokens()


func _apply_character_change_entry(next_character: Dictionary, change_entry: Dictionary, fragment_data: Dictionary, base_state: Dictionary) -> Dictionary:
	var field_name = str(change_entry.get("field", "")).strip_edges()
	if field_name.is_empty():
		return next_character
	var mode = _normalized_change_mode(change_entry)
	var value_source = _normalized_change_value_source(change_entry)
	var current_value: Variant = next_character.get(field_name, null)

	if _uses_string_array_payload(field_name, current_value):
		next_character[field_name] = _apply_string_array_mode(next_character.get(field_name, []), mode, change_entry)
		return next_character

	if current_value is int or current_value is float or _is_computed_numeric_character_field(field_name) or field_name in ["x", "y", "z", "size", "width", "height"]:
		var before_hp = int(next_character.get("hp", 0))
		var current_numeric_value = int(next_character.get(field_name, 0))
		if value_source == "intent" and _is_computed_numeric_character_field(field_name) and mode in ["add", "subtract"]:
			if _fragment_has_computable_character_source(base_state, fragment_data):
				var computed_delta = _computed_character_numeric_delta(change_entry, fragment_data, base_state, next_character)
				next_character[field_name] = current_numeric_value + computed_delta if mode == "add" else current_numeric_value - computed_delta
			else:
				next_character[field_name] = _manual_apply_numeric_mode(current_numeric_value, mode, change_entry)
		else:
			next_character[field_name] = _manual_apply_numeric_mode(current_numeric_value, mode, change_entry)
		if field_name == "hp":
			next_character["hp"] = clampi(int(next_character.get("hp", 0)), 0, int(next_character.get("max_hp", 999)))
			var after_hp = int(next_character.get("hp", 0))
			var hp_delta = after_hp - before_hp
			if hp_delta != 0 and fragment_data.has("_visual_events"):
				fragment_data["_visual_events"].append({
					"type": "hp_delta",
					"target_id": str(next_character.get("id", "")),
					"hp_delta": hp_delta,
				})
		return next_character

	if _uses_bool_payload(field_name, current_value):
		next_character[field_name] = bool(change_entry.get("bool_value", false))
		return next_character

	var string_value: Variant = change_entry.get("string_value", null)
	next_character[field_name] = "" if string_value == null else str(string_value)
	return next_character


func _apply_generic_change_entry(current_container: Dictionary, change_entry: Dictionary) -> Dictionary:
	var next_container: Dictionary = current_container.duplicate(true)
	var field_name = str(change_entry.get("field", "")).strip_edges()
	if field_name.is_empty():
		return next_container
	if field_name == "battlefield_features":
		return next_container
	var mode = _normalized_change_mode(change_entry)
	var current_value: Variant = next_container.get(field_name, null)
	if _uses_string_array_payload(field_name, current_value):
		next_container[field_name] = _apply_string_array_mode(next_container.get(field_name, []), mode, change_entry)
	elif current_value is int or current_value is float:
		next_container[field_name] = _manual_apply_numeric_mode(int(next_container.get(field_name, 0)), mode, change_entry)
	elif _uses_bool_payload(field_name, current_value):
		next_container[field_name] = bool(change_entry.get("bool_value", false))
	else:
		var string_value: Variant = change_entry.get("string_value", null)
		next_container[field_name] = "" if string_value == null else str(string_value)
	return next_container


func _computed_character_numeric_delta(change_entry: Dictionary, fragment_data: Dictionary, base_state: Dictionary, target_character: Dictionary) -> int:
	var field_name = str(change_entry.get("field", "")).strip_edges()
	var source_character: Dictionary = _resolve_fragment_source_character(base_state, fragment_data)
	var source_stat = _source_stat_for_fragment(source_character, fragment_data)
	var amount = float(source_stat)
	if field_name == "hp" and _normalized_change_mode(change_entry) == "subtract":
		var defence_stat = _target_defence_stat_for_fragment(target_character, fragment_data)
		var defence_multiplier = DEFENCE_FORMULA_NUMERATOR / (DEFENCE_FORMULA_NUMERATOR + float(defence_stat) * DEFENCE_FORMULA_STAT_SCALE)
		amount *= defence_multiplier
		amount *= _combined_elemental_multiplier(fragment_data, target_character)
		if str(fragment_data.get("action_kind", "")).strip_edges().to_lower() == "attack":
			amount *= ATTACK_DAMAGE_RUNTIME_MULTIPLIER
	if field_name != "hp" and field_name != "max_hp":
		amount *= NON_HP_INTENT_SCALAR
	amount *= _effective_fragment_power_scale(fragment_data)
	return maxi(1, int(round(amount)))


func _source_stat_for_fragment(source_character: Dictionary, fragment_data: Dictionary) -> int:
	var action_kind = str(fragment_data.get("action_kind", "")).strip_edges().to_lower()
	var physical_or_magic = str(fragment_data.get("physical_or_magic", "")).strip_edges().to_lower()
	if physical_or_magic == "magic":
		return maxi(1, int(source_character.get("magic_power", 10)))
	if physical_or_magic == "physical":
		return maxi(1, int(source_character.get("physical_attack", 10)))
	if action_kind in ["support", "status", "create", "environment", "control"]:
		return maxi(1, int(source_character.get("magic_power", 10)))
	return maxi(1, maxi(int(source_character.get("physical_attack", 10)), int(source_character.get("magic_power", 10))))


func _target_defence_stat_for_fragment(target_character: Dictionary, fragment_data: Dictionary) -> int:
	var physical_or_magic = str(fragment_data.get("physical_or_magic", "")).strip_edges().to_lower()
	if physical_or_magic == "magic":
		return maxi(0, int(target_character.get("magic_defence", 0)))
	return maxi(0, int(target_character.get("physical_defence", 0)))


func _fragment_has_computable_character_source(state: Dictionary, fragment_data: Dictionary) -> bool:
	return not _resolve_fragment_source_character(state, fragment_data).is_empty()


func _resolve_fragment_source_character(state: Dictionary, fragment_data: Dictionary) -> Dictionary:
	var characters: Array = state.get("characters", []) if state.get("characters", []) is Array else []
	var source_id = _resolve_character_id(characters, str(fragment_data.get("source_id", "")))
	var source_index = _find_entity_index_by_id(characters, source_id)
	if source_index == -1:
		return {}
	return characters[source_index]


func _effective_fragment_power_scale(fragment_data: Dictionary) -> float:
	return _normalize_power_multiplier(fragment_data.get("power_multiplier", 1.0))


func _normalize_power_multiplier(raw_power_multiplier: Variant) -> float:
	if raw_power_multiplier is int or raw_power_multiplier is float:
		return clampf(float(raw_power_multiplier), 0.0, 12.0)
	return 1.0


func _combined_elemental_multiplier(fragment_data: Dictionary, target_character: Dictionary) -> float:
	var attack_elements: Array = _filtered_elements(fragment_data.get("elements", []))
	var defender_elements: Array = _filtered_elements(target_character.get("elements", []))
	if attack_elements.is_empty() or defender_elements.is_empty():
		return 1.0
	var multiplier = 1.0
	for attack_element_variant in attack_elements:
		var attack_element = str(attack_element_variant)
		for defender_element_variant in defender_elements:
			multiplier *= _elemental_pair_multiplier(attack_element, str(defender_element_variant))
	return multiplier


func _elemental_pair_multiplier(attack_element: String, defender_element: String) -> float:
	var attack_key = attack_element.strip_edges().to_lower()
	var defender_key = defender_element.strip_edges().to_lower()
	if not ELEMENT_TYPES.has(attack_key) or not ELEMENT_TYPES.has(defender_key):
		return 1.0
	var attack_map_variant: Variant = ELEMENTAL_INTERACTION_MAP.get(attack_key, {})
	if attack_map_variant is Dictionary:
		return float((attack_map_variant as Dictionary).get(defender_key, ELEMENTAL_DEFAULT_MULTIPLIER))
	return ELEMENTAL_DEFAULT_MULTIPLIER


func _manual_apply_numeric_mode(current_value: int, mode: String, change_entry: Dictionary) -> int:
	var amount = int(change_entry.get("int_value", 0) if change_entry.get("int_value", null) != null else 0)
	match mode:
		"add":
			return current_value + amount
		"subtract":
			return current_value - amount
		"set":
			return amount
		_:
			return current_value


func _apply_string_array_mode(current_value: Variant, mode: String, change_entry: Dictionary) -> Array:
	var result: Array = _string_array(current_value)
	var values: Array = _string_array(change_entry.get("string_list_value", []))
	match mode:
		"set":
			return values
		"append_unique":
			for value in values:
				if not result.has(value):
					result.append(value)
		"remove_items":
			for value in values:
				result.erase(value)
	return result


func _normalized_change_mode(change_entry: Dictionary) -> String:
	var mode = str(change_entry.get("mode", "set")).strip_edges().to_lower()
	if mode in ["set", "add", "subtract", "append_unique", "remove_items"]:
		return mode
	return "set"


func _normalized_change_value_source(change_entry: Dictionary) -> String:
	var value_source = str(change_entry.get("value_source", "manual")).strip_edges().to_lower()
	if value_source == "intent":
		return "intent"
	return "manual"


func _uses_string_array_payload(field_name: String, current_value: Variant) -> bool:
	return STRING_ARRAY_CHANGE_FIELDS.has(field_name) or current_value is Array


func _uses_bool_payload(_field_name: String, current_value: Variant) -> bool:
	return current_value is bool


func _is_computed_numeric_character_field(field_name: String) -> bool:
	return COMPUTED_NUMERIC_CHARACTER_FIELDS.has(field_name)



# Area filtering and positions


func _entity_is_within_fragment_area(_op_name: String, _op_id: String, entity_data: Dictionary, fragment_data: Dictionary) -> bool:
	var targeting_kind = str(fragment_data.get("targeting_kind", "none")).strip_edges().to_lower()
	if targeting_kind != "area":
		return true
	var area = _normalize_target_area(fragment_data.get("target_area", null))
	if area == null:
		return true
	var point: Vector3 = _entity_point_for_area(entity_data)
	var dx = abs(point.x - float(area.get("x", 0)))
	var dy = abs(point.y - float(area.get("y", 0)))
	var dz = abs(point.z - float(area.get("z", 0)))
	var radius = float(area.get("radius", 0))
	return max(dx, dy) <= radius and dz <= radius


func _entity_point_for_area(entity_data: Dictionary) -> Vector3:
	return Vector3(float(entity_data.get("x", 0)), float(entity_data.get("y", 0)), float(entity_data.get("z", 0)))


func _normalize_target_area(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var raw_area: Dictionary = value
	return {
		"x": int(raw_area.get("x", 0)),
		"y": int(raw_area.get("y", 0)),
		"z": int(raw_area.get("z", 0)),
		"radius": maxi(0, int(raw_area.get("radius", 0))),
	}



# Cost and multiplier histories


func _canonical_round_cost_action(action_text: String) -> String:
	var canonical = action_text.to_lower().strip_edges()
	for whitespace in [" ", "\n", "\r", "\t"]:
		canonical = canonical.replace(whitespace, "")
	return canonical


func _round_cost_cache_key(acting_side: String, action_text: String) -> String:
	return "%s|%s" % [acting_side, _canonical_round_cost_action(action_text)]


func _get_cached_round_cost_verdict(acting_side: String, action_text: String) -> Dictionary:
	var key = _round_cost_cache_key(acting_side, action_text)
	var cached: Variant = _round_cost_verdict_cache.get(key, null)
	if cached is Dictionary:
		return (cached as Dictionary).duplicate(true)
	return {}


func _store_round_cost_verdict(acting_side: String, action_text: String, verdict: Dictionary) -> void:
	_round_cost_verdict_cache[_round_cost_cache_key(acting_side, action_text)] = verdict.duplicate(true)


func _normalize_action_for_history(action_text: String) -> String:
	var normalized = action_text.to_lower()
	for marker in [",", ".", "!", "?", ";", ":", "(", ")", "[", "]", "{", "}", "\"", "'", "-", "_", "/", "\\", "\n", "\r", "\t"]:
		normalized = normalized.replace(marker, " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()


func _tokenize_action_for_history(action_text: String) -> Array:
	var normalized = _normalize_action_for_history(action_text)
	if normalized.is_empty():
		return []
	var tokens: Array = []
	var seen: Dictionary = {}
	for raw_part in normalized.split(" ", false):
		var token = raw_part.strip_edges()
		if token.length() < COST_VERDICT_MIN_TOKEN_LENGTH:
			continue
		if seen.has(token):
			continue
		seen[token] = true
		tokens.append(token)
	return tokens


func _record_cost_verdict(acting_side: String, action_text: String, verdict: Dictionary) -> void:
	var entry: Dictionary = verdict.duplicate(true)
	entry["acting_side"] = acting_side
	entry["normalized_action"] = _normalize_action_for_history(action_text)
	entry["action_words"] = _tokenize_action_for_history(action_text)
	if not _cost_verdict_history.is_empty():
		var last_entry_variant: Variant = _cost_verdict_history[_cost_verdict_history.size() - 1]
		if last_entry_variant is Dictionary:
			var last_entry: Dictionary = last_entry_variant
			if str(last_entry.get("acting_side", "")) == acting_side and str(last_entry.get("normalized_action", "")) == str(entry.get("normalized_action", "")) and int(last_entry.get("probability_cost", -1)) == int(entry.get("probability_cost", -2)) and str(last_entry.get("status", "")) == str(entry.get("status", "")):
				_cost_verdict_history[_cost_verdict_history.size() - 1] = entry
				return
	_cost_verdict_history.append(entry)
	while _cost_verdict_history.size() > COST_VERDICT_HISTORY_MAX:
		_cost_verdict_history.remove_at(0)


func _select_cost_verdict_history(acting_side: String, action_text: String) -> Array:
	return _select_history_entries(_cost_verdict_history, acting_side, action_text, COST_VERDICT_HISTORY_CONTEXT_LIMIT)


func _select_power_multiplier_verdict_history(team_a_action: String, team_b_action: String) -> Array:
	return _select_history_entries(_power_multiplier_verdict_history, "", "%s || %s" % [team_a_action, team_b_action], POWER_MULTIPLIER_VERDICT_HISTORY_CONTEXT_LIMIT)


func _select_history_entries(history: Array, acting_side: String, action_text: String, limit: int) -> Array:
	if history.is_empty():
		return []
	var normalized_action = _normalize_action_for_history(action_text)
	var action_words = _tokenize_action_for_history(action_text)
	var candidates: Array = []
	for i in range(history.size()):
		if not (history[i] is Dictionary):
			continue
		var entry: Dictionary = history[i]
		var score = _score_history_entry(entry, acting_side, normalized_action, action_words, i, history.size())
		if score > 0:
			candidates.append({"entry": entry, "score": score, "index": i})
	candidates.sort_custom(_compare_history_candidates)
	var selected: Array = []
	for candidate_variant in candidates:
		if selected.size() >= limit:
			break
		var candidate: Dictionary = candidate_variant
		selected.append((candidate.get("entry", {}) as Dictionary).duplicate(true))
	return selected


func _score_history_entry(entry: Dictionary, acting_side: String, normalized_action: String, action_words: Array, history_index: int, total_history_size: int) -> int:
	var entry_side = str(entry.get("acting_side", ""))
	var entry_normalized = str(entry.get("normalized_action", ""))
	var entry_words: Array = entry.get("action_words", []) if entry.get("action_words", []) is Array else []
	var exact_match = not normalized_action.is_empty() and entry_normalized == normalized_action
	var overlap = 0
	for token_variant in action_words:
		if entry_words.has(str(token_variant)):
			overlap += 1
	if not exact_match and overlap == 0 and entry_side != acting_side:
		return 0
	var score = overlap * 12
	score += total_history_size - history_index
	if entry_side == acting_side:
		score += 20
	if exact_match:
		score += 1000
	elif not normalized_action.is_empty() and (entry_normalized.contains(normalized_action) or normalized_action.contains(entry_normalized)):
		score += 60
	return score


func _compare_history_candidates(a: Dictionary, b: Dictionary) -> bool:
	var score_a = int(a.get("score", 0))
	var score_b = int(b.get("score", 0))
	if score_a == score_b:
		return int(a.get("index", 0)) > int(b.get("index", 0))
	return score_a > score_b


func _record_power_multiplier_verdicts(team_a_action: String, team_b_action: String, story_fragments: Array) -> void:
	var combined_action_text = "%s || %s" % [team_a_action.strip_edges(), team_b_action.strip_edges()]
	var normalized_action = _normalize_action_for_history(combined_action_text)
	var action_words = _tokenize_action_for_history(combined_action_text)
	for fragment_variant in story_fragments:
		if not (fragment_variant is Dictionary):
			continue
		var attrs: Dictionary = _fragment_attrs(fragment_variant)
		if attrs.is_empty():
			continue
		var mechanics: Dictionary = attrs.get("mechanics", {}) if attrs.get("mechanics", null) is Dictionary else {}
		var power_multiplier = float(mechanics.get("power_multiplier", 1.0))
		var update_reasoning = str(attrs.get("update_reasoning", "")).strip_edges()
		var action_kind = str(mechanics.get("action_kind", "")).strip_edges().to_lower()
		var physical_or_magic = str(mechanics.get("physical_or_magic", "")).strip_edges().to_lower()
		var text_effect = str(attrs.get("text_effect", "")).strip_edges().to_lower()
		var elements: Array = _filtered_elements(mechanics.get("elements", []))
		if is_equal_approx(power_multiplier, 1.0) and update_reasoning.is_empty() and action_kind.is_empty() and text_effect.is_empty():
			continue
		var entry = {
			"normalized_action": normalized_action,
			"action_words": action_words,
			"team_a_action": team_a_action,
			"team_b_action": team_b_action,
			"fragment_text": str((fragment_variant as Dictionary).get("text", "")),
			"text_effect": text_effect,
			"update_reasoning": update_reasoning,
			"action_kind": action_kind,
			"physical_or_magic": physical_or_magic,
			"elements": elements,
			"power_multiplier": power_multiplier,
		}
		_power_multiplier_verdict_history.append(entry)
		while _power_multiplier_verdict_history.size() > POWER_MULTIPLIER_VERDICT_HISTORY_MAX:
			_power_multiplier_verdict_history.remove_at(0)



# State normalization and lookup


func _normalize_game_state(value: Variant) -> Dictionary:
	var state: Dictionary = value if value is Dictionary else {}
	state["round_number"] = int(state.get("round_number", 1))
	state["phase"] = str(state.get("phase", "round_planning"))
	state["winner"] = str(state.get("winner", "None"))
	state["team_a_probability"] = int(state.get("team_a_probability", STARTING_PROBABILITY))
	state["team_b_probability"] = int(state.get("team_b_probability", STARTING_PROBABILITY))
	adjust_prob(STARTING_PROBABILITY, false)
	adjust_prob(STARTING_PROBABILITY, true)
	state["map_width"] = MAP_WIDTH
	state["map_height"] = MAP_HEIGHT
	state["map_name"] = str(state.get("map_name", "Unnamed Arena"))
	state["visual_theme"] = str(state.get("visual_theme", BATTLE_STYLE))
	state["characters"] = _normalize_character_array(state.get("characters", []))
	state["objects"] = _normalize_object_array(state.get("objects", []))
	state["ongoing_effects"] = _string_array(state.get("ongoing_effects", []))
	state["recent_round_history"] = _string_array(state.get("recent_round_history", []))
	state["other_important_notes"] = _string_array(state.get("other_important_notes", []))
	var battlefield: Dictionary = state.get("battlefield", {}) if state.get("battlefield", {}) is Dictionary else {}
	battlefield["terrain"] = str(battlefield.get("terrain", "open arena"))
	battlefield["visibility"] = str(battlefield.get("visibility", "clear"))
	battlefield["battlefield_features"] = _normalize_battlefield_feature_array(battlefield.get("battlefield_features", []))
	battlefield["environmental_notes"] = _string_array(battlefield.get("environmental_notes", []))
	state["battlefield"] = battlefield
	state["battle_conclusion"] = str(state.get("battle_conclusion", ""))
	return state


func _normalize_character_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var character = _normalize_character_state(item)
			if not character.is_empty():
				result.append(character)
	return result


func _normalize_object_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var object_data = _normalize_object_state(item)
			if not object_data.is_empty():
				result.append(object_data)
	return result


func _normalize_battlefield_feature_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var feature = _normalize_battlefield_feature_state(item)
			if not feature.is_empty():
				result.append(feature)
	return result


func _normalize_character_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var character: Dictionary = (value as Dictionary).duplicate(true)
	character["id"] = _canonical_character_id(str(character.get("id", "")))
	if str(character.get("id", "")).is_empty():
		return {}
	character["display_name"] = str(character.get("display_name", character.get("name", "Unknown")))
	character["nouns"] = _string_array(character.get("nouns", []))
	character["adjectives"] = _string_array(character.get("adjectives", []))
	character["elements"] = _filtered_elements(character.get("elements", []))
	character["side"] = _normalized_side(str(character.get("side", "Neutral")))
	var max_hp = maxi(1, int(character.get("max_hp", 100)))
	character["max_hp"] = max_hp
	character["hp"] = clampi(int(character.get("hp", max_hp)), 0, max_hp)
	character["physical_attack"] = int(character.get("physical_attack", 10))
	character["physical_defence"] = int(character.get("physical_defence", 10))
	character["magic_power"] = int(character.get("magic_power", 10))
	character["magic_defence"] = int(character.get("magic_defence", 10))
	character["speed"] = int(character.get("speed", 10))
	character["size"] = maxi(0, int(character.get("size", 2)))
	character["status_effects"] = _string_array(character.get("status_effects", []))
	character["important_notes"] = _string_array(character.get("important_notes", []))
	character["x"] = clampi(int(character.get("x", 0)), 0, MAP_WIDTH - 1)
	character["y"] = clampi(int(character.get("y", 0)), 0, MAP_HEIGHT - 1)
	character["z"] = maxi(0, int(character.get("z", 0)))
	character["position_label"] = str(character.get("position_label", character.get("position", "")))
	var raw_attachment_id: Variant = character.get("attached_to_character_id", null)
	character["attached_to_character_id"] = _canonical_character_id(str(raw_attachment_id).strip_edges()) if raw_attachment_id != null else ""
	character["attachment_mode"] = _normalized_attachment_mode(str(character.get("attachment_mode", "")), str(character.get("attached_to_character_id", "")))
	character.erase("position")
	character.erase("name")
	return character


func _normalize_object_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var object_data: Dictionary = (value as Dictionary).duplicate(true)
	object_data["id"] = str(object_data.get("id", ""))
	if str(object_data.get("id", "")).is_empty():
		return {}
	object_data["name"] = str(object_data.get("name", object_data["id"]))
	object_data["controller"] = _normalized_side(str(object_data.get("controller", "Neutral")))
	object_data["state"] = _string_array(object_data.get("state", []))
	object_data["x"] = clampi(int(object_data.get("x", 0)), 0, MAP_WIDTH - 1)
	object_data["y"] = clampi(int(object_data.get("y", 0)), 0, MAP_HEIGHT - 1)
	object_data["z"] = maxi(0, int(object_data.get("z", 0)))
	object_data["size"] = maxi(1, int(object_data.get("size", object_data.get("width", 1))))
	object_data["location_label"] = str(object_data.get("location_label", object_data.get("location", "")))
	var raw_attachment_id: Variant = object_data.get("attached_to_character_id", null)
	object_data["attached_to_character_id"] = _canonical_character_id(str(raw_attachment_id).strip_edges()) if raw_attachment_id != null else ""
	object_data["attachment_mode"] = _normalized_attachment_mode(str(object_data.get("attachment_mode", "")), str(object_data.get("attached_to_character_id", "")))
	object_data.erase("width")
	object_data.erase("height")
	object_data.erase("location")
	return object_data


func _normalize_battlefield_feature_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var feature: Dictionary = (value as Dictionary).duplicate(true)
	feature["id"] = str(feature.get("id", ""))
	if str(feature.get("id", "")).is_empty():
		return {}
	feature["name"] = str(feature.get("name", feature["id"]))
	feature["feature_kind"] = str(feature.get("feature_kind", "effect")).strip_edges().to_lower()
	if not ["hazard", "zone", "terrain_feature", "effect"].has(feature["feature_kind"]):
		feature["feature_kind"] = "effect"
	feature["controller"] = _normalized_side(str(feature.get("controller", "Neutral")))
	feature["state"] = _string_array(feature.get("state", []))
	feature["x"] = clampi(int(feature.get("x", 0)), 0, MAP_WIDTH - 1)
	feature["y"] = clampi(int(feature.get("y", 0)), 0, MAP_HEIGHT - 1)
	feature["z"] = maxi(0, int(feature.get("z", 0)))
	feature["width"] = maxi(1, int(feature.get("width", 1)))
	feature["height"] = maxi(1, int(feature.get("height", 1)))
	feature["location_label"] = str(feature.get("location_label", feature.get("location", "")))
	feature.erase("location")
	return feature


func _repair_initialized_state_characters(initialized_state_variant: Variant, initializer_characters: Array, map_width: int, map_height: int) -> Dictionary:
	var initialized_state: Dictionary = initialized_state_variant.duplicate(true) if initialized_state_variant is Dictionary else {}
	var incoming: Array = initialized_state.get("characters", []) if initialized_state.get("characters", []) is Array else []
	var by_id: Dictionary = {}
	for character_variant in incoming:
		if character_variant is Dictionary:
			var raw: Dictionary = character_variant
			var char_id = _canonical_character_id(str(raw.get("id", "")))
			if not char_id.is_empty():
				raw["id"] = char_id
				by_id[char_id] = raw

	var repaired: Array = []
	var side_indices = {"Team A": 0, "Team B": 0, "Neutral": 0}
	for starting_variant in initializer_characters:
		if not (starting_variant is Dictionary):
			continue
		var starting_character: Dictionary = starting_variant.duplicate(true)
		var char_id = _canonical_character_id(str(starting_character.get("id", "")))
		if char_id.is_empty():
			continue
		starting_character["id"] = char_id
		var side = _normalized_side(str(starting_character.get("side", "Neutral")))
		var side_index = int(side_indices.get(side, 0))
		side_indices[side] = side_index + 1
		var merged: Dictionary = starting_character.duplicate(true)
		if by_id.has(char_id):
			var init_character: Dictionary = by_id[char_id]
			for key in init_character.keys():
				merged[key] = init_character[key]
		if not merged.has("x") or not merged.has("y") or not merged.has("z") or str(merged.get("position_label", "")).strip_edges().is_empty():
			merged = _apply_default_position_to_character(merged, side_index, map_width, map_height)
		repaired.append(merged)
	initialized_state["characters"] = repaired
	initialized_state.erase("team_a")
	initialized_state.erase("team_b")
	return initialized_state


func _apply_default_position_to_character(character: Dictionary, side_index: int, map_width: int, map_height: int) -> Dictionary:
	var next_character: Dictionary = character.duplicate(true)
	var team_a_spawns = [
		{"x": 3, "y": 12, "z": 0, "position_label": "southwest lane"},
		{"x": 2, "y": 9, "z": 0, "position_label": "west-central lane"},
		{"x": 5, "y": 13, "z": 0, "position_label": "southern support line"},
	]
	var team_b_spawns = [
		{"x": 12, "y": 3, "z": 0, "position_label": "northeast lane"},
		{"x": 13, "y": 6, "z": 0, "position_label": "east-central lane"},
		{"x": 10, "y": 2, "z": 0, "position_label": "northern support line"},
	]
	var side = str(next_character.get("side", "Neutral"))
	var source = team_a_spawns if side == "Team A" else team_b_spawns
	var chosen: Dictionary = source[clampi(side_index, 0, source.size() - 1)]
	next_character["x"] = clampi(int(chosen.get("x", 0)), 0, map_width - 1)
	next_character["y"] = clampi(int(chosen.get("y", 0)), 0, map_height - 1)
	next_character["z"] = maxi(0, int(chosen.get("z", 0)))
	next_character["position_label"] = str(chosen.get("position_label", ""))
	return next_character


func _normalized_side(side: String) -> String:
	var s = side.strip_edges()
	if s == "Team A" or s == "Team B" or s == "Neutral":
		return s
	return "Neutral"


func _normalized_attachment_mode(mode: String, parent_id: String) -> String:
	var m = mode.strip_edges().to_lower()
	if parent_id.strip_edges().is_empty():
		return ""
	if m in ["carried", "equipped", "mounted", "in_inventory", "stashed"]:
		return m
	return ""


func _canonical_character_id(raw_id: String) -> String:
	var char_id = raw_id.strip_edges()
	if char_id.begins_with("a_") or char_id.begins_with("b_"):
		return char_id.substr(2)
	return char_id


func _resolve_character_id(characters: Array, raw_id: String) -> String:
	var target = _canonical_character_id(raw_id)
	if _find_entity_index_by_id(characters, target) != -1:
		return target
	return target


func _find_entity_index_by_id(items: Array, id: String) -> int:
	for i in range(items.size()):
		if items[i] is Dictionary and str((items[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _remove_entity_by_id(items: Array, id: String) -> void:
	for i in range(items.size() - 1, -1, -1):
		if items[i] is Dictionary and str((items[i] as Dictionary).get("id", "")) == id:
			items.remove_at(i)


func _existing_ids(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		if item is Dictionary:
			result[str((item as Dictionary).get("id", ""))] = true
	return result


func _generate_unique_runtime_id(existing_ids: Dictionary, requested_id: String, fallback_prefix: String) -> String:
	var base = requested_id.strip_edges()
	if base.is_empty():
		base = fallback_prefix
	base = base.to_lower().replace(" ", "_")
	var candidate = base
	var i = 2
	while existing_ids.has(candidate):
		candidate = "%s_%d" % [base, i]
		i += 1
	existing_ids[candidate] = true
	return candidate


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text = str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


func _filtered_elements(value: Variant) -> Array:
	var result: Array = []
	for element in _string_array(value):
		var normalized = element.to_lower()
		if ELEMENT_TYPES.has(normalized) and not result.has(normalized):
			result.append(normalized)
	return result



# Map API stubs


func redraw_tokens() -> void:
	if map_manager != null and map_manager.has_method("redraw_tokens"):
		map_manager.redraw_tokens(game_state)
		return
	print("TODO map.redraw_tokens(game_state)")


func spawn_token(entity: Dictionary) -> void:
	if map_manager != null and map_manager.has_method("spawn_token"):
		map_manager.spawn_token(entity)
		return
	print("TODO map.spawn_token: ", entity.get("id", ""))


func remove_token(entity_id: String) -> void:
	if map_manager != null and map_manager.has_method("remove_token"):
		map_manager.remove_token(entity_id)
		return
	print("TODO map.remove_token: ", entity_id)


func redraw_token(entity_id: String) -> void:
	if map_manager != null and map_manager.has_method("redraw_token"):
		map_manager.redraw_token(entity_id, game_state)
		return
	print("TODO map.redraw_token: ", entity_id)


func move_token(entity_id: String, x: int, y: int, z: int = 0) -> void:
	if map_manager != null and map_manager.has_method("move_token"):
		map_manager.move_token(entity_id, x, y, z)
		return
	print("TODO map.move_token: %s -> (%d, %d, %d)" % [entity_id, x, y, z])


func attach_tokens(child_id: String, parent_id: String, attachment_mode: String) -> void:
	if map_manager != null and map_manager.has_method("attach_tokens"):
		map_manager.attach_tokens(child_id, parent_id, attachment_mode)
		return
	print("TODO map.attach_tokens: %s -> %s mode=%s" % [child_id, parent_id, attachment_mode])


func detach_token(child_id: String) -> void:
	if map_manager != null and map_manager.has_method("detach_token"):
		map_manager.detach_token(child_id)
		return
	print("TODO map.detach_token: ", child_id)


func trigger_attack(source_id: String, target_ids: Array, effect: String = "hit", hp_delta: int = 0) -> void:
	if map_manager != null and map_manager.has_method("trigger_attack"):
		map_manager.trigger_attack(source_id, target_ids, effect, hp_delta)
		return

	print("TODO map.trigger_attack: ", source_id, " -> ", target_ids, " effect=", effect, " hp_delta=", hp_delta)

func trigger_effect_at(x: int, y: int, z: int, effect: String) -> void:
	if map_manager != null and map_manager.has_method("trigger_effect_at"):
		map_manager.trigger_effect_at(x, y, z, effect)
		return
	print("TODO map.trigger_effect_at: (%d, %d, %d) %s" % [x, y, z, effect])


func spawn_battlefield_feature(feature: Dictionary) -> void:
	if map_manager != null and map_manager.has_method("spawn_battlefield_feature"):
		map_manager.spawn_battlefield_feature(feature)
		return
	print("TODO map.spawn_battlefield_feature: ", feature.get("id", ""))


func remove_battlefield_feature(feature_id: String) -> void:
	if map_manager != null and map_manager.has_method("remove_battlefield_feature"):
		map_manager.remove_battlefield_feature(feature_id)
		return
	print("TODO map.remove_battlefield_feature: ", feature_id)


func redraw_battlefield_features() -> void:
	if map_manager != null and map_manager.has_method("redraw_battlefield_features"):
		map_manager.redraw_battlefield_features(game_state)
		return
	print("TODO map.redraw_battlefield_features")


func _update_token_from_entity(entity: Dictionary) -> void:
	if entity.is_empty():
		return
	if entity.has("x") and entity.has("y"):
		move_token(str(entity.get("id", "")), int(entity.get("x", 0)), int(entity.get("y", 0)), int(entity.get("z", 0)))
	redraw_token(str(entity.get("id", "")))


func _sync_token_attachments() -> void:
	for character in game_state.get("characters", []):
		if character is Dictionary:
			_sync_single_token_attachment(character)
	for object_data in game_state.get("objects", []):
		if object_data is Dictionary:
			_sync_single_token_attachment(object_data)


func _sync_single_token_attachment(entity: Dictionary) -> void:
	var child_id = str(entity.get("id", ""))
	var parent_id = str(entity.get("attached_to_character_id", ""))
	var mode = str(entity.get("attachment_mode", ""))
	if child_id.is_empty():
		return
	if parent_id.is_empty() or mode.is_empty():
		detach_token(child_id)
		return
	attach_tokens(child_id, parent_id, mode)


func _apply_fragment_visual_stubs(fragment_data: Dictionary) -> void:
	var effect = str(fragment_data.get("text_effect", "hit"))
	if effect.is_empty():
		effect = "hit"
	var source_id = str(fragment_data.get("source_id", ""))
	var target_ids: Array = fragment_data.get("target_ids", []) if fragment_data.get("target_ids", []) is Array else []
	var hp_delta_by_target: Dictionary = {}

	for event_variant in fragment_data.get("_visual_events", []):
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		if str(event.get("type", "")) != "hp_delta":
			continue
		var target_id = str(event.get("target_id", ""))
		if target_id.is_empty():
			continue
		hp_delta_by_target[target_id] = int(hp_delta_by_target.get(target_id, 0)) + int(event.get("hp_delta", 0))

	if not source_id.is_empty() and not target_ids.is_empty():
		for target_id_variant in target_ids:
			var target_id = str(target_id_variant)
			var hp_delta = int(hp_delta_by_target.get(target_id, 0))
			trigger_attack(source_id, [target_id], effect, hp_delta)




# Initialiser TTS

func _start_initialiser_tts(text: String) -> void:
	if not enable_initialiser_tts:
		return
	var trimmed_text = text.strip_edges()
	if trimmed_text.is_empty():
		return
	if not ElevenlabsClient.has_api_key():
		push_warning("Initialiser TTS skipped: missing ElevenLabs API key. Create user://elevenlabs_api_key.txt")
		return

	_initialiser_tts_request_id += 1
	var request_id = _initialiser_tts_request_id
	_run_initialiser_tts(request_id, trimmed_text)


func _run_initialiser_tts(request_id: int, text: String) -> void:
	var voice_id = _ensure_selected_initialiser_tts_voice_id()
	if voice_id.is_empty():
		push_warning("Initialiser TTS skipped: missing ElevenLabs voice id.")
		return

	var cache_path = _initialiser_tts_cache_path(text, voice_id)
	if FileAccess.file_exists(cache_path):
		var cached_file = FileAccess.open(cache_path, FileAccess.READ)
		if cached_file != null:
			_start_initialiser_tts_pcm_stream()
			_queue_initialiser_tts_pcm_bytes(cached_file.get_buffer(cached_file.get_length()))
			cached_file.close()
			return

	_start_initialiser_tts_pcm_stream()
	var result: Dictionary = await ElevenlabsClient.stream_speech(
		text,
		voice_id,
		elevenlabs_model_id,
		elevenlabs_output_format,
		Callable(self, "_on_initialiser_tts_chunk").bind(request_id),
		elevenlabs_voice_speed
	)
	if request_id != _initialiser_tts_request_id:
		return
	if result.has("error"):
		push_warning("Initialiser TTS failed: %s" % str(result.get("error", "Unknown error")))
		return
	var bytes: PackedByteArray = result.get("bytes", PackedByteArray())
	if not bytes.is_empty():
		_save_initialiser_tts_cache_bytes(cache_path, bytes)


func _stop_initialiser_tts() -> void:
	_initialiser_tts_request_id += 1
	if is_instance_valid(_initialiser_tts_player):
		_initialiser_tts_player.stop()
		_initialiser_tts_player.stream = null
	_initialiser_tts_playback = null
	_initialiser_tts_pending_frames.clear()
	_initialiser_tts_pcm_remainder = PackedByteArray()


func _ensure_initialiser_tts_player() -> void:
	if is_instance_valid(_initialiser_tts_player):
		return
	var player = AudioStreamPlayer.new()
	player.name = "InitialiserTtsPlayer"
	player.bus = "Master"
	player.volume_db = initialiser_tts_volume_db
	add_child(player)
	_initialiser_tts_player = player


func _start_initialiser_tts_pcm_stream() -> void:
	_ensure_initialiser_tts_player()
	if not is_instance_valid(_initialiser_tts_player):
		return
	_initialiser_tts_pending_frames.clear()
	_initialiser_tts_pcm_remainder = PackedByteArray()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = initialiser_tts_mix_rate
	stream.buffer_length = initialiser_tts_buffer_length
	_initialiser_tts_player.stream = stream
	_initialiser_tts_player.volume_db = initialiser_tts_volume_db
	_initialiser_tts_player.play()
	var playback_variant: Variant = _initialiser_tts_player.get_stream_playback()
	_initialiser_tts_playback = playback_variant as AudioStreamGeneratorPlayback


func _on_initialiser_tts_chunk(chunk: PackedByteArray, request_id: int) -> void:
	if request_id != _initialiser_tts_request_id:
		return
	_queue_initialiser_tts_pcm_bytes(chunk)


func _queue_initialiser_tts_pcm_bytes(chunk: PackedByteArray) -> void:
	if chunk.is_empty():
		return
	var combined = PackedByteArray()
	if not _initialiser_tts_pcm_remainder.is_empty():
		combined.append_array(_initialiser_tts_pcm_remainder)
	combined.append_array(chunk)
	var usable_size = combined.size() - (combined.size() % 2)
	_initialiser_tts_pcm_remainder = PackedByteArray()
	if usable_size < combined.size():
		_initialiser_tts_pcm_remainder.append(combined[combined.size() - 1])
	var offset = 0
	while offset < usable_size:
		var frame_count = mini(1024, int((usable_size - offset) / 2.0))
		var frames = PackedVector2Array()
		frames.resize(frame_count)
		for frame_index in range(frame_count):
			var lo = int(combined[offset])
			var hi = int(combined[offset + 1])
			var sample = lo | (hi << 8)
			if sample >= 32768:
				sample -= 65536
			var amplitude = clampf(float(sample) / 32768.0, -1.0, 1.0)
			frames[frame_index] = Vector2(amplitude, amplitude)
			offset += 2
		_initialiser_tts_pending_frames.append(frames)


func _drain_initialiser_tts_frames() -> void:
	if _initialiser_tts_playback == null:
		return
	while not _initialiser_tts_pending_frames.is_empty():
		var frames_variant: Variant = _initialiser_tts_pending_frames[0]
		if not (frames_variant is PackedVector2Array):
			_initialiser_tts_pending_frames.remove_at(0)
			continue
		var frames = frames_variant as PackedVector2Array
		if not _initialiser_tts_playback.can_push_buffer(frames.size()):
			return
		_initialiser_tts_playback.push_buffer(frames)
		_initialiser_tts_pending_frames.remove_at(0)


func _pick_random_initialiser_tts_voice_id() -> String:
	if elevenlabs_initializer_voice_ids.is_empty():
		return ""
	return str(elevenlabs_initializer_voice_ids[randi() % elevenlabs_initializer_voice_ids.size()]).strip_edges()


func _ensure_selected_initialiser_tts_voice_id() -> String:
	if not elevenlabs_voice_id.strip_edges().is_empty():
		return elevenlabs_voice_id.strip_edges()
	if _selected_initialiser_tts_voice_id.is_empty():
		_selected_initialiser_tts_voice_id = _pick_random_initialiser_tts_voice_id()
	return _selected_initialiser_tts_voice_id


func _initialiser_tts_cache_path(text: String, voice_id: String) -> String:
	var cache_seed = "initialiser_tts:\nvoice:%s\nmodel:%s\nformat:%s\nspeed:%s\ntext:%s" % [
		voice_id,
		elevenlabs_model_id,
		elevenlabs_output_format,
		str(elevenlabs_voice_speed),
		text,
	]
	return "%s/%s.%s" % [
		initialiser_tts_cache_dir,
		cache_seed.sha256_text(),
		_elevenlabs_output_extension(elevenlabs_output_format),
	]


func _save_initialiser_tts_cache_bytes(cache_path: String, bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return
	var absolute_path = ProjectSettings.globalize_path(cache_path)
	var dir_path = absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_err = DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_err != OK:
			push_warning("Failed to create initialiser TTS cache dir: %s" % dir_path)
			return
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open initialiser TTS cache file for writing: %s" % cache_path)
		return
	file.store_buffer(bytes)
	file.close()


func _elevenlabs_output_extension(output_format: String) -> String:
	var fmt = output_format.to_lower()
	if fmt.begins_with("pcm"):
		return "pcm"
	if fmt.begins_with("mp3"):
		return "mp3"
	if fmt.begins_with("ulaw"):
		return "ulaw"
	if fmt.begins_with("alaw"):
		return "alaw"
	return "pcm"


# OpenAI calls


func _call_initializer(initialiser_input: Dictionary) -> Dictionary:
	var initialiser_prompt = DataUtils.load_prompt_text("res://prompts/initialiser.txt")
	return await OpenaiClient.call_structured(
		{},
		initialiser_input,
		"battle_initializer",
		INITIALIZER_OUTPUT_SCHEMA,
		initialiser_prompt,
		"gpt-5.4-mini",
		"medium"
	)


func _call_cost_judge(side: String, action: String) -> Dictionary:
	var input_obj = {
		"recent_verdict_history": _select_cost_verdict_history(side, action),
		"acting_side": side,
		"proposed_action": action,
		"game_state": game_state,
		"allowed_elements": ELEMENT_TYPES,
	}
	var cost_prompt = DataUtils.load_prompt_text("res://prompts/cost-judge.txt")
	return await OpenaiClient.call_structured(
		{},
		input_obj,
		"cost_judge",
		COST_OUTPUT_SCHEMA,
		cost_prompt,
		MODEL,
		COST_JUDGE_REASONING_EFFORT
	)


func _call_team_b_action() -> Dictionary:
	var input_obj = {
		"side": "Team B",
		"game_state": game_state,
		"recent_team_a_action": last_team_a_action,
		"team_b_probability": int(game_state.get("team_b_probability", 0)),
		"allowed_elements": ELEMENT_TYPES,
	}
	var team_b_prompt = DataUtils.load_prompt_text("res://prompts/enemy-ai.txt")
	return await OpenaiClient.call_structured(
		{},
		input_obj,
		"team_b_action",
		TEAM_B_OUTPUT_SCHEMA,
		team_b_prompt,
		"gpt-5.4-mini",
		"low"
	)


func _call_narrator_resolution(narrator_input: Dictionary, on_field: Callable) -> Dictionary:
	var narrator_prompt = DataUtils.load_prompt_text("res://prompts/narrator.txt")
	return await OpenaiClient.call_structured_streaming(
		{},
		narrator_input,
		"narrator_resolution",
		NARRATOR_OUTPUT_SCHEMA,
		[],
		["story_fragments"],
		on_field,
		Callable(),
		narrator_prompt,
		NARRATOR_MODEL,
		NARRATOR_REASONING_EFFORT
	)


func _fallback_team_b_cost() -> Dictionary:
	return {
		"short_player_summary": "Team B takes a simple safe action.",
		"probability_cost": 1,
		"cost_band": "easy",
		"status": "playable",
		"cheaper_alternative": "",
	}

func _team_b_cost_fallback(judged_cost: Dictionary, team_b_probability: int) -> Dictionary:
	var cheaper_alternative = str(judged_cost.get("cheaper_alternative", "")).strip_edges()

	if cheaper_alternative.is_empty():
		return {
			"action": "Team B takes a simple guarded stance.",
			"cost": {
				"probability_cost": 1,
				"cost_band": "easy",
				"status": "playable",
				"short_player_summary": "",
				"cheaper_alternative": "",
			},
		}

	var original_cost = maxi(1, int(judged_cost.get("probability_cost", 1)))
	var fallback_cost = mini(
		team_b_probability,
		mini(int(floor(float(original_cost) * 0.5)), 5)
	)
	fallback_cost = maxi(1, fallback_cost)

	return {
		"action": cheaper_alternative,
		"cost": {
			"probability_cost": fallback_cost,
			"cost_band": "easy",
			"status": "playable",
			"short_player_summary": "Fallback to the cost judge's cheaper alternative for Team B.",
			"cheaper_alternative": "",
		},
	}


func adjust_prob(amount: int, is_player: bool):
	if is_player:
		player_prob += amount
		player_prob_changed.emit(player_prob)
	else:
		opp_prob += amount;
		opp_prob_changed.emit(opp_prob)

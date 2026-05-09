extends Node

const WritingRichTextEffectScript = preload("res://scripts/writing_rich_text_effect.gd")
const FireballRichTextEffectScript = preload("res://scripts/fireball_rich_text_effect.gd")
const GlowRichTextEffectScript = preload("res://scripts/glow_rich_text_effect.gd")
const SemanticRichTextEffectScript = preload("res://scripts/semantic_rich_text_effect.gd")

@export var font_library: FontLibrary

const SEMANTIC_EFFECTS: Array[String] = [
	# elements
	"fire",
	"ice",
	"lightning",
	"water",
	"plant",
	"earth",
	"light",
	"dark",
	"air",

	# actions
	"hit",
	"move",
]

const PRESET_WRITING_DEFAULT := {
	"effect_name": "writing",
	"params": {
		"settle": 0.85,
	},
}

const PRESET_WRITING_ACTION := {
	"effect_name": "writing",
	"params": {
		"settle": 1.4,
		"lift": 1.7,
		"glow": 0.8,
	},
}

const PRESET_WRITING_NARRATOR := {
	"effect_name": "writing",
	"params": {
		"settle": 1.45,
		"lift": 2.0,
		"glow": 2.0,
		"drop": 2.8,
		"tail_decay": 1.08,
		"tail_strength": 1.2,
	},
}

const PRESET_WRITING_STAMP := {
	"effect_name": "writing",
	"params": {
		"settle": 1.45,
		"lift": 0.65,
		"glow": 2.0,
		"tail_decay": 1.08,
		"tail_strength": 1.2,
	},
}


func ensure_installed(rtl: RichTextLabel) -> void:
	if not is_instance_valid(rtl):
		return

	if bool(rtl.get_meta("text_effects_installed", false)):
		return

	rtl.install_effect(WritingRichTextEffectScript.new())
	rtl.install_effect(FireballRichTextEffectScript.new())
	rtl.install_effect(GlowRichTextEffectScript.new())

	for effect_name in SEMANTIC_EFFECTS:
		var effect := SemanticRichTextEffectScript.new()
		effect.bbcode = effect_name
		rtl.install_effect(effect)

	rtl.set_meta("text_effects_installed", true)


func writing_default() -> Dictionary:
	return PRESET_WRITING_DEFAULT.duplicate(true)


func writing_action() -> Dictionary:
	return PRESET_WRITING_ACTION.duplicate(true)


func writing_narrator() -> Dictionary:
	return PRESET_WRITING_NARRATOR.duplicate(true)


func writing_stamp() -> Dictionary:
	return PRESET_WRITING_STAMP.duplicate(true)


func semantic(effect_name: String, params: Dictionary = {}) -> Dictionary:
	return {
		"effect_name": effect_name,
		"params": params.duplicate(true),
	}


func effect_name_from_preset(preset: Dictionary) -> String:
	return str(preset.get("effect_name", ""))


func effect_params_from_preset(preset: Dictionary) -> String:
	var params_variant: Variant = preset.get("params", {})
	var params: Dictionary = params_variant if params_variant is Dictionary else {}

	if params.is_empty():
		return ""

	var keys := params.keys()
	keys.sort()

	var parts: Array[String] = []
	for key_variant in keys:
		var key := str(key_variant)
		var value_variant: Variant = params.get(key_variant)
		parts.append("%s=%s" % [key, _format_param_value(value_variant)])

	return " ".join(parts)


func wrap_character(
	char_text: String,
	effect_name: String,
	effect_params: String = ""
) -> String:
	var font_path := _font_path_for_effect(effect_name)
	return wrap_character_with_font_path(char_text, effect_name, effect_params, font_path)


func wrap_text(
	text: String,
	effect_name: String,
	effect_params: String = ""
) -> String:
	var font_path := _font_path_for_effect(effect_name)
	return wrap_text_with_font_path(text, effect_name, effect_params, font_path)


func wrap_preset_character(char_text: String, preset: Dictionary) -> String:
	return wrap_character(
		char_text,
		effect_name_from_preset(preset),
		effect_params_from_preset(preset)
	)


func wrap_preset_text(text: String, preset: Dictionary) -> String:
	return wrap_text(
		text,
		effect_name_from_preset(preset),
		effect_params_from_preset(preset)
	)


func wrap_character_with_font_path(
	char_text: String,
	effect_name: String,
	effect_params: String = "",
	font_path: String = ""
) -> String:
	var escaped := escape_bbcode_text(char_text)

	if whitespace_only(char_text):
		return escaped

	var styled_text := escaped

	if not font_path.is_empty():
		styled_text = "[font=%s]%s[/font]" % [font_path, styled_text]

	if effect_name.is_empty():
		return styled_text

	if effect_params.is_empty():
		return "[%s]%s[/%s]" % [effect_name, styled_text, effect_name]

	return "[%s %s]%s[/%s]" % [
		effect_name,
		effect_params,
		styled_text,
		effect_name,
	]


func wrap_text_with_font_path(
	text: String,
	effect_name: String,
	effect_params: String = "",
	font_path: String = ""
) -> String:
	var parts: Array[String] = []

	for idx in range(text.length()):
		parts.append(
			wrap_effect_character_only(
				text.substr(idx, 1),
				effect_name,
				effect_params
			)
		)

	var wrapped := "".join(parts)

	if not font_path.is_empty():
		wrapped = "[font=%s]%s[/font]" % [font_path, wrapped]

	return wrapped


func wrap_effect_character_only(
	char_text: String,
	effect_name: String,
	effect_params: String = ""
) -> String:
	var escaped := escape_bbcode_text(char_text)

	if whitespace_only(char_text):
		return escaped

	if effect_name.is_empty():
		return escaped

	if effect_params.is_empty():
		return "[%s]%s[/%s]" % [effect_name, escaped, effect_name]

	return "[%s %s]%s[/%s]" % [
		effect_name,
		effect_params,
		escaped,
		effect_name,
	]


func wrap_glow(
	text: String,
	color: Color,
	settle: float = 1.45,
	decay: float = 1.08
) -> String:
	var escaped := escape_bbcode_text(text)

	return "[glow r=%s g=%s b=%s settle=%s decay=%s]%s[/glow]" % [
		_format_param_value(color.r),
		_format_param_value(color.g),
		_format_param_value(color.b),
		_format_param_value(settle),
		_format_param_value(decay),
		escaped,
	]


func wrap_font_size(text: String, size: int) -> String:
	return "[font_size=%d]%s[/font_size]" % [size, text]


func wrap_color(text: String, color: Color) -> String:
	return "[color=%s]%s[/color]" % [color.to_html(), text]


func escape_bbcode_text(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func whitespace_only(char_text: String) -> bool:
	return char_text == " " or char_text == "\n" or char_text == "\t"


func _font_path_for_effect(effect_name: String) -> String:
	if font_library == null:
		return ""

	return font_library.get_font_path(effect_name)


func _format_param_value(value: Variant) -> String:
	if value is float:
		var as_float := float(value)
		if is_equal_approx(as_float, round(as_float)):
			return str(int(round(as_float)))
		return str(as_float)

	return str(value)

extends Resource
class_name FontLibrary

@export var use_system_fonts_when_missing := true

# Elements
@export var fire_font: Font
@export var ice_font: Font
@export var lightning_font: Font
@export var water_font: Font
@export var plant_font: Font
@export var earth_font: Font
@export var light_font: Font
@export var dark_font: Font
@export var air_font: Font

# Actions
@export var hit_font: Font
@export var move_font: Font

# Other
@export var runes_font: Font
@export var dropcap_font: Font
@export var narrator_font: Font
@export var default_font: Font


const SYSTEM_FONT_NAMES := {
	"default": ["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman"],

	"fire": ["Copperplate Gothic Bold", "Perpetua Titling MT", "Georgia"],
	"ice": ["Cambria", "Constantia", "Georgia"],
	"lightning": ["Copperplate Gothic Bold", "Perpetua Titling MT", "Cambria"],
	"water": ["Georgia", "Cambria", "Times New Roman"],
	"plant": ["Gabriola", "Segoe Script", "Palatino Linotype", "Georgia"],
	"earth": ["Rockwell", "Georgia", "Cambria"],
	"light": ["Baskerville Old Face", "Palatino Linotype", "Georgia"],
	"dark": ["Old English Text MT", "Georgia"],
	"air": ["Baskerville Old Face", "Palatino Linotype", "Georgia"],

	"hit": ["Copperplate Gothic Bold", "Impact", "Cambria"],
	"move": ["Cambria", "Constantia", "Georgia"],

	"runes": ["Copperplate Gothic Bold", "Perpetua Titling MT", "Georgia"],
	"dropcap": ["Copperplate Gothic Bold", "Palatino Linotype", "Georgia"],
	"narrator": ["Palatino Linotype", "Book Antiqua", "Georgia"],
}


func get_font(key: String) -> Font:
	var project_font := get_project_font(key)
	if project_font != null:
		return project_font

	if use_system_fonts_when_missing:
		return get_system_font(key)

	return default_font


func get_project_font(key: String) -> Font:
	match key:
		"fire":
			return fire_font
		"ice":
			return ice_font
		"lightning":
			return lightning_font
		"water":
			return water_font
		"plant":
			return plant_font
		"earth":
			return earth_font
		"light":
			return light_font
		"dark":
			return dark_font
		"air":
			return air_font

		"hit":
			return hit_font
		"move":
			return move_font

		"runes":
			return runes_font
		"dropcap":
			return dropcap_font
		"narrator":
			return narrator_font
		"default":
			return default_font

		_:
			return default_font


func get_system_font(key: String) -> Font:
	var names: Array = SYSTEM_FONT_NAMES.get(key, SYSTEM_FONT_NAMES["default"])

	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	return font


func apply_to_rich_text(rtl: RichTextLabel, key: String) -> void:
	if not is_instance_valid(rtl):
		return

	var font := get_font(key)
	if font == null:
		return

	rtl.add_theme_font_override("normal_font", font)
	rtl.add_theme_font_override("bold_font", font)
	rtl.add_theme_font_override("italics_font", font)
	rtl.add_theme_font_override("bold_italics_font", font)
	rtl.add_theme_font_override("mono_font", font)


func apply_to_label(label_node: Label, key: String) -> void:
	if not is_instance_valid(label_node):
		return

	var font := get_font(key)
	if font == null:
		return

	label_node.add_theme_font_override("font", font)


func apply_to_button(button: Button, key: String) -> void:
	if not is_instance_valid(button):
		return

	var font := get_font(key)
	if font == null:
		return

	button.add_theme_font_override("font", font)

func get_font_path(key: String) -> String:
	var font := get_project_font(key)
	if font is FontFile and not font.resource_path.is_empty():
		return font.resource_path
	return ""
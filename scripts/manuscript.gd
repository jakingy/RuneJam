extends VBoxContainer

signal action_submitted(text: String)
signal action_text_changed(text: String)
@export var font_library: FontLibrary

const MEDIEVAL_PAPER_PATH := "res://assets/manuscript/medieval-paper.png"
const QUILL_ICON_PATH := "res://assets/manuscript/quill.png"

const MANUSCRIPT_PAPER_BLEND_SHADER_CODE := """
shader_type canvas_item;

uniform float fade_top = 0.0;
uniform float fade_bottom = 0.0;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.5;

void fragment() {
    vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;
    vec4 tex = texture(TEXTURE, UV + vec2(-ps.x, -ps.y)) * 0.0625
        + texture(TEXTURE, UV + vec2(0.0, -ps.y)) * 0.125
        + texture(TEXTURE, UV + vec2(ps.x, -ps.y)) * 0.0625
        + texture(TEXTURE, UV + vec2(-ps.x, 0.0)) * 0.125
        + texture(TEXTURE, UV) * 0.25
        + texture(TEXTURE, UV + vec2(ps.x, 0.0)) * 0.125
        + texture(TEXTURE, UV + vec2(-ps.x, ps.y)) * 0.0625
        + texture(TEXTURE, UV + vec2(0.0, ps.y)) * 0.125
        + texture(TEXTURE, UV + vec2(ps.x, ps.y)) * 0.0625;
    float top_alpha = fade_top <= 0.0 ? 1.0 : smoothstep(0.0, fade_top, UV.y);
    float bottom_alpha = fade_bottom <= 0.0 ? 1.0 : 1.0 - smoothstep(1.0 - fade_bottom, 1.0, UV.y);
    COLOR = vec4(tex.rgb, tex.a * top_alpha * bottom_alpha);
}
"""

const MANUSCRIPT_RUNE_SEQUENCE := ["A", "R", "X", "V", "N", "K", "L", "E", "O", "S", "T", "Y", "M", "H", "D", "P", "C"]

const COLOR_TEXT := Color(0.0, 0.0, 0.0, 0.8)
const COLOR_TEXT_DIM := Color(0.533, 0.533, 0.533)
const COLOR_ACCENT := Color(0.788, 0.659, 0.298)
const COLOR_ACCENT_DIM := Color(0.541, 0.427, 0.169)
const COLOR_BORDER := Color(0.2, 0.2, 0.2)
const COLOR_SURFACE2 := Color(0.141, 0.141, 0.141)

const TYPEWRITER_DELAY := 0.004
const TYPEWRITER_DELAY_FAST := 0.0014
const TYPEWRITER_DELAY_ACTION := 0.0023
const TYPEWRITER_DELAY_WAITING := 0.0058

const MANUSCRIPT_TEXT_SIZE := 27
const MANUSCRIPT_SMALL_TEXT_SIZE := 17
const MANUSCRIPT_TITLE_SIZE := 18
const MANUSCRIPT_INPUT_TEXT_SIZE := 23
const MANUSCRIPT_DROPCAP_SIZE := 108
const MANUSCRIPT_RUNE_SIZE := 22

const ACTION_STAMP_SFX_PATH := "res://assets/sfx/writing-stamp.mp3"
const NARRATOR_RING_SFX_PATHS := [
	"res://assets/sfx/magic_crystal/SFX_Crystal_Stone_Ring-01.wav",
	"res://assets/sfx/magic_crystal/SFX_Crystal_Stone_Ring-02.wav",
	"res://assets/sfx/magic_crystal/SFX_Crystal_Stone_Ring-03.wav",
]
const NARRATOR_CRACKLE_SFX_PATHS := [
	"res://assets/sfx/magic_crystal/SFX_Crystal_Stone_Crackles-01.wav",
	"res://assets/sfx/magic_crystal/SFX_Crystal_Stone_Crackles-02.wav",
	"res://assets/sfx/magic_crystal/SFX_Crystal_Stone_Crackles-03.wav",
]

const THINKING_MESSAGES := {
	"cost": ["The referee deliberates", "Weighing the odds", "Consulting the probability scrolls", "The judge considers your gambit"],
	"narrator": ["The narrator weaves the tale", "The quill scratches across parchment", "Fate turns its gaze upon the arena", "The story unfolds"],
	"team_b": ["Team B schemes in the shadows", "The enemy confers", "A dark strategy takes shape", "Whispers pass between foes"],
	"init": ["The arena takes shape", "Ancient runes flicker to life", "The battlefield awakens"],
}

@onready var _battle: Node = $"../.."

@onready var manuscript_frame: PanelContainer = $ManuscriptFrame
@onready var manuscript_shell: HBoxContainer = $ManuscriptFrame/ManuscriptShell
@onready var paper_margin: MarginContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin
@onready var manuscript_paper_surface: Control = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface
@onready var manuscript_paper_segments: Control = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperSegments
@onready var manuscript_paper_tint: ColorRect = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperTint
@onready var manuscript_paper_padding: MarginContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding
@onready var manuscript_paper_content: VBoxContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent
@onready var manuscript_scroll: ScrollContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/ManuscriptScroll
@onready var writing: VBoxContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/ManuscriptScroll/Writing
@onready var input_padding: MarginContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding
@onready var input_bar: HBoxContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding/InputBar
@onready var player_input: LineEdit = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding/InputBar/PlayerInput
@onready var play_btn: Button = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding/InputBar/PlayBtn

var manuscript_rune_layer: Control = null
var manuscript_left_rune_label: RichTextLabel = null

var _manuscript_refresh_queued := false
var _manuscript_last_paper_height := 0.0
var _manuscript_last_paper_width := 0.0

var _paper_texture: Texture2D = null
var _quill_icon_texture: Texture2D = null
var _send_btn_icon_glow: TextureRect = null
var _send_btn_icon_core: TextureRect = null
var _manuscript_paper_shader: Shader = null

var _typewriter_queue: Array[Dictionary] = []
var _typewriter_active := false

var _last_input_text_length := 0
var _input_crystal_tick := 0
var _typing_text_magic_tween: Tween = null
var _ui_sfx_cache: Dictionary = {}


func run_debug_test() -> void:
	add_system_message("System message test.")
	add_team_a_message("The player lunges forward with a risky attack.")
	add_team_b_message("The opponent circles back and prepares a counter.")
	add_cost_message(4, "grounded", "This action is possible, but requires careful positioning.")

	var narrator := add_streaming_narrator_message()
	append_streaming_narration(narrator, "The arena falls silent as the first strike lands. ")
	append_streaming_narration(narrator, "Dust rises from the floor while both sides prepare their next move.")

func _ready() -> void:
	TextEffects.font_library = font_library

	_apply_node_layout_safety()
	_ensure_rune_nodes()
	_apply_basic_theme()
	_apply_original_input_theme()
	_connect_input()
	_connect_scroll_and_resize()
	_ensure_send_button_icon_layers()
	refresh_send_button_state()
	queue_manuscript_refresh()
	
	#run_debug_test.call_deferred()



# ── setup ──

func _apply_node_layout_safety() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var expand_nodes: Array[Control] = [
		manuscript_frame,
		manuscript_shell,
		paper_margin,
		manuscript_paper_surface,
		manuscript_paper_padding,
		manuscript_paper_content,
		manuscript_scroll,
		input_padding,
		input_bar,
		player_input,
	]

	for node in expand_nodes:
		if is_instance_valid(node):
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for node in [
		manuscript_frame,
		manuscript_shell,
		paper_margin,
		manuscript_paper_surface,
		manuscript_paper_padding,
		manuscript_paper_content,
		manuscript_scroll,
	]:
		if is_instance_valid(node):
			node.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if is_instance_valid(writing):
		writing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		writing.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if is_instance_valid(input_padding):
		input_padding.size_flags_vertical = Control.SIZE_SHRINK_END

	if is_instance_valid(input_bar):
		input_bar.size_flags_vertical = Control.SIZE_SHRINK_END

	if is_instance_valid(player_input):
		player_input.custom_minimum_size.y = 36.0

	if is_instance_valid(play_btn):
		play_btn.custom_minimum_size = Vector2(90.0, 36.0)

	# Structural parents pass input; the scroll/input controls handle it.
	for node in [
		manuscript_frame,
		manuscript_shell,
		paper_margin,
		manuscript_paper_surface,
		manuscript_paper_padding,
		manuscript_paper_content,
		writing,
		input_padding,
		input_bar,
	]:
		if is_instance_valid(node):
			node.mouse_filter = Control.MOUSE_FILTER_PASS

	if is_instance_valid(manuscript_scroll):
		manuscript_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		manuscript_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		manuscript_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if is_instance_valid(player_input):
		player_input.mouse_filter = Control.MOUSE_FILTER_STOP

	if is_instance_valid(play_btn):
		play_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	if is_instance_valid(manuscript_paper_segments):
		manuscript_paper_segments.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(manuscript_paper_tint):
		manuscript_paper_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_rune_nodes() -> void:
	manuscript_rune_layer = manuscript_paper_surface.get_node_or_null("ManuscriptRuneLayer") as Control
	if manuscript_rune_layer == null:
		manuscript_rune_layer = Control.new()
		manuscript_rune_layer.name = "ManuscriptRuneLayer"
		manuscript_rune_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		manuscript_rune_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		manuscript_paper_surface.add_child(manuscript_rune_layer)

	manuscript_rune_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	manuscript_left_rune_label = manuscript_rune_layer.get_node_or_null("LeftRuneGutter") as RichTextLabel
	if manuscript_left_rune_label == null:
		manuscript_left_rune_label = RichTextLabel.new()
		manuscript_left_rune_label.name = "LeftRuneGutter"
		manuscript_rune_layer.add_child(manuscript_left_rune_label)

	manuscript_left_rune_label.bbcode_enabled = false
	manuscript_left_rune_label.scroll_active = false
	manuscript_left_rune_label.fit_content = false
	manuscript_left_rune_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	manuscript_left_rune_label.selection_enabled = false
	manuscript_left_rune_label.context_menu_enabled = false
	manuscript_left_rune_label.shortcut_keys_enabled = false
	manuscript_left_rune_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_basic_theme() -> void:
	if is_instance_valid(manuscript_frame):
		var manuscript_style := StyleBoxFlat.new()
		manuscript_style.bg_color = Color(0.07, 0.055, 0.04, 0.98)
		manuscript_style.border_color = Color(0.41, 0.29, 0.13, 1.0)
		manuscript_style.set_border_width_all(2)
		manuscript_style.set_corner_radius_all(10)
		manuscript_style.content_margin_left = 0
		manuscript_style.content_margin_right = 0
		manuscript_style.content_margin_top = 0
		manuscript_style.content_margin_bottom = 0
		manuscript_style.shadow_color = Color(0.02, 0.01, 0.0, 0.45)
		manuscript_style.shadow_size = 6
		manuscript_frame.add_theme_stylebox_override("panel", manuscript_style)

	if is_instance_valid(manuscript_left_rune_label):
		manuscript_left_rune_label.add_theme_color_override("default_color", Color(0.3, 0.9, 5.8, 1.0))
		manuscript_left_rune_label.add_theme_font_size_override("normal_font_size", MANUSCRIPT_RUNE_SIZE)
		manuscript_left_rune_label.self_modulate = Color(1.0, 1.0, 1.0, 0.45)
		apply_font_to_rich_text(manuscript_left_rune_label, "runes")

	if is_instance_valid(writing):
		writing.add_theme_constant_override("separation", 14)

	if is_instance_valid(input_bar):
		input_bar.add_theme_constant_override("separation", 10)


func _apply_original_input_theme() -> void:
	if not is_instance_valid(player_input):
		return

	apply_font_to_line_edit(player_input, "narrator")
	player_input.add_theme_font_size_override("font_size", MANUSCRIPT_INPUT_TEXT_SIZE)
	player_input.add_theme_color_override("font_color", Color(0.23, 0.18, 0.1, 1.0))
	player_input.add_theme_color_override("font_placeholder_color", Color(0.42, 0.33, 0.21, 0.82))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.84, 0.77, 0.6, 0.98)
	normal_style.border_color = Color(0.46, 0.35, 0.2, 1.0)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(7)
	normal_style.content_margin_left = 14
	normal_style.content_margin_right = 14
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	normal_style.shadow_color = Color(0.08, 0.05, 0.02, 0.25)
	normal_style.shadow_size = 2
	player_input.add_theme_stylebox_override("normal", normal_style)

	var focus_style := normal_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.74, 0.58, 0.27, 1.0)
	focus_style.shadow_color = Color(0.53, 0.41, 0.18, 0.22)
	focus_style.shadow_size = 4
	player_input.add_theme_stylebox_override("focus", focus_style)

	var read_only_style := normal_style.duplicate() as StyleBoxFlat
	read_only_style.border_color = Color(0.36, 0.29, 0.19, 0.9)
	read_only_style.bg_color = Color(0.67, 0.6, 0.48, 0.92)
	player_input.add_theme_stylebox_override("read_only", read_only_style)

	_set_typing_text_magic_strength(0.0)


func _on_input_text_changed_original(new_text: String) -> void:
	var new_length := new_text.length()
	refresh_send_button_state()

	if new_length > _last_input_text_length:
		var typed_char := new_text.substr(new_length - 1, 1) if new_length > 0 else ""
		_play_input_crystal_sfx(typed_char)
	elif new_length < _last_input_text_length:
		_play_input_erase_sfx()

	if new_length > 0 and player_input.editable:
		_start_typing_text_magic()
	else:
		_stop_typing_text_magic()

	_last_input_text_length = new_length


func _play_action_commit_sfx() -> void:
	if not is_sendable():
		return
	_play_ui_sfx(ACTION_STAMP_SFX_PATH, -8.0, randf_range(0.96, 1.04))


func _set_typing_text_magic_strength(amount: float) -> void:
	var clamped := clampf(amount, 0.0, 1.0)
	var font_color := Color(7.72, 2.49, 0.82, 1.0).lerp(Color(15.72, 0.9, 0.42, 1.0), clamped * 0.9)
	var caret_color := COLOR_ACCENT.lerp(Color(1.0, 0.89, 0.6, 1.0), clamped)

	if is_instance_valid(player_input):
		player_input.add_theme_color_override("font_color", font_color)
		player_input.add_theme_color_override("caret_color", caret_color)


func _start_typing_text_magic() -> void:
	if not is_instance_valid(player_input) or not player_input.editable:
		return
	if is_instance_valid(_typing_text_magic_tween):
		return

	_set_typing_text_magic_strength(0.35)
	_typing_text_magic_tween = create_tween().set_loops()
	_typing_text_magic_tween.tween_method(_set_typing_text_magic_strength, 0.1, 1.0, 1.9)
	_typing_text_magic_tween.tween_method(_set_typing_text_magic_strength, 1.0, 0.1, 0.5)


func _stop_typing_text_magic() -> void:
	if is_instance_valid(_typing_text_magic_tween):
		_typing_text_magic_tween.kill()
	_typing_text_magic_tween = null
	_set_typing_text_magic_strength(0.0)


func _connect_input() -> void:
	if is_instance_valid(player_input):
		_last_input_text_length = player_input.text.length()

		player_input.text_changed.connect(func(new_text: String) -> void:
			_on_input_text_changed_original(new_text)
			action_text_changed.emit(new_text)
		)

		player_input.text_submitted.connect(func(text: String) -> void:
			_play_action_commit_sfx()
			action_submitted.emit(text.strip_edges())
		)

	if is_instance_valid(play_btn):
		play_btn.pressed.connect(func() -> void:
			_play_action_commit_sfx()
			action_submitted.emit(get_input_text())
		)


func _connect_scroll_and_resize() -> void:
	var v_scroll := manuscript_scroll.get_v_scroll_bar()
	if is_instance_valid(v_scroll):
		v_scroll.value_changed.connect(update_manuscript_scroll_offset)
		v_scroll.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
		v_scroll.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
		v_scroll.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
		v_scroll.add_theme_stylebox_override("grabber_pressed", StyleBoxEmpty.new())
		v_scroll.custom_minimum_size.x = 0

	if is_instance_valid(manuscript_paper_surface):
		manuscript_paper_surface.resized.connect(queue_manuscript_refresh)

	if is_instance_valid(writing):
		writing.resized.connect(queue_manuscript_refresh)


# ── Input API ──

func enable_input(placeholder: String = "Enter your action.") -> void:
	if not is_instance_valid(player_input):
		return
	player_input.editable = true
	player_input.placeholder_text = placeholder
	_last_input_text_length = player_input.text.length()
	if _last_input_text_length > 0:
		_start_typing_text_magic()
	else:
		_stop_typing_text_magic()
	refresh_send_button_state()


func disable_input(placeholder: String = "") -> void:
	if not is_instance_valid(player_input):
		return
	player_input.editable = false
	_last_input_text_length = 0
	_stop_typing_text_magic()
	if not placeholder.is_empty():
		player_input.placeholder_text = placeholder
	refresh_send_button_state()


func clear_input() -> void:
	if not is_instance_valid(player_input):
		return
	player_input.text = ""
	_last_input_text_length = 0
	_stop_typing_text_magic()
	refresh_send_button_state()
	action_text_changed.emit("")


func set_input_text(text: String) -> void:
	if not is_instance_valid(player_input):
		return
	player_input.text = text
	_last_input_text_length = text.length()
	if _last_input_text_length > 0 and player_input.editable:
		_start_typing_text_magic()
	else:
		_stop_typing_text_magic()
	refresh_send_button_state()
	action_text_changed.emit(text)


func get_input_text() -> String:
	if not is_instance_valid(player_input):
		return ""
	return player_input.text.strip_edges()


func focus_input() -> void:
	if is_instance_valid(player_input) and player_input.editable:
		player_input.grab_focus()


func is_sendable() -> bool:
	return is_instance_valid(player_input) and player_input.editable and not player_input.text.strip_edges().is_empty()


func refresh_send_button_state() -> void:
	if not is_instance_valid(play_btn):
		return

	var can_send := is_sendable()
	play_btn.disabled = not can_send
	update_send_button_visual_state(can_send)


# ── Paper/runes ──

func queue_manuscript_refresh() -> void:
	if _manuscript_refresh_queued:
		return
	_manuscript_refresh_queued = true
	refresh_manuscript_ui.call_deferred()


func refresh_manuscript_ui() -> void:
	_manuscript_refresh_queued = false
	rebuild_manuscript_paper()
	rebuild_manuscript_runes()
	update_manuscript_scroll_offset()


func load_manuscript_paper_texture() -> Texture2D:
	if _paper_texture != null:
		return _paper_texture

	var loaded: Variant = load(MEDIEVAL_PAPER_PATH)
	if loaded is Texture2D:
		_paper_texture = loaded
	else:
		push_warning("Could not load manuscript paper texture: %s" % MEDIEVAL_PAPER_PATH)

	return _paper_texture


func load_png_texture(texture_path: String) -> Texture2D:
	if not FileAccess.file_exists(texture_path):
		return null

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(texture_path)
	if bytes.is_empty():
		return null

	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null

	return ImageTexture.create_from_image(image)


func get_manuscript_paper_shader() -> Shader:
	if _manuscript_paper_shader == null:
		_manuscript_paper_shader = Shader.new()
		_manuscript_paper_shader.code = MANUSCRIPT_PAPER_BLEND_SHADER_CODE
	return _manuscript_paper_shader


func rebuild_manuscript_paper() -> void:
	if not is_instance_valid(manuscript_paper_surface) or not is_instance_valid(manuscript_paper_segments):
		return

	var paper_texture := load_manuscript_paper_texture()
	if paper_texture == null:
		return

	var area_width: float = maxf(320.0, manuscript_paper_surface.size.x)
	var content_height: float = maxf(manuscript_paper_surface.size.y, writing.size.y + 180.0)
	var area_height: float = maxf(480.0, content_height)

	if (
		manuscript_paper_segments.get_child_count() > 0
		and area_height <= _manuscript_last_paper_height
		and absf(area_width - _manuscript_last_paper_width) < 1.0
	):
		update_manuscript_scroll_offset()
		return

	_manuscript_last_paper_width = area_width
	_manuscript_last_paper_height = area_height + 200.0
	manuscript_paper_segments.size = Vector2(area_width, _manuscript_last_paper_height)

	for child in manuscript_paper_segments.get_children():
		child.queue_free()

	var paper_aspect := 740.0 / 493.0
	var segment_height := area_width * paper_aspect
	var step_y := segment_height * 0.6
	var segment_count := maxi(
		2,
		int(ceil(maxf(_manuscript_last_paper_height - segment_height, 0.0) / maxf(step_y, 1.0))) + 2
	)

	for idx in range(segment_count):
		var rect := TextureRect.new()
		rect.name = "PaperSegment%d" % idx
		rect.texture = paper_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = Vector2(0.0, float(idx) * step_y)
		rect.size = Vector2(area_width, segment_height)
		rect.modulate = Color(0.55, 0.53, 0.50, 1.0)

		var paper_material := ShaderMaterial.new()
		paper_material.shader = get_manuscript_paper_shader()
		paper_material.set_shader_parameter("fade_top", 0.2 if idx > 0 else 0.0)
		paper_material.set_shader_parameter("fade_bottom", 0.26 if idx < segment_count - 1 else 0.0)
		rect.material = paper_material

		manuscript_paper_segments.add_child(rect)

	update_manuscript_scroll_offset()


func build_manuscript_rune_text(line_count: int, seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var lines: PackedStringArray = []
	for _idx in range(line_count):
		lines.append(MANUSCRIPT_RUNE_SEQUENCE[rng.randi() % MANUSCRIPT_RUNE_SEQUENCE.size()])

	return "\n".join(lines)


func rebuild_manuscript_runes() -> void:
	if not is_instance_valid(manuscript_paper_surface) or not is_instance_valid(manuscript_left_rune_label):
		return

	var content_height: float = maxf(manuscript_paper_surface.size.y, writing.size.y + 180.0)
	var full_height: float = maxf(480.0, content_height)
	var rune_top := 18.0
	var rune_height := full_height - rune_top

	manuscript_left_rune_label.position = Vector2(10.0, rune_top)
	manuscript_left_rune_label.size = Vector2(30.0, rune_height)

	var line_count := maxi(18, int(ceil(rune_height / 22.0)))
	manuscript_left_rune_label.text = build_manuscript_rune_text(line_count, 42)
	apply_font_to_rich_text(manuscript_left_rune_label, "runes")

func update_manuscript_scroll_offset(_value: float = 0.0) -> void:
	var offset_y := -float(manuscript_scroll.scroll_vertical)

	if is_instance_valid(manuscript_paper_segments):
		manuscript_paper_segments.position.y = offset_y

	if is_instance_valid(manuscript_rune_layer):
		manuscript_rune_layer.position.y = offset_y


# ── Quill button ──

func get_quill_icon_texture() -> Texture2D:
	if _quill_icon_texture == null:
		_quill_icon_texture = load_png_texture(QUILL_ICON_PATH)
	return _quill_icon_texture


func _ensure_send_button_icon_layers() -> void:
	if not is_instance_valid(play_btn):
		return

	var quill_texture := get_quill_icon_texture()
	if quill_texture == null:
		return

	if not is_instance_valid(_send_btn_icon_glow):
		_send_btn_icon_glow = TextureRect.new()
		_send_btn_icon_glow.name = "QuillGlow"
		_send_btn_icon_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_send_btn_icon_glow.texture = quill_texture
		_send_btn_icon_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_send_btn_icon_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_send_btn_icon_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		play_btn.add_child(_send_btn_icon_glow)

	if not is_instance_valid(_send_btn_icon_core):
		_send_btn_icon_core = TextureRect.new()
		_send_btn_icon_core.name = "QuillCore"
		_send_btn_icon_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_send_btn_icon_core.texture = quill_texture
		_send_btn_icon_core.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_send_btn_icon_core.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_send_btn_icon_core.set_anchors_preset(Control.PRESET_FULL_RECT)
		_send_btn_icon_core.offset_left = 6.0
		_send_btn_icon_core.offset_top = 6.0
		_send_btn_icon_core.offset_right = -6.0
		_send_btn_icon_core.offset_bottom = -6.0
		play_btn.add_child(_send_btn_icon_core)


func update_send_button_visual_state(can_send: bool) -> void:
	_ensure_send_button_icon_layers()

	if not is_instance_valid(_send_btn_icon_glow) or not is_instance_valid(_send_btn_icon_core):
		return

	if can_send:
		_send_btn_icon_glow.self_modulate = Color(2.2, 1.7, 0.72, 0.95)
		_send_btn_icon_glow.offset_left = -6.0
		_send_btn_icon_glow.offset_top = -6.0
		_send_btn_icon_glow.offset_right = 6.0
		_send_btn_icon_glow.offset_bottom = 6.0
		_send_btn_icon_core.self_modulate = Color(1.22, 1.08, 0.82, 1.0)
	else:
		_send_btn_icon_glow.self_modulate = Color(1.0, 1.0, 1.0, 0.22)
		_send_btn_icon_glow.offset_left = -2.0
		_send_btn_icon_glow.offset_top = -2.0
		_send_btn_icon_glow.offset_right = 2.0
		_send_btn_icon_glow.offset_bottom = 2.0
		_send_btn_icon_core.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


# ── Messages ──

func show_modal(title: String, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.size = Vector2i(600, 500)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())


func create_msg_container(bg_color: Color, border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.0)
	style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.22)
	style.border_width_bottom = 1
	style.set_corner_radius_all(0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 10

	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func wrap_with_alignment(panel: PanelContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer_left := Control.new()
	spacer_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_left.size_flags_stretch_ratio = 0.5

	var spacer_right := Control.new()
	spacer_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_right.size_flags_stretch_ratio = 0.5

	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 6.0

	row.add_child(spacer_left)
	row.add_child(panel)
	row.add_child(spacer_right)

	return row

func apply_font_to_rich_text(rtl: RichTextLabel, key: String) -> void:
	if font_library == null:
		print("No font_library assigned on Manuscript")
		return
	if not is_instance_valid(rtl):
		print("Invalid RichTextLabel for font key: ", key)
		return

	font_library.apply_to_rich_text(rtl, key)

func apply_font_to_label(label_node: Label, key: String) -> void:
	if font_library == null:
		return
	font_library.apply_to_label(label_node, key)


func apply_font_to_button(button_node: Button, key: String) -> void:
	if font_library == null:
		return
	font_library.apply_to_button(button_node, key)


func apply_font_to_line_edit(line_edit: LineEdit, key: String) -> void:
	if font_library == null:
		return
	if font_library.has_method("apply_to_line_edit"):
		font_library.apply_to_line_edit(line_edit, key)
	elif font_library.has_method("get_font"):
		var font: Font = font_library.get_font(key)
		if font != null:
			line_edit.add_theme_font_override("font", font)

func add_msg_to_chat(panel: PanelContainer) -> void:
	if not is_instance_valid(writing):
		return

	var row := wrap_with_alignment(panel)
	writing.add_child(row)

	await get_tree().process_frame
	queue_manuscript_refresh()

	# Original behaviour: adding a new message always jumps to bottom.
	manuscript_scroll.scroll_vertical = int(manuscript_scroll.get_v_scroll_bar().max_value)
	update_manuscript_scroll_offset()


func remove_msg(panel: Variant) -> void:
	if not is_instance_valid(panel):
		return

	if panel is Node:
		var node := panel as Node
		if is_instance_valid(node.get_parent()):
			node.get_parent().queue_free()
		else:
			node.queue_free()


func make_rich_text_selectable(rich_text: RichTextLabel) -> void:
	rich_text.selection_enabled = true
	rich_text.context_menu_enabled = true
	rich_text.shortcut_keys_enabled = true
	rich_text.mouse_filter = Control.MOUSE_FILTER_PASS


func create_plain_rich_text(text: String, color: Color, font_size: int) -> RichTextLabel:
	var content := RichTextLabel.new()
	content.bbcode_enabled = false
	content.fit_content = true
	content.scroll_active = false
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("default_color", color)
	content.add_theme_font_size_override("normal_font_size", font_size)
	content.text = text
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_rich_text_selectable(content)
	apply_font_to_rich_text(content, "narrator")
	return content


func create_narrator_rich_text() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", COLOR_TEXT)
	rtl.add_theme_font_size_override("normal_font_size", MANUSCRIPT_TEXT_SIZE)
	rtl.text = ""
	make_rich_text_selectable(rtl)
	apply_font_to_rich_text(rtl, "narrator")
	return rtl


func create_narrator_dropcap_layout() -> Dictionary:
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_theme_constant_override("separation", 0)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 4)
	layout.add_child(hbox)

	var dropcap := RichTextLabel.new()
	dropcap.bbcode_enabled = true
	dropcap.fit_content = true
	dropcap.scroll_active = false
	dropcap.autowrap_mode = TextServer.AUTOWRAP_OFF
	dropcap.visible = false
	dropcap.custom_minimum_size = Vector2(60, 0)
	dropcap.add_theme_color_override("default_color", COLOR_TEXT)
	dropcap.add_theme_font_size_override("normal_font_size", MANUSCRIPT_DROPCAP_SIZE)
	make_rich_text_selectable(dropcap)
	ensure_text_effects(dropcap)
	apply_font_to_rich_text(dropcap, "dropcap")
	hbox.add_child(dropcap)

	var first_lines := create_narrator_rich_text()
	hbox.add_child(first_lines)

	var continuation := create_narrator_rich_text()
	layout.add_child(continuation)

	first_lines.set_meta("narrator_has_dropcap", false)
	first_lines.set_meta("narrator_dropcap_label", dropcap)
	first_lines.set_meta("narrator_overflow_rtl", continuation)
	first_lines.set_meta("narrator_overflow_height", 76.0)
	first_lines.set_meta("narrator_overflow_active", false)
	first_lines.set_meta("narrator_overflow_pending", false)
	first_lines.set_meta("narrator_story_root", first_lines)
	first_lines.set_meta("narrator_full_text", "")
	continuation.set_meta("narrator_story_root", first_lines)

	return {"layout": layout, "first_lines": first_lines}


func extract_dropcap_text(rtl: RichTextLabel, full_text: String) -> String:
	if not is_instance_valid(rtl):
		return full_text
	if not rtl.has_meta("narrator_has_dropcap"):
		return full_text
	if bool(rtl.get_meta("narrator_has_dropcap")):
		return full_text
	if full_text.is_empty():
		return full_text

	rtl.set_meta("narrator_has_dropcap", true)

	if rtl.has_meta("narrator_dropcap_label"):
		var dropcap_variant: Variant = rtl.get_meta("narrator_dropcap_label")
		if dropcap_variant is RichTextLabel:
			var dropcap_label := dropcap_variant as RichTextLabel
			if is_instance_valid(dropcap_label):
				var effect_params = TextEffects.effect_params_from_preset(TextEffects.writing_narrator())
				dropcap_label.visible_characters = -1
				dropcap_label.text = build_effect_bbcode_char(full_text.substr(0, 1), "writing", effect_params)
				dropcap_label.visible = true

	_play_ui_sfx(ACTION_STAMP_SFX_PATH, -17.0, 1.0)
	return full_text.substr(1)


func resolve_narrator_overflow_rtl(rtl: RichTextLabel) -> RichTextLabel:
	var root := get_narrator_story_root(rtl)
	if not is_instance_valid(root):
		root = rtl

	if bool(root.get_meta("narrator_overflow_active", false)) and root.has_meta("narrator_overflow_rtl"):
		var active_overflow_variant: Variant = root.get_meta("narrator_overflow_rtl")
		if active_overflow_variant is RichTextLabel and is_instance_valid(active_overflow_variant as RichTextLabel):
			return active_overflow_variant as RichTextLabel

	return rtl


func get_narrator_story_root(rtl: RichTextLabel) -> RichTextLabel:
	if not is_instance_valid(rtl):
		return null

	if not rtl.has_meta("narrator_story_root"):
		return rtl

	var root_variant: Variant = rtl.get_meta("narrator_story_root", null)
	if root_variant is RichTextLabel and is_instance_valid(root_variant as RichTextLabel):
		return root_variant as RichTextLabel

	return rtl


func uses_narrator_story_flow(rtl: RichTextLabel) -> bool:
	return is_instance_valid(rtl) and rtl.has_meta("narrator_story_root")


func get_narrator_full_text(rtl: RichTextLabel) -> String:
	var root := get_narrator_story_root(rtl)
	if not is_instance_valid(root):
		return ""
	return str(root.get_meta("narrator_full_text", ""))


func reset_narrator_full_text(rtl: RichTextLabel) -> void:
	var root := get_narrator_story_root(rtl)
	if not is_instance_valid(root):
		return

	root.set_meta("narrator_full_text", "")
	root.set_meta("narrator_overflow_active", false)
	root.set_meta("narrator_overflow_pending", false)


func append_narrator_full_text(rtl: RichTextLabel, chunk: String) -> void:
	if chunk.is_empty():
		return

	var root := get_narrator_story_root(rtl)
	if not is_instance_valid(root):
		return

	root.set_meta("narrator_full_text", get_narrator_full_text(root) + chunk)


func is_whitespace_char(char_text: String) -> bool:
	return char_text == " " or char_text == "\n" or char_text == "\t"


func add_stamp_msg(sections: Array, bg: Color, border: Color, title: String = "", title_color: Color = Color.WHITE) -> PanelContainer:
	var panel := create_msg_container(bg, border)

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.scroll_active = false
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("default_color", COLOR_TEXT)
	content.add_theme_font_size_override("normal_font_size", MANUSCRIPT_TEXT_SIZE)
	content.text = ""
	content.visible_characters = -1
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_rich_text_selectable(content)
	apply_font_to_rich_text(content, "narrator")
	ensure_text_effects(content)

	var preset = TextEffects.writing_stamp()
	var effect_name = TextEffects.effect_name_from_preset(preset)
	var effect_params = TextEffects.effect_params_from_preset(preset)

	var parts: Array[String] = []
	if not title.is_empty():
		var title_bbcode := stamp_text_with_wrapping(title.to_upper(), effect_name, effect_params)
		var glow_open := "[glow r=%s g=%s b=%s]" % [str(title_color.r), str(title_color.g), str(title_color.b)]
		
		var base_color_html := title_color.clamp().to_html()
		parts.append("[font_size=13][b][color=%s]%s%s[/glow][/color][/b][/font_size]" % [base_color_html, glow_open, title_bbcode])

	for section in sections:
		if not (section is Dictionary):
			continue
		var sec := section as Dictionary
		var section_text := str(sec.get("text", ""))
		if section_text.is_empty():
			continue

		var stamped := stamp_text_with_wrapping(section_text, effect_name, effect_params)
		var font_size := int(sec.get("size", 0))
		var color: Variant = sec.get("color", null)

		if color is Color and font_size > 0:
			stamped = "[font_size=%d][color=%s]%s[/color][/font_size]" % [font_size, (color as Color).to_html(), stamped]
		elif font_size > 0:
			stamped = "[font_size=%d]%s[/font_size]" % [font_size, stamped]
		elif color is Color:
			stamped = "[color=%s]%s[/color]" % [(color as Color).to_html(), stamped]

		parts.append(stamped)

	content.text = "\n".join(parts)

	panel.add_child(content)
	add_msg_to_chat(panel)
	_spawn_stamp_burst_effect(content)
	_play_ui_sfx(ACTION_STAMP_SFX_PATH, -8.0)
	return panel


func stamp_text_with_wrapping(text: String, effect_name: String, effect_params: String) -> String:
	return TextEffects.wrap_text(text, effect_name, effect_params)


func add_narrate_msg(
	text: String,
	bg: Color,
	border: Color,
	title: String = "",
	title_color: Color = Color.WHITE,
	preset: Dictionary = {}
) -> PanelContainer:
	var panel := create_msg_container(bg, border)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	if not title.is_empty():
		vbox.add_child(create_glow_title(title, title_color, title_color.clamp()))

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.scroll_active = false
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("default_color", COLOR_TEXT)
	content.add_theme_font_size_override("normal_font_size", MANUSCRIPT_TEXT_SIZE)
	content.text = ""
	content.visible_characters = 0
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_rich_text_selectable(content)
	apply_font_to_rich_text(content, "narrator")
	ensure_text_effects(content)

	vbox.add_child(content)
	panel.add_child(vbox)
	add_msg_to_chat(panel)

	var active_preset = preset if not preset.is_empty() else TextEffects.writing_narrator()
	start_typewriter_preset(content, text, active_preset, false, TYPEWRITER_DELAY_ACTION)

	return panel


func create_glow_title(title: String, glow_color: Color, base_color: Color = COLOR_TEXT) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_color_override("default_color", base_color)
	rtl.add_theme_font_size_override("normal_font_size", MANUSCRIPT_TITLE_SIZE)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_rich_text_selectable(rtl)
	ensure_text_effects(rtl)
	apply_font_to_rich_text(rtl, "narrator")
	rtl.text = "[b]" + TextEffects.wrap_glow(title.to_upper(), glow_color) + "[/b]"
	return rtl


func add_system_msg(text: String) -> PanelContainer:
	var panel := create_msg_container(Color(0, 0, 0, 0), COLOR_BORDER)
	var content := create_plain_rich_text(text, COLOR_ACCENT_DIM, 13)
	panel.add_child(content)
	add_msg_to_chat(panel)
	return panel


func add_narrator_message(text: String) -> PanelContainer:
	var panel := create_msg_container(COLOR_SURFACE2, COLOR_BORDER)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(create_glow_title("Narrator", Color(6.0, 4.5, 1.5, 1.0)))

	var narrator := create_narrator_dropcap_layout()
	vbox.add_child(narrator["layout"])

	panel.add_child(vbox)
	add_msg_to_chat(panel)

	start_typewriter_preset(narrator["first_lines"], text, TextEffects.writing_narrator(), true)
	return panel


func add_streaming_narrator_message() -> RichTextLabel:
	var panel := create_msg_container(COLOR_SURFACE2, COLOR_BORDER)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(create_glow_title("Narrator", Color(6.0, 4.5, 1.5, 1.0)))

	var narrator := create_narrator_dropcap_layout()
	vbox.add_child(narrator["layout"])

	panel.add_child(vbox)
	add_msg_to_chat(panel)

	return narrator["first_lines"]

func add_system_message(text: String) -> PanelContainer:
	return add_system_msg(text)


func add_team_a_message(text: String) -> PanelContainer:
	return add_stamp_msg(
		[{"text": text}],
		Color(0.086, 0.149, 0.251),
		Color(0.165, 0.29, 0.478),
		"Your Action",
		Color(0.2, 0.6, 1.0, 1.0)
	)


func add_team_b_message(text: String) -> PanelContainer:
	return add_narrate_msg(
		text,
		Color(0.165, 0.086, 0.086),
		Color(0.353, 0.165, 0.165),
		"Opponent",
		Color(1.0, 0.2, 0.2, 1.0),
		TextEffects.writing_narrator()
	)


func add_cost_message(cost: int, band: String, summary: String) -> PanelContainer:
	var lines: Array[String] = []
	if cost > 0:
		lines.append("%d  (%s)" % [cost, band])
	if not summary.is_empty():
		lines.append(summary)

	return add_narrate_msg(
		"\n".join(lines),
		Color(0.102, 0.102, 0.165),
		Color(0.2, 0.2, 0.267),
		"Cost Judge",
		Color(4.0, 1.5, 8.0, 1.0),
		TextEffects.writing_narrator()
	)


func add_labeled_rich_message(
	label_text: String,
	label_color: Color,
	bg_color: Color,
	border_color: Color,
	text: String,
	adaptive_eta: bool = false
) -> PanelContainer:
	var message := build_rich_message(label_text, label_color, bg_color, border_color)
	var content: RichTextLabel = message["content"]
	add_msg_to_chat(message["panel"])
	start_typewriter(content, text, adaptive_eta)
	return message["panel"]


func add_streaming_rich_message(
	label_text: String,
	label_color: Color,
	bg_color: Color,
	border_color: Color
) -> RichTextLabel:
	var message := build_rich_message(label_text, label_color, bg_color, border_color)
	add_msg_to_chat(message["panel"])
	return message["content"]


func build_rich_message(
	label_text: String,
	label_color: Color,
	bg_color: Color,
	border_color: Color
) -> Dictionary:
	var panel := create_msg_container(bg_color, border_color)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var label_node := Label.new()
	label_node.text = label_text
	label_node.add_theme_color_override("font_color", label_color)
	label_node.add_theme_font_size_override("font_size", 11)
	apply_font_to_label(label_node, "narrator")
	vbox.add_child(label_node)

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.scroll_active = false
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("default_color", COLOR_TEXT)
	content.add_theme_font_size_override("normal_font_size", MANUSCRIPT_TEXT_SIZE)
	content.text = ""
	content.visible = true
	content.visible_characters = 0
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_rich_text_selectable(content)
	apply_font_to_rich_text(content, "narrator")
	vbox.add_child(content)

	panel.add_child(vbox)

	return {
		"panel": panel,
		"content": content,
	}

func add_thinking_message(category: String) -> PanelContainer:
	var glow_colors := {
		"cost": Color(2.5, 1.0, 5.0, 1.0),
		"narrator": Color(4.0, 3.0, 1.0, 1.0),
		"team_b": Color(4.0, 0.5, 0.3, 1.0),
		"init": Color(0.3, 1.5, 2.0, 1.0),
	}

	var msgs: Array = THINKING_MESSAGES.get(category, THINKING_MESSAGES["narrator"])
	var text: String = msgs[randi() % msgs.size()]
	var glow_color: Color = glow_colors.get(category, Color(4.0, 3.0, 1.0, 1.0))

	var panel := create_msg_container(Color(0, 0, 0, 0), COLOR_BORDER)

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.scroll_active = false
	content.add_theme_color_override("default_color", COLOR_TEXT_DIM)
	content.add_theme_font_size_override("normal_font_size", MANUSCRIPT_SMALL_TEXT_SIZE )
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_rich_text_selectable(content)
	ensure_text_effects(content)
	apply_font_to_rich_text(content, "narrator")

	var glow_open := "[glow r=%s g=%s b=%s settle=999]" % [str(glow_color.r), str(glow_color.g), str(glow_color.b)]
	content.text = "%s%s...[/glow]" % [glow_open, TextEffects.escape_bbcode_text(text)]
	content.visible_characters = -1

	var tween := create_tween().set_loops(100)
	tween.tween_property(content, "self_modulate:a", 0.4, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(content, "self_modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	panel.add_child(content)
	panel.set_meta("tween", tween)
	add_msg_to_chat(panel)

	return panel


# ── Typewriter ──

func start_typewriter(
	rtl: RichTextLabel,
	full_text: String,
	adaptive_eta: bool = false,
	delay_override: float = -1.0,
	effect_name: String = "writing",
	effect_params: String = "settle=0.85",
	on_complete: Callable = Callable()
) -> void:
	ensure_text_effects(rtl)
	rtl.visible_characters = -1
	rtl.text = ""

	reset_narrator_full_text(rtl)
	full_text = extract_dropcap_text(rtl, full_text)

	_typewriter_queue.append({
		"rtl": rtl,
		"pending_text": full_text,
		"index": 0,
		"adaptive_eta": adaptive_eta,
		"delay_override": delay_override,
		"effect_name": effect_name,
		"effect_params": effect_params,
		"on_complete": on_complete,
	})

	if not _typewriter_active:
		process_typewriter()


func append_typewriter(
	rtl: RichTextLabel,
	text: String,
	adaptive_eta: bool = false,
	delay_override: float = -1.0,
	effect_name: String = "writing",
	effect_params: String = "settle=0.85",
	on_complete: Callable = Callable()
) -> void:
	if text.is_empty() or not is_instance_valid(rtl):
		return

	ensure_text_effects(rtl)
	rtl.visible_characters = -1

	text = extract_dropcap_text(rtl, text)
	if text.is_empty():
		return

	_typewriter_queue.append({
		"rtl": rtl,
		"pending_text": text,
		"index": 0,
		"adaptive_eta": adaptive_eta,
		"delay_override": delay_override,
		"effect_name": effect_name,
		"effect_params": effect_params,
		"on_complete": on_complete,
	})

	if not _typewriter_active:
		process_typewriter()


func get_typewriter_delay(entry: Dictionary) -> float:
	var override_variant: Variant = entry.get("delay_override", -1.0)
	if override_variant is float and float(override_variant) >= 0.0:
		return float(override_variant)
	if override_variant is int and int(override_variant) >= 0:
		return float(override_variant)

	if bool(entry.get("adaptive_eta", false)):
		var remaining := estimate_narrator_remaining_seconds()
		if remaining <= 0.12:
			return 0.0031
		if remaining <= 0.55:
			return 0.0034
		if remaining <= 1.2:
			return 0.0038
		if remaining <= 2.2:
			return 0.0045
		return TYPEWRITER_DELAY_WAITING

	return TYPEWRITER_DELAY


func estimate_narrator_remaining_seconds() -> float:
	if _battle != null:
		if "_narrator_resolution_ready" in _battle and bool(_battle._narrator_resolution_ready):
			return 0.0
		if "_speculative_narrator_done" in _battle and bool(_battle._speculative_narrator_done):
			return 0.0
		if "_speculative_narrator_running" in _battle and bool(_battle._speculative_narrator_running) and "_speculative_narrator_started_msec" in _battle:
			var elapsed_spec := float(Time.get_ticks_msec() - int(_battle._speculative_narrator_started_msec)) / 1000.0
			return clampf(2.8 - elapsed_spec, 0.12, 2.8)
		if "current_phase" in _battle and str(_battle.current_phase) == "processing" and "_streaming_narrator_started_msec" in _battle:
			var started := int(_battle._streaming_narrator_started_msec)
			if started > 0:
				var elapsed_live := float(Time.get_ticks_msec() - started) / 1000.0
				return clampf(2.6 - elapsed_live, 0.12, 2.6)

	return 1.1


func start_typewriter_preset(
	rtl: RichTextLabel,
	full_text: String,
	preset: Dictionary,
	adaptive_eta: bool = false,
	delay_override: float = -1.0,
	on_complete: Callable = Callable()
) -> void:
	var resolved_preset := preset.duplicate(true)
	var effect_name = TextEffects.effect_name_from_preset(resolved_preset)

	if not effect_name.is_empty():
		var params_variant: Variant = resolved_preset.get("params", {})
		var params: Dictionary = params_variant if params_variant is Dictionary else {}
		params["len"] = full_text.length()
		resolved_preset["params"] = params

	start_typewriter(
		rtl,
		full_text,
		adaptive_eta,
		delay_override,
		TextEffects.effect_name_from_preset(resolved_preset),
		TextEffects.effect_params_from_preset(resolved_preset),
		on_complete
	)


func append_typewriter_preset(
	rtl: RichTextLabel,
	text: String,
	preset: Dictionary,
	adaptive_eta: bool = false,
	delay_override: float = -1.0,
	on_complete: Callable = Callable()
) -> void:
	var resolved_preset := preset.duplicate(true)
	var effect_name = TextEffects.effect_name_from_preset(resolved_preset)

	if not effect_name.is_empty():
		var params_variant: Variant = resolved_preset.get("params", {})
		var params: Dictionary = params_variant if params_variant is Dictionary else {}
		params["len"] = text.length()
		resolved_preset["params"] = params

	append_typewriter(
		rtl,
		text,
		adaptive_eta,
		delay_override,
		TextEffects.effect_name_from_preset(resolved_preset),
		TextEffects.effect_params_from_preset(resolved_preset),
		on_complete
	)


func append_streaming_narration(
	target: RichTextLabel,
	text: String,
	adaptive_eta: bool = true,
	delay_override: float = -1.0,
	on_complete: Callable = Callable()
) -> void:
	append_typewriter_preset(target, text, TextEffects.writing_narrator(), adaptive_eta, delay_override, on_complete)


func append_streaming_text(
	target: RichTextLabel,
	text: String,
	delay_override: float = -1.0,
	on_complete: Callable = Callable()
) -> void:
	append_typewriter(target, text, false, delay_override, "writing", "settle=0.85", on_complete)


func set_stamped_text_preset(rtl: RichTextLabel, text: String, preset: Dictionary) -> void:
	if not is_instance_valid(rtl):
		return

	ensure_text_effects(rtl)
	rtl.visible_characters = -1
	rtl.text = ""

	text = extract_dropcap_text(rtl, text)

	var resolved_preset := preset.duplicate(true)
	var effect_name = TextEffects.effect_name_from_preset(resolved_preset)

	if not effect_name.is_empty():
		var params_variant: Variant = resolved_preset.get("params", {})
		var params: Dictionary = params_variant if params_variant is Dictionary else {}
		params["len"] = text.length()
		resolved_preset["params"] = params

	var effect_params = TextEffects.effect_params_from_preset(resolved_preset)

	var stamped_parts: Array[String] = []
	for idx in range(text.length()):
		stamped_parts.append(build_effect_bbcode_char(text.substr(idx, 1), effect_name, effect_params))

	rtl.text = "".join(stamped_parts)
	_spawn_stamp_burst_effect(rtl)
	_play_ui_sfx(ACTION_STAMP_SFX_PATH, -8.0)


func process_typewriter() -> void:
	_typewriter_active = true

	while _typewriter_queue.size() > 0:
		var entry: Dictionary = _typewriter_queue[0]
		var rtl: RichTextLabel = entry["rtl"]
		var pending_text: String = str(entry.get("pending_text", ""))

		while int(entry["index"]) < pending_text.length():
			if not is_instance_valid(rtl):
				break

			var step_delay := get_typewriter_delay(entry)
			var next_char := pending_text.substr(int(entry["index"]), 1)
			var effect_name := str(entry.get("effect_name", "writing"))
			var effect_params := str(entry.get("effect_params", "settle=0.85"))

			var narrator_story_flow := uses_narrator_story_flow(rtl)
			if narrator_story_flow:
				var story_root := get_narrator_story_root(rtl)
				var resolved_before_write := resolve_narrator_overflow_rtl(story_root)
				if resolved_before_write != rtl:
					_update_external_streaming_target(rtl, resolved_before_write)
					rtl = resolved_before_write
					entry["rtl"] = rtl
					ensure_text_effects(rtl)
					rtl.visible_characters = -1

			var v_scroll := manuscript_scroll.get_v_scroll_bar()
			var should_follow := true
			if is_instance_valid(v_scroll):
				# Original behaviour: during typewriter, only follow if already near bottom.
				should_follow = (v_scroll.max_value - float(v_scroll.value)) <= 24.0

			rtl.append_text(build_effect_bbcode_char(next_char, effect_name, effect_params))
			append_narrator_full_text(rtl, next_char)

			if narrator_story_flow:
				var story_root_after_write := get_narrator_story_root(rtl)
				if rtl == story_root_after_write:
					var overflow_threshold := float(story_root_after_write.get_meta("narrator_overflow_height", 76.0))
					if story_root_after_write.get_content_height() > overflow_threshold:
						story_root_after_write.set_meta("narrator_overflow_pending", true)

				if is_whitespace_char(next_char) and bool(story_root_after_write.get_meta("narrator_overflow_pending", false)):
					story_root_after_write.set_meta("narrator_overflow_pending", false)
					story_root_after_write.set_meta("narrator_overflow_active", true)

					var resolved_rtl := resolve_narrator_overflow_rtl(story_root_after_write)
					if resolved_rtl != rtl:
						_update_external_streaming_target(rtl, resolved_rtl)
						rtl = resolved_rtl
						entry["rtl"] = rtl
						ensure_text_effects(rtl)
						rtl.visible_characters = -1

			_play_narrator_crystal_sfx(entry, next_char, effect_name, effect_params)

			entry["index"] = int(entry["index"]) + 1

			if should_follow and is_instance_valid(v_scroll):
				manuscript_scroll.scroll_vertical = int(v_scroll.max_value)
				update_manuscript_scroll_offset()

			await get_tree().create_timer(step_delay).timeout

		var on_complete_variant: Variant = entry.get("on_complete", Callable())
		if on_complete_variant is Callable:
			var on_complete := on_complete_variant as Callable
			if on_complete.is_valid():
				on_complete.call()

		_typewriter_queue.pop_front()

	_typewriter_active = false


func _update_external_streaming_target(old_rtl: RichTextLabel, new_rtl: RichTextLabel) -> void:
	if _battle == null:
		return
	if "_streaming_narrator_content" in _battle and _battle._streaming_narrator_content == old_rtl:
		_battle._streaming_narrator_content = new_rtl


func ensure_text_effects(rtl: RichTextLabel) -> void:
	TextEffects.ensure_installed(rtl)


func build_effect_bbcode_char(char_text: String, effect_name: String, effect_params: String = "") -> String:
	return TextEffects.wrap_character(char_text, effect_name, effect_params)


# ── Optional delegated effects/sfx ──

func _get_cached_ui_sfx(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _ui_sfx_cache.has(path):
		return _ui_sfx_cache[path]
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Could not load UI SFX: %s" % path)
		return null
	_ui_sfx_cache[path] = stream
	return stream


func _play_ui_sfx(path: String, volume_db: float = -8.0, pitch_scale: float = 1.0) -> void:
	if path.is_empty():
		return
	if _battle != null and _battle.has_method("_play_ui_sfx"):
		_battle._play_ui_sfx(path, volume_db, pitch_scale)
		return

	var stream := _get_cached_ui_sfx(path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _spawn_stamp_burst_effect(target: Control) -> void:
	if _battle != null and _battle.has_method("_spawn_stamp_burst_effect"):
		_battle._spawn_stamp_burst_effect(target)


func _is_narrator_writing_effect(effect_name: String, effect_params: String) -> bool:
	return effect_name == "writing" and effect_params.contains("drop=")


func _random_sfx_path(paths: Array) -> String:
	if paths.is_empty():
		return ""
	return str(paths[randi() % paths.size()])


func _play_narrator_crystal_hit(is_punctuation: bool = false, crackle: bool = false, ring_boost_db: float = 0.0, crackle_boost_db: float = 0.0) -> void:
	_play_ui_sfx(
		_random_sfx_path(NARRATOR_RING_SFX_PATHS),
		(-13.5 if not is_punctuation else -10.5) + ring_boost_db,
		randf_range(0.96, 1.05)
	)
	if crackle:
		_play_ui_sfx(
			_random_sfx_path(NARRATOR_CRACKLE_SFX_PATHS),
			(-20.5 if not is_punctuation else -17.5) + crackle_boost_db,
			randf_range(0.94, 1.04)
		)


func _play_narrator_crystal_sfx(entry: Dictionary, next_char: String, effect_name: String, effect_params: String) -> void:
	if _battle != null and _battle.has_method("_play_narrator_crystal_sfx"):
		_battle._play_narrator_crystal_sfx(entry, next_char, effect_name, effect_params)
		return

	if not _is_narrator_writing_effect(effect_name, effect_params):
		return
	if next_char.strip_edges().is_empty():
		return
	var tick := int(entry.get("narrator_sfx_tick", 0))
	entry["narrator_sfx_tick"] = tick + 1
	var is_punctuation := next_char in [".", ",", "!", "?", ";", ":"]
	_play_narrator_crystal_hit(is_punctuation, is_punctuation or (tick % 6 == 0 and randf() < 0.55))


func _play_input_crystal_sfx(typed_char: String) -> void:
	if typed_char.strip_edges().is_empty():
		return
	_input_crystal_tick += 1
	var is_punctuation := typed_char in [".", ",", "!", "?", ";", ":"]
	_play_narrator_crystal_hit(is_punctuation, is_punctuation or (_input_crystal_tick % 6 == 0 and randf() < 0.55))


func _play_input_erase_sfx() -> void:
	_play_ui_sfx(
		_random_sfx_path(NARRATOR_CRACKLE_SFX_PATHS),
		-16.0,
		randf_range(0.85, 0.95)
	)

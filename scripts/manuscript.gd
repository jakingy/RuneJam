extends VBoxContainer

signal action_submitted(text: String)
signal action_text_changed(text: String)

@onready var _battle: Node = $"../.."

@onready var manuscript_frame: PanelContainer = $ManuscriptFrame
@onready var manuscript_scroll: ScrollContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/ManuscriptScroll
@onready var writing: VBoxContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/ManuscriptScroll/Writing
@onready var input_padding: MarginContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding
@onready var input_bar: VBoxContainer = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding/InputBar
@onready var player_input: LineEdit = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding/InputBar/PlayerInput
@onready var play_btn: Button = $ManuscriptFrame/ManuscriptShell/PaperMargin/ManuscriptPaperSurface/ManuscriptPaperPadding/ManuscriptPaperContent/InputPadding/InputBar/PlayBtn

var typewriter_delay: float = 0.004
var typewriter_action_delay: float = 0.0023

var _typewriter_queue: Array[Dictionary] = []
var _typewriter_active: bool = false


func _ready() -> void:
    if _battle != null:
        if "TYPEWRITER_DELAY" in _battle:
            typewriter_delay = float(_battle.TYPEWRITER_DELAY)
        if "TYPEWRITER_DELAY_ACTION" in _battle:
            typewriter_action_delay = float(_battle.TYPEWRITER_DELAY_ACTION)

    if is_instance_valid(player_input):
        player_input.text_changed.connect(func(new_text: String) -> void:
            refresh_send_button_state()
            action_text_changed.emit(new_text)
        )

        player_input.text_submitted.connect(func(text: String) -> void:
            action_submitted.emit(text.strip_edges())
        )

    if is_instance_valid(play_btn):
        play_btn.pressed.connect(func() -> void:
            action_submitted.emit(get_input_text())
        )

    if is_instance_valid(writing):
        writing.resized.connect(scroll_to_bottom_deferred)

    refresh_send_button_state()


# ── Input API ──

func enable_input(placeholder: String = "Enter your action.") -> void:
    if not is_instance_valid(player_input):
        return

    player_input.editable = true
    player_input.placeholder_text = placeholder
    refresh_send_button_state()


func disable_input(placeholder: String = "") -> void:
    if not is_instance_valid(player_input):
        return

    player_input.editable = false
    if not placeholder.is_empty():
        player_input.placeholder_text = placeholder
    refresh_send_button_state()


func clear_input() -> void:
    if not is_instance_valid(player_input):
        return

    player_input.text = ""
    refresh_send_button_state()
    action_text_changed.emit("")


func set_input_text(text: String) -> void:
    if not is_instance_valid(player_input):
        return

    player_input.text = text
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
    return (
        is_instance_valid(player_input)
        and player_input.editable
        and not player_input.text.strip_edges().is_empty()
    )


func refresh_send_button_state() -> void:
    if not is_instance_valid(play_btn):
        return

    play_btn.disabled = not is_sendable()


# ── Message API ──

func add_system_message(text: String) -> PanelContainer:
    return add_plain_message(
        "System",
        text,
        Color(0, 0, 0, 0),
        Color(0.2, 0.2, 0.2),
        Color(0.55, 0.55, 0.55),
        false
    )


func add_team_a_message(text: String) -> PanelContainer:
    return add_plain_message(
        "Your Action",
        text,
        Color(0.086, 0.149, 0.251),
        Color(0.165, 0.29, 0.478),
        Color(0.75, 0.88, 1.0),
        false
    )


func add_team_b_message(text: String) -> PanelContainer:
    return add_plain_message(
        "Opponent",
        text,
        Color(0.165, 0.086, 0.086),
        Color(0.353, 0.165, 0.165),
        Color(1.0, 0.78, 0.72),
        true,
        typewriter_action_delay
    )


func add_cost_message(cost: int, band: String, summary: String) -> PanelContainer:
    var lines: Array[String] = []

    if cost > 0:
        lines.append("%d  (%s)" % [cost, band])

    if not summary.is_empty():
        lines.append(summary)

    return add_plain_message(
        "Cost Judge",
        "\n".join(lines),
        Color(0.102, 0.102, 0.165),
        Color(0.2, 0.2, 0.267),
        Color(0.78, 0.72, 1.0),
        true,
        typewriter_action_delay
    )


func add_analysis_message(text: String) -> PanelContainer:
    return add_plain_message(
        "Analysis",
        text,
        Color(0.102, 0.102, 0.165),
        Color(0.2, 0.2, 0.267),
        Color(0.75, 0.78, 1.0),
        true
    )


func add_narrator_message(text: String) -> PanelContainer:
    return add_plain_message(
        "Narrator",
        text,
        Color(0.141, 0.141, 0.141),
        Color(0.2, 0.2, 0.2),
        Color(0.95, 0.88, 0.7),
        true
    )


func add_thinking_message(category: String) -> PanelContainer:
    var messages := {
        "cost": "The referee deliberates...",
        "narrator": "The narrator weaves the tale...",
        "team_b": "Team B schemes...",
        "init": "The arena takes shape..."
    }

    var text: String = str(messages.get(category, "Thinking..."))

    return add_plain_message(
        "",
        text,
        Color(0, 0, 0, 0),
        Color(0.2, 0.2, 0.2),
        Color(0.55, 0.55, 0.55),
        false
    )


func add_streaming_narrator_message() -> RichTextLabel:
    return add_streaming_plain_message(
        "Narrator",
        Color(0.141, 0.141, 0.141),
        Color(0.2, 0.2, 0.2),
        Color(0.95, 0.88, 0.7)
    )


func add_streaming_analysis_message() -> RichTextLabel:
    return add_streaming_plain_message(
        "Analysis",
        Color(0.102, 0.102, 0.165),
        Color(0.2, 0.2, 0.267),
        Color(0.75, 0.78, 1.0)
    )


func append_streaming_narration(
    target: RichTextLabel,
    text: String,
    adaptive_eta: bool = true,
    delay_override: float = -1.0,
    on_complete: Callable = Callable()
) -> void:
    append_typewriter(target, text, delay_override, on_complete)


func append_streaming_text(
    target: RichTextLabel,
    text: String,
    delay_override: float = -1.0,
    on_complete: Callable = Callable()
) -> void:
    append_typewriter(target, text, delay_override, on_complete)


func remove_msg(panel: Variant) -> void:
    if not is_instance_valid(panel):
        return

    if panel is Node:
        var node := panel as Node

        # Messages are wrapped in an HBox row, so remove the row if possible.
        if is_instance_valid(node.get_parent()):
            node.get_parent().queue_free()
        else:
            node.queue_free()


func show_modal(title: String, text: String) -> void:
    var dialog := AcceptDialog.new()
    dialog.title = title
    dialog.dialog_text = text
    dialog.size = Vector2i(600, 500)
    add_child(dialog)
    dialog.popup_centered()

    dialog.confirmed.connect(func() -> void:
        dialog.queue_free()
    )

    dialog.canceled.connect(func() -> void:
        dialog.queue_free()
    )


# ── Message construction ──

func add_plain_message(
    label_text: String,
    text: String,
    bg_color: Color,
    border_color: Color,
    label_color: Color,
    typewrite: bool = false,
    delay_override: float = -1.0
) -> PanelContainer:
    var message := build_plain_message(label_text, bg_color, border_color, label_color)
    var panel: PanelContainer = message["panel"]
    var content: RichTextLabel = message["content"]

    add_msg_to_chat(panel)

    if typewrite:
        start_typewriter(content, text, delay_override)
    else:
        content.text = text
        content.visible_characters = -1

    return panel


func add_streaming_plain_message(
    label_text: String,
    bg_color: Color,
    border_color: Color,
    label_color: Color
) -> RichTextLabel:
    var message := build_plain_message(label_text, bg_color, border_color, label_color)
    add_msg_to_chat(message["panel"])
    return message["content"]


func build_plain_message(
    label_text: String,
    bg_color: Color,
    border_color: Color,
    label_color: Color
) -> Dictionary:
    var panel := create_msg_container(bg_color, border_color)

    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_theme_constant_override("separation", 4)

    if not label_text.is_empty():
        var label_node := Label.new()
        label_node.text = label_text
        label_node.add_theme_color_override("font_color", label_color)
        label_node.add_theme_font_size_override("font_size", 11)
        vbox.add_child(label_node)

    var content := create_rich_text("")
    vbox.add_child(content)

    panel.add_child(vbox)

    return {
        "panel": panel,
        "content": content,
    }


func create_msg_container(bg_color: Color, border_color: Color) -> PanelContainer:
    var panel := PanelContainer.new()

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


func create_rich_text(text: String) -> RichTextLabel:
    var content := RichTextLabel.new()
    content.bbcode_enabled = false
    content.fit_content = true
    content.scroll_active = false
    content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.selection_enabled = true
    content.context_menu_enabled = true
    content.shortcut_keys_enabled = true
    content.add_theme_color_override("default_color", Color(0, 0, 0, 0.85))
    content.add_theme_font_size_override("normal_font_size", 18)
    content.text = text
    content.visible_characters = -1
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return content


func wrap_with_alignment(panel: PanelContainer) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var spacer_left := Control.new()
    spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer_left.size_flags_stretch_ratio = 0.5

    var spacer_right := Control.new()
    spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer_right.size_flags_stretch_ratio = 0.5

    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_stretch_ratio = 6.0

    row.add_child(spacer_left)
    row.add_child(panel)
    row.add_child(spacer_right)

    return row


func add_msg_to_chat(panel: PanelContainer) -> void:
    if not is_instance_valid(writing):
        return

    var row := wrap_with_alignment(panel)
    writing.add_child(row)

    await get_tree().process_frame
    scroll_to_bottom()


# ── Scrolling ──

func scroll_to_bottom_deferred() -> void:
    scroll_to_bottom.call_deferred()


func scroll_to_bottom() -> void:
    if not is_instance_valid(manuscript_scroll):
        return

    var v_scroll := manuscript_scroll.get_v_scroll_bar()
    if is_instance_valid(v_scroll):
        manuscript_scroll.scroll_vertical = int(v_scroll.max_value)


func should_follow_scroll() -> bool:
    if not is_instance_valid(manuscript_scroll):
        return true

    var v_scroll := manuscript_scroll.get_v_scroll_bar()
    if not is_instance_valid(v_scroll):
        return true

    return (v_scroll.max_value - float(v_scroll.value)) <= 24.0


# ── Typewriter ──

func start_typewriter(
    rtl: RichTextLabel,
    full_text: String,
    delay_override: float = -1.0,
    on_complete: Callable = Callable()
) -> void:
    if not is_instance_valid(rtl):
        return

    rtl.text = ""
    rtl.visible_characters = -1

    _typewriter_queue.append({
        "rtl": rtl,
        "pending_text": full_text,
        "index": 0,
        "delay": delay_override if delay_override >= 0.0 else typewriter_delay,
        "on_complete": on_complete,
    })

    if not _typewriter_active:
        process_typewriter()


func append_typewriter(
    rtl: RichTextLabel,
    text: String,
    delay_override: float = -1.0,
    on_complete: Callable = Callable()
) -> void:
    if text.is_empty() or not is_instance_valid(rtl):
        return

    rtl.visible_characters = -1

    _typewriter_queue.append({
        "rtl": rtl,
        "pending_text": text,
        "index": 0,
        "delay": delay_override if delay_override >= 0.0 else typewriter_delay,
        "on_complete": on_complete,
    })

    if not _typewriter_active:
        process_typewriter()


func process_typewriter() -> void:
    _typewriter_active = true

    while _typewriter_queue.size() > 0:
        var entry: Dictionary = _typewriter_queue[0]
        var rtl: RichTextLabel = entry["rtl"]
        var pending_text: String = str(entry.get("pending_text", ""))
        var delay: float = float(entry.get("delay", typewriter_delay))

        while int(entry["index"]) < pending_text.length():
            if not is_instance_valid(rtl):
                break

            var follow := should_follow_scroll()
            var next_char := pending_text.substr(int(entry["index"]), 1)

            rtl.append_text(next_char)

            entry["index"] = int(entry["index"]) + 1

            if follow:
                scroll_to_bottom()

            await get_tree().create_timer(delay).timeout

        var on_complete_variant: Variant = entry.get("on_complete", Callable())
        if on_complete_variant is Callable:
            var on_complete: Callable = on_complete_variant
            if on_complete.is_valid():
                on_complete.call()

        _typewriter_queue.pop_front()

    _typewriter_active = false

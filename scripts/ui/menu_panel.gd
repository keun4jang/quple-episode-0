extends CanvasLayer
## MenuPanel — 가방/퀘스트/상점 화면이 공통으로 쓰는 창 틀.
## 각 화면은 이 스크립트를 상속하고 _build_content() / _refresh_content() 만 구현한다.

const COL_INK := Color("#1B1622")
const COL_PANEL := Color("#F7ECD8")
const COL_GOLD := Color("#F5D563")

var content: VBoxContainer
var _title_label: Label
var _subtitle_label: Label

func _ready() -> void:
    layer = 7
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _build_frame()
    _build_content()

func panel_title() -> String:
    return "메뉴"

func _build_content() -> void:
    pass

func _refresh_content() -> void:
    pass

func open() -> void:
    _refresh_content()
    visible = true
    get_tree().paused = true

func close() -> void:
    visible = false
    if not BattleSystem.in_battle:
        get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()

func _build_frame() -> void:
    var dim := ColorRect.new()
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.05, 0.04, 0.08, 0.75)
    add_child(dim)

    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 50
    panel.offset_right = -50
    panel.offset_top = 180
    panel.offset_bottom = -180
    panel.add_theme_stylebox_override("panel", pixel_box(COL_PANEL, COL_INK))
    add_child(panel)

    var margin := MarginContainer.new()
    set_margins(margin, 28)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 16)
    margin.add_child(box)

    var header := HBoxContainer.new()
    box.add_child(header)

    var title_col := VBoxContainer.new()
    title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_col)

    _title_label = make_label(panel_title(), 46, COL_INK)
    title_col.add_child(_title_label)

    _subtitle_label = make_label("", 26, Color("#6A5A4A"))
    title_col.add_child(_subtitle_label)

    var close_btn := Button.new()
    close_btn.text = "닫기"
    close_btn.custom_minimum_size = Vector2(150, 90)
    close_btn.add_theme_font_size_override("font_size", 30)
    close_btn.add_theme_color_override("font_color", COL_PANEL)
    close_btn.add_theme_stylebox_override("normal", pixel_box(Color("#4A3D63"), COL_INK))
    close_btn.add_theme_stylebox_override("hover", pixel_box(Color("#61507F"), COL_INK))
    close_btn.add_theme_stylebox_override("pressed", pixel_box(Color("#31294A"), COL_INK))
    close_btn.pressed.connect(func():
        if AudioManager: AudioManager.ui_select()
        close())
    header.add_child(close_btn)

    var sep := ColorRect.new()
    sep.custom_minimum_size = Vector2(0, 5)
    sep.color = COL_INK
    box.add_child(sep)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 14)
    scroll.add_child(content)

func set_subtitle(text: String) -> void:
    if _subtitle_label:
        _subtitle_label.text = text

func clear_content() -> void:
    for c in content.get_children():
        c.queue_free()

# ── 공용 위젯 ────────────────────────────────────────
func make_label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func pixel_box(bg: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(5)
    sb.set_corner_radius_all(0)
    return sb

func make_card(border: Color = COL_INK) -> PanelContainer:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", pixel_box(Color("#EADFC6"), border))
    return card

func make_small_button(text: String, cb: Callable, enabled: bool = true) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(160, 84)
    b.disabled = not enabled
    b.add_theme_font_size_override("font_size", 28)
    b.add_theme_color_override("font_color", COL_PANEL)
    b.add_theme_stylebox_override("normal", pixel_box(Color("#4A3D63"), COL_INK))
    b.add_theme_stylebox_override("hover", pixel_box(Color("#61507F"), COL_INK))
    b.add_theme_stylebox_override("pressed", pixel_box(Color("#31294A"), COL_INK))
    b.add_theme_stylebox_override("disabled", pixel_box(Color("#B4AFA4"), Color("#8A8578")))
    b.pressed.connect(func():
        if AudioManager: AudioManager.ui_select()
        cb.call())
    return b

func set_margins(m: MarginContainer, v: int) -> void:
    m.add_theme_constant_override("margin_left", v)
    m.add_theme_constant_override("margin_right", v)
    m.add_theme_constant_override("margin_top", v)
    m.add_theme_constant_override("margin_bottom", v)

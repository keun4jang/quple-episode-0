extends CanvasLayer
## HudUI — 화면에 항상 떠 있는 정보/메뉴 바.
## 왼쪽 위에 스탯 → 메뉴 버튼 그리드 → 목표를 세로로 쌓고, 오른쪽 위에 반짝 조각을 둔다.
## 아래쪽 절반은 조이스틱·상호작용 버튼 자리라 비워둔다.
##
## 버튼 크기 근거: 터치 최소 권장치는 Apple HIG 44pt / Material 48dp.
## 1080폭 세로 화면은 대략 3배 밀도라 환산하면 132~144px이므로 150×124로 잡았다.
## 버튼 사이 간격 14px도 같은 기준(8dp≈24px의 절반 이상)을 지킨다.

const COL_INK := Color("#1B1622")
const COL_PANEL := Color("#F7ECD8")

const BTN_SIZE := Vector2(150, 124)
const BTN_GAP := 14
const GRID_COLUMNS := 4
const HUD_LEFT := 24
const PANEL_WIDTH := 642  # 150*4 + 14*3

## 왼쪽 위 메뉴 — 이름은 다른 게임에서 쓰는 일반적인 용어로 통일한다
const MENU_ITEMS := [
    {"label": "인벤토리", "action": "panel", "target": "inventory"},
    {"label": "장비", "action": "panel", "target": "equip"},
    {"label": "스킬", "action": "panel", "target": "skill"},
    {"label": "퀘스트", "action": "panel", "target": "quest"},
    {"label": "상점", "action": "panel", "target": "shop"},
    {"label": "앨범", "action": "album", "target": ""},
    {"label": "설정", "action": "settings", "target": ""},
]

var _hp_fill: ColorRect
var _mp_fill: ColorRect
var _exp_fill: ColorRect
var _lv_label: Label
var _hp_label: Label
var _coin_label: Label
var _goal_label: Label
var _toast_box: VBoxContainer

func _ready() -> void:
    layer = 5
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    PlayerStats.stats_changed.connect(_refresh)
    PlayerStats.leveled_up.connect(func(lv): toast("마음 레벨 %d 달성!" % lv, Color("#F5D563")))
    QuestSystem.quest_completed.connect(func(qid, reward):
        toast("퀘스트 완료 — %s\n%s" % [QuestSystem.QUESTS[qid].name, reward], Color("#7FBF6A")))
    Episode0State.state_changed.connect(func(_s): _refresh_goal())
    _refresh()
    _refresh_goal()

func _build() -> void:
    # ── 왼쪽 위 스탯 패널 ──
    var panel := PanelContainer.new()
    panel.position = Vector2(HUD_LEFT, 24)
    panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
    panel.add_theme_stylebox_override("panel", _pixel_box(Color(0.96, 0.93, 0.85, 0.92), COL_INK))
    add_child(panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 14)
    box.add_child(top_row)

    _lv_label = _label("LV 1", 34, COL_INK)
    top_row.add_child(_lv_label)

    _hp_label = _label("", 26, Color("#6A5A4A"))
    _hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    top_row.add_child(_hp_label)

    _hp_fill = _add_bar(box, 26, Color("#E0645A"))
    _mp_fill = _add_bar(box, 18, Color("#6C9BD4"))
    _exp_fill = _add_bar(box, 10, Color("#F5D563"))

    # ── 오른쪽 위 화폐 ──
    var coin_panel := PanelContainer.new()
    coin_panel.position = Vector2(766, 24)
    coin_panel.custom_minimum_size = Vector2(290, 0)
    coin_panel.add_theme_stylebox_override("panel", _pixel_box(Color(0.16, 0.13, 0.2, 0.92), Color("#F5D563")))
    add_child(coin_panel)

    var cmargin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        cmargin.add_theme_constant_override("margin_" + side, 12)
    coin_panel.add_child(cmargin)

    _coin_label = _label("✦ 0", 32, Color("#F5D563"))
    _coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cmargin.add_child(_coin_label)

    # ── 왼쪽 위 메뉴 버튼 그리드 (스탯 바로 아래) ──
    var menu := GridContainer.new()
    menu.columns = GRID_COLUMNS
    menu.position = Vector2(HUD_LEFT, 200)
    menu.add_theme_constant_override("h_separation", BTN_GAP)
    menu.add_theme_constant_override("v_separation", BTN_GAP)
    add_child(menu)
    for item in MENU_ITEMS:
        _menu_button(menu, item)

    # ── 현재 목표 (버튼 그리드 아래) ──
    var goal_panel := PanelContainer.new()
    goal_panel.position = Vector2(HUD_LEFT, 486)
    goal_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
    goal_panel.add_theme_stylebox_override("panel", _pixel_box(Color(0.16, 0.13, 0.2, 0.80), Color("#6E5F8A")))
    add_child(goal_panel)

    var gmargin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        gmargin.add_theme_constant_override("margin_" + side, 12)
    goal_panel.add_child(gmargin)

    _goal_label = _label("", 24, Color("#FFF6E4"))
    _goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    gmargin.add_child(_goal_label)

    # ── 토스트(알림) 영역 ──
    _toast_box = VBoxContainer.new()
    _toast_box.position = Vector2(140, 400)
    _toast_box.custom_minimum_size = Vector2(800, 0)
    _toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
    _toast_box.add_theme_constant_override("separation", 10)
    _toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_toast_box)

func toast(text: String, color: Color = Color("#FFF6E4")) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _pixel_box(Color(0.12, 0.1, 0.16, 0.94), color))
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    panel.add_child(margin)
    var lbl := _label(text, 28, color)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    margin.add_child(lbl)
    _toast_box.add_child(panel)
    panel.modulate.a = 0.0
    var t := create_tween()
    t.tween_property(panel, "modulate:a", 1.0, 0.2)
    t.tween_interval(2.4)
    t.tween_property(panel, "modulate:a", 0.0, 0.4)
    t.tween_callback(panel.queue_free)

func _refresh() -> void:
    _lv_label.text = "LV %d" % PlayerStats.level
    _hp_label.text = "체력 %d/%d   마음력 %d/%d" % [
        PlayerStats.hp, PlayerStats.max_hp, PlayerStats.mp, PlayerStats.max_mp]
    _coin_label.text = "✦ %d" % PlayerStats.coins
    _set_bar(_hp_fill, float(PlayerStats.hp) / float(PlayerStats.max_hp))
    _set_bar(_mp_fill, float(PlayerStats.mp) / float(PlayerStats.max_mp))
    _set_bar(_exp_fill, float(PlayerStats.exp_points) / float(max(1, PlayerStats.exp_to_next())))

func _refresh_goal() -> void:
    var goals: Dictionary = {
        0: "불 켜진 사무실로 가기", 1: "회사 안으로 들어가기", 2: "사무실로 가기",
        3: "애인과 이야기하기", 4: "조금 더 둘러보기", 5: "대표실 근처로 가보기",
        6: "애인에게 돌아가기", 7: "여행 물품 3개 챙기기", 8: "사원증 반납하기",
        9: "회사 밖으로 나가기", 10: "첫 사진 찍기", 11: "여행 앨범 확인하기", 12: "여행 시작!",
    }
    var s: int = int(Episode0State.current_state)
    _goal_label.text = "목표 — " + goals.get(s, "")

# ── 위젯 도우미 ──────────────────────────────────────
func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _add_bar(parent: Control, height: int, color: Color) -> ColorRect:
    var wrap := Control.new()
    wrap.custom_minimum_size = Vector2(0, height)
    wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg := ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.2, 0.17, 0.15, 0.5)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(bg)
    var fill := ColorRect.new()
    fill.set_anchors_preset(Control.PRESET_FULL_RECT)
    fill.color = color
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(fill)
    parent.add_child(wrap)
    return fill

func _set_bar(fill: ColorRect, ratio: float) -> void:
    fill.anchor_right = clamp(ratio, 0.0, 1.0)

func _menu_button(parent: Control, item: Dictionary) -> void:
    var b := Button.new()
    b.text = item.label
    b.custom_minimum_size = BTN_SIZE
    b.add_theme_font_size_override("font_size", 28)
    b.add_theme_color_override("font_color", COL_PANEL)
    b.add_theme_stylebox_override("normal", _pixel_box(Color(0.29, 0.24, 0.39, 0.92), COL_INK))
    b.add_theme_stylebox_override("hover", _pixel_box(Color(0.38, 0.31, 0.5, 0.95), COL_INK))
    b.add_theme_stylebox_override("pressed", _pixel_box(Color(0.19, 0.16, 0.29, 0.95), COL_INK))
    b.pressed.connect(_on_menu_pressed.bind(String(item.action), String(item.target)))
    parent.add_child(b)

func _on_menu_pressed(action: String, target: String) -> void:
    if AudioManager:
        AudioManager.ui_select()
    match action:
        "panel":
            GameUI.open_panel(target)
        "album":
            GameUI.open_album()
        "settings":
            GameUI.open_settings()

func _pixel_box(bg: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(5)
    sb.set_corner_radius_all(0)
    return sb

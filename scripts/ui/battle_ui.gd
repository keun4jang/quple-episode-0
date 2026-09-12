extends CanvasLayer
## BattleUI — 그림자 감정과의 전투 화면. 전부 코드로 만든다(외부 이미지 없음).
## 픽셀 톤을 유지하려고 모서리를 각지게, 테두리를 두껍게 쓴다.

const CELL := 22.0          # 적 픽셀 한 칸 크기
const COL_INK := Color("#1B1622")
const COL_PANEL := Color("#F7ECD8")
const COL_PANEL_DARK := Color("#2A2336")
const COL_HP := Color("#E0645A")
const COL_MP := Color("#6C9BD4")
const COL_EXP := Color("#F5D563")
const COL_GOLD := Color("#F5D563")

var _root: Control
var _backdrop: ColorRect
var _flash: ColorRect
var _enemy_holder: Control
var _enemy_sprite: Control
var _enemy_name: Label
var _enemy_title: Label
var _enemy_hp_fill: ColorRect
var _enemy_hp_label: Label
var _msg_label: Label
var _player_hp_fill: ColorRect
var _player_mp_fill: ColorRect
var _player_stat_label: Label
var _action_row: HBoxContainer
var _submenu: PanelContainer
var _submenu_box: VBoxContainer

var _busy: bool = false
var _time: float = 0.0
var _shake: float = 0.0

func _ready() -> void:
    layer = 8
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _build()
    BattleSystem.battle_started.connect(_on_battle_started)

func _process(delta: float) -> void:
    if not visible:
        return
    _time += delta
    # 적 둥실둥실 + 배경 맥동
    # (_enemy_holder는 VBoxContainer의 자식이라 위치가 컨테이너에 덮어써진다 — 스프라이트를 직접 움직인다)
    if _enemy_sprite and is_instance_valid(_enemy_sprite):
        _enemy_sprite.position.y = sin(_time * 1.8) * 10.0
        _enemy_sprite.rotation = sin(_time * 1.1) * 0.02
    if _backdrop:
        _backdrop.color.a = 0.88 + sin(_time * 2.0) * 0.03
    # 화면 흔들림 감쇠
    if _shake > 0.0:
        _shake = max(0.0, _shake - delta * 38.0)
        _root.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
    elif _root.position != Vector2.ZERO:
        _root.position = Vector2.ZERO

# ── 화면 구성 ────────────────────────────────────────
func _build() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    _backdrop = ColorRect.new()
    _backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _backdrop.color = Color(0.08, 0.06, 0.12, 0.9)
    _root.add_child(_backdrop)

    # 배경 장식 — 떠다니는 작은 별(픽셀 점)
    for i in range(28):
        var star := ColorRect.new()
        var s: float = 4.0 + (i % 3) * 3.0
        star.size = Vector2(s, s)
        star.position = Vector2(
            40 + fposmod(i * 137.0, 1000.0),
            120 + fposmod(i * 313.0, 1500.0)
        )
        star.color = Color(1, 1, 1, 0.10 + (i % 4) * 0.05)
        star.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _root.add_child(star)

    # ── 적 영역 ──
    var enemy_box := VBoxContainer.new()
    enemy_box.position = Vector2(60, 150)
    enemy_box.custom_minimum_size = Vector2(960, 0)
    enemy_box.add_theme_constant_override("separation", 10)
    enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
    _root.add_child(enemy_box)

    _enemy_name = _make_label("", 56, Color("#FFF6E4"))
    _enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_box.add_child(_enemy_name)

    _enemy_title = _make_label("", 24, Color("#C8B8E0"))
    _enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_box.add_child(_enemy_title)

    # 적 체력바
    var hp_wrap := _make_bar_wrap(Vector2(620, 34))
    enemy_box.add_child(hp_wrap)
    _enemy_hp_fill = hp_wrap.get_meta("fill")
    _enemy_hp_fill.color = COL_HP
    _enemy_hp_label = _make_label("", 22, Color("#FFF6E4"))
    _enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_box.add_child(_enemy_hp_label)

    # 적 스프라이트 자리
    _enemy_holder = Control.new()
    _enemy_holder.custom_minimum_size = Vector2(0, 330)
    _enemy_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    enemy_box.add_child(_enemy_holder)

    # ── 메시지 창 ──
    var msg_panel := PanelContainer.new()
    msg_panel.position = Vector2(50, 980)
    msg_panel.custom_minimum_size = Vector2(980, 170)
    msg_panel.add_theme_stylebox_override("panel", _pixel_box(COL_PANEL_DARK, Color("#6E5F8A")))
    _root.add_child(msg_panel)

    var msg_margin := MarginContainer.new()
    _set_margins(msg_margin, 26)
    msg_panel.add_child(msg_margin)

    _msg_label = _make_label("", 30, Color("#FFF6E4"))
    _msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    msg_margin.add_child(_msg_label)

    # ── 플레이어 패널 ──
    var pp := PanelContainer.new()
    pp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    pp.offset_left = 40
    pp.offset_right = -40
    pp.offset_top = -560
    pp.offset_bottom = -40
    pp.add_theme_stylebox_override("panel", _pixel_box(COL_PANEL, COL_INK))
    _root.add_child(pp)

    var pmargin := MarginContainer.new()
    _set_margins(pmargin, 24)
    pp.add_child(pmargin)

    var pbox := VBoxContainer.new()
    pbox.add_theme_constant_override("separation", 12)
    pmargin.add_child(pbox)

    _player_stat_label = _make_label("", 28, COL_INK)
    pbox.add_child(_player_stat_label)

    var hp_row := _make_bar_wrap(Vector2(0, 30))
    _player_hp_fill = hp_row.get_meta("fill")
    _player_hp_fill.color = COL_HP
    pbox.add_child(hp_row)

    var mp_row := _make_bar_wrap(Vector2(0, 22))
    _player_mp_fill = mp_row.get_meta("fill")
    _player_mp_fill.color = COL_MP
    pbox.add_child(mp_row)

    _action_row = HBoxContainer.new()
    _action_row.add_theme_constant_override("separation", 16)
    _action_row.custom_minimum_size = Vector2(0, 130)
    pbox.add_child(_action_row)

    _add_action("싸운다", _on_press_fight)
    _add_action("가방", _on_press_bag)
    _add_action("거리두기", _on_press_flee)

    # ── 하위 메뉴(스킬/아이템) ──
    _submenu = PanelContainer.new()
    _submenu.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _submenu.offset_left = 60
    _submenu.offset_right = -60
    _submenu.offset_top = -1120
    _submenu.offset_bottom = -580
    _submenu.add_theme_stylebox_override("panel", _pixel_box(COL_PANEL, COL_INK))
    _submenu.visible = false
    _root.add_child(_submenu)

    var sm_margin := MarginContainer.new()
    _set_margins(sm_margin, 20)
    _submenu.add_child(sm_margin)

    var sm_scroll := ScrollContainer.new()
    sm_margin.add_child(sm_scroll)

    _submenu_box = VBoxContainer.new()
    _submenu_box.add_theme_constant_override("separation", 10)
    _submenu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sm_scroll.add_child(_submenu_box)

    # ── 화면 플래시 ──
    _flash = ColorRect.new()
    _flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flash.color = Color(1, 1, 1, 0)
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_flash)

# ── 전투 시작 ────────────────────────────────────────
func _on_battle_started(enemy: Dictionary) -> void:
    visible = true
    get_tree().paused = true
    _busy = true
    _submenu.visible = false
    _time = 0.0

    _enemy_name.text = enemy.name
    _enemy_title.text = enemy.title
    _build_enemy_sprite(enemy.id)
    _refresh_bars()

    if AudioManager:
        AudioManager.play_bgm("tense")

    # 등장 연출: 흰 플래시 → 적이 위에서 툭 떨어짐
    await _do_flash(0.9, 0.25)
    _shake = 14.0
    _msg_label.text = "%s이(가) 나타났다!" % enemy.name
    await get_tree().create_timer(0.7).timeout
    _msg_label.text = enemy.line
    await get_tree().create_timer(0.6).timeout
    _msg_label.text = "어떻게 할까?"
    _busy = false
    _set_actions_enabled(true)

func _build_enemy_sprite(id: String) -> void:
    # 이전 전투에서 쓴 스프라이트와 그 정렬용 래퍼까지 전부 치운다
    for c in _enemy_holder.get_children():
        c.queue_free()
    _enemy_sprite = null
    var def: Dictionary = BattleSystem.enemy_def(id)
    if def.is_empty():
        return
    var palette := PixelArt.enemy_palette(def.colors)
    _enemy_sprite = PixelArt.build(def.art, palette, CELL)
    var w: float = _enemy_sprite.custom_minimum_size.x
    _enemy_sprite.position = Vector2(-w * 0.5, 0)
    var center := Control.new()
    center.set_anchors_preset(Control.PRESET_CENTER_TOP)
    center.anchor_left = 0.5
    center.anchor_right = 0.5
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_enemy_sprite)
    _enemy_holder.add_child(center)
    # 등장 스케일 연출
    _enemy_sprite.scale = Vector2(0.2, 0.2)
    _enemy_sprite.pivot_offset = Vector2(w * 0.5, _enemy_sprite.custom_minimum_size.y * 0.5)
    var t := create_tween()
    t.tween_property(_enemy_sprite, "scale", Vector2(1, 1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── 행동 버튼 ────────────────────────────────────────
func _on_press_fight() -> void:
    if _busy:
        return
    _open_submenu("skill")

func _on_press_bag() -> void:
    if _busy:
        return
    _open_submenu("item")

func _on_press_flee() -> void:
    if _busy:
        return
    _submenu.visible = false
    await _run_turn(BattleSystem.player_flee())

func _open_submenu(mode: String) -> void:
    for c in _submenu_box.get_children():
        c.queue_free()
    if mode == "skill":
        for id in BattleSystem.available_skills():
            var s: Dictionary = BattleSystem.SKILLS[id]
            var cost := "MP %d" % s.mp if s.mp > 0 else "MP 0"
            var btn := _make_list_button("%s   (%s)\n%s" % [s.name, cost, s.desc])
            btn.disabled = PlayerStats.mp < s.mp
            btn.pressed.connect(func(): _choose_skill(id))
            _submenu_box.add_child(btn)
    else:
        var any := false
        for item_id in PlayerStats.inventory.keys():
            if not ItemDB.is_consumable(item_id):
                continue
            any = true
            var item: Dictionary = ItemDB.get_item(item_id)
            var n: int = PlayerStats.item_count(item_id)
            var btn := _make_list_button("%s ×%d\n%s" % [item.name, n, item.desc])
            btn.pressed.connect(func(): _choose_item(item_id))
            _submenu_box.add_child(btn)
        if not any:
            var empty := _make_label("가방이 비어 있어요.", 28, COL_INK)
            _submenu_box.add_child(empty)
    var back := _make_list_button("뒤로")
    back.pressed.connect(func(): _submenu.visible = false)
    _submenu_box.add_child(back)
    _submenu.visible = true
    if AudioManager:
        AudioManager.ui_select()

func _choose_skill(id: String) -> void:
    if _busy:
        return
    _submenu.visible = false
    await _run_turn(BattleSystem.player_use_skill(id))

func _choose_item(id: String) -> void:
    if _busy:
        return
    _submenu.visible = false
    await _run_turn(BattleSystem.player_use_item(id))

# ── 턴 연출 ──────────────────────────────────────────
func _run_turn(events: Array) -> void:
    _busy = true
    _set_actions_enabled(false)
    for ev in events:
        await _play_event(ev)
    _refresh_bars()
    if BattleSystem.in_battle:
        _msg_label.text = "어떻게 할까?"
        _busy = false
        _set_actions_enabled(true)

func _play_event(ev: Dictionary) -> void:
    match ev.type:
        "text":
            _msg_label.text = ev.msg
            await get_tree().create_timer(0.55).timeout
        "damage_enemy":
            if AudioManager:
                AudioManager.play_sfx("confirm")
            await _do_flash(0.5, 0.08)
            _shake = 18.0 if ev.get("crit", false) else 10.0
            _hit_sprite()
            _spawn_damage_number(ev.amount, ev.get("crit", false), true)
            _refresh_bars()
            if ev.get("crit", false):
                _msg_label.text = "회심의 일격! %d" % ev.amount
            await get_tree().create_timer(0.5).timeout
        "damage_player":
            if AudioManager:
                AudioManager.play_sfx("page_turn")
            _backdrop.color = Color(0.35, 0.05, 0.08, 0.9)
            _shake = 22.0 if ev.get("heavy", false) else 12.0
            _spawn_damage_number(ev.amount, ev.get("heavy", false), false)
            _refresh_bars()
            await get_tree().create_timer(0.45).timeout
            _backdrop.color = Color(0.08, 0.06, 0.12, 0.9)
        "heal":
            if ev.amount > 0:
                _spawn_float_text("+%d" % ev.amount, Color("#7FBF6A"), false)
            _refresh_bars()
            await get_tree().create_timer(0.35).timeout
        "buff":
            _spawn_float_text("힘 +%d" % ev.amount, COL_GOLD, false)
            await get_tree().create_timer(0.35).timeout
        "enemy_defeated":
            await _dissolve_enemy()
        "victory":
            await _show_victory(ev)
        "defeat":
            await _show_defeat()
        "flee_success":
            await _close_battle("flee")

func _hit_sprite() -> void:
    if not _enemy_sprite or not is_instance_valid(_enemy_sprite):
        return
    var t := create_tween()
    t.tween_property(_enemy_sprite, "modulate", Color(3, 3, 3, 1), 0.06)
    t.tween_property(_enemy_sprite, "modulate", Color(1, 1, 1, 1), 0.12)

func _dissolve_enemy() -> void:
    _msg_label.text = "%s이(가) 옅어진다..." % BattleSystem.enemy.name
    if _enemy_sprite and is_instance_valid(_enemy_sprite):
        # 픽셀이 하나씩 흩어지는 연출
        var pixels := _enemy_sprite.get_children()
        pixels.shuffle()
        for i in range(pixels.size()):
            var px: ColorRect = pixels[i]
            var t := create_tween()
            t.set_parallel(true)
            t.tween_property(px, "position", px.position + Vector2(randf_range(-160, 160), randf_range(-220, -60)), 0.8)
            t.tween_property(px, "modulate:a", 0.0, 0.8)
        await get_tree().create_timer(0.85).timeout
    await _do_flash(0.8, 0.2)

func _show_victory(ev: Dictionary) -> void:
    var result: Dictionary = BattleSystem.apply_victory(ev)
    if AudioManager:
        AudioManager.play_sfx("clear_fanfare")
    var lines: Array = ["걷어냈다!", "경험치 +%d   반짝 조각 +%d" % [ev.exp, ev.coins]]
    for item_id in ev.drops:
        lines.append("%s 획득!" % ItemDB.item_name(item_id))
    for lv in result.levels:
        lines.append("마음 레벨 %d! 더 단단해졌어요." % lv)
    _refresh_bars()
    for line in lines:
        _msg_label.text = line
        await get_tree().create_timer(0.85).timeout
    await _close_battle("victory")

func _show_defeat() -> void:
    _msg_label.text = "잠시 주저앉았다..."
    await get_tree().create_timer(0.9).timeout
    _msg_label.text = "하지만 괜찮아. 숨을 고르고 다시 일어선다."
    await get_tree().create_timer(1.1).timeout
    await _close_battle("defeat")

func _close_battle(result: String) -> void:
    var t := create_tween()
    t.tween_property(_root, "modulate:a", 0.0, 0.35)
    await t.finished
    visible = false
    _root.modulate.a = 1.0
    _busy = false
    get_tree().paused = false
    BattleSystem.end_battle(result)
    _restore_field_bgm()

func _restore_field_bgm() -> void:
    if not AudioManager:
        return
    var scene := get_tree().current_scene
    if scene == null:
        return
    match scene.name:
        "CompanyFront3D":
            AudioManager.play_bgm("night")
        "BossDoorHallway3D":
            AudioManager.play_bgm("tense")
        "MainMenu3D":
            AudioManager.play_bgm("menu")
        _:
            AudioManager.play_bgm("indoor")

# ── 연출 도우미 ──────────────────────────────────────
func _do_flash(strength: float, dur: float) -> void:
    _flash.color = Color(1, 1, 1, strength)
    var t := create_tween()
    t.tween_property(_flash, "color:a", 0.0, dur)
    await t.finished

func _spawn_damage_number(amount: int, big: bool, on_enemy: bool) -> void:
    var color := Color("#FFF6E4") if on_enemy else COL_HP
    if big:
        color = COL_GOLD if on_enemy else Color("#FF3A2A")
    _spawn_float_text(str(amount), color, on_enemy, big)

func _spawn_float_text(text: String, color: Color, on_enemy: bool, big: bool = false) -> void:
    var lbl := _make_label(text, 84 if big else 62, color)
    lbl.z_index = 50
    var x := 540.0 + randf_range(-70, 70)
    var y := 520.0 if on_enemy else 1240.0
    lbl.position = Vector2(x, y)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _root.add_child(lbl)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(lbl, "position:y", y - 130, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    t.tween_property(lbl, "modulate:a", 0.0, 0.7)
    t.chain().tween_callback(lbl.queue_free)

func _refresh_bars() -> void:
    if BattleSystem.in_battle and not BattleSystem.enemy.is_empty():
        var e: Dictionary = BattleSystem.enemy
        _set_bar(_enemy_hp_fill, float(e.hp) / float(e.max_hp))
        _enemy_hp_label.text = "%d / %d" % [e.hp, e.max_hp]
    _set_bar(_player_hp_fill, float(PlayerStats.hp) / float(PlayerStats.max_hp))
    _set_bar(_player_mp_fill, float(PlayerStats.mp) / float(PlayerStats.max_mp))
    _player_stat_label.text = "LV %d   체력 %d/%d   마음력 %d/%d   ✦%d" % [
        PlayerStats.level, PlayerStats.hp, PlayerStats.max_hp,
        PlayerStats.mp, PlayerStats.max_mp, PlayerStats.coins
    ]

func _set_bar(fill: ColorRect, ratio: float) -> void:
    if fill == null:
        return
    fill.anchor_right = clamp(ratio, 0.0, 1.0)

func _set_actions_enabled(on: bool) -> void:
    for c in _action_row.get_children():
        if c is Button:
            c.disabled = not on

# ── 위젯 빌더 ────────────────────────────────────────
func _make_label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", COL_INK)
    l.add_theme_constant_override("outline_size", 6)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _pixel_box(bg: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(6)
    sb.set_corner_radius_all(0)
    return sb

func _make_bar_wrap(min_size: Vector2) -> Control:
    var wrap := Control.new()
    wrap.custom_minimum_size = min_size
    wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg := ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.12, 0.1, 0.16, 0.85)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(bg)
    var fill := ColorRect.new()
    fill.set_anchors_preset(Control.PRESET_FULL_RECT)
    fill.anchor_right = 1.0
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(fill)
    wrap.set_meta("fill", fill)
    return wrap

func _add_action(text: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size = Vector2(0, 120)
    b.add_theme_font_size_override("font_size", 38)
    b.add_theme_color_override("font_color", COL_PANEL)
    b.add_theme_stylebox_override("normal", _pixel_box(Color("#4A3D63"), COL_INK))
    b.add_theme_stylebox_override("hover", _pixel_box(Color("#61507F"), COL_INK))
    b.add_theme_stylebox_override("pressed", _pixel_box(Color("#31294A"), COL_INK))
    b.add_theme_stylebox_override("disabled", _pixel_box(Color("#5A5460"), Color("#3A3640")))
    b.pressed.connect(cb)
    _action_row.add_child(b)

func _make_list_button(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 110)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 28)
    b.add_theme_color_override("font_color", COL_INK)
    b.add_theme_stylebox_override("normal", _pixel_box(Color("#EADFC6"), COL_INK))
    b.add_theme_stylebox_override("hover", _pixel_box(Color("#FFF4DC"), COL_INK))
    b.add_theme_stylebox_override("pressed", _pixel_box(Color("#D6C9AC"), COL_INK))
    b.add_theme_stylebox_override("disabled", _pixel_box(Color("#C9C4B8"), Color("#8A8578")))
    return b

func _set_margins(m: MarginContainer, v: int) -> void:
    m.add_theme_constant_override("margin_left", v)
    m.add_theme_constant_override("margin_right", v)
    m.add_theme_constant_override("margin_top", v)
    m.add_theme_constant_override("margin_bottom", v)

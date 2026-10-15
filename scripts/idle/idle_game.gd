extends Control
## 진짜 행복 (키우기) - 한 화면. 풍경 위에서 쿼카가 알아서 싸우고, 화면을 톡 치면 한 번 더 때린다.
## 아래 큰 버튼 셋(캐릭터·장비·스테이지) + [보스 도전]. 규칙은 전부 IdleState/IdleFight 에 있고,
## 여기는 그리기·연출·버튼만 한다 (`docs/redesign-idle.md`).

const SAVE_EVERY := 10.0
const MENU_PATH := "res://scenes/menu/MainMenu3D.tscn"
const INK := Color("#4A3428")
const PAPER := Color("#FFF8EA")
const CREAM := Color("#FFF1D2")
const EDGE := Color("#C9955B")
const GOLD := Color("#FFC94A")
const HERO_PX := 4.0
const MON_PX := 4.4
const BOSS_PX := 5.2
## 몬스터 사이를 걸을 때 풍경이 흐르는 빠르기 (px/초).
const WALK_SPEED := 340.0

## 직업별 필살기 빛깔.
const SKILL_COL := {"warrior": Color("#FFB347"), "mage": Color("#8FB5FF"), "archer": Color("#9BE38B"),
	"thief": Color("#C49BFF")}

var fight := IdleFight.new()

var _world: Control
var _bg: IdleBackdrop
var _hero: IdleActor
var _mon: IdleActor
var _fx: IdleFx
var _flash_rect: ColorRect
var _hero_bar: ProgressBar
var _mon_bar: ProgressBar
var _mon_name: Label

var _stage_lbl: Label
var _wave_dots: Control
var _lv_lbl: Label
var _power_lbl: Label
var _xp_bar: ProgressBar
var _coin_lbl: Label
var _coin_pill: PanelContainer
var _boss_box: Control
var _boss_bar: ProgressBar
var _boss_name: Label
var _btns: Dictionary = {}
var _gear_dot: Control
var _boss_btn: Button
var _auto_btn: Button
var _menu_btn: Button
var _tap_hint: Label

var _dim: ColorRect
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _tab := ""
var _banner: Label
var _toast_lbl: Label

var _say_layer: Control
var _say_lbl: Label
var _say_hint: Label
var _say_lines: Array = []
var _say_done: Callable
var _say_at := 0.0

var _t := 0.0
var _save_t := 0.0
var _shake := 0.0
var _freeze := 0.0
var _walk := 0.0
var _end_t := 0.0
var _blocked := false
var _tapped_once := false
var _skill_job := ""
var _skill_i := 0
var _mon_tint := Color.WHITE
var _tweens: Dictionary = {}
var _hero_home := Vector2.ZERO
var _mon_home := Vector2.ZERO


func _ready() -> void:
	add_to_group("idle_game")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not IdleState.load_save():
		IdleState.reset()
	_build()
	resized.connect(_layout)
	_layout()
	AudioManager.play_bgm("room")
	var r := IdleState.claim_offline(int(Time.get_unix_time_from_system()))
	if not IdleState.seen_intro:
		IdleState.seen_intro = true
		_say(["여기는 꿈결이에요.", "처음엔 화면을 톡톡 쳐서 함께 싸워요.",
			"레벨 5가 되면 쿼카가 알아서 싸우는 자동사냥이 열려요.", "장비를 키워서 더 먼 곳으로 보내 주세요."],
			func(): _after_intro(r))
	else:
		_after_intro(r)


func _after_intro(r: Dictionary) -> void:
	if not r.is_empty():
		var h := int(r["minutes"]) / 60
		var m := int(r["minutes"]) % 60
		var t := ("%d시간 %d분" % [h, m]) if h > 0 else ("%d분" % m)
		var lines := ["자는 동안 %s 싸웠어요." % t, "꿈조각 %s개를 모았어요." % _num(int(r["coins"]))]
		if int(r.get("levels", 0)) > 0:
			lines.append("레벨도 올랐어요!")
		_say(lines, _begin)
	else:
		_begin()


func _begin() -> void:
	IdleState.save(int(Time.get_unix_time_from_system()))
	_start_stage()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		IdleState.save(int(Time.get_unix_time_from_system()))


# ── 만들기 ───────────────────────────────────────────────────────────

func _build() -> void:
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_bg = IdleBackdrop.new()
	_world.add_child(_bg)
	_hero = IdleActor.new()
	_hero.px = HERO_PX
	_hero.flip = true
	_world.add_child(_hero)
	_hero.set_sheet("res://assets/sprites/hero-walk.png")
	_mon = IdleActor.new()
	_mon.px = MON_PX
	_world.add_child(_mon)
	_hero_bar = _bar(Color("#7AD98A"), Vector2(110, 14))
	_world.add_child(_hero_bar)
	_mon_bar = _bar(Color("#FF7B84"), Vector2(130, 14))
	_world.add_child(_mon_bar)
	_mon_name = _label("", 22, Color.WHITE, true)
	_mon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.add_child(_mon_name)
	_fx = IdleFx.new()
	_world.add_child(_fx)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	# ── 위 줄
	var sp := _pill()
	sp.name = "StagePill"
	add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sp.add_child(sv)
	_stage_lbl = _label("", 28)
	sv.add_child(_stage_lbl)
	_wave_dots = Control.new()
	_wave_dots.custom_minimum_size = Vector2(200, 18)
	_wave_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_dots.draw.connect(_draw_dots)
	sv.add_child(_wave_dots)

	var lp := _pill()
	lp.name = "LvPill"
	add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	lp.add_child(lv)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 14)
	lv.add_child(lh)
	_lv_lbl = _label("", 28)
	lh.add_child(_lv_lbl)
	_power_lbl = _label("", 20, Color("#8A6A50"))
	_power_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	lh.add_child(_power_lbl)
	_xp_bar = _bar(GOLD, Vector2(220, 12))
	lv.add_child(_xp_bar)

	_coin_pill = _pill()
	add_child(_coin_pill)
	_coin_lbl = _label("", 30, Color("#B9771E"))
	_coin_pill.add_child(_coin_lbl)

	_menu_btn = _button("메뉴", 22)
	_menu_btn.pressed.connect(_leave)
	add_child(_menu_btn)

	# 우두머리 체력 (위 가운데, 크게)
	_boss_box = VBoxContainer.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_name = _label("", 26, Color.WHITE, true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color("#FF5A6A"), Vector2(520, 22))
	_boss_box.add_child(_boss_bar)

	_tap_hint = _label("화면을 톡 치면 한 번 더 때려요!", 24, Color.WHITE, true)
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tap_hint)

	# ── 아래 줄
	var names := {"char": "캐릭터", "gear": "장비", "stage": "스테이지"}
	for k in ["char", "gear", "stage"]:
		var b := _button(names[k], 30)
		b.pressed.connect(_open_tab.bind(k))
		add_child(b)
		_btns[k] = b
	_gear_dot = Control.new()
	_gear_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gear_dot.size = Vector2(26, 26)
	_gear_dot.draw.connect(func() -> void:
		_gear_dot.draw_circle(Vector2(13, 13), 12.0, Color.WHITE)
		_gear_dot.draw_circle(Vector2(13, 13), 9.0, Color("#FF5A5A")))
	(_btns["gear"] as Button).add_child(_gear_dot)
	_auto_btn = _button("", 26)
	_auto_btn.pressed.connect(_on_auto)
	add_child(_auto_btn)
	_boss_btn = _button("보스 도전!", 30, Color("#FF8A7A"), Color("#B8473C"), Color.WHITE)
	_boss_btn.pressed.connect(_on_boss)
	_boss_btn.visible = false
	add_child(_boss_btn)

	# ── 창 하나
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.08, 0.1, 0.4)
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_tab())
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(PAPER, EDGE, 26, 5, 18))
	_panel.visible = false
	add_child(_panel)
	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_body)

	_banner = _label("", 54, Color.WHITE, true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)
	_toast_lbl = _label("", 28, Color.WHITE, true)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.modulate.a = 0.0
	add_child(_toast_lbl)

	# ── 한 문장씩 (입력은 `_input` 에서 받는다 - 위에 무엇이 덮여 있든 터치가 닿게)
	_say_layer = Control.new()
	_say_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_say_layer.visible = false
	add_child(_say_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.13, 0.10, 0.20, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_layer.add_child(dim)
	_say_lbl = _label("", 44, Color.WHITE, true)
	_say_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_say_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_layer.add_child(_say_lbl)
	_say_hint = _label("▼ 화면을 눌러 주세요", 24, Color(1, 1, 1, 0.75))
	_say_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_say_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_layer.add_child(_say_hint)


func _layout() -> void:
	var w := size.x
	var h := size.y
	_world.size = size
	_bg.size = size
	_flash_rect.size = size
	var gy := h * IdleBackdrop.GROUND
	_hero_home = Vector2(w * 0.37, gy + 30)
	_mon_home = Vector2(w * 0.64, gy + 30)
	_hero.position = _hero_home
	_mon.position = _mon_home

	var sp := get_node("StagePill") as Control
	sp.position = Vector2(18, 14)
	var lp := get_node("LvPill") as Control
	lp.position = Vector2(300, 14)
	_menu_btn.size = Vector2(110, 60)
	_menu_btn.position = Vector2(w - 128, 16)
	_coin_pill.position = Vector2(w - 128 - 16 - 250, 14)
	_coin_pill.custom_minimum_size = Vector2(250, 0)
	_boss_box.position = Vector2(w * 0.5 - 260, 96)
	_boss_box.size = Vector2(520, 60)
	_tap_hint.position = Vector2(0, h * 0.25)
	_tap_hint.size = Vector2(w, 40)

	var bw := 200.0
	var bh := 86.0
	var x := 18.0
	for k in ["char", "gear", "stage"]:
		var b: Button = _btns[k]
		b.position = Vector2(x, h - bh - 14)
		b.size = Vector2(bw, bh)
		x += bw + 12.0
	_gear_dot.position = Vector2(bw - 30, 4)
	_boss_btn.size = Vector2(250, bh)
	_boss_btn.position = Vector2(w - 268, h - bh - 14)
	_auto_btn.size = Vector2(170, bh)
	_auto_btn.position = Vector2(w - 268 - 12 - 170, h - bh - 14)

	_dim.size = size
	var pw := minf(w - 60.0, 1120.0)
	_panel.position = Vector2((w - pw) * 0.5, 92)
	_panel.size = Vector2(pw, h - 92 - bh - 30)
	_panel.custom_minimum_size = _panel.size

	_banner.position = Vector2(0, h * 0.26)
	_banner.size = Vector2(w, 70)
	_toast_lbl.position = Vector2(0, h * 0.36)
	_toast_lbl.size = Vector2(w, 44)
	_say_layer.size = size
	_say_hint.position = Vector2(0, h - 80)
	_say_hint.size = Vector2(w, 40)


func _box(bg: Color, border: Color, radius := 22, bw := 4, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0.2, 0.12, 0.08, 0.22)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s


func _pill() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := _box(Color(1, 0.98, 0.93, 0.88), Color(1, 1, 1, 0.9), 20, 3, 10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	p.add_theme_stylebox_override("panel", s)
	return p


func _bar(col: Color, sz: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = sz
	b.size = sz
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(sz.y * 0.5))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.22, 0.16, 0.18, 0.55)
	bg.set_corner_radius_all(int(sz.y * 0.5))
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.85)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


func _label(t: String, fs: int, col := INK, outline := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.22, 0.14, 0.16))
		l.add_theme_constant_override("outline_size", maxi(6, fs / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, fs: int, bg := CREAM, border := EDGE, font_col := INK) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_pressed_color", font_col)
	b.add_theme_color_override("font_hover_color", font_col)
	b.add_theme_color_override("font_disabled_color", Color("#A89A8C"))
	var n := _box(bg, border, 24, 4, 8)
	var p := _box(bg.darkened(0.12), border, 24, 4, 8)
	p.shadow_size = 2
	var d := _box(Color("#EDE6DC"), Color("#C9BDB0"), 24, 4, 8)
	d.shadow_size = 0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func() -> void: b.scale = Vector2(0.96, 0.96))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	return b


# ── 전투 흐름 ────────────────────────────────────────────────────────

func _start_stage() -> void:
	fight.start(IdleState.stage)
	var info := fight.info
	_bg.zone = int(info["zone"])
	var boss := bool(info["boss"])
	_mon.set_sheet("res://assets/sprites/s-%s-walk.png" % String(info["kind"]))
	_mon.px = BOSS_PX if boss else MON_PX
	_mon_tint = _tint_of(_mon.tex)
	_mon.visible = false
	_mon_bar.visible = false
	_mon_name.visible = false
	_hero.rotation = 0.0
	_hero.modulate = Color.WHITE
	_hero.position = _hero_home
	_walk = IdleFight.SPAWN_DELAY
	_boss_box.visible = false
	_banner_show(IdleData.stage_label(IdleState.stage), Color.WHITE)
	_refresh()


## 몬스터 그림의 대표 빛깔 (부서질 때 파편 색).
func _tint_of(tex: Texture2D) -> Color:
	if tex == null:
		return Color.WHITE
	var img := tex.get_image()
	if img == null:
		return Color.WHITE
	if img.is_compressed():
		img.decompress()
	var sum := Vector3.ZERO
	var n := 0
	var cw := img.get_width() / 4
	var ch := img.get_height() / 3
	for y in range(0, ch, 2):
		for x in range(0, cw, 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	if n == 0:
		return Color.WHITE
	sum /= float(n)
	return Color(sum.x, sum.y, sum.z).lightened(0.1)


func _process(dt: float) -> void:
	_t += dt
	_shake = maxf(0.0, _shake - dt * 60.0)
	_world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - dt * 2.5)
	_hero.walking = _walk > 0.0
	if _walk > 0.0:
		_walk -= dt
		_bg.scroll += WALK_SPEED * dt
	var manual := not IdleState.auto_active()
	_tap_hint.text = "화면을 톡톡 쳐서 공격해요!" if manual else "화면을 톡 치면 한 번 더 때려요!"
	_tap_hint.visible = (manual or not _tapped_once) and not fight.done and fight.state == "fight" \
		and not _panel.visible and not _blocked
	_tap_hint.modulate.a = 0.6 + 0.4 * sin(_t * 4.0)
	if IdleState.boss_failed:
		var s := 1.0 + 0.04 * sin(_t * 6.0)
		_boss_btn.scale = Vector2(s, s)
	_update_bars()
	_save_t += dt
	if _save_t >= SAVE_EVERY:
		_save_t = 0.0
		IdleState.save(int(Time.get_unix_time_from_system()))
	if _blocked:
		return
	if _freeze > 0.0:
		_freeze -= dt
		return
	if _end_t > 0.0:
		_end_t -= dt
		if _end_t <= 0.0:
			_finish()
		return
	if fight.done:
		return
	for e in fight.tick(minf(dt, 0.25)):
		_on_event(e)
	if fight.done:
		_end_t = 1.3 if fight.result == "defeat" else (1.1 if bool(fight.info["boss"]) else 0.35)


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _blocked or _panel.visible:
		return
	accept_event()
	var evs := fight.tap()
	if evs.is_empty():
		return
	_tapped_once = true
	var at: Vector2 = (e as InputEventMouseButton).position - _world.position
	_fx.ring(at, 6.0, 40.0, Color(1, 1, 1, 0.9), 5.0, 0.25)
	for ev in evs:
		_on_event(ev)


func _on_event(e: Dictionary) -> void:
	match String(e["k"]):
		"spawn":
			_on_spawn(e)
		"skill":
			_skill_job = IdleState.job
			_skill_i = 0
			_fx.text(_hero_head() + Vector2(0, -30), String(e["name"]) + "!", SKILL_COL.get(_skill_job, GOLD), 46, 1.1)
			_flash(0.25)
		"hero_hit":
			_on_hero_hit(e)
		"mon_hit":
			_on_mon_hit(e)
		"kill":
			_on_kill(e)
		"level_up":
			_fx.pillar(_hero_home, GOLD)
			_fx.ring(_hero_home + Vector2(0, -40), 20.0, 180.0, GOLD, 12.0, 0.6)
			_fx.burst(_hero_home + Vector2(0, -40), GOLD, 22, 420.0, 10.0, 0.9, 200.0, "star", 0.0, true)
			_fx.text(_hero_head() + Vector2(0, -50), "LEVEL UP!", GOLD, 56, 1.4, 0.0, 90.0)
			AudioManager.souvenir_get()
			if int(e["level"]) >= IdleData.AUTO_LV and int(e["level"]) - 1 < IdleData.AUTO_LV:
				IdleState.auto_on = true
				_banner_show("자동사냥이 열렸어요!", GOLD)
				_toast("이제 쿼카가 알아서 싸워요")
			_refresh()
		"defeat":
			AudioManager.battle_defeat()
			_tween(_hero, "rotation", -1.45, 0.4)
			_hero.flash = 0.8
			_hero.flash_col = Color("#FF8080")
			_fx.text(_hero_head(), "털썩…", Color("#FFD0D0"), 36, 1.2)


func _on_spawn(e: Dictionary) -> void:
	var boss := bool(e["boss"])
	_mon.visible = true
	_mon.modulate = Color.WHITE
	_mon.scale = Vector2.ONE
	_mon.flip = false
	_mon.position = _mon_home + Vector2(300, 0)
	_mon.walking = true
	var tw := _tween(_mon, "position", _mon_home, 0.3)
	tw.finished.connect(func() -> void: _mon.walking = false)
	var nm := String(IdleData.MOB_NAMES.get(String(e["kind"]), ""))
	if boss:
		_boss_name.text = "우두머리 · " + nm
		_boss_box.visible = true
		_banner_show("우두머리 등장!", Color("#FF8A8A"))
		_shake = 14.0
		AudioManager.sky_crack()
	else:
		_mon_bar.visible = true
		_mon_name.visible = true
		_mon_name.text = nm
	_refresh()


func _mon_mid() -> Vector2:
	return _mon_home + Vector2(0, -_mon.height() * 0.5)


func _mon_head() -> Vector2:
	return _mon_home + Vector2(randf_range(-30, 30), -_mon.height() - 6)


func _hero_head() -> Vector2:
	return _hero_home + Vector2(0, -_hero.height() - 10)


func _on_hero_hit(e: Dictionary) -> void:
	var dmg := _num(int(e["dmg"]))
	var crit := bool(e["crit"])
	if bool(e.get("tap", false)):
		_lunge(_hero, _hero_home, 34.0, 0.05, 0.12)
		_fx.slash(_mon_mid() + Vector2(randf_range(-20, 20), randf_range(-20, 20)), randf_range(-PI, PI), 44.0,
			Color("#BFEFFF"), 10.0, 0.18)
		_fx.burst(_mon_mid(), Color("#E6FBFF"), 6, 260.0, 6.0, 0.4)
		_hit_mon(0.6, 10.0)
		_fx.text(_mon_head(), dmg, Color("#BFEFFF"), 30, 0.7)
		AudioManager.battle_weak_hit()
		return
	if bool(e["skill"]):
		_skill_hit(dmg, crit)
		return
	# 기본 공격 - 달려들어 벤다
	_lunge(_hero, _hero_home, 70.0, 0.06, 0.18, 6.0)
	var ang := randf_range(-0.6, 0.6) + (PI if randf() < 0.5 else 0.0)
	if crit:
		_fx.slash(_mon_mid(), ang, 78.0, GOLD, 24.0, 0.26)
		_fx.slash(_mon_mid(), ang + 1.4, 64.0, Color.WHITE, 16.0, 0.22, 0.05)
		_fx.burst(_mon_mid(), GOLD, 18, 480.0, 10.0, 0.6, 700.0, "star")
		_fx.text(_mon_head() + Vector2(0, -36), "치명타!", Color("#FFE9A0"), 28, 0.8)
		_fx.text(_mon_head(), dmg, GOLD, 62, 1.0)
		_shake = 10.0
		_freeze = 0.06
		_hit_mon(1.0, 26.0)
	else:
		_fx.slash(_mon_mid(), ang, 60.0, Color("#FFF6D8"), 16.0, 0.22)
		_fx.burst(_mon_mid(), Color("#FFF2C4"), 10, 360.0, 7.0, 0.45)
		_fx.text(_mon_head(), dmg, Color.WHITE, 42, 0.85)
		_hit_mon(0.9, 16.0)
	AudioManager.battle_hit()


func _skill_hit(dmg: String, crit: bool) -> void:
	var col: Color = SKILL_COL.get(_skill_job, GOLD)
	var i := _skill_i
	_skill_i += 1
	match _skill_job:
		"warrior":
			_lunge(_hero, _hero_home, 120.0, 0.08, 0.25, 26.0)
			_fx.ring(_mon_mid(), 30.0, 220.0, col, 16.0, 0.45)
			_fx.ring(_mon_mid(), 10.0, 120.0, Color.WHITE, 8.0, 0.3)
			_fx.burst(_mon_mid(), col, 24, 560.0, 12.0, 0.7, 800.0, "star")
			_fx.text(_mon_head(), dmg, col, 66, 1.1)
			_shake = 18.0
			_freeze = 0.08
			_hit_mon(1.0, 40.0)
			AudioManager.battle_hit()
		"mage":
			var d := 0.32
			_tween(_hero, "position", _hero_home + Vector2(0, -36), 0.12).chain().tween_property(
				_hero, "position", _hero_home, 0.2)
			_fx.meteor(_mon_mid() + Vector2(-420, -520), _mon_mid(), col, d)
			_fx.text(_mon_head(), dmg, col.lightened(0.3), 70, 1.1, d)
			_later(d, func() -> void:
				_shake = 22.0
				_flash(0.35)
				_hit_mon(1.0, 34.0)
				AudioManager.battle_hit())
		"archer":
			var d := 0.07 * i
			_later(d, func() -> void: _lunge(_hero, _hero_home, -14.0, 0.04, 0.08))
			_fx.arrow(_hero_home + Vector2(30, -_hero.height() * 0.55), _mon_mid() + Vector2(0, randf_range(-24, 24)),
				col, 0.12, d)
			_fx.burst(_mon_mid(), col, 8, 320.0, 7.0, 0.4, 700.0, "sq", d + 0.12)
			_fx.text(_mon_head() + Vector2(0, -i * 30), dmg, col.lightened(0.2), 40 if not crit else 54, 0.9, d + 0.12)
			_later(d + 0.12, func() -> void:
				_shake = maxf(_shake, 6.0)
				_hit_mon(0.8, 10.0)
				AudioManager.battle_weak_hit())
		"thief":
			var tw := _tween(_hero, "position", _mon_home + Vector2(90, 0), 0.08)
			tw.tween_callback(func() -> void: _hero.flip = false)
			tw.tween_interval(0.12)
			tw.tween_callback(func() -> void: _hero.flip = true)
			tw.tween_property(_hero, "position", _hero_home, 0.16)
			_fx.slash(_mon_mid(), -0.8, 70.0, col, 20.0, 0.25, 0.06)
			_fx.slash(_mon_mid(), 0.8 + PI, 70.0, Color.WHITE, 16.0, 0.25, 0.12)
			_fx.burst(_mon_mid(), col, 20, 480.0, 9.0, 0.6, 700.0, "star", 0.08)
			_fx.text(_mon_head() + Vector2(0, -36), "급소!", Color("#E9D8FF"), 28, 0.8, 0.08)
			_fx.text(_mon_head(), dmg, col.lightened(0.2), 66, 1.1, 0.08)
			_later(0.08, func() -> void:
				_shake = 14.0
				_freeze = 0.06
				_hit_mon(1.0, 24.0)
				AudioManager.battle_hit())
		_:
			_fx.text(_mon_head(), dmg, GOLD, 50, 1.0)
			_hit_mon(1.0, 20.0)


func _hit_mon(flash: float, knock: float) -> void:
	if not _mon.visible:
		return
	_mon.flash = flash
	_mon.flash_col = Color.WHITE
	_mon.squash = Vector2(0.82, 1.12)
	_lunge(_mon, _mon_home, knock, 0.05, 0.16)


func _on_mon_hit(e: Dictionary) -> void:
	_lunge(_mon, _mon_home, -80.0, 0.08, 0.2, 10.0)
	_later(0.07, func() -> void:
		_hero.flash = 0.7
		_hero.flash_col = Color("#FF7070")
		_hero.squash = Vector2(1.15, 0.86)
		_lunge(_hero, _hero_home, -18.0, 0.05, 0.15)
		_fx.burst(_hero_home + Vector2(0, -_hero.height() * 0.5), Color("#FF8A8A"), 8, 300.0, 7.0, 0.4)
		_fx.text(_hero_head() + Vector2(randf_range(-20, 20), 0), _num(int(e["dmg"])), Color("#FF9A9A"), 34, 0.8)
		_shake = maxf(_shake, 5.0)
		AudioManager.battle_hurt())


func _on_kill(e: Dictionary) -> void:
	var boss := bool(e["boss"])
	var mid := _mon_mid()
	_kill_tween(_mon)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mon, "modulate:a", 0.0, 0.25)
	tw.tween_property(_mon, "scale", Vector2(1.3, 0.4), 0.25)
	tw.chain().tween_callback(func() -> void:
		_mon.visible = false
		_mon.scale = Vector2.ONE)
	_mon.flash = 1.0
	_mon_bar.visible = false
	_mon_name.visible = false
	_fx.burst(mid, _mon_tint, 30 if not boss else 60, 520.0, 12.0 if not boss else 16.0, 0.8, 800.0)
	_fx.burst(mid, Color.WHITE, 10, 300.0, 6.0, 0.5, 300.0, "star")
	var coin_to := _coin_pill.global_position + _coin_pill.size * 0.5 - _world.global_position
	_fx.burst(mid, GOLD, 6 if not boss else 16, 300.0, 11.0, 1.0, 600.0, "coin", 0.05, true, coin_to)
	_fx.text(mid + Vector2(0, -40), "+%s ✦" % _num(int(e["coin"])), GOLD, 30, 1.0, 0.1, 50.0)
	if boss:
		_shake = 24.0
		_flash(0.5)
		_freeze = 0.15
		_fx.ring(mid, 20.0, 320.0, GOLD, 18.0, 0.7)
		_banner_show("우두머리를 물리쳤어요!", GOLD)
	var d: Array = e["drop"]
	if not d.is_empty():
		_toast("새 장비! %s" % IdleData.item_name(String(d[0]), int(d[1]), IdleState.job))
		_fx.pillar(mid + Vector2(0, _mon.height() * 0.5), Color("#9AE0FF"), 1.2)
		AudioManager.souvenir_get()
	else:
		AudioManager.pickup()
	_walk = IdleFight.SPAWN_DELAY
	_refresh()


func _finish() -> void:
	if fight.result == "clear":
		var was_boss := bool(fight.info["boss"])
		var o := IdleState.on_clear()
		var rw: Array = o.get("reward", [])
		if not rw.is_empty():
			_toast("우두머리 선물! %s" % IdleData.item_name(String(rw[0]), int(rw[1]), IdleState.job))
		elif was_boss and bool(o["new_best"]):
			_toast("새 구역이 열렸어요!")
		IdleState.save(int(Time.get_unix_time_from_system()))
		if o.has("ending"):
			IdleState.ending_seen = true
			IdleState.save()
			_say(["마지막 우두머리까지 물리쳤어요!", "꿈결에 다시 고요한 아침이 와요.",
				"고마워요.", "쿼카는 더 먼 곳으로 계속 걸어가요."], _start_stage)
			return
	else:
		IdleState.on_defeat()
		_toast("한 걸음 물러나 힘을 모아요")
		IdleState.save(int(Time.get_unix_time_from_system()))
	_start_stage()
	if _tab == "stage":
		_fill_stage()


func _refresh_auto() -> void:
	var sb_on := _box(Color("#B8E6A0"), Color("#5E9A4A"), 24, 4, 8)
	if not IdleState.can_auto():
		_auto_btn.text = "자동\nLV%d부터" % IdleData.AUTO_LV
		_auto_btn.add_theme_stylebox_override("normal", _box(Color("#E9E2D6"), Color("#BFB2A2"), 24, 4, 8))
		_auto_btn.add_theme_stylebox_override("hover", _box(Color("#E9E2D6"), Color("#BFB2A2"), 24, 4, 8))
	elif IdleState.auto_on:
		_auto_btn.text = "자동 켜짐"
		_auto_btn.add_theme_stylebox_override("normal", sb_on)
		_auto_btn.add_theme_stylebox_override("hover", sb_on)
	else:
		_auto_btn.text = "자동 꺼짐"
		_auto_btn.add_theme_stylebox_override("normal", _box(CREAM, EDGE, 24, 4, 8))
		_auto_btn.add_theme_stylebox_override("hover", _box(CREAM, EDGE, 24, 4, 8))


func _on_auto() -> void:
	AudioManager.ui_click()
	if not IdleState.can_auto():
		_toast("레벨 %d부터 자동사냥을 할 수 있어요" % IdleData.AUTO_LV)
		_shake_btn(_auto_btn)
		return
	IdleState.auto_on = not IdleState.auto_on
	_toast("자동사냥을 켰어요" if IdleState.auto_on else "자동사냥을 껐어요 - 화면을 톡톡 쳐서 싸워요")
	IdleState.save()
	_refresh_auto()


func _shake_btn(b: Control) -> void:
	var x := b.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(b, "position:x", x + (10.0 if i % 2 == 0 else -10.0), 0.04)
	tw.tween_property(b, "position:x", x, 0.04)


func _on_boss() -> void:
	if IdleState.challenge_boss():
		AudioManager.ui_confirm()
		_end_t = 0.0
		_start_stage()


# ── 연출 도우미 ──────────────────────────────────────────────────────

func _kill_tween(n: Node) -> void:
	var old = _tweens.get(n)
	if old != null and (old as Tween).is_valid():
		(old as Tween).kill()


func _tween(n: Node, prop: String, to, dur: float) -> Tween:
	_kill_tween(n)
	var tw := create_tween()
	tw.tween_property(n, prop, to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[n] = tw
	return tw


## 집 자리에서 dx 만큼 튀어 나갔다가(hop 만큼 뛰어) 돌아온다.
func _lunge(a: IdleActor, home: Vector2, dx: float, out_t: float, back_t: float, hop := 0.0) -> void:
	if a == _hero and fight.done and fight.result == "defeat":
		return
	var tw := _tween(a, "position", home + Vector2(dx, -hop), out_t)
	tw.tween_property(a, "position", home, back_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if absf(dx) > 40.0:
		a.squash = Vector2(1.2, 0.85)


func _later(d: float, f: Callable) -> void:
	if d <= 0.0:
		f.call()
		return
	# 트윈은 이 노드와 함께 사라진다 - 장면을 떠난 뒤에 불리지 않게.
	create_tween().tween_callback(f).set_delay(d)


func _flash(a: float) -> void:
	_flash_rect.color = Color(1, 1, 1, maxf(_flash_rect.color.a, a))


func _banner_show(t: String, col: Color) -> void:
	_banner.text = t
	_banner.add_theme_color_override("font_color", col)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.3, 1.3)
	_banner.pivot_offset = _banner.size * 0.5
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


func _toast(t: String) -> void:
	_toast_lbl.text = t
	_toast_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_toast_lbl, "modulate:a", 0.0, 0.5)


func _update_bars() -> void:
	_hero_bar.max_value = maxf(1.0, fight.hero_max)
	_hero_bar.value = fight.hero_hp
	_hero_bar.position = _hero.position + Vector2(-55, -_hero.height() - 26)
	_hero_bar.visible = not fight.info.is_empty()
	_mon_bar.max_value = maxf(1.0, fight.mon_max)
	_mon_bar.value = fight.mon_hp
	_mon_bar.position = _mon.position + Vector2(-65, -_mon.height() - 24)
	_mon_name.size = Vector2(240, 30)
	_mon_name.position = _mon.position + Vector2(-120, 14)
	_boss_bar.max_value = maxf(1.0, fight.mon_max)
	_boss_bar.value = fight.mon_hp


func _draw_dots() -> void:
	var info := fight.info
	if info.is_empty():
		return
	if bool(info["boss"]):
		_wave_dots.draw_string(_fx.font, Vector2(0, 16), "우두머리", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color("#D0453C"))
		return
	var killed := fight.total - fight.left
	for i in IdleData.WAVE:
		var c := Vector2(10 + i * 26, 9)
		_wave_dots.draw_circle(c, 9.0, Color("#E8D9C2"))
		if i < killed:
			_wave_dots.draw_circle(c, 7.0, Color("#F2A33A"))
		elif i == killed:
			_wave_dots.draw_circle(c, 5.0, Color("#D0453C"))


func _refresh() -> void:
	_stage_lbl.text = IdleData.stage_label(IdleState.stage)
	_wave_dots.queue_redraw()
	_coin_lbl.text = "✦ %s" % _num(IdleState.coins)
	_lv_lbl.text = "LV %d" % IdleState.level
	_power_lbl.text = "전투력 %s" % _num(IdleState.power())
	_xp_bar.max_value = IdleData.exp_need(IdleState.level)
	_xp_bar.value = IdleState.xp if IdleState.level < IdleData.LEVEL_MAX else _xp_bar.max_value
	_boss_btn.visible = IdleState.boss_failed
	_refresh_auto()
	if not IdleState.boss_failed:
		_boss_btn.scale = Vector2.ONE
	var can := false
	for s in IdleData.SLOTS:
		if IdleState.can_enhance(String(s)):
			can = true
			break
	_gear_dot.visible = can
	if _tab == "gear" and _panel.visible:
		_refresh_gear_buttons()


static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


# ── 창 셋 ────────────────────────────────────────────────────────────

func _open_tab(k: String) -> void:
	AudioManager.ui_click()
	if _tab == k and _panel.visible:
		_close_tab()
		return
	_tab = k
	_panel.visible = true
	_dim.visible = true
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_fill()


func _close_tab() -> void:
	_tab = ""
	_panel.visible = false
	_dim.visible = false


func _fill() -> void:
	match _tab:
		"char":
			_fill_char()
		"gear":
			_fill_gear()
		"stage":
			_fill_stage()


func _clear_body() -> void:
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)
		c.queue_free()


func _title(t: String, sub := "") -> void:
	var row := HBoxContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(t, 36))
	if sub != "":
		v.add_child(_label(sub, 20, Color("#9A7A60")))
	row.add_child(v)
	var x := _button("닫기", 24)
	x.custom_minimum_size = Vector2(120, 58)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(_close_tab)
	row.add_child(x)
	_panel_body.add_child(row)


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color("#FFFDF6"), Color("#EAD3B0"), 18, 3, 12))
	return p


func _fill_char() -> void:
	_clear_body()
	_title("캐릭터", "레벨이 오르면 저절로 세져요")
	var h := IdleState.hero()
	var j: Dictionary = IdleData.JOBS[IdleState.job]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	_panel_body.add_child(top)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 150)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _hero.tex != null:
		var a := AtlasTexture.new()
		a.atlas = _hero.tex
		a.region = Rect2(Vector2.ZERO, _hero.cell)
		portrait.texture = a
	top.add_child(portrait)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	top.add_child(info)
	info.add_child(_label("LV %d  %s" % [IdleState.level, String(j["name"])], 34))
	info.add_child(_label("전투력 %s" % _num(IdleState.power()), 26, Color("#B9771E")))
	info.add_child(_label("체력 %s   공격 %s   방어 %s" % [_num(int(h["hp"])), _num(int(h["atk"])), _num(int(h["def"]))], 24))
	var sk: Dictionary = h["skill"]
	if not sk.is_empty():
		info.add_child(_label("필살기 「%s」 %d초마다 저절로" % [String(sk["name"]), int(sk["every"])], 22,
			SKILL_COL.get(IdleState.job, INK).darkened(0.3)))
	if not IdleState.can_pick_job():
		_panel_body.add_child(_label("LV %d 이 되면 직업을 고를 수 있어요." % IdleData.JOB_LV, 24, Color("#9A7A60")))
		return
	_panel_body.add_child(_label("직업 - 언제든 공짜로 바꿔요", 24, Color("#9A7A60")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for jid in IdleData.JOB_ORDER:
		var jd: Dictionary = IdleData.JOBS[jid]
		var col: Color = SKILL_COL.get(jid, CREAM)
		var on: bool = IdleState.job == jid
		var b := _button("%s\n%s" % [String(jd["name"]), String(jd["desc"])], 20,
			col.lightened(0.55) if not on else col, col.darkened(0.3))
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if on:
			b.text = "✓ " + b.text
		b.pressed.connect(_pick_job.bind(String(jid)))
		row.add_child(b)
	_panel_body.add_child(row)


func _pick_job(j: String) -> void:
	if IdleState.job == j:
		return
	if IdleState.set_job(j):
		AudioManager.ui_confirm()
		_fx.pillar(_hero_home, SKILL_COL.get(j, GOLD), 0.8)
		_end_t = 0.0
		_start_stage()
		_fill_char()
		IdleState.save()


var _gear_btns: Dictionary = {}


func _fill_gear() -> void:
	_clear_body()
	_title("장비", "꿈조각으로 강화해요 - 실패는 없어요")
	_gear_btns = {}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_panel_body.add_child(grid)
	var sname := {"atk": "공격", "hp": "체력", "def": "방어"}
	for s in IdleData.SLOTS:
		var g: Array = IdleState.gear[s]
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		row.add_child(v)
		v.add_child(_label("%s  +%d" % [IdleData.item_name(String(s), int(g[0]), IdleState.job), int(g[1])], 24))
		v.add_child(_label("%s · %d단계 · %s +%s" % [String(IdleData.SLOT_NAME[s]), int(g[0]),
			sname[IdleData.SLOT_STAT[s]], _num(int(IdleData.slot_value(String(s), int(g[0]), int(g[1]))))], 18,
			Color("#9A7A60")))
		var b := _button("", 20, Color("#FFE3A3"), EDGE)
		b.custom_minimum_size = Vector2(150, 62)
		b.pressed.connect(_enhance.bind(String(s)))
		row.add_child(b)
		_gear_btns[s] = b
		grid.add_child(card)
	var all := _button("한꺼번에 강화", 26, Color("#FFC96B"), EDGE)
	all.custom_minimum_size = Vector2(0, 66)
	all.pressed.connect(_enhance_all)
	_gear_btns["_all"] = all
	_panel_body.add_child(all)
	_panel_body.add_child(_label("더 센 장비는 몬스터가 떨어뜨리고, 우두머리를 처음 물리치면 선물로 줘요.", 18,
		Color("#9A7A60")))
	_refresh_gear_buttons()


func _refresh_gear_buttons() -> void:
	var any := false
	for s in IdleData.SLOTS:
		var b: Button = _gear_btns.get(s)
		if b == null:
			continue
		var g: Array = IdleState.gear[s]
		if int(g[1]) >= IdleData.PLUS_MAX:
			b.text = "최고!"
			b.disabled = true
		else:
			b.text = "강화\n✦%s" % _num(IdleState.enhance_cost_of(String(s)))
			b.disabled = not IdleState.can_enhance(String(s))
			any = any or not b.disabled
	var all: Button = _gear_btns.get("_all")
	if all != null:
		all.disabled = not any


func _enhance(slot: String) -> void:
	if IdleState.enhance(slot):
		AudioManager.ui_confirm()
		_after_enhance()


## 가장 싼 칸부터 꿈조각이 떨어질 때까지 올린다.
func _enhance_all() -> void:
	var n := 0
	while n < 500:
		var best := ""
		var cost := 0
		for s in IdleData.SLOTS:
			if IdleState.can_enhance(String(s)):
				var c := IdleState.enhance_cost_of(String(s))
				if best == "" or c < cost:
					best = String(s)
					cost = c
		if best == "":
			break
		IdleState.enhance(best)
		n += 1
	if n > 0:
		AudioManager.ui_confirm()
		_toast("%d번 강화했어요!" % n)
		_after_enhance()


func _after_enhance() -> void:
	var keep := fight.hero_hp / maxf(1.0, fight.hero_max)
	fight.h = IdleState.hero()
	fight.hero_max = float(fight.h["hp"])
	fight.hero_hp = fight.hero_max * keep
	_fx.burst(_hero_home + Vector2(0, -_hero.height() * 0.5), GOLD, 12, 300.0, 8.0, 0.6, 200.0, "star", 0.0, true)
	_hero.flash = 0.6
	_hero.flash_col = Color("#FFF3B0")
	IdleState.save()
	_fill_gear()
	_refresh()


func _fill_stage() -> void:
	_clear_body()
	_title("스테이지", "가본 곳으로 다시 갈 수 있어요")
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	sc.add_child(vb)
	_panel_body.add_child(sc)
	var last := mini(IdleState.best, IdleData.STAGE_MAX)
	var zone_max := (last - 1) / IdleData.STAGES_PER_ZONE
	for zi in range(zone_max + 1):
		var z: Dictionary = IdleData.ZONES[zi]
		var sky: Array = z["sky"]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color(sky[1]), Color(sky[0]).darkened(0.15), 18, 3, 10))
		vb.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(_label("%d. %s" % [zi + 1, String(z["name"])], 24))
		var gr := GridContainer.new()
		gr.columns = 10
		gr.add_theme_constant_override("h_separation", 6)
		for i in range(1, IdleData.STAGES_PER_ZONE + 1):
			var n := zi * IdleData.STAGES_PER_ZONE + i
			var here := n == IdleState.stage
			var b := _button(str(i) if i < 10 else "왕", 20, GOLD if here else CREAM, EDGE)
			b.custom_minimum_size = Vector2(80, 52)
			b.disabled = n > IdleState.best
			b.pressed.connect(_go_stage.bind(n))
			gr.add_child(b)
		cv.add_child(gr)
	if IdleState.best > IdleData.STAGE_MAX:
		var b := _button("잿마루 끝없는 길 (지금까지 %d)" % (IdleState.best - IdleData.STAGE_MAX - 1), 24)
		b.pressed.connect(_go_stage.bind(IdleState.best))
		vb.add_child(b)


func _go_stage(n: int) -> void:
	if IdleState.go_stage(n):
		AudioManager.ui_click()
		_close_tab()
		_end_t = 0.0
		_start_stage()


# ── 한 문장씩 ────────────────────────────────────────────────────────

func _say(lines: Array, done: Callable) -> void:
	_say_lines = lines.duplicate()
	_say_done = done
	_blocked = true
	_say_layer.visible = true
	_say_next()


func _say_next() -> void:
	if _say_lines.is_empty():
		_say_layer.visible = false
		_blocked = false
		if _say_done.is_valid():
			_say_done.call()
		return
	_say_lbl.text = String(_say_lines.pop_front())
	_say_lbl.modulate.a = 0.0
	create_tween().tween_property(_say_lbl, "modulate:a", 1.0, 0.25)
	_say_at = _t
	AudioManager.page_turn()


## 문장 장이 떠 있으면 **어떤 누름이든** 다음 문장으로 넘긴다. GUI 보다 먼저 받으므로
## 위에 무엇이 덮여 있어도 막히지 않는다 (예전엔 어두운 막이 터치를 먹어서 넘어가지 않았다).
func _input(e: InputEvent) -> void:
	if not _say_layer.visible:
		return
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventKey and e.pressed and not e.echo)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	# 터치 한 번이 터치+마우스 두 사건으로 들어온다 - 같은 누름으로 두 장 넘기지 않게.
	if _t - _say_at < 0.25:
		return
	_say_next()


## 안드로이드 뒤로가기: 열린 창을 닫는다. 닫을 게 있었으면 참.
func close_panel() -> bool:
	if _say_layer.visible:
		_say_next()
		return true
	if _panel.visible:
		_close_tab()
		return true
	return false


func _leave() -> void:
	IdleState.save(int(Time.get_unix_time_from_system()))
	SceneTransition.go_to(MENU_PATH, "normal")

extends Control
## 진짜 행복 (키우기) - 한 화면. 풍경 위에서 쿼카가 알아서 싸우고, 화면을 톡 치면 한 번 더 때린다.
## 아래 큰 버튼 셋(캐릭터·장비·스테이지) + [자동] + [보스 도전], 오른쪽에 직업 스킬 버튼 셋.
## 규칙은 전부 IdleState/IdleFight 에 있고, 여기는 그리기·연출·버튼만 한다 (`docs/redesign-idle.md`).
## 색·버튼·아이콘은 `IdleUi` 한 곳에서 (2026-10 UI 전체 개편).

const SAVE_EVERY := 10.0
const MENU_PATH := "res://scenes/menu/MainMenu3D.tscn"
const SETTINGS_SCENE := "res://scenes/ui/SettingsUI.tscn"
const GOLD := IdleUi.GOLD
const HERO_PX := 4.0
const MON_PX := 4.4
const BOSS_PX := 5.2
## 몬스터 사이를 걸을 때 풍경이 흐르는 빠르기 (px/초).
const WALK_SPEED := 340.0

## 직업별 빛깔 (스킬·필살기).
const SKILL_COL := IdleUi.JOB_COL
## 직업별 손에 든 것.
const WEAPON_OF := {"novice": "stick", "warrior": "sword", "mage": "staff", "archer": "bow", "thief": "dagger"}

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

var _stage_pill: PanelContainer
var _lv_pill: PanelContainer
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
var _char_dot: Control
var _boss_btn: Button
var _auto_btn: Button
var _auto_lbl: Label
var _menu_btn: Button
var _tap_hint: Label
var _skill_btns: Array = []

var _dim: ColorRect
var _panel: PanelContainer
var _panel_head: VBoxContainer
var _panel_scroll: ScrollContainer
var _panel_body: VBoxContainer
var _tab := ""
var _banner: Label
var _toast_lbl: Label

## 필살기 컷인 - 화면을 가로지르는 직업 빛깔 띠 + 스킬 이름 (실제 시간으로 움직인다)
var _cut: Control
var _cut_dim: ColorRect
var _cut_band: ColorRect
var _cut_line_a: ColorRect
var _cut_line_b: ColorRect
var _cut_lbl: Label
var _cut_sub: Label
var _cut_t := -1.0
var _cut_dur := 0.8
var _cut_big := false

## 메뉴(멈춤) 창 · 우두머리 보상 카드
var _menu_layer: Control
var _reward_layer: Control
var _reward_box: VBoxContainer
var _reward_t := 0.0
var _settings: Node

var _say_layer: Control
var _say_lbl: Label
var _say_hint: Label
var _say_lines: Array = []
var _say_done: Callable
var _say_at := 0.0

var _t := 0.0
var _save_t := 0.0
## 화면 흔들림 = 쌓이고 저절로 줄어드는 '충격'(0~1), 흔들림 크기는 그 제곱 (`game-feel` 스킬).
var _trauma := 0.0
var _zoom := 0.0              ## 치명타·필살기 때 화면이 살짝 다가왔다 돌아간다
var _stop_id := 0
var _calm := false            ## 설정 "화면 흔들림·번쩍임 줄이기"
var _vfx: IdleVfx
var _bokeh: CPUParticles2D
var _post: ColorRect
var _post_mat: ShaderMaterial
var _die_tw: Tween
var _walk := 0.0
var _end_t := 0.0
var _end_armed := false
var _blocked := false
var _tapped_once := false
var _skill_job := ""
var _skill_si := 0
var _skill_i := 0
var _skill_hits := 1
var _mon_tint := Color.WHITE
var _tweens: Dictionary = {}
var _hero_home := Vector2.ZERO
var _mon_home := Vector2.ZERO
var _last_boss_kill: Dictionary = {}
var _look_job := "?"


func _ready() -> void:
	add_to_group("idle_game")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not IdleState.load_save():
		IdleState.reset()
	_load_calm()
	_build()
	resized.connect(_layout)
	_layout()
	AudioManager.play_bgm("adventure")
	var r := IdleState.claim_offline(int(Time.get_unix_time_from_system()))
	if not IdleState.seen_intro:
		IdleState.seen_intro = true
		_say(["여기는 꿈결이에요.", "처음엔 화면을 톡톡 쳐서 함께 싸워요.",
			"레벨 5가 되면 쿼카가 알아서 싸우는 자동사냥이 열려요.", "직업을 고르면 오른쪽에 스킬 버튼이 생겨요.",
			"장비를 키워서 더 먼 곳으로 보내 주세요."],
			func(): _after_intro(r))
	else:
		_after_intro(r)


func _load_calm() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		_calm = bool(cfg.get_value("fx", "calm", false))


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
	_bokeh = IdleVfx.make_bokeh(Vector2(1600, 720))
	_world.add_child(_bokeh)
	_hero = IdleActor.new()
	_hero.px = HERO_PX
	_hero.flip = true
	_world.add_child(_hero)
	_mon = IdleActor.new()
	_mon.px = MON_PX
	_world.add_child(_mon)
	_hero_bar = IdleUi.bar(IdleUi.GREEN, Vector2(110, 14))
	_world.add_child(_hero_bar)
	_mon_bar = IdleUi.bar(Color("#FF7B84"), Vector2(130, 14))
	_world.add_child(_mon_bar)
	_mon_name = IdleUi.label("", 22, Color.WHITE, true)
	_mon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.add_child(_mon_name)
	_fx = IdleFx.new()
	_world.add_child(_fx)
	_vfx = IdleVfx.new()
	_world.add_child(_vfx)

	# 가장자리를 살짝 어둡게 (비녜트) - 눈이 가운데 싸움으로 모인다. 체력이 낮으면 붉게 숨쉰다.
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psh := Shader.new()
	psh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.22, 0.12, 0.26, 1.0);
uniform float strength = 0.42;
uniform float hurt = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.3, 1.0);
	float v = smoothstep(0.32, 0.9, length(d));
	vec3 c = mix(tint.rgb, vec3(0.85, 0.08, 0.14), clamp(hurt, 0.0, 1.0));
	COLOR = vec4(c, v * (strength + hurt * 0.45));
}
"""
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = psh
	_post.material = _post_mat
	add_child(_post)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	_build_cutin()

	# ── 위 줄: 스테이지 · 레벨 · 꿈조각 · 메뉴
	_stage_pill = _pill()
	add_child(_stage_pill)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_stage_pill.add_child(sv)
	_stage_lbl = IdleUi.label("", 26)
	sv.add_child(_stage_lbl)
	_wave_dots = Control.new()
	_wave_dots.custom_minimum_size = Vector2(200, 18)
	_wave_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_dots.draw.connect(_draw_dots)
	sv.add_child(_wave_dots)

	_lv_pill = _pill()
	add_child(_lv_pill)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 3)
	_lv_pill.add_child(lv)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 14)
	lv.add_child(lh)
	_lv_lbl = IdleUi.label("", 26, GOLD)
	lh.add_child(_lv_lbl)
	_power_lbl = IdleUi.label("", 19, IdleUi.SUB)
	_power_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	lh.add_child(_power_lbl)
	_xp_bar = IdleUi.bar(GOLD, Vector2(220, 12))
	lv.add_child(_xp_bar)

	_coin_pill = _pill()
	add_child(_coin_pill)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	_coin_pill.add_child(ch)
	var ci := IdleUi.icon("coin", 30.0, GOLD)
	ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(ci)
	_coin_lbl = IdleUi.label("", 28, GOLD)
	ch.add_child(_coin_lbl)

	_menu_btn = IdleUi.round_button("menu", 64.0)
	_menu_btn.pressed.connect(_open_menu)
	add_child(_menu_btn)

	# 우두머리 체력 (위 가운데, 크게)
	_boss_box = VBoxContainer.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_name = IdleUi.label("", 26, Color.WHITE, true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = IdleUi.bar(Color("#FF5A6A"), Vector2(520, 22))
	_boss_box.add_child(_boss_bar)

	_tap_hint = IdleUi.label("화면을 톡 치면 한 번 더 때려요!", 24, Color.WHITE, true)
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tap_hint)

	# ── 스킬 버튼 셋 (오른쪽, 위에서 아래로 LV 30 · 15 · 5 - 엄지에 가까운 아래가 첫 스킬)
	for i in 3:
		var sb := IdleSkillButton.new()
		sb.index = i
		sb.custom_minimum_size = Vector2(96, 96)
		sb.size = Vector2(96, 96)
		sb.pressed.connect(_on_skill_btn)
		add_child(sb)
		_skill_btns.append(sb)

	# ── 아래 줄
	var names := {"char": "캐릭터", "gear": "장비", "stage": "스테이지"}
	var icons := {"char": "hero", "gear": "bag", "stage": "map"}
	for k in ["char", "gear", "stage"]:
		var b := IdleUi.icon_button(names[k], icons[k], 22)
		b.pressed.connect(_open_tab.bind(k))
		add_child(b)
		_btns[k] = b
	_gear_dot = _dot()
	(_btns["gear"] as Button).add_child(_gear_dot)
	_char_dot = _dot()
	(_btns["char"] as Button).add_child(_char_dot)
	_auto_btn = IdleUi.button("", 22)
	var av := HBoxContainer.new()
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	av.add_theme_constant_override("separation", 8)
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aic := IdleUi.icon("auto", 30.0, IdleUi.CREAM)
	aic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_child(aic)
	_auto_lbl = IdleUi.label("", 22)
	_auto_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_child(_auto_lbl)
	_auto_btn.add_child(av)
	_auto_btn.pressed.connect(_on_auto)
	add_child(_auto_btn)
	_boss_btn = IdleUi.icon_button("보스 도전!", "boss", 22, "gold")
	_boss_btn.pressed.connect(_on_boss)
	_boss_btn.visible = false
	add_child(_boss_btn)

	# 큰 글씨 알림은 창보다 **아래** 층 - 창을 열어 둔 채로 스테이지가 바뀌어도 글씨가 창 위에 겹치지 않는다.
	_banner = IdleUi.label("", 54, Color.WHITE, true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)

	# ── 창 하나 (캐릭터 · 장비 · 스테이지)
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.04, 0.14, 0.5)
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_tab())
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", IdleUi.panel_style())
	_panel.visible = false
	add_child(_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	_panel.add_child(pv)
	_panel_head = VBoxContainer.new()
	pv.add_child(_panel_head)
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.setup(_panel_scroll)
	IdleUi.style_scroll(_panel_scroll)
	pv.add_child(_panel_scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 12)
	_panel_scroll.add_child(_panel_body)

	_toast_lbl = IdleUi.label("", 28, Color.WHITE, true)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.modulate.a = 0.0
	add_child(_toast_lbl)

	_build_reward()
	_build_menu()

	# ── 한 문장씩 (입력은 `_input` 에서 받는다 - 위에 무엇이 덮여 있든 터치가 닿게)
	_say_layer = Control.new()
	_say_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_say_layer.visible = false
	add_child(_say_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.07, 0.18, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_layer.add_child(dim)
	_say_lbl = IdleUi.label("", 44, IdleUi.CREAM, true)
	_say_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_say_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_layer.add_child(_say_lbl)
	# (예전엔 "▼" 를 썼는데 폰트에 없는 글자라 폰에서 네모가 떴다)
	_say_hint = IdleUi.label("화면을 눌러 주세요", 24, Color(1, 1, 1, 0.7))
	_say_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_layer.add_child(_say_hint)


func _pill() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", IdleUi.pill_style())
	return p


func _dot() -> Control:
	var d := Control.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.size = Vector2(26, 26)
	d.draw.connect(func() -> void:
		d.draw_circle(Vector2(13, 13), 12.0, IdleUi.INK)
		d.draw_circle(Vector2(13, 13), 9.0, IdleUi.RED))
	return d


func _build_cutin() -> void:
	_cut = Control.new()
	_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut.visible = false
	add_child(_cut)
	_cut_dim = ColorRect.new()
	_cut_dim.color = Color(0.05, 0.02, 0.1, 0.0)
	_cut_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut.add_child(_cut_dim)
	_cut_band = ColorRect.new()
	_cut_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut.add_child(_cut_band)
	_cut_line_a = ColorRect.new()
	_cut_line_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut.add_child(_cut_line_a)
	_cut_line_b = ColorRect.new()
	_cut_line_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut.add_child(_cut_line_b)
	_cut_sub = IdleUi.label("", 24, Color.WHITE, true)
	_cut.add_child(_cut_sub)
	_cut_lbl = IdleUi.label("", 64, Color.WHITE, true)
	_cut.add_child(_cut_lbl)


func _build_reward() -> void:
	_reward_layer = Control.new()
	_reward_layer.visible = false
	_reward_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_reward_layer)
	var d := ColorRect.new()
	d.color = Color(0.06, 0.03, 0.12, 0.55)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_layer.add_child(d)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", IdleUi.panel_style())
	_reward_layer.add_child(card)
	_reward_box = VBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", 10)
	card.add_child(_reward_box)
	_reward_layer.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and _reward_t > 0.6:
			_close_reward())


func _build_menu() -> void:
	_menu_layer = Control.new()
	_menu_layer.visible = false
	_menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_layer)
	var d := ColorRect.new()
	d.color = Color(0.06, 0.03, 0.12, 0.6)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	d.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_menu())
	_menu_layer.add_child(d)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", IdleUi.panel_style())
	card.custom_minimum_size = Vector2(460, 0)
	_menu_layer.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var t := IdleUi.label("메뉴", 38, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := IdleUi.label("잠깐 멈췄어요", 20, IdleUi.SUB)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var rows := [["계속하기", "play", "gold", _close_menu], ["설정", "gear", "plum", _open_settings],
		["메인 화면으로", "home", "plum", _leave]]
	for r in rows:
		var b := _row_button(String(r[0]), String(r[1]), String(r[2]))
		b.pressed.connect(r[3])
		v.add_child(b)
	var ver := IdleUi.label("", 16, IdleUi.MUTED)
	ver.name = "Ver"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)


## 아이콘이 왼쪽에 붙은 넓은 버튼 (메뉴 줄).
func _row_button(t: String, icon_kind: String, style: String) -> Button:
	var b := IdleUi.button("", 26, style)
	b.custom_minimum_size = Vector2(0, 72)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fc := Color("#3A2410") if style == "gold" else IdleUi.CREAM
	var ic := IdleUi.icon(icon_kind, 30.0, fc)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := IdleUi.label(t, 26, fc)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.add_child(h)
	return b


func _layout() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	_world.size = size
	_bg.size = size
	_flash_rect.size = size
	_post.size = size
	_bokeh.emission_rect_extents = size * 0.5
	_bokeh.position = size * 0.5
	_bg.ground = 0.5 if portrait else IdleBackdrop.GROUND
	var gy := h * _bg.ground
	_hero_home = Vector2(w * (0.3 if portrait else 0.37), gy + 30)
	_mon_home = Vector2(w * (0.72 if portrait else 0.64), gy + 30)
	_hero.position = _hero_home
	_mon.position = _mon_home

	var bh := 86.0
	if portrait:
		# ── 세로: 위 두 줄(스테이지·꿈조각·메뉴 / 레벨), 가운데 싸움, 아래 두 줄(자동·스킬 / 큰 버튼 셋)
		_stage_pill.position = Vector2(14, 14)
		_menu_btn.size = Vector2(64, 64)
		_menu_btn.position = Vector2(w - 78, 14)
		_coin_pill.custom_minimum_size = Vector2(190, 0)
		_coin_pill.position = Vector2(w - 78 - 12 - 190, 14)
		_lv_pill.position = Vector2(14, 100)
		_boss_box.size = Vector2(w - 80, 60)
		_boss_box.position = Vector2(40, 190)
		_tap_hint.position = Vector2(0, h * 0.2)
		_tap_hint.size = Vector2(w, 40)
		var bw := (w - 28.0 - 20.0) / 3.0
		var x := 14.0
		for k in ["char", "gear", "stage"]:
			var b: Button = _btns[k]
			b.position = Vector2(x, h - bh - 18)
			b.size = Vector2(bw, bh)
			x += bw + 10.0
		_gear_dot.position = Vector2(bw - 30, 4)
		_char_dot.position = Vector2(bw - 30, 4)
		var sk := 96.0
		var row2 := h - bh - 18 - 14 - sk
		_auto_btn.size = Vector2(150, sk)
		_auto_btn.position = Vector2(14, row2)
		for i in _skill_btns.size():
			var sb: IdleSkillButton = _skill_btns[i]
			sb.size = Vector2(sk, sk)
			sb.position = Vector2(w - 14 - sk - (_skill_btns.size() - 1 - i) * (sk + 12), row2)
		_boss_btn.size = Vector2(minf(320.0, w - 40.0), bh)
		_boss_btn.position = Vector2((w - _boss_btn.size.x) * 0.5, row2 - bh - 16)
	# 세로 화면은 싸움터가 좁고 높다 - 캐릭터를 조금 키운다
	_hero.px = _px(HERO_PX)
	if not fight.info.is_empty():
		_mon.px = _px(BOSS_PX if bool(fight.info["boss"]) else MON_PX)
	if portrait:
		pass
		_dim.size = size
		_panel.position = Vector2(14, 92)
		_panel.size = Vector2(w - 28, h - 92 - bh - 40)
		_panel.custom_minimum_size = _panel.size
		_banner.position = Vector2(0, h * 0.24)
		_banner.size = Vector2(w, 70)
		_toast_lbl.position = Vector2(0, h * 0.31)
		_toast_lbl.size = Vector2(w, 44)
		_toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_stage_pill.position = Vector2(18, 14)
		_lv_pill.position = Vector2(286, 14)
		_menu_btn.size = Vector2(64, 64)
		_menu_btn.position = Vector2(w - 82, 14)
		_coin_pill.custom_minimum_size = Vector2(220, 0)
		_coin_pill.position = Vector2(w - 82 - 14 - 220, 14)
		_boss_box.position = Vector2(w * 0.5 - 260, 96)
		_boss_box.size = Vector2(520, 60)
		_tap_hint.position = Vector2(0, h * 0.25)
		_tap_hint.size = Vector2(w, 40)
		var bw := 168.0
		var x := 18.0
		for k in ["char", "gear", "stage"]:
			var b: Button = _btns[k]
			b.position = Vector2(x, h - bh - 14)
			b.size = Vector2(bw, bh)
			x += bw + 10.0
		_gear_dot.position = Vector2(bw - 30, 4)
		_char_dot.position = Vector2(bw - 30, 4)
		_boss_btn.size = Vector2(190, bh)
		_boss_btn.position = Vector2(w - 208, h - bh - 14)
		_auto_btn.size = Vector2(170, bh)
		_auto_btn.position = Vector2(w - 208 - 12 - 170, h - bh - 14)
		# 스킬 버튼: 오른쪽 위로 쌓는다 (첫 스킬이 맨 아래)
		var sy := h - bh - 14 - 18 - 96
		for i in _skill_btns.size():
			var sb: IdleSkillButton = _skill_btns[i]
			sb.size = Vector2(96, 96)
			sb.position = Vector2(w - 18 - 96, sy - i * 108)
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

	_cut.size = size
	_cut_dim.size = size
	_menu_layer.size = size
	_reward_layer.size = size
	_center_card(_menu_layer)
	_center_card(_reward_layer)


func _px(base: float) -> float:
	return base * (1.3 if size.y > size.x else 1.0)


## 세로 화면인가 (창 안의 칸 수를 줄인다).
func _narrow() -> bool:
	return size.x < 900.0


func _center_card(layer: Control) -> void:
	var card := layer.get_node_or_null("Card") as Control
	if card == null:
		return
	card.reset_size()
	var cs := card.get_combined_minimum_size()
	card.size = cs
	card.position = (size - cs) * 0.5


# ── 생김새 ───────────────────────────────────────────────────────────

## 직업마다 다른 차림(투구·고깔·두건…)과 손에 든 무기. 차림 그림은 `tools/pixel/make-job-sprites.py` 가 만든다.
func _apply_look() -> void:
	var j := IdleState.job
	if j == _look_job:
		return
	_look_job = j
	var path := "res://assets/sprites/hero-%s-walk.png" % j
	if j == "novice" or not ResourceLoader.exists(path):
		path = "res://assets/sprites/hero-walk.png"
	_hero.set_sheet(path)
	_hero.weapon = String(WEAPON_OF.get(j, "stick"))
	_hero.swing = 0.0
	_hero.reach = 0.0
	_hero.pull = 0.0


# ── 전투 흐름 ────────────────────────────────────────────────────────

func _start_stage() -> void:
	fight.start(IdleState.stage)
	# 평소엔 신나는 곡, 우두머리 스테이지는 더 빠르고 긴장되는 곡 (같은 곡이면 이어서 튼다)
	AudioManager.play_bgm("boss" if bool(fight.info.get("boss", false)) else "adventure")
	_apply_look()
	_end_armed = false
	_end_t = 0.0
	var info := fight.info
	_bg.zone = int(info["zone"])
	IdleVfx.tint_bokeh(_bokeh, Color(IdleBackdrop.THEMES[_bg.zone]["sun"]).lerp(
		Color(IdleBackdrop.THEMES[_bg.zone]["accent"]), 0.35))
	var boss := bool(info["boss"])
	_mon.set_sheet("res://assets/sprites/s-%s-walk.png" % String(info["kind"]))
	_mon.px = _px(BOSS_PX if boss else MON_PX)
	_mon_tint = _tint_of(_mon.tex)
	if _die_tw != null and _die_tw.is_valid():
		_die_tw.kill()
	_mon.dissolve = 0.0
	_mon.visible = false
	_mon.modulate = Color.WHITE
	_mon_bar.visible = false
	_mon_name.visible = false
	_hero.rotation = 0.0
	_hero.modulate = Color.WHITE
	_hero.position = _hero_home
	_walk = IdleFight.SPAWN_DELAY
	_boss_box.visible = false
	if not _panel.visible:
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


func _paused() -> bool:
	return _blocked or _menu_layer.visible or _reward_layer.visible \
		or (_settings != null and is_instance_valid(_settings) and _settings.visible)


func _process(dt: float) -> void:
	_t += dt
	var rdt := dt / maxf(Engine.time_scale, 0.001)          # 멈칫하는 동안에도 흔들림은 실제 시간으로 줄어든다
	_trauma = maxf(0.0, _trauma - rdt * 1.3)
	_zoom = maxf(0.0, _zoom - rdt * 3.5)
	var sh := _trauma * _trauma
	var st := Time.get_ticks_msec() / 1000.0 * 30.0
	_world.position = Vector2(16.0 * sh * (0.6 * sin(st * 1.1) + 0.4 * sin(st * 2.3 + 1.0)),
		11.0 * sh * (0.6 * sin(st * 1.7 + 2.0) + 0.4 * sin(st * 2.9)))
	_world.pivot_offset = _mon_home.lerp(_hero_home, 0.5) + Vector2(0, -60)
	_world.rotation = 0.02 * sh * sin(st * 0.9)
	var z := 1.0 + 0.07 * _zoom * _zoom
	_world.scale = Vector2(z, z)
	_update_cut(rdt)
	if _reward_layer.visible:
		_reward_t += rdt
		if _reward_t > 3.5 and IdleState.auto_active():
			_close_reward()
	if _post_mat != null:
		var ratio := fight.hero_hp / maxf(1.0, fight.hero_max)
		var hurt := clampf((0.35 - ratio) / 0.35, 0.0, 1.0) if not fight.done and not fight.info.is_empty() else 0.0
		_post_mat.set_shader_parameter("hurt", hurt * (0.65 + 0.35 * sin(_t * 6.0)))
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - dt * 2.5)
	_hero.walking = _walk > 0.0
	if _walk > 0.0:
		_walk -= dt
		_bg.scroll += WALK_SPEED * dt
	if fight.raged and _mon.visible and _mon.dissolve <= 0.0:
		var p := 0.5 + 0.5 * sin(_t * 8.0)
		_mon.modulate = Color(1.0, 0.75 + 0.25 * (1.0 - p), 0.75 + 0.25 * (1.0 - p))
	var manual := not IdleState.auto_active()
	if manual and IdleState.can_auto():
		_tap_hint.text = "자동이 꺼져 있어요 - 톡톡 치고 스킬 버튼을 눌러요!"
	else:
		_tap_hint.text = "화면을 톡톡 쳐서 공격해요!" if manual else "화면을 톡 치면 한 번 더 때려요!"
	_tap_hint.visible = (manual or not _tapped_once) and not fight.done and fight.state == "fight" \
		and not _panel.visible and not _paused()
	_tap_hint.modulate.a = 0.6 + 0.4 * sin(_t * 4.0)
	if IdleState.boss_failed:
		var s := 1.0 + 0.04 * sin(_t * 6.0)
		_boss_btn.scale = Vector2(s, s)
	_update_bars()
	_update_skill_btns()
	_save_t += dt
	if _save_t >= SAVE_EVERY:
		_save_t = 0.0
		IdleState.save(int(Time.get_unix_time_from_system()))
	if _paused():
		return
	if _end_t > 0.0:
		_end_t -= dt
		if _end_t <= 0.0:
			_finish()
		return
	if not fight.done:
		for e in fight.tick(minf(dt, 0.25)):
			_on_event(e)
	_arm_end()


## 스테이지가 끝났으면 (자동 공격이든 톡 친 한 방이든) 잠깐 뒤에 다음으로 넘긴다. 한 번만.
func _arm_end() -> void:
	if not fight.done or _end_armed or fight.info.is_empty():
		return
	_end_armed = true
	# 우두머리는 쓰러지는 연출을 끝까지 본다
	_end_t = 1.3 if fight.result == "defeat" else (2.4 if bool(fight.info["boss"]) else 0.35)


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _paused() or _panel.visible:
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
	_arm_end()


func _on_event(e: Dictionary) -> void:
	match String(e["k"]):
		"spawn":
			_on_spawn(e)
		"skill":
			_on_skill(e)
		"hero_hit":
			_on_hero_hit(e)
		"mon_hit":
			_on_mon_hit(e)
		"kill":
			_on_kill(e)
		"rage":
			_banner_show("우두머리가 화났어요!", Color("#FF7A7A"))
			_impact(2, 0.0)
			_fx.ring(_mon_mid(), 30.0, 260.0, Color("#FF5A5A"), 14.0, 0.5)
			_vfx.burst(_mon_mid(), Color("#FF5A5A"), 30, 420.0, 0.8, 0.6, true)
			AudioManager.sky_crack()
		"level_up":
			_fx.pillar(_hero_home, GOLD)
			_fx.ring(_hero_home + Vector2(0, -40), 20.0, 180.0, GOLD, 12.0, 0.6)
			_fx.burst(_hero_home + Vector2(0, -40), GOLD, 22, 420.0, 10.0, 0.9, 200.0, "star", 0.0, true)
			_fx.text(_hero_head() + Vector2(0, -50), "LEVEL UP!", GOLD, 56, 1.4, 0.0, 90.0)
			_vfx.burst(_hero_home + Vector2(0, -30), GOLD, 30, 300.0, 1.3, 0.6, true)
			_pop(_lv_pill, 1.2)
			_add_trauma(0.25)
			AudioManager.souvenir_get()
			var lv := int(e["level"])
			if lv >= IdleData.AUTO_LV and lv - 1 < IdleData.AUTO_LV:
				IdleState.auto_on = true
				_banner_show("자동사냥이 열렸어요!", GOLD)
				_toast("이제 쿼카가 알아서 싸워요")
			for i in IdleData.skills_of(IdleState.job).size():
				var sk: Dictionary = IdleData.skills_of(IdleState.job)[i]
				if int(sk["lv"]) == lv:
					_banner_show("새 스킬 '%s'!" % String(sk["name"]), SKILL_COL.get(IdleState.job, GOLD))
					_toast("오른쪽 스킬 버튼이 열렸어요")
					_pop(_skill_btns[i], 1.4)
			_refresh()
		"defeat":
			AudioManager.battle_defeat()
			_tween(_hero, "rotation", -1.45, 0.4)
			_hero.flash = 0.8
			_hero.flash_col = Color("#FF8080")
			_fx.text(_hero_head(), "털썩…", Color("#FFD0D0"), 36, 1.2)


func _on_spawn(e: Dictionary) -> void:
	var boss := bool(e["boss"])
	if _die_tw != null and _die_tw.is_valid():
		_die_tw.kill()
	_mon.visible = true
	_mon.modulate = Color.WHITE
	_mon.dissolve = 0.0
	_mon.scale = Vector2.ONE
	_mon.flip = false
	_mon.position = _mon_home + Vector2(300, 0)
	_mon.walking = true
	var tw := _tween(_mon, "position", _mon_home, 0.3)
	tw.finished.connect(func() -> void:
		_mon.walking = false
		_mon.squash = Vector2(1.25, 0.78)
		_vfx.burst(_mon_home + Vector2(0, -6), Color("#E8DCC8"), 6, 140.0, 0.45, 0.35, true))
	var nm := String(IdleData.MOB_NAMES.get(String(e["kind"]), ""))
	if boss:
		_boss_name.text = "우두머리 · " + nm
		_boss_box.visible = true
		_pop(_boss_box, 1.25)
		_banner_show("우두머리 등장!", Color("#FF8A8A"))
		_impact(2, 0.0)
		_fx.wave(_mon_home, 420.0, Color("#FF6A6A"), 14.0, 0.7)
		_vfx.burst(_mon_home + Vector2(0, -40), Color("#FF6A6A"), 24, 420.0, 0.9, 0.7, true, 0.3)
		AudioManager.sky_crack()
	else:
		_mon_bar.visible = true
		_mon_name.visible = true
		_mon_name.text = nm
	_refresh()


func _mon_mid() -> Vector2:
	return _mon_home + Vector2(0, -_mon.height() * 0.5)


func _mon_head() -> Vector2:
	return _mon_home + Vector2(randf_range(-36, 36), -_mon.height() - 6)


func _hero_head() -> Vector2:
	return _hero_home + Vector2(0, -_hero.height() - 10)


## 무기 끝 (대략) - 마법 구슬·화살이 나가는 자리.
func _hand() -> Vector2:
	return _hero.position + Vector2(-_hero.hand.x * _hero.px + 10.0, _hero.hand.y * _hero.px - 8.0)


func _on_hero_hit(e: Dictionary) -> void:
	var dmg := _num(int(e["dmg"]))
	var crit := bool(e["crit"])
	if bool(e.get("tap", false)):
		_lunge(_hero, _hero_home, 34.0, 0.05, 0.12)
		_swing(1.0, -1.2, 0.05, 0.12)
		_fx.slash(_mon_mid() + Vector2(randf_range(-20, 20), randf_range(-20, 20)), randf_range(-PI, PI), 44.0,
			Color("#BFEFFF"), 10.0, 0.18)
		_vfx.burst(_mon_mid(), Color("#9FE6FF"), 6, 260.0, 0.35, 0.3)
		_hit_mon(0.6, 10.0)
		_fx.text(_mon_head(), dmg, Color("#BFEFFF"), 30, 0.7)
		_add_trauma(0.08)
		AudioManager.battle_weak_hit()
		return
	if bool(e["skill"]):
		_skill_hit(dmg, crit)
		return
	var d := _basic_attack()
	if crit:
		_crit_fx(dmg, d)
	else:
		_fx.text(_mon_head(), dmg, Color.WHITE, 42, 0.85, d)
		_later(d, func() -> void:
			_impact(1)
			_hit_mon(0.9, 16.0)
			AudioManager.battle_hit())


## 직업마다 다른 기본 공격 동작. 맞는 순간까지 걸리는 시간(초)을 돌려준다.
func _basic_attack() -> float:
	var col: Color = SKILL_COL.get(IdleState.job, GOLD)
	match IdleState.job:
		"warrior":
			# 칼을 등 뒤로 크게 들었다가 내려 벤다
			_hero.squash = Vector2(1.15, 0.88)
			_swing(1.9, -2.1, 0.09, 0.22)
			_lunge(_hero, _hero_home, 80.0, 0.07, 0.2, 8.0)
			_fx.slash(_mon_mid(), -PI * 0.6, 74.0, Color("#FFF2D8"), 20.0, 0.24, 0.05)
			_vfx.burst(_mon_mid(), Color("#FFE0B0"), 12, 420.0, 0.45, 0.4, false, 0.07)
			return 0.07
		"mage":
			# 지팡이를 내밀면 빛 구슬이 날아간다
			_swing(-0.7, -0.7, 0.06, 0.25)
			_tween_prop(_hero, "reach", 3.0, 0.06, 0.2)
			_hero.glow = 0.8
			_hero.glow_col = col
			_fx.orb(_hand(), _mon_mid(), col, 0.2)
			_vfx.burst(_mon_mid(), col, 16, 420.0, 0.5, 0.45, false, 0.2)
			_fx.ring(_mon_mid(), 10.0, 90.0, col, 8.0, 0.3, 0.2)
			return 0.2
		"archer":
			# 시위를 당겼다 놓는다 - 한 걸음 물러서며
			_tween_prop(_hero, "pull", 1.0, 0.08, 0.06)
			_lunge(_hero, _hero_home, -12.0, 0.08, 0.12)
			_fx.arrow(_hand(), _mon_mid() + Vector2(0, randf_range(-18, 18)), Color("#FFF2C8"), 0.12, 0.08)
			_vfx.burst(_mon_mid(), Color("#E8F8D8"), 8, 300.0, 0.35, 0.35, false, 0.2)
			return 0.2
		"thief":
			# 순식간에 파고들어 두 번 찌른다
			var tw := _tween(_hero, "position", _mon_home + Vector2(-120, 0), 0.06)
			tw.tween_interval(0.1)
			tw.tween_property(_hero, "position", _hero_home, 0.14)
			_tween_prop(_hero, "reach", 4.0, 0.05, 0.08)
			_fx.slash(_mon_mid(), -0.5, 52.0, Color("#E9D8FF"), 12.0, 0.16, 0.06)
			_fx.slash(_mon_mid(), 0.5 + PI, 52.0, Color.WHITE, 10.0, 0.16, 0.12)
			_vfx.burst(_mon_mid(), col, 8, 320.0, 0.35, 0.3, false, 0.06)
			return 0.06
		_:
			_swing(1.2, -1.5, 0.06, 0.18)
			_lunge(_hero, _hero_home, 70.0, 0.06, 0.18, 6.0)
			var ang := randf_range(-0.6, 0.6) + (PI if randf() < 0.5 else 0.0)
			_fx.slash(_mon_mid(), ang, 60.0, Color("#FFF6D8"), 16.0, 0.22)
			_vfx.burst(_mon_mid(), Color("#FFE7B0"), 10, 380.0, 0.45, 0.4)
			return 0.0


## 치명타 - 화면이 다가오고 집중선이 터지고 금빛 숫자가 크게 박힌다.
func _crit_fx(dmg: String, d: float) -> void:
	_fx.rays(_mon_mid(), Color(1, 0.95, 0.7), 18, 50.0, 380.0, 0.32, d)
	_fx.slash(_mon_mid(), randf_range(-0.6, 0.6), 84.0, GOLD, 26.0, 0.26, d)
	_fx.slash(_mon_mid(), randf_range(1.0, 2.0), 70.0, Color.WHITE, 18.0, 0.22, d + 0.05)
	_fx.ring(_mon_mid(), 20.0, 200.0, GOLD, 12.0, 0.35, d)
	_vfx.burst(_mon_mid(), Color("#FFC94A"), 26, 620.0, 0.65, 0.6, false, d)
	_fx.burst(_mon_mid(), GOLD, 10, 520.0, 10.0, 0.6, 700.0, "star", d)
	_fx.text(_mon_head() + Vector2(0, -44), "치명타!", Color("#FFE9A0"), 34, 0.9, d)
	_fx.text(_mon_head(), dmg, GOLD, 74, 1.1, d)
	_later(d, func() -> void:
		_impact(1, 0.08)
		_zoom = maxf(_zoom, 0.8)
		_flash(0.15)
		_add_trauma(0.18)
		_hit_mon(1.0, 28.0)
		AudioManager.battle_hit())


# ── 스킬 ─────────────────────────────────────────────────────────────

func _on_skill(e: Dictionary) -> void:
	_skill_job = IdleState.job
	_skill_si = int(e.get("i", 0))
	_skill_i = 0
	_skill_hits = int(e.get("hits", 1))
	var col: Color = SKILL_COL.get(_skill_job, GOLD)
	_cutin(String(e["name"]), col, _skill_si)
	_hero.glow = 1.0
	_hero.glow_col = col
	_vfx.burst(_hero_home + Vector2(0, -_hero.height() * 0.5), col, 16 + 10 * _skill_si, 220.0, 0.7, 0.5, true)
	_fx.ring(_hero_home + Vector2(0, -_hero.height() * 0.5), 10.0, 120.0 + 60.0 * _skill_si, col, 10.0, 0.4)
	_flash(0.15 + 0.1 * _skill_si)
	if _skill_si == 2 and not _calm:
		_slowmo(0.35, 0.45)          # 마지막 필살기는 잠깐 느려진다


func _on_skill_btn(i: int) -> void:
	var sk := IdleData.skills_of(IdleState.job)
	if IdleState.job == "novice" or i >= sk.size():
		_toast("레벨 %d에 직업을 고르면 스킬을 배워요" % IdleData.JOB_LV)
		_shake_btn(_skill_btns[i])
		return
	if not IdleState.skill_unlocked(i):
		_toast("'%s'는 레벨 %d에 배워요" % [String(sk[i]["name"]), int(sk[i]["lv"])])
		_shake_btn(_skill_btns[i])
		return
	if _paused() or _panel.visible:
		return
	if fight.state != "fight":
		return
	var evs := fight.cast(i)
	if evs.is_empty():
		_toast("아직 쿨타임이에요")
		return
	AudioManager.ui_confirm()
	for ev in evs:
		_on_event(ev)
	_arm_end()


func _update_skill_btns() -> void:
	var sk := IdleData.skills_of(IdleState.job)
	var col: Color = SKILL_COL.get(IdleState.job, GOLD)
	var lvs := [5, 15, 30]
	for i in _skill_btns.size():
		var b: IdleSkillButton = _skill_btns[i]
		if i >= sk.size():
			b.set_state("", col, true, lvs[i], 0.0, 0.0)
			continue
		var s: Dictionary = sk[i]
		var locked := not IdleState.skill_unlocked(i)
		var ch := fight.skill_charge(i)
		var left := float(fight.cds[i]) if i < fight.cds.size() else 0.0
		b.set_state(String(s["short"]), col, locked, int(s["lv"]), ch, left)


## 스킬 한 대마다 그리는 것 - 직업 x 스킬 번호.
func _skill_hit(dmg: String, crit: bool) -> void:
	var col: Color = SKILL_COL.get(_skill_job, GOLD)
	var i := _skill_i
	_skill_i += 1
	var last := _skill_i >= _skill_hits
	var key := "%s%d" % [_skill_job, _skill_si]
	var fs := 46 if not crit else 60
	match key:
		"warrior0":   # 방패치기 - 웅크렸다가 크게 뛰어든다
			_hero.squash = Vector2(1.25, 0.75)
			_later(0.07, func() -> void:
				_lunge(_hero, _hero_home, 120.0, 0.08, 0.25, 26.0)
				_swing(1.6, -2.2, 0.08, 0.25))
			_fx.ring(_mon_mid(), 30.0, 220.0, col, 16.0, 0.45, 0.12)
			_fx.ring(_mon_mid(), 10.0, 120.0, Color.WHITE, 8.0, 0.3, 0.12)
			_vfx.burst(_mon_mid(), col, 30, 620.0, 0.7, 0.7, false, 0.12)
			_fx.burst(_mon_mid(), col, 10, 560.0, 12.0, 0.7, 800.0, "star", 0.12)
			_fx.text(_mon_head(), dmg, col, 68, 1.1, 0.12)
			_fx.text(_hero_head(), "막기!", Color("#FFE0B0"), 30, 0.9, 0.1)
			_hit_at(0.12, 2, 40.0)
		"warrior1":   # 회오리베기 - 빙글 돌며 네 번
			var d := 0.09 * i
			if i == 0:
				_lunge(_hero, _hero_home, 90.0, 0.08, 0.5, 4.0)
			_later(d, func() -> void: _tween_prop(_hero, "swing", _hero.swing - TAU * 0.5, 0.08, 0.0))
			_fx.slash(_mon_mid(), i * 1.6, 90.0, col, 22.0, 0.22, d)
			_fx.ring(_mon_mid(), 30.0, 140.0, Color(col, 0.8), 8.0, 0.25, d)
			_vfx.burst(_mon_mid(), col, 12, 460.0, 0.45, 0.45, false, d)
			_fx.text(_mon_head() + Vector2(0, -i * 26), dmg, col.lightened(0.2), fs, 0.9, d)
			_hit_at(d, 1, 20.0)
			if last:
				_later(d + 0.12, func() -> void: _hero.swing = 0.0)
		"warrior2":   # 대지가르기 - 높이 뛰어 땅을 내리친다
			_tween(_hero, "position", _hero_home + Vector2(150, -160), 0.18).chain().tween_property(
				_hero, "position", _hero_home + Vector2(170, 0), 0.08)
			_later(0.26, func() -> void: _tween(_hero, "position", _hero_home, 0.3))
			_swing(2.2, -2.6, 0.24, 0.3)
			var d2 := 0.26
			_fx.wave(_mon_home, 560.0, col, 16.0, 0.6, d2)
			_fx.wave(_mon_home, 380.0, Color.WHITE, 10.0, 0.45, d2)
			_fx.pillar(_mon_home, col, 0.8)
			_fx.rays(_mon_mid(), col.lightened(0.3), 22, 70.0, 460.0, 0.4, d2)
			_vfx.burst(_mon_home + Vector2(0, -20), Color("#C9A57A"), 40, 700.0, 0.9, 0.8, true, d2)
			_fx.burst(_mon_mid(), col, 18, 700.0, 14.0, 0.8, 900.0, "star", d2)
			_fx.text(_mon_head(), dmg, col.lightened(0.3), 92, 1.3, d2)
			_later(d2, func() -> void:
				_flash(0.5)
				_zoom = 1.0)
			_hit_at(d2, 2, 60.0)
		"mage0":      # 별똥별
			var d := 0.34
			_tween(_hero, "position", _hero_home + Vector2(0, -36), 0.12).chain().tween_property(
				_hero, "position", _hero_home, 0.2)
			_swing(-1.2, -1.2, 0.1, 0.3)
			_vfx.burst(_hero_home + Vector2(20, -_hero.height()), col, 12, 160.0, 0.6, 0.45, true)
			_fx.meteor(_mon_mid() + Vector2(-420, -520), _mon_mid(), col, d)
			_vfx.burst(_mon_mid(), col, 34, 680.0, 0.8, 0.8, false, d)
			_fx.text(_mon_head(), dmg, col.lightened(0.3), 72, 1.1, d)
			_later(d, func() -> void: _flash(0.3))
			_hit_at(d, 2, 34.0)
		"mage1":      # 얼음창 셋
			var d := 0.12 + 0.1 * i
			var ice := Color("#BFEFFF")
			if i == 0:
				_tween_prop(_hero, "reach", 3.0, 0.08, 0.4)
			_fx.arrow(_hand() + Vector2(0, (i - 1) * 22.0), _mon_mid() + Vector2(0, (i - 1) * 18.0), ice, 0.14, d - 0.12)
			_fx.burst(_mon_mid(), ice, 10, 420.0, 8.0, 0.5, 600.0, "sq", d)
			_vfx.burst(_mon_mid(), ice, 14, 420.0, 0.5, 0.45, false, d)
			_fx.text(_mon_head() + Vector2(0, -i * 28), dmg, ice, fs, 0.9, d)
			_hit_at(d, 1, 14.0)
			if last:
				_later(d, func() -> void: _mon.flash_col = ice)
		"mage2":      # 유성우
			var d := 0.18 + 0.11 * i
			var at := _mon_mid() + Vector2(randf_range(-70, 70), randf_range(-30, 30))
			if i == 0:
				_swing(-1.4, -1.4, 0.1, 1.0)
				_fx.pillar(_hero_home, col, 1.0)
			_fx.meteor(at + Vector2(randf_range(-520, -260), -560), at, col.lerp(Color("#FFD07A"), randf()), d)
			_fx.text(_mon_head() + Vector2(randf_range(-30, 30), -i * 22), dmg, col.lightened(0.3), fs, 0.9, d)
			_hit_at(d, 1 if not last else 2, 20.0)
			if last:
				_later(d, func() -> void:
					_flash(0.45)
					_zoom = 1.0)
		"archer0":    # 연사
			var d := 0.07 * i
			_later(d, func() -> void:
				_lunge(_hero, _hero_home, -14.0, 0.04, 0.08)
				_tween_prop(_hero, "pull", 1.0, 0.03, 0.04))
			_fx.arrow(_hand(), _mon_mid() + Vector2(0, randf_range(-24, 24)), col, 0.12, d)
			_vfx.burst(_mon_mid(), col, 8, 340.0, 0.4, 0.4, false, d + 0.12)
			_fx.text(_mon_head() + Vector2(0, -i * 30), dmg, col.lightened(0.2), 40 if not crit else 54, 0.9, d + 0.12)
			_hit_at(d + 0.12, 0, 10.0)
		"archer1":    # 꿰뚫는 화살 - 오래 당겨 빛나는 한 발
			_tween_prop(_hero, "pull", 1.0, 0.22, 0.05)
			_lunge(_hero, _hero_home, -30.0, 0.2, 0.2)
			_hero.glow = 1.0
			var d := 0.3
			_fx.arrow(_hand(), _mon_mid() + Vector2(260, 0), Color.WHITE, 0.16, 0.22)
			_fx.arrow(_hand() + Vector2(0, -4), _mon_mid() + Vector2(260, -4), col, 0.16, 0.22)
			_fx.rays(_mon_mid(), col.lightened(0.4), 16, 40.0, 320.0, 0.3, d)
			_fx.ring(_mon_mid(), 10.0, 160.0, Color.WHITE, 10.0, 0.3, d)
			_vfx.burst(_mon_mid(), col, 24, 620.0, 0.6, 0.6, false, d)
			_fx.text(_mon_head() + Vector2(0, -40), "관통!", Color("#E8FFD8"), 32, 0.9, d)
			_fx.text(_mon_head(), dmg, col.lightened(0.3), 78, 1.1, d)
			_later(d, func() -> void: _zoom = 0.9)
			_hit_at(d, 2, 40.0)
		"archer2":    # 화살비
			var d := 0.15 + 0.06 * i
			if i == 0:
				_swing(-1.2, -1.2, 0.08, 1.0)
				_tween_prop(_hero, "pull", 1.0, 0.1, 0.1)
				for k in 5:
					_fx.arrow(_hand(), _hand() + Vector2(120 + k * 30, -700), col, 0.2, k * 0.03)
			var at := _mon_mid() + Vector2(randf_range(-80, 80), randf_range(-10, 30))
			_fx.arrow(at + Vector2(randf_range(-60, 60), -620), at, col.lightened(0.2), 0.16, d)
			_vfx.burst(at, col, 6, 260.0, 0.35, 0.3, false, d + 0.16)
			if i % 3 == 0:
				_fx.text(_mon_head() + Vector2(randf_range(-40, 40), -i * 8), dmg, col.lightened(0.2), fs, 0.8, d + 0.16)
			_hit_at(d + 0.16, 0, 6.0)
		"thief0":     # 급소 찌르기 - 등 뒤로 돌아가 찌른다
			var tw := _tween(_hero, "position", _mon_home + Vector2(90, 0), 0.08)
			tw.tween_callback(func() -> void: _hero.flip = false)
			tw.tween_interval(0.12)
			tw.tween_callback(func() -> void: _hero.flip = true)
			tw.tween_property(_hero, "position", _hero_home, 0.16)
			_tween_prop(_hero, "reach", 5.0, 0.1, 0.1)
			_vfx.burst(_hero_home + Vector2(0, -_hero.height() * 0.5), col, 10, 200.0, 0.4, 0.4)
			_fx.slash(_mon_mid(), -0.8, 70.0, col, 20.0, 0.25, 0.06)
			_fx.slash(_mon_mid(), 0.8 + PI, 70.0, Color.WHITE, 16.0, 0.25, 0.12)
			_fx.rays(_mon_mid(), col.lightened(0.3), 12, 40.0, 260.0, 0.25, 0.08)
			_vfx.burst(_mon_mid(), col, 22, 520.0, 0.6, 0.55, false, 0.08)
			_fx.text(_mon_head() + Vector2(0, -36), "급소!", Color("#E9D8FF"), 30, 0.8, 0.08)
			_fx.text(_mon_head(), dmg, col.lightened(0.2), 66, 1.1, 0.08)
			_hit_at(0.08, 1, 24.0)
		"thief1":     # 그림자 연격 - 앞뒤로 번갈아 여섯 번
			var d := 0.07 * i
			var side := 1.0 if i % 2 == 0 else -1.0
			_later(d, func() -> void:
				_hero.position = _mon_home + Vector2(110.0 * side, 0)
				_hero.flip = side < 0.0
				_hero.modulate = Color(0.75, 0.6, 1.0, 0.85)
				_vfx.burst(_hero.position + Vector2(0, -50), col.darkened(0.3), 6, 180.0, 0.3, 0.3))
			_fx.slash(_mon_mid(), randf_range(-PI, PI), 66.0, col, 16.0, 0.18, d)
			_fx.text(_mon_head() + Vector2(randf_range(-30, 30), -i * 16), dmg, col.lightened(0.25), fs, 0.8, d)
			_hit_at(d, 0, 12.0)
			if last:
				_later(d + 0.1, func() -> void:
					_hero.flip = true
					_hero.modulate = Color.WHITE
					_tween(_hero, "position", _hero_home, 0.14))
		"thief2":     # 암살 - 사라졌다가 등 뒤에서 X 자로
			_hero.modulate = Color(1, 1, 1, 0.0)
			_vfx.burst(_hero_home + Vector2(0, -50), Color("#2A2140"), 20, 260.0, 0.5, 0.5, true)
			var d := 0.3
			_later(0.18, func() -> void:
				_hero.position = _mon_home + Vector2(100, 0)
				_hero.flip = false
				_hero.modulate = Color.WHITE
				_tween_prop(_hero, "reach", 6.0, 0.06, 0.2))
			_fx.slash(_mon_mid(), -0.8, 110.0, col, 26.0, 0.3, d)
			_fx.slash(_mon_mid(), 0.8, 110.0, Color.WHITE, 22.0, 0.3, d + 0.06)
			_fx.rays(_mon_mid(), col.lightened(0.4), 22, 60.0, 440.0, 0.4, d)
			_vfx.burst(_mon_mid(), col, 40, 700.0, 0.8, 0.8, false, d)
			_fx.text(_mon_head() + Vector2(0, -46), "암살!", Color("#E9D8FF"), 36, 1.0, d)
			_fx.text(_mon_head(), dmg, col.lightened(0.3), 92, 1.3, d)
			_later(d, func() -> void:
				_flash(0.4)
				_zoom = 1.0)
			_later(d + 0.35, func() -> void:
				_hero.flip = true
				_tween(_hero, "position", _hero_home, 0.18))
			_hit_at(d, 2, 50.0)
		_:
			_fx.text(_mon_head(), dmg, GOLD, 50, 1.0)
			_hit_mon(1.0, 20.0)
	if crit and not key in ["thief0", "thief2", "archer1"]:
		_fx.rays(_mon_mid(), Color(1, 0.95, 0.7), 10, 40.0, 240.0, 0.25)


## d 초 뒤에 맞는다 (충격 단계 · 넉백).
func _hit_at(d: float, tier: int, knock: float) -> void:
	_later(d, func() -> void:
		_impact(tier)
		_hit_mon(1.0, knock)
		if tier >= 2:
			_add_trauma(0.15)
		if tier == 0:
			AudioManager.battle_weak_hit()
		else:
			AudioManager.battle_hit())


func _hit_mon(flash: float, knock: float) -> void:
	if not _mon.visible or _mon.dissolve > 0.0:
		return
	_mon.flash = flash
	if _mon.flash_col != Color("#BFEFFF"):
		_mon.flash_col = Color.WHITE
	_mon.squash = Vector2(0.8, 1.15)
	_lunge(_mon, _mon_home, knock, 0.05, 0.16)


func _on_mon_hit(e: Dictionary) -> void:
	_mon.flash_col = Color.WHITE
	_mon.squash = Vector2(0.88, 1.1)
	_lunge(_mon, _mon_home, -80.0, 0.08, 0.2, 10.0)
	_later(0.07, func() -> void:
		_hero.flash = 0.7
		_hero.flash_col = Color("#FF7070")
		_hero.squash = Vector2(1.15, 0.86)
		_lunge(_hero, _hero_home, -18.0, 0.05, 0.15)
		_vfx.burst(_hero_home + Vector2(0, -_hero.height() * 0.5), Color("#FF7A7A"), 8, 300.0, 0.4, 0.4)
		_fx.text(_hero_head() + Vector2(randf_range(-20, 20), 0), _num(int(e["dmg"])), Color("#FF9A9A"), 34, 0.8)
		_impact(0)
		AudioManager.battle_hurt())


func _on_kill(e: Dictionary) -> void:
	var boss := bool(e["boss"])
	var mid := _mon_mid()
	_kill_tween(_mon, "position")
	_mon.flash = 0.8
	_mon.edge_col = _mon_tint.lightened(0.5)
	if _die_tw != null and _die_tw.is_valid():
		_die_tw.kill()
	_die_tw = create_tween()
	_die_tw.tween_property(_mon, "dissolve", 1.0, 0.42 if not boss else 1.6).set_trans(Tween.TRANS_SINE)
	_die_tw.tween_callback(func() -> void:
		_mon.visible = false
		_mon.dissolve = 0.0)
	_mon_bar.visible = false
	_mon_name.visible = false
	_vfx.burst(mid, _mon_tint.lightened(0.3), 18 if not boss else 46, 260.0, 1.1, 0.5, true)
	_vfx.burst(mid, Color.WHITE, 10, 420.0, 0.5, 0.35)
	_fx.burst(mid, _mon_tint, 12 if not boss else 30, 480.0, 10.0 if not boss else 14.0, 0.7, 800.0)
	var coin_to := _coin_pill.global_position + _coin_pill.size * 0.5 - _world.global_position
	_fx.burst(mid, GOLD, 6 if not boss else 40, 300.0 if not boss else 520.0, 11.0, 1.0, 600.0, "coin", 0.05, true,
		coin_to)
	_later(0.6, func() -> void:
		_pop(_coin_pill, 1.12)
		_coin_lbl.text = _num(IdleState.coins))
	_fx.text(mid + Vector2(0, -40), "+%s" % _num(int(e["coin"])), GOLD, 30 if not boss else 46, 1.0, 0.1, 50.0)
	if boss:
		_last_boss_kill = e
		_boss_celebrate(mid)
	else:
		_impact(1, 0.05)
	var d: Array = e["drop"]
	if not d.is_empty():
		_toast("새 장비! %s" % IdleData.item_name(String(d[0]), int(d[1]), IdleState.job))
		_fx.pillar(mid + Vector2(0, _mon.height() * 0.5), Color("#9AE0FF"), 1.2)
		_vfx.burst(mid, Color("#9AE0FF"), 24, 300.0, 1.2, 0.6, true)
		AudioManager.souvenir_get()
	else:
		AudioManager.pickup()
	_walk = IdleFight.SPAWN_DELAY
	_refresh()
	_coin_lbl.text = _num(IdleState.coins - int(e["coin"]))


## 우두머리를 물리쳤다 - 느려지고, 하얗게 터지고, 불꽃이 여러 번 피어오른다.
func _boss_celebrate(mid: Vector2) -> void:
	_impact(2, 0.16)
	_add_trauma(0.3)
	_flash(0.7)
	_zoom = 1.0
	if not _calm:
		_slowmo(0.3, 0.7)
	_fx.rays(mid, Color(1, 0.95, 0.75), 28, 80.0, 620.0, 0.6)
	_fx.ring(mid, 20.0, 360.0, GOLD, 20.0, 0.8)
	_fx.ring(mid, 10.0, 220.0, Color.WHITE, 12.0, 0.6, 0.1)
	_fx.wave(_mon_home, 640.0, GOLD, 16.0, 0.8)
	_fx.pillar(_mon_home, GOLD, 1.6)
	_vfx.burst(mid, GOLD, 50, 760.0, 1.4, 0.9)
	_banner_show("우두머리를 물리쳤어요!", GOLD)
	# 불꽃놀이 - 화면 여기저기서 차례로
	var cols := [GOLD, Color("#FF8FB0"), Color("#8FE0FF"), Color("#B9FF8F"), Color("#C9A8FF")]
	for k in 7:
		var p := Vector2(size.x * randf_range(0.2, 0.8), size.y * randf_range(0.15, 0.45))
		var c: Color = cols[k % cols.size()]
		var dl := 0.35 + k * 0.22
		_fx.ring(p, 6.0, 120.0, c, 6.0, 0.6, dl)
		_fx.burst(p, c, 22, 360.0, 7.0, 0.9, 160.0, "star", dl)
		_later(dl, func() -> void: AudioManager.pickup())
	AudioManager.souvenir_get()


func _finish() -> void:
	if fight.result == "clear":
		var was_boss := bool(fight.info["boss"])
		var o := IdleState.on_clear()
		var rw: Array = o.get("reward", [])
		IdleState.save(int(Time.get_unix_time_from_system()))
		if was_boss:
			_show_reward(o, rw)
		if o.has("ending"):
			IdleState.ending_seen = true
			IdleState.save()
			_reward_layer.visible = false
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


## 우두머리 보상 카드 - 받은 것을 한 장에 모아 보여 준다.
func _show_reward(o: Dictionary, rw: Array) -> void:
	for c in _reward_box.get_children():
		_reward_box.remove_child(c)
		c.queue_free()
	var e := _last_boss_kill
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.add_child(IdleUi.icon("chest", 56.0, Color("#C98A3A")))
	var t := IdleUi.label("우두머리 보상", 40, GOLD)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	_reward_box.add_child(head)
	var lines: Array = []
	lines.append(["coin", "꿈조각 +%s" % _num(int(e.get("coin", 0))), GOLD])
	lines.append(["star", "경험 +%s" % _num(int(e.get("xp", 0))), Color("#BFEFFF")])
	if int(o.get("bonus", 0)) > 0:
		lines.append(["chest", "처음 물리친 보물 상자  꿈조각 +%s" % _num(int(o["bonus"])), Color("#FFD9A0")])
	if not rw.is_empty():
		lines.append(["bag", "선물 장비  %s" % IdleData.item_name(String(rw[0]), int(rw[1]), IdleState.job),
			Color("#9AE0FF")])
	if bool(o.get("new_best", false)):
		lines.append(["map", "새 구역이 열렸어요!", IdleUi.GREEN])
	for ln in lines:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", IdleUi.card_style())
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var ic := IdleUi.icon(String(ln[0]), 32.0, ln[2])
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(IdleUi.label(String(ln[1]), 26, ln[2]))
		_reward_box.add_child(row)
	var ok := IdleUi.button("받기", 28, "gold")
	ok.custom_minimum_size = Vector2(0, 68)
	ok.pressed.connect(_close_reward)
	_reward_box.add_child(ok)
	_reward_layer.visible = true
	_reward_t = 0.0
	_center_card(_reward_layer)
	var card := _reward_layer.get_node("Card") as Control
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_fx.burst(size * 0.5 - _world.position, GOLD, 30, 520.0, 9.0, 1.0, 300.0, "star")


func _close_reward() -> void:
	if not _reward_layer.visible:
		return
	AudioManager.ui_click()
	_reward_layer.visible = false
	_refresh()


func _refresh_auto() -> void:
	var st := "plum"
	if not IdleState.can_auto():
		_auto_lbl.text = "자동\nLV%d부터" % IdleData.AUTO_LV
		_auto_lbl.add_theme_font_size_override("font_size", 18)
		_auto_btn.modulate = Color(1, 1, 1, 0.65)
	elif IdleState.auto_on:
		_auto_lbl.text = "자동 켜짐"
		_auto_lbl.add_theme_font_size_override("font_size", 22)
		_auto_btn.modulate = Color.WHITE
		st = "on"
	else:
		_auto_lbl.text = "자동 꺼짐"
		_auto_lbl.add_theme_font_size_override("font_size", 22)
		_auto_btn.modulate = Color.WHITE
	var sb := IdleUi.box(Color("#2F6B4A") if st == "on" else IdleUi.INK_3,
		IdleUi.GREEN if st == "on" else Color(1, 1, 1, 0.18), 22, 3, 8)
	_auto_btn.add_theme_stylebox_override("normal", sb)
	_auto_btn.add_theme_stylebox_override("hover", sb)


func _on_auto() -> void:
	AudioManager.ui_click()
	if not IdleState.can_auto():
		_toast("레벨 %d부터 자동사냥을 할 수 있어요" % IdleData.AUTO_LV)
		_shake_btn(_auto_btn)
		return
	IdleState.auto_on = not IdleState.auto_on
	_toast("자동사냥을 켰어요" if IdleState.auto_on else "자동사냥을 껐어요 - 톡톡 치고 스킬을 직접 눌러요")
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


# ── 메뉴 (멈춤) · 설정 ───────────────────────────────────────────────

func _open_menu() -> void:
	AudioManager.ui_click()
	_close_tab()
	var ver := _menu_layer.get_node_or_null("Card/VBoxContainer/Ver") as Label
	if ver == null:
		for c in _menu_layer.get_node("Card").get_children():
			if c is VBoxContainer:
				ver = c.get_node_or_null("Ver") as Label
	if ver != null:
		ver.text = "진짜 행복 v%s" % String(ProjectSettings.get_setting("application/config/version", ""))
	_menu_layer.visible = true
	_center_card(_menu_layer)
	var card := _menu_layer.get_node("Card") as Control
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	IdleState.save(int(Time.get_unix_time_from_system()))


func _close_menu() -> void:
	if _menu_layer.visible:
		AudioManager.ui_click()
	_menu_layer.visible = false
	_load_calm()


func _open_settings() -> void:
	AudioManager.ui_click()
	if _settings == null or not is_instance_valid(_settings):
		var ps := load(SETTINGS_SCENE) as PackedScene
		if ps == null:
			_toast("설정을 열지 못했어요")
			return
		_settings = ps.instantiate()
		add_child(_settings)
		# 게임 중에는 "기록 초기화" 를 숨긴다 - 지우는 건 메인 화면의 [처음부터 하기] 에서만 (확인창이 있다)
		for n in ["Root/Panel/Margin/Scroll/Body/ResetBtn", "Root/Panel/Margin/Scroll/Body/ResetHint",
				"Root/Panel/Margin/Body/ResetBtn", "Root/Panel/Margin/Body/ResetHint"]:
			var node := _settings.get_node_or_null(n) as CanvasItem
			if node != null:
				node.visible = false
	_menu_layer.visible = false
	_settings.open()


# ── 연출 도우미 ──────────────────────────────────────────────────────

## 충격 크기 단계 - 같은 무게의 일엔 같은 반응 (작음 0 · 보통 1 · 큼 2).
const IMPACT_TRAUMA := [0.16, 0.38, 0.8]
const IMPACT_STOP := [0.0, 0.04, 0.1]


func _impact(tier: int, extra_stop := -1.0) -> void:
	_add_trauma(IMPACT_TRAUMA[tier])
	_hitstop(IMPACT_STOP[tier] if extra_stop < 0.0 else extra_stop)


func _add_trauma(a: float) -> void:
	_trauma = clampf(_trauma + a * (0.3 if _calm else 1.0), 0.0, 1.0)


## 아주 잠깐 시간을 거의 멈춘다 (때린 느낌). 실제 시간으로 재는 타이머라 멈춘 동안에도 풀린다.
func _hitstop(d: float) -> void:
	if _calm or d <= 0.0:
		return
	_slowmo(0.06, d)


## 시간을 scale 배로 느리게 (real_secs 실제 초 동안). 겹치면 마지막 것이 끝낼 때 돌아온다.
func _slowmo(scale_v: float, real_secs: float) -> void:
	_stop_id += 1
	var id := _stop_id
	Engine.time_scale = minf(Engine.time_scale, scale_v) if Engine.time_scale < 1.0 else scale_v
	get_tree().create_timer(real_secs, true, false, true).timeout.connect(func() -> void:
		if id == _stop_id:
			Engine.time_scale = 1.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## 필살기 컷인 - 직업 빛깔 띠가 화면을 가로지르며 스킬 이름이 박힌다 (실제 시간).
func _cutin(name_t: String, col: Color, si: int) -> void:
	_cut_big = si == 2
	_cut_dur = 0.7 if si == 0 else (0.85 if si == 1 else 1.1)
	_cut_t = 0.0
	_cut.visible = true
	_cut_lbl.text = name_t + "!"
	_cut_lbl.add_theme_font_size_override("font_size", 56 + si * 12)
	_cut_sub.text = ["스킬", "스킬", "필살기"][clampi(si, 0, 2)]
	_cut_band.color = Color(col.r, col.g, col.b, 0.86)
	_cut_line_a.color = Color(1, 1, 1, 0.9)
	_cut_line_b.color = Color(1, 1, 1, 0.9)
	_update_cut(0.0)


func _update_cut(rdt: float) -> void:
	if _cut_t < 0.0:
		return
	_cut_t += rdt
	var w := size.x
	var h := size.y
	var k := _cut_t / _cut_dur
	if k >= 1.0:
		_cut_t = -1.0
		_cut.visible = false
		return
	var bh := 96.0 + (40.0 if _cut_big else 0.0)
	var y := h * 0.30
	var slide := clampf(_cut_t / 0.14, 0.0, 1.0)
	slide = 1.0 - pow(1.0 - slide, 3.0)
	var fade := 1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0)
	_cut_dim.color.a = (0.5 if _cut_big else 0.18) * fade * slide
	_cut_band.size = Vector2(w * 1.2, bh * (0.4 + 0.6 * slide))
	_cut_band.position = Vector2(lerpf(-w * 1.2, -w * 0.1, slide), y - _cut_band.size.y * 0.5)
	_cut_band.modulate.a = fade
	_cut_line_a.size = Vector2(w, 4)
	_cut_line_b.size = Vector2(w, 4)
	_cut_line_a.position = Vector2(lerpf(w, 0.0, slide), y - bh * 0.5 - 10)
	_cut_line_b.position = Vector2(lerpf(-w, 0.0, slide), y + bh * 0.5 + 6)
	_cut_line_a.modulate.a = fade
	_cut_line_b.modulate.a = fade
	_cut_lbl.reset_size()
	var ls := _cut_lbl.get_combined_minimum_size()
	var drift := (k - 0.5) * 40.0
	_cut_lbl.position = Vector2(lerpf(w, (w - ls.x) * 0.5, slide) + drift, y - ls.y * 0.5)
	_cut_lbl.modulate.a = fade
	_cut_sub.reset_size()
	_cut_sub.position = Vector2(_cut_lbl.position.x + 6, y - bh * 0.5 - 2)
	_cut_sub.modulate.a = fade


## 눌린 듯 찌그러졌다가 살짝 넘치며 돌아온다 (TRANS_BACK - 살아 있는 '뽁').
func _pop(c: Control, amt := 1.18) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(amt, amt)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _tkey(n: Object, prop: String) -> String:
	return "%d:%s" % [n.get_instance_id(), prop]


func _kill_tween(n: Object, prop: String) -> void:
	var old = _tweens.get(_tkey(n, prop))
	if old != null and (old as Tween).is_valid():
		(old as Tween).kill()


func _tween(n: Object, prop: String, to, dur: float) -> Tween:
	_kill_tween(n, prop)
	var tw := create_tween()
	tw.tween_property(n, prop, to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[_tkey(n, prop)] = tw
	return tw


## 값을 to 까지 갔다가 0 으로 돌아오게 (무기 내밀기·시위 당기기).
func _tween_prop(n: Object, prop: String, to: float, out_t: float, back_t: float) -> void:
	var tw := _tween(n, prop, to, out_t)
	if back_t > 0.0:
		tw.tween_property(n, prop, 0.0, back_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## 무기를 from 으로 들었다가 to 까지 휘두르고 제자리로.
func _swing(from: float, to: float, out_t: float, back_t: float) -> void:
	_hero.swing = from
	var tw := _tween(_hero, "swing", to, out_t)
	tw.tween_property(_hero, "swing", 0.0, back_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


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
	create_tween().tween_callback(f).set_delay(d)


func _flash(a: float) -> void:
	_flash_rect.color = Color(1, 1, 1, maxf(_flash_rect.color.a, a * (0.3 if _calm else 1.0)))


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
		IdleUi.draw_icon(_wave_dots, "boss", Vector2(10, 9), 20.0, IdleUi.RED)
		_wave_dots.draw_string(_fx.font, Vector2(26, 16), "우두머리", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, IdleUi.RED)
		return
	var killed := fight.total - fight.left
	for i in IdleData.WAVE:
		var c := Vector2(10 + i * 26, 9)
		_wave_dots.draw_circle(c, 8.0, Color(1, 1, 1, 0.18))
		if i < killed:
			_wave_dots.draw_circle(c, 7.0, GOLD)
		elif i == killed:
			_wave_dots.draw_circle(c, 5.0, IdleUi.RED)


func _refresh() -> void:
	_stage_lbl.text = IdleData.stage_label(IdleState.stage)
	_wave_dots.queue_redraw()
	_coin_lbl.text = _num(IdleState.coins)
	_lv_lbl.text = "LV %d" % IdleState.level
	_power_lbl.text = "전투력 %s" % _num(IdleState.power())
	_xp_bar.max_value = IdleData.exp_need(IdleState.level)
	_xp_bar.value = IdleState.xp if IdleState.level < IdleData.LEVEL_MAX else _xp_bar.max_value
	_boss_btn.visible = IdleState.boss_failed
	if not _narrow():       # 가로 화면에서만 보스 버튼 자리를 비켜 준다 (세로는 보스 버튼이 위 줄에 따로 뜬다)
		_auto_btn.position.x = (size.x - 208 - 12 - 170) if IdleState.boss_failed else (size.x - 18 - 170)
	_refresh_auto()
	if not IdleState.boss_failed:
		_boss_btn.scale = Vector2.ONE
	var can := false
	for s in IdleData.SLOTS:
		if IdleState.can_enhance(String(s)):
			can = true
			break
	_gear_dot.visible = can
	var can_t := false
	for t in IdleData.TRAIN_STATS:
		if IdleState.can_train(String(t)):
			can_t = true
			break
	_char_dot.visible = can_t
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
	_banner.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_fill()
	_panel_scroll.scroll_vertical = 0


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
	_gear_btns = {}               # 지워질 버튼을 들고 있지 않게 (창을 빨리 바꾸면 지운 버튼을 만졌다)
	for box in [_panel_head, _panel_body]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()


func _title(t: String, sub := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(IdleUi.label(t, 36, GOLD))
	if sub != "":
		v.add_child(IdleUi.label(sub, 19, IdleUi.SUB))
	row.add_child(v)
	var x := IdleUi.round_button("close", 58.0, "ghost")
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(_close_tab)
	row.add_child(x)
	_panel_head.add_child(row)
	var line := ColorRect.new()
	line.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	_panel_head.add_child(line)


func _section(t: String) -> void:
	var l := IdleUi.label(t, 22, GOLD.lerp(IdleUi.CREAM, 0.4))
	_panel_body.add_child(l)


func _card(border := IdleUi.LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", IdleUi.card_style(border))
	return p


## 직업 그림의 앞모습 한 칸.
func _portrait_of(job: String, sz: Vector2) -> TextureRect:
	var path := "res://assets/sprites/hero-%s-walk.png" % job
	if job == "novice" or not ResourceLoader.exists(path):
		path = "res://assets/sprites/hero-walk.png"
	var tex := load(path) as Texture2D
	var tr := TextureRect.new()
	tr.custom_minimum_size = sz
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(Vector2.ZERO, Vector2(tex.get_width() / 4.0, tex.get_height() / 3.0))
		tr.texture = a
	return tr


func _fill_char() -> void:
	_clear_body()
	_title("캐릭터", "레벨이 오르면 저절로 세지고, 새 스킬을 배워요")
	var h := IdleState.hero()
	var j: Dictionary = IdleData.JOBS[IdleState.job]
	var jc: Color = SKILL_COL.get(IdleState.job, GOLD)

	# 위: 얼굴 + 이름·전투력·능력치
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	_panel_body.add_child(top)
	var frame := _card(jc)
	frame.add_child(_portrait_of(IdleState.job, Vector2(110, 130)))
	top.add_child(frame)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var nm := HBoxContainer.new()
	nm.add_theme_constant_override("separation", 12)
	nm.add_child(IdleUi.label("LV %d" % IdleState.level, 36, GOLD))
	nm.add_child(IdleUi.label(String(j["name"]), 36, jc))
	info.add_child(nm)
	info.add_child(IdleUi.label("전투력 %s" % _num(IdleState.power()), 24, IdleUi.CREAM))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	for st in [["체력", int(h["hp"]), IdleUi.GREEN], ["공격", int(h["atk"]), Color("#FF9F7A")],
			["방어", int(h["def"]), Color("#8FC8FF")]]:
		var c := _card()
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 0)
		sv.add_child(IdleUi.label(String(st[0]), 17, st[2]))
		sv.add_child(IdleUi.label(_num(int(st[1])), 24))
		c.add_child(sv)
		c.custom_minimum_size = Vector2(130, 0)
		stats.add_child(c)
	info.add_child(stats)

	# 직업
	if not IdleState.can_pick_job():
		_section("직업")
		var lc := _card()
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 10)
		lh.add_child(IdleUi.icon("lock", 30.0, IdleUi.MUTED))
		lh.add_child(IdleUi.label("LV %d 이 되면 직업을 고를 수 있어요." % IdleData.JOB_LV, 22, IdleUi.SUB))
		lc.add_child(lh)
		_panel_body.add_child(lc)
	else:
		_section("직업 - 언제든 공짜로 바꿔요")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for jid in IdleData.JOB_ORDER:
			row.add_child(_job_card(String(jid)))
		_panel_body.add_child(row)

	_fill_skills()
	_fill_train()


func _job_card(jid: String) -> Button:
	var jd: Dictionary = IdleData.JOBS[jid]
	var col: Color = SKILL_COL.get(jid, GOLD)
	var on := IdleState.job == jid
	var b := IdleUi.button("", 18, "plum", col if not on else Color(0, 0, 0, 0))
	if on:
		var sb := IdleUi.box(IdleUi.INK_2.lerp(col, 0.5), GOLD, 22, 5, 8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := _portrait_of(jid, Vector2(56, 66))
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var n := IdleUi.label(("지금  " if on else "") + String(jd["name"]), 22, GOLD if on else IdleUi.CREAM)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var d := IdleUi.label(String(jd["desc"]), 16, IdleUi.SUB)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	b.add_child(v)
	b.pressed.connect(_pick_job.bind(jid))
	return b


## 스킬 목록 - 레벨이 되면 배운다 (못 배운 것도 보여 준다: 무엇을 향해 키우는지 알게).
func _fill_skills() -> void:
	var sk := IdleData.skills_of(IdleState.job)
	_section("스킬 - 레벨이 오르면 배워요 (오른쪽 버튼)")
	if sk.is_empty():
		var lc := _card()
		lc.add_child(IdleUi.label("직업을 고르면 직업마다 스킬 셋을 LV 5 · 15 · 30 에 배워요.", 20, IdleUi.SUB))
		_panel_body.add_child(lc)
		return
	var col: Color = SKILL_COL.get(IdleState.job, GOLD)
	for i in sk.size():
		var s: Dictionary = sk[i]
		var open := IdleState.skill_unlocked(i)
		var c := _card(col if open else IdleUi.LINE)
		c.modulate = Color.WHITE if open else Color(1, 1, 1, 0.6)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		c.add_child(hb)
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(64, 64)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var short := String(s["short"])
		var bc := col if open else IdleUi.MUTED
		badge.draw.connect(func() -> void:
			badge.draw_circle(Vector2(32, 32), 30.0, IdleUi.INK)
			badge.draw_arc(Vector2(32, 32), 28.0, 0, TAU, 32, bc, 4.0, true)
			if open:
				var f := _fx.font
				var fs := 20 if short.length() <= 2 else 16
				var w := f.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				badge.draw_string(f, Vector2(32 - w * 0.5, 39), short, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			else:
				IdleUi.draw_icon(badge, "lock", Vector2(32, 32), 30.0, IdleUi.MUTED))
		hb.add_child(badge)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 12)
		nm.add_child(IdleUi.label(String(s["name"]), 24, col.lightened(0.2) if open else IdleUi.CREAM))
		nm.add_child(IdleUi.label("쿨타임 %d초" % int(s["cd"]), 18, IdleUi.SUB))
		if i == 2:
			nm.add_child(IdleUi.label("필살기", 18, GOLD))
		v.add_child(nm)
		v.add_child(IdleUi.label(String(s["desc"]), 18, IdleUi.SUB))
		hb.add_child(v)
		var tag := IdleUi.label("배웠어요" if open else "LV %d에 배워요" % int(s["lv"]), 20,
			IdleUi.GREEN if open else IdleUi.MUTED)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tag)
		_panel_body.add_child(c)


## 수련 - 장비를 다 키운 뒤에도 꿈조각을 쓸 곳. 공격·체력·방어를 1% 씩 끝없이.
func _fill_train() -> void:
	if not IdleState.train_open():
		_section("수련")
		var lc := _card()
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 10)
		lh.add_child(IdleUi.icon("lock", 30.0, IdleUi.MUTED))
		lh.add_child(IdleUi.label("5구역 굽이나루 우두머리를 물리치면 열려요", 20, IdleUi.SUB))
		lc.add_child(lh)
		_panel_body.add_child(lc)
		return
	_section("수련 - 꿈조각으로 끝없이 세져요 (단계마다 1%)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for t in IdleData.TRAIN_STATS:
		var lv := int(IdleState.train[t])
		var b := IdleUi.button("%s %d단계 (+%d%%)\n꿈조각 %s" % [String(IdleData.TRAIN_NAME[t]), lv,
			int(round((IdleState.train_mult(String(t)) - 1.0) * 100.0)), _num(IdleState.train_cost_of(String(t)))], 20,
			"gold")
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not IdleState.can_train(String(t))
		b.pressed.connect(_on_train.bind(String(t)))
		row.add_child(b)
	_panel_body.add_child(row)


func _on_train(stat: String) -> void:
	if IdleState.do_train(stat):
		AudioManager.ui_confirm()
		_after_enhance()


func _pick_job(j: String) -> void:
	if IdleState.job == j:
		return
	if IdleState.set_job(j):
		AudioManager.ui_confirm()
		fight.reset_cooldowns()
		_apply_look()
		_fx.pillar(_hero_home, SKILL_COL.get(j, GOLD), 0.8)
		_vfx.burst(_hero_home + Vector2(0, -50), SKILL_COL.get(j, GOLD), 30, 300.0, 1.0, 0.6, true)
		_hero.glow = 1.0
		_hero.glow_col = SKILL_COL.get(j, GOLD)
		_end_t = 0.0
		_start_stage()
		var sc := _panel_scroll.scroll_vertical
		_fill_char()
		_panel_scroll.set_deferred("scroll_vertical", sc)
		IdleState.save()


var _gear_btns: Dictionary = {}


func _fill_gear() -> void:
	_clear_body()
	_title("장비", "꿈조각으로 강화해요 - 실패는 없어요")
	_gear_btns = {}
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_panel_body.add_child(grid)
	var sname := {"atk": "공격", "hp": "체력", "def": "방어"}
	var scol := {"atk": Color("#FF9F7A"), "hp": IdleUi.GREEN, "def": Color("#8FC8FF")}
	for s in IdleData.SLOTS:
		var g: Array = IdleState.gear[s]
		var st := String(IdleData.SLOT_STAT[s])
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var stripe := ColorRect.new()
		stripe.color = scol[st]
		stripe.custom_minimum_size = Vector2(6, 0)
		row.add_child(stripe)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		row.add_child(v)
		var nh := HBoxContainer.new()
		nh.add_theme_constant_override("separation", 8)
		nh.add_child(IdleUi.label(IdleData.item_name(String(s), int(g[0]), IdleState.job), 23))
		nh.add_child(IdleUi.label("+%d" % int(g[1]), 23, GOLD))
		v.add_child(nh)
		v.add_child(IdleUi.label("%s · %d단계 · %s +%s" % [String(IdleData.SLOT_NAME[s]), int(g[0]),
			sname[st], _num(int(IdleData.slot_value(String(s), int(g[0]), int(g[1]))))], 17, IdleUi.SUB))
		var b := IdleUi.button("", 19, "gold")
		b.custom_minimum_size = Vector2(150, 62)
		b.pressed.connect(_enhance.bind(String(s)))
		row.add_child(b)
		_gear_btns[s] = b
		grid.add_child(card)
	var all := IdleUi.button("한꺼번에 강화", 26, "gold")
	all.custom_minimum_size = Vector2(0, 66)
	all.pressed.connect(_enhance_all)
	_gear_btns["_all"] = all
	_panel_body.add_child(all)
	_panel_body.add_child(IdleUi.label("더 센 장비는 몬스터가 떨어뜨리고, 우두머리를 처음 물리치면 선물로 줘요.", 18,
		IdleUi.SUB))
	_refresh_gear_buttons()


func _refresh_gear_buttons() -> void:
	var any := false
	for s in IdleData.SLOTS:
		var b = _gear_btns.get(s)
		if b == null or not is_instance_valid(b):
			continue
		var g: Array = IdleState.gear[s]
		if int(g[1]) >= IdleData.PLUS_MAX:
			b.text = "최고!"
			b.disabled = true
		else:
			b.text = "강화\n꿈조각 %s" % _num(IdleState.enhance_cost_of(String(s)))
			b.disabled = not IdleState.can_enhance(String(s))
			any = any or not b.disabled
	var all = _gear_btns.get("_all")
	if all != null and is_instance_valid(all):
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
	var sc := _panel_scroll.scroll_vertical
	_fill()
	_panel_scroll.set_deferred("scroll_vertical", sc)
	_refresh()


func _fill_stage() -> void:
	_clear_body()
	_title("스테이지", "가본 곳으로 다시 갈 수 있어요")
	var last := mini(IdleState.best, IdleData.STAGE_MAX)
	var zone_max := (last - 1) / IdleData.STAGES_PER_ZONE
	for zi in range(zone_max + 1):
		var z: Dictionary = IdleData.ZONES[zi]
		var sky: Array = z["sky"]
		var card := _card(Color(sky[0]))
		_panel_body.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", 10)
		hh.add_child(IdleUi.label("%d구역" % (zi + 1), 20, Color(sky[0])))
		hh.add_child(IdleUi.label(String(z["name"]), 24))
		cv.add_child(hh)
		var gr := GridContainer.new()
		gr.columns = 5 if _narrow() else 10
		gr.add_theme_constant_override("h_separation", 6)
		for i in range(1, IdleData.STAGES_PER_ZONE + 1):
			var n := zi * IdleData.STAGES_PER_ZONE + i
			var here := n == IdleState.stage
			var b := IdleUi.button(str(i) if i < 10 else "왕", 20, "gold" if here else "plum")
			b.custom_minimum_size = Vector2(80, 52)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = n > IdleState.best
			b.pressed.connect(_go_stage.bind(n))
			gr.add_child(b)
		cv.add_child(gr)
	if IdleState.best > IdleData.STAGE_MAX:
		var b := IdleUi.button("잿마루 끝없는 길 (지금까지 %d)" % (IdleState.best - IdleData.STAGE_MAX - 1), 24, "gold")
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(_go_stage.bind(IdleState.best))
		_panel_body.add_child(b)


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
## 위에 무엇이 덮여 있어도 막히지 않는다.
func _input(e: InputEvent) -> void:
	if not _say_layer.visible:
		return
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventKey and e.pressed and not e.echo)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _t - _say_at < 0.25:
		return
	_say_next()


## 안드로이드 뒤로가기: 열린 것을 하나 닫는다. 닫을 게 있었으면 참.
func close_panel() -> bool:
	if _say_layer.visible:
		_say_next()
		return true
	if _reward_layer.visible:
		_close_reward()
		return true
	if _menu_layer.visible:
		_close_menu()
		return true
	if _panel.visible:
		_close_tab()
		return true
	return false


func _leave() -> void:
	_menu_layer.visible = false
	IdleState.save(int(Time.get_unix_time_from_system()))
	SceneTransition.go_to(MENU_PATH, "normal")

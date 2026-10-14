extends Control
## 진짜 행복 (키우기) - 한 화면. 전투(자동) + 큰 버튼 셋(캐릭터·장비·스테이지) + [보스 도전].
## 규칙은 전부 IdleState/IdleFight 에 있고, 여기는 그리기와 버튼만 한다 (`docs/redesign-idle.md`).

const W := 1280.0
const H := 720.0
const SAVE_EVERY := 10.0
const MENU_PATH := "res://scenes/menu/MainMenu3D.tscn"
const INK := Color("#3B3550")
const PAPER := Color("#FFF8EC")
const GOLD := Color("#F2B544")

var fight := IdleFight.new()
var _sky: TextureRect
var _grad: Gradient
var _ground: ColorRect
var _hero: TextureRect
var _mon: TextureRect
var _hero_bar: ProgressBar
var _mon_bar: ProgressBar
var _mon_name: Label
var _stage_lbl: Label
var _wave_lbl: Label
var _coin_lbl: Label
var _lv_lbl: Label
var _xp_bar: ProgressBar
var _boss_btn: Button
var _tab_btns: Dictionary = {}
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _tab := ""
var _fx: Control
var _toast_lbl: Label
var _say_layer: Control
var _say_lbl: Label
var _say_lines: Array = []
var _say_done: Callable
var _t := 0.0
var _save_t := 0.0
var _hero_tex: Texture2D
var _mon_tex: Texture2D
var _mon_kind := ""
var _hero_flash := 0.0
var _mon_flash := 0.0
var _hero_lunge := 0.0
var _mon_lunge := 0.0
var _mon_alive := false
var _blocked := false         ## 이야기 장이 떠 있는 동안 전투를 멈춘다


func _ready() -> void:
	add_to_group("idle_game")
	if not IdleState.load_save():
		IdleState.reset()
	_build()
	AudioManager.play_bgm("room")
	var back := Time.get_unix_time_from_system()
	var r := IdleState.claim_offline(int(back))
	if not IdleState.seen_intro:
		IdleState.seen_intro = true
		_say(["여기는 꿈결.", "작은 쿼카가 혼자서도 씩씩하게 싸워요.", "나는 장비를 키우고, 더 먼 곳으로 보내 주면 돼요."],
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_grad = Gradient.new()
	var gt := GradientTexture2D.new()
	gt.gradient = _grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_sky = TextureRect.new()
	_sky.texture = gt
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_ground = ColorRect.new()
	_ground.position = Vector2(0, 470)
	_ground.size = Vector2(W, H - 470)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	_hero_tex = load("res://assets/sprites/hero-walk.png")
	_hero = _sprite()
	add_child(_hero)
	_mon = _sprite()
	add_child(_mon)
	_hero_bar = _bar(Color("#7FD08C"))
	add_child(_hero_bar)
	_mon_bar = _bar(Color("#E8737A"))
	add_child(_mon_bar)
	_mon_name = _label("", 22)
	_mon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_mon_name)

	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	# 위 줄
	var top := ColorRect.new()
	top.color = Color(1, 1, 1, 0.55)
	top.size = Vector2(W, 78)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_stage_lbl = _label("", 30)
	_stage_lbl.position = Vector2(24, 8)
	add_child(_stage_lbl)
	_wave_lbl = _label("", 20)
	_wave_lbl.position = Vector2(26, 46)
	add_child(_wave_lbl)
	_lv_lbl = _label("", 26)
	_lv_lbl.position = Vector2(420, 6)
	add_child(_lv_lbl)
	_xp_bar = _bar(GOLD)
	_xp_bar.position = Vector2(420, 48)
	_xp_bar.size = Vector2(220, 14)
	add_child(_xp_bar)
	_coin_lbl = _label("", 28)
	_coin_lbl.position = Vector2(700, 18)
	add_child(_coin_lbl)
	var out := _button("나가기", 18)
	out.position = Vector2(W - 130, 14)
	out.size = Vector2(110, 50)
	out.pressed.connect(_leave)
	add_child(out)

	# 아래 줄
	var names := {"char": "캐릭터", "gear": "장비", "stage": "스테이지"}
	var x := 24.0
	for k in ["char", "gear", "stage"]:
		var b := _button(names[k], 32)
		b.position = Vector2(x, H - 118)
		b.size = Vector2(240, 96)
		b.pressed.connect(_open_tab.bind(k))
		add_child(b)
		_tab_btns[k] = b
		x += 256.0
	_boss_btn = _button("보스 도전!", 32)
	_boss_btn.position = Vector2(W - 304, H - 118)
	_boss_btn.size = Vector2(280, 96)
	_boss_btn.add_theme_color_override("font_color", Color("#B0303A"))
	_boss_btn.pressed.connect(_on_boss)
	_boss_btn.visible = false
	add_child(_boss_btn)

	# 창 하나
	_panel = PanelContainer.new()
	_panel.position = Vector2(60, 90)
	_panel.size = Vector2(W - 120, 500)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = INK
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 8)
	_panel.add_child(_panel_body)

	_toast_lbl = _label("", 28)
	_toast_lbl.position = Vector2(0, 110)
	_toast_lbl.size = Vector2(W, 50)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.modulate.a = 0.0
	add_child(_toast_lbl)

	# 한 문장씩 보여 주는 층
	_say_layer = Control.new()
	_say_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_layer.visible = false
	add_child(_say_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.16, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_layer.add_child(dim)
	_say_lbl = _label("", 40)
	_say_lbl.add_theme_color_override("font_color", Color.WHITE)
	_say_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_say_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_say_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_layer.add_child(_say_lbl)
	var hint := _label("화면을 누르세요", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.position = Vector2(0, H - 70)
	hint.size = Vector2(W, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_layer.add_child(hint)
	_say_layer.gui_input.connect(_say_input)


func _sprite() -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.size = Vector2(200, 18)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.18, 0.28, 0.35)
	bg.set_corner_radius_all(6)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, size: int) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("#7C7590"))
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#FFE9B8")
	n.set_corner_radius_all(16)
	n.set_border_width_all(3)
	n.border_color = INK
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color("#F6CF7A")
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("#E4DDD0")
	d.border_color = Color("#9C94A8")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.focus_mode = Control.FOCUS_NONE
	return b


# ── 전투 흐름 ────────────────────────────────────────────────────────

func _start_stage() -> void:
	fight.start(IdleState.stage)
	var info := fight.info
	var z: Dictionary = IdleData.ZONES[int(info["zone"])]
	var sky: Array = z["sky"]
	_grad.set_color(0, Color(sky[0]))
	_grad.set_color(1, Color(sky[1]))
	_ground.color = Color(sky[0]).darkened(0.35)
	_mon_alive = false
	_mon.visible = false
	_mon_bar.visible = false
	_mon_name.text = ""
	_set_mon_kind(String(info["kind"]))
	_refresh()


func _set_mon_kind(kind: String) -> void:
	_mon_kind = kind
	var p := "res://assets/sprites/s-%s-walk.png" % kind
	_mon_tex = load(p) if ResourceLoader.exists(p) else null


func _process(dt: float) -> void:
	_t += dt
	_hero_flash = maxf(0.0, _hero_flash - dt)
	_mon_flash = maxf(0.0, _mon_flash - dt)
	_hero_lunge = maxf(0.0, _hero_lunge - dt * 4.0)
	_mon_lunge = maxf(0.0, _mon_lunge - dt * 4.0)
	if not _blocked and not fight.done:
		var evs := fight.tick(minf(dt, 0.25))
		for e in evs:
			_on_event(e)
	elif fight.done and not _blocked:
		_finish()
	_draw_actors()
	_save_t += dt
	if _save_t >= SAVE_EVERY:
		_save_t = 0.0
		IdleState.save(int(Time.get_unix_time_from_system()))


func _on_event(e: Dictionary) -> void:
	match String(e["k"]):
		"spawn":
			_mon_alive = true
			_mon.visible = true
			_mon_bar.visible = true
			_mon_name.text = String(IdleData.MOB_NAMES.get(String(e["kind"]), ""))
			_refresh()
		"hero_hit":
			_hero_lunge = 1.0
			_mon_flash = 0.15
			var crit: bool = bool(e["crit"])
			var txt := str(e["dmg"]) + ("!" if crit else "")
			_pop(txt, _mon_pos() + Vector2(0, -120), GOLD if crit else Color.WHITE,
				34 if crit else 26)
			AudioManager.battle_hit()
		"mon_hit":
			_mon_lunge = 1.0
			_hero_flash = 0.15
			_pop(str(e["dmg"]), _hero_pos() + Vector2(0, -120), Color("#FF8A8A"), 24)
			AudioManager.battle_hurt()
		"skill":
			_pop(String(e["name"]), _hero_pos() + Vector2(0, -170), Color("#9AE0FF"), 32)
		"kill":
			_mon_alive = false
			_mon.visible = false
			_mon_bar.visible = false
			_pop("+%d" % int(e["coin"]), _mon_pos() + Vector2(0, -60), GOLD, 24)
			if not (e["drop"] as Array).is_empty():
				var d: Array = e["drop"]
				_toast("%s 을(를) 얻었어요!" % IdleData.item_name(String(d[0]), int(d[1]), IdleState.job))
			_refresh()
		"level_up":
			_toast("레벨 %d!" % int(e["level"]))
			AudioManager.souvenir_get()
			_refresh()


func _finish() -> void:
	if fight.result == "clear":
		var was_boss := bool(fight.info["boss"])
		var o := IdleState.on_clear()
		var rw: Array = o.get("reward", [])
		if not rw.is_empty():
			_toast("우두머리 선물! %s" % IdleData.item_name(String(rw[0]), int(rw[1]), IdleState.job))
		elif was_boss and bool(o["new_best"]):
			_toast("우두머리를 물리쳤어요!")
		IdleState.save(int(Time.get_unix_time_from_system()))
		if o.has("ending"):
			IdleState.ending_seen = true
			_blocked = true
			_say(["마지막 우두머리까지 물리쳤어요!", "꿈결에 다시 고요한 아침이 와요.",
				"고마워요. 쿼카는 더 먼 곳으로 계속 걸어가요."], func(): _blocked = false; _start_stage())
			return
	else:
		IdleState.on_defeat()
		_toast("쓰러졌어요… 한 걸음 물러나 힘을 모아요")
		IdleState.save(int(Time.get_unix_time_from_system()))
	_start_stage()
	if _tab == "stage":
		_fill_stage()


func _on_boss() -> void:
	if IdleState.challenge_boss():
		_start_stage()


# ── 그리기 ───────────────────────────────────────────────────────────

func _hero_pos() -> Vector2:
	return Vector2(300, 470)


func _mon_pos() -> Vector2:
	return Vector2(930, 470)


func _cell(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	var cw := tex.get_width() / 4.0
	var ch := tex.get_height() / 3.0
	a.region = Rect2(col * cw, row * ch, cw, ch)
	return a


func _place(r: TextureRect, tex: Texture2D, feet: Vector2, scale_px: float, lunge: float, dir: float) -> void:
	var cw := tex.get_width() / 4.0
	var ch := tex.get_height() / 3.0
	r.size = Vector2(cw, ch) * scale_px
	r.position = feet - Vector2(r.size.x * 0.5, r.size.y) + Vector2(dir * lunge * 40.0, -absf(sin(_t * 6.0)) * 4.0)


func _draw_actors() -> void:
	var f := int(_t * 6.0) % 4
	if _hero_tex != null:
		_hero.texture = _cell(_hero_tex, f, 1)
		_hero.flip_h = true
		_place(_hero, _hero_tex, _hero_pos(), 7.0, _hero_lunge, 1.0)
		_hero.modulate = Color(1, 0.6, 0.6) if _hero_flash > 0.0 else Color.WHITE
		_hero_bar.position = _hero_pos() + Vector2(-100, 18)
		_hero_bar.max_value = maxf(1.0, fight.hero_max)
		_hero_bar.value = fight.hero_hp
	if _mon_tex != null and _mon.visible:
		_mon.texture = _cell(_mon_tex, f, 0)
		var boss := bool(fight.info.get("boss", false))
		_place(_mon, _mon_tex, _mon_pos(), 5.0 if boss else 6.0, _mon_lunge, -1.0)
		_mon.modulate = Color(1, 0.6, 0.6) if _mon_flash > 0.0 else Color.WHITE
		_mon_bar.position = _mon_pos() + Vector2(-100, 18)
		_mon_bar.max_value = maxf(1.0, fight.mon_max)
		_mon_bar.value = fight.mon_hp
		_mon_name.position = _mon_pos() + Vector2(-100, 44)
		_mon_name.size = Vector2(200, 30)


func _refresh() -> void:
	var info := fight.info if not fight.info.is_empty() else IdleData.stage_info(IdleState.stage)
	_stage_lbl.text = IdleData.stage_label(IdleState.stage)
	var left := fight.total - fight.left if fight.total > 0 else 0
	_wave_lbl.text = "우두머리!" if bool(info["boss"]) else "몬스터 %d / %d" % [mini(left + 1, IdleData.WAVE), IdleData.WAVE]
	_coin_lbl.text = "✦ 꿈조각 %s" % _num(IdleState.coins)
	_lv_lbl.text = "LV %d" % IdleState.level
	_xp_bar.max_value = IdleData.exp_need(IdleState.level)
	_xp_bar.value = IdleState.xp
	_boss_btn.visible = IdleState.boss_failed
	_hero_bar.max_value = maxf(1.0, fight.hero_max)


func _pop(txt: String, at: Vector2, col: Color, size: int) -> void:
	var l := _label(txt, size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = at + Vector2(randf_range(-30, 30), 0)
	_fx.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _toast(t: String) -> void:
	_toast_lbl.text = t
	_toast_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_toast_lbl, "modulate:a", 0.0, 0.5)


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
	_fill()


func _close_tab() -> void:
	_tab = ""
	_panel.visible = false


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


func _title(t: String) -> void:
	var row := HBoxContainer.new()
	var l := _label(t, 34)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var x := _button("닫기", 22)
	x.custom_minimum_size = Vector2(110, 48)
	x.pressed.connect(_close_tab)
	row.add_child(x)
	_panel_body.add_child(row)


func _fill_char() -> void:
	_clear_body()
	_title("캐릭터")
	var h := IdleState.hero()
	var j: Dictionary = IdleData.JOBS[IdleState.job]
	_panel_body.add_child(_label("LV %d · %s · 전투력 %s" % [IdleState.level, String(j["name"]), _num(IdleState.power())], 28))
	var need := IdleData.exp_need(IdleState.level)
	_panel_body.add_child(_label("경험 %d / %d" % [IdleState.xp, need] if IdleState.level < IdleData.LEVEL_MAX else "최고 레벨!", 22))
	_panel_body.add_child(_label("체력 %d · 공격 %d · 방어 %d" % [int(h["hp"]), int(h["atk"]), int(h["def"])], 26))
	var sk: Dictionary = h["skill"]
	if not sk.is_empty():
		_panel_body.add_child(_label("필살기 %s - %d초마다 저절로 나가요" % [String(sk["name"]), int(sk["every"])], 22))
	if not IdleState.can_pick_job():
		_panel_body.add_child(_label("LV %d 이 되면 직업을 고를 수 있어요." % IdleData.JOB_LV, 24))
		return
	_panel_body.add_child(_label("직업 (언제든 공짜로 바꿔요)", 24))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for jid in IdleData.JOB_ORDER:
		var jd: Dictionary = IdleData.JOBS[jid]
		var b := _button("%s\n%s" % [String(jd["name"]), String(jd["desc"])], 20)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = IdleState.job == jid
		b.pressed.connect(_pick_job.bind(String(jid)))
		row.add_child(b)
	_panel_body.add_child(row)


func _pick_job(j: String) -> void:
	if IdleState.set_job(j):
		AudioManager.ui_confirm()
		fight.start(IdleState.stage)       # 새 몸으로 이 스테이지부터 다시
		_start_stage()
		_fill_char()
		IdleState.save()


func _fill_gear() -> void:
	_clear_body()
	_title("장비 - 꿈조각으로 강화해요 (실패 없어요)")
	var sname := {"atk": "공격", "hp": "체력", "def": "방어"}
	for s in IdleData.SLOTS:
		var g: Array = IdleState.gear[s]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := _label("%s  [%d단계 +%d]" % [IdleData.item_name(String(s), int(g[0]), IdleState.job), int(g[0]), int(g[1])], 24)
		info.custom_minimum_size = Vector2(520, 0)
		row.add_child(info)
		var v := _label("%s +%d" % [sname[IdleData.SLOT_STAT[s]], int(IdleData.slot_value(String(s), int(g[0]), int(g[1])))], 24)
		v.custom_minimum_size = Vector2(160, 0)
		row.add_child(v)
		var b := _button("", 22)
		b.custom_minimum_size = Vector2(250, 56)
		if int(g[1]) >= IdleData.PLUS_MAX:
			b.text = "최고 강화"
			b.disabled = true
		else:
			b.text = "강화 ✦%s" % _num(IdleState.enhance_cost_of(String(s)))
			b.disabled = not IdleState.can_enhance(String(s))
		b.pressed.connect(_enhance.bind(String(s)))
		row.add_child(b)
		_panel_body.add_child(row)
	_panel_body.add_child(_label("더 센 장비는 몬스터가 떨어뜨리고, 우두머리를 처음 물리치면 선물을 줘요.", 20))


func _enhance(slot: String) -> void:
	if IdleState.enhance(slot):
		AudioManager.ui_confirm()
		var keep := fight.hero_hp / maxf(1.0, fight.hero_max)
		fight.h = IdleState.hero()
		fight.hero_max = float(fight.h["hp"])
		fight.hero_hp = fight.hero_max * keep
		_refresh()
		_fill_gear()


func _fill_stage() -> void:
	_clear_body()
	_title("스테이지 - 가본 곳으로 다시 갈 수 있어요")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 390)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	_panel_body.add_child(sc)
	var last := mini(IdleState.best, IdleData.STAGE_MAX)
	var zone_max := (last - 1) / IdleData.STAGES_PER_ZONE
	for zi in range(zone_max + 1):
		var z: Dictionary = IdleData.ZONES[zi]
		vb.add_child(_label("%d. %s" % [zi + 1, String(z["name"])], 24))
		var gr := GridContainer.new()
		gr.columns = 10
		gr.add_theme_constant_override("h_separation", 6)
		for i in range(1, IdleData.STAGES_PER_ZONE + 1):
			var n := zi * IdleData.STAGES_PER_ZONE + i
			var b := _button(str(i) if i < 10 else "왕", 20)
			b.custom_minimum_size = Vector2(86, 52)
			b.disabled = n > IdleState.best
			if n == IdleState.stage:
				b.add_theme_color_override("font_color", Color("#B0303A"))
				b.text = "▶" + b.text
			b.pressed.connect(_go_stage.bind(n))
			gr.add_child(b)
		vb.add_child(gr)
	if IdleState.best > IdleData.STAGE_MAX:
		var b := _button("잿마루 끝없는 길 (지금까지 %d)" % (IdleState.best - IdleData.STAGE_MAX - 1), 24)
		b.pressed.connect(_go_stage.bind(IdleState.best))
		vb.add_child(b)


func _go_stage(n: int) -> void:
	if IdleState.go_stage(n):
		AudioManager.ui_click()
		_close_tab()
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
	AudioManager.page_turn()


func _say_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventKey and e.pressed and not e.echo):
		accept_event()
		_say_next()


func _unhandled_key_input(e: InputEvent) -> void:
	if _say_layer.visible and e is InputEventKey and e.pressed and not e.echo:
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

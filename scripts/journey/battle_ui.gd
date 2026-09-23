class_name BattleUI
extends CanvasLayer
## 마음 겨루기 화면.
##
## **마을을 지우지 않는다.** 뒤에 서 있던 그 자리가 어둡게 깔린 채로
## 남는다 — 어디서 싸우는지가 보여야 여행의 한 장면으로 읽힌다.
##
## 일어난 일은 `Battle` 이 **사건 배열**로 돌려준다. 이 화면은 그걸
## 한 줄씩 재생만 한다 — 규칙과 그림을 갈라 두면 규칙을 고쳐도 화면이
## 안 깨지고, 검사도 화면 없이 규칙만 돌려볼 수 있다.
##
## **포켓몬 골드처럼** — 기술마다 마음력이 얼마나 드는지 한눈에 보이고,
## 맞고 때리는 순간에 반응이 있어야 손맛이 난다. 그래서 여기엔 규칙과
## 상관없는 "느낌" 만 모아 둔다: 맞으면 흔들리고, 옅어지면 스러지고,
## 세게 닿으면 조각이 튄다. `Battle` 은 이런 걸 하나도 모른다.

signal closed(won: bool)

## 사건 하나를 보여 주고 다음까지 기다리는 시간. 검사는 0 으로 둔다.
var step_secs := 0.42

var _root: Control
var _pic: TextureRect
var _e_name: Label
var _e_bar: Control
var _e_fill: ColorRect
var _e_num: Label
var _e_st: Label
var _intent: Label
var _log: Label
var _hp_fill: ColorRect
var _hp_num: Label
var _mp_fill: ColorRect
var _mp_num: Label
var _lv: Label
var _my_st: Label
var _menu: VBoxContainer
var _list: ScrollContainer
var _list_box: VBoxContainer
var _busy := false
var _over := false
var _won := false
## **악당을 고르면 저절로 붙는다.** 매 턴 마음을 직접 고르지 않아도
## 기본 공격(웃어넘기기, 마음력 0)을 자동으로 반복한다 - 그러면서도
## 마음을 쓰고 싶으면 언제든 "마음을 쓴다" 로 끼어들 수 있다. 자동은
## 그 사이사이를 메울 뿐, 사람이 고르는 걸 대신 막지 않는다.
var _auto := true
const AUTO_SKILL := "smile"
## 주인공 쪽 그림. 여태 이 화면엔 그늘 그림만 있었다 — 때리는 쪽이
## 안 보이니 손맛이 반쪽이었다. 새 그림을 그리는 대신 세계에서 이미
## 쓰는 `hero-walk.png` 한 칸을 오려 쓴다.
var _hero: TextureRect
var _hero_tex: Texture2D

const BAR_W := 360.0
const MY_BAR_W := 300.0
const INK := Color("#F4EDE2")
const DIM := Color("#A79A8A")

## 체력이 줄수록 색이 바뀐다(포켓몬 골드의 그 초록-노랑-빨강). 숫자를
## 안 읽어도 "위험하다" 가 눈에 먼저 들어와야 한다.
const HP_HIGH := Color("#7FB08A")
const HP_MID := Color("#E3C15A")
const HP_LOW := Color("#D9705A")


func _ready() -> void:
	layer = 12
	add_to_group("overlay")
	add_to_group("battle_ui")
	_build()


## 뒤로가기가 부른다. 싸우는 중이면 물러나기와 같다.
func close() -> void:
	if _over:
		_finish()
	elif not _busy:
		_act_flee()


func open(kind: String) -> void:
	Battle.start(kind)
	var e := Battle.enemy
	_pic.texture = load("res://assets/sprites/s-%s.png" % String(e["sheet"]))
	_e_name.text = String(e["name"])
	_log.text = String(e["line"])
	AudioManager.wind_gust()
	_refresh()
	_show_menu()
	# 나타나는 연출 — 옅은 데서 짙어진다.
	_pic.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_pic, "modulate:a", 1.0, 0.45)


# ── 짓기 ──────────────────────────────────────────────────────────────

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	# **0.80 으로는 마을이 너무 또렷했다.** 뒤에 선 자리가 보이는 건
	# 좋지만, 바닥 무늬와 소품이 그늘 실루엣과 같은 밝기로 남으면
	# 어느 것이 적인지가 안 읽힌다. 배경으로 물러날 만큼 낮춘다.
	dim.color = Color(0.07, 0.06, 0.09, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	# ── 그늘 쪽 (위 가운데) ──
	_e_name = _label(30, Color("#FFC8C8"))
	_e_name.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_e_name.offset_left = -300
	_e_name.offset_right = 300
	_e_name.offset_top = 22
	_root.add_child(_e_name)

	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pic.offset_left = -150
	_pic.offset_right = 150
	_pic.offset_top = 52
	_pic.offset_bottom = 292
	_root.add_child(_pic)

	# 등급색과 시작 색을 맞춘다 — 첫 프레임부터 초록이어야 나중에
	# 색이 바뀌는 게 "줄어든다" 는 뜻으로 읽힌다.
	_e_bar = _bar(_root, Control.PRESET_CENTER_TOP, -BAR_W * 0.5, 300,
		BAR_W, 22, HP_HIGH)
	_e_fill = _e_bar.get_child(1)
	_e_num = _e_bar.get_child(2)

	_e_st = _label(19, Color("#C8FFD8"))
	_e_st.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_e_st.offset_left = -360
	_e_st.offset_right = 360
	_e_st.offset_top = 328
	_root.add_child(_e_st)

	_intent = _label(21, Color("#FFE39A"))
	_intent.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_intent.offset_left = -360
	_intent.offset_right = 360
	_intent.offset_top = 356
	_root.add_child(_intent)

	# ── 한 줄 말 (가운데) ──
	_log = _label(24, INK)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_log.offset_left = -400
	_log.offset_right = 400
	_log.offset_top = 394
	_log.offset_bottom = 462
	_root.add_child(_log)

	# ── 나 (왼쪽 아래) ──
	#
	# LV·체력·마음력 판 위에 작게 선다. 적수(그늘)는 위 가운데에 큰
	# 그림이 있는데 내 쪽엔 그림이 하나도 없었다 - 때리는 게 누군지
	# 안 보이니 얻어맞는 그늘만 일방적으로 보이는 셈이었다.
	_hero = TextureRect.new()
	_hero.texture = _hero_frame(2, 0)
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hero.offset_left = 30
	_hero.offset_right = 30 + 84
	_hero.offset_top = -278
	_hero.offset_bottom = -182
	_root.add_child(_hero)

	_lv = _label(24, Color("#FFE39A"), HORIZONTAL_ALIGNMENT_LEFT)
	_lv.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lv.offset_left = 26
	_lv.offset_right = 360
	_lv.offset_top = -176
	_lv.offset_bottom = -146
	_root.add_child(_lv)

	var hp_bar := _bar(_root, Control.PRESET_BOTTOM_LEFT, 26, -142,
		MY_BAR_W, 22, Color("#7FB08A"))
	_hp_fill = hp_bar.get_child(1)
	_hp_num = hp_bar.get_child(2)
	var mp_bar := _bar(_root, Control.PRESET_BOTTOM_LEFT, 26, -112,
		MY_BAR_W, 22, Color("#7FA8D8"))
	_mp_fill = mp_bar.get_child(1)
	_mp_num = mp_bar.get_child(2)

	_my_st = _label(19, Color("#FFD9A8"), HORIZONTAL_ALIGNMENT_LEFT)
	_my_st.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_my_st.offset_left = 26
	_my_st.offset_right = 420
	_my_st.offset_top = -82
	_my_st.offset_bottom = -56
	_root.add_child(_my_st)

	# ── 고를 것 (오른쪽 아래) ──
	_menu = VBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_END
	_menu.add_theme_constant_override("separation", 10)
	_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_menu.offset_left = -300
	_menu.offset_right = -26
	_menu.offset_top = -250
	_menu.offset_bottom = -26
	_root.add_child(_menu)

	# **목록은 아래에서 위로 자란다.** 높이를 못 박아 뒀더니 스킬 여섯에
	# "그만두기" 까지 일곱 줄이 되면서 맨 아랫줄이 화면 밖으로 잘렸다.
	# 손에 쥘 것은 더 길어질 수 있어서(주운 것이 열 가지가 넘는다)
	# 굴릴 수 있게 감싼다.
	_list = ScrollContainer.new()
	_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_list.offset_left = -440
	_list.offset_right = -26
	_list.offset_top = -420
	_list.offset_bottom = -26
	_list.visible = false
	_root.add_child(_list)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_list_box)


func _label(size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.09, 0.12))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 막대 하나. [바탕, 채움, 숫자] 순서로 자식을 단다 — 부르는 쪽이
## `get_child(1)`, `get_child(2)` 로 집어 간다.
func _bar(parent: Control, preset: int, x: float, y: float,
		w: float, h: float, col: Color) -> Control:
	var box := Control.new()
	box.set_anchors_preset(preset)
	box.offset_left = x
	box.offset_right = x + w
	box.offset_top = y
	box.offset_bottom = y + h
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	var bg := ColorRect.new()
	bg.color = Color(0.20, 0.18, 0.22, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)

	var fill := ColorRect.new()
	fill.color = col
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.offset_right = w
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)

	var num := _label(17, Color(0.10, 0.09, 0.12))
	num.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.65))
	num.add_theme_constant_override("outline_size", 5)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(num)
	box.set_meta("w", w)
	return box


## `grade` 를 켜면 채움 색까지 체력 비율에 맞춰 바뀐다 — 마음력 막대는
## 그대로 파랑이어야 해서(줄어든다고 위험 신호를 줄 일이 아니다) 기본은 끈다.
func _fill_to(fill: ColorRect, now: int, most: int, w: float,
		grade := false) -> void:
	var k: float = clampf(float(now) / maxf(1.0, float(most)), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fill, "offset_right", w * k, 0.22)
	if grade:
		tw.parallel().tween_property(fill, "color", _hp_color(k), 0.22)


## 절반 넘게 남았으면 초록, 5분의 1까지는 노랑으로 물들다가, 그 아래는
## 빨강. 경계마다 뚝 끊기지 않게 두 구간을 각각 이어 붙인다.
func _hp_color(k: float) -> Color:
	k = clampf(k, 0.0, 1.0)
	if k >= 0.5:
		return HP_MID.lerp(HP_HIGH, (k - 0.5) / 0.5)
	if k >= 0.2:
		return HP_LOW.lerp(HP_MID, (k - 0.2) / 0.3)
	return HP_LOW


# ── 새로 고치기 ──────────────────────────────────────────────────────

func _refresh() -> void:
	var e := Battle.enemy
	if not e.is_empty():
		_fill_to(_e_fill, int(e["hp"]), int(e["hp_max"]), BAR_W, true)
		_e_num.text = "%d / %d" % [int(e["hp"]), int(e["hp_max"])]
		_e_st.text = _status_text(Battle.enemy_status, Battle.ENEMY_STATUSES)
	_fill_to(_hp_fill, Battle.hp, Battle.hp_max(), MY_BAR_W, true)
	_fill_to(_mp_fill, Battle.mp, Battle.mp_max(), MY_BAR_W)
	_hp_num.text = "체력  %d / %d" % [Battle.hp, Battle.hp_max()]
	_mp_num.text = "마음력  %d / %d" % [Battle.mp, Battle.mp_max()]
	_lv.text = "LV %d" % Battle.level
	_my_st.text = _status_text(Battle.my_status, Battle.STATUSES)
	_intent.text = ("> " + Battle.intent()) if Battle.in_battle else ""
	# 자동 사냥 중이면 같은 줄에 덧붙인다 - 줄을 늘리면(`\n`) 바로
	# 아래 `_log` 와 겹친다. 버튼 글자("자동 사냥 끄기") 만으로는
	# 지나치기 쉬워 한마디 더한다.
	if Battle.in_battle and _auto:
		_intent.text += "   ·   자동으로 붙는 중"


func _status_text(held: Dictionary, table: Dictionary) -> String:
	if held.is_empty():
		return ""
	var bits: Array = []
	for id in held:
		bits.append("%s %d" % [String(table[id]["name"]), int(held[id])])
	return "  ·  ".join(bits)


# ── 고를 것 ──────────────────────────────────────────────────────────

func _show_menu() -> void:
	_list.visible = false
	for c in _menu.get_children():
		c.queue_free()
	_menu.visible = true
	_add_btn(_menu, "자동 사냥 끄기" if _auto else "자동 사냥 켜기", _toggle_auto)
	_add_btn(_menu, "마음을 쓴다", _open_skills)
	_add_btn(_menu, "손에 쥔다", _open_items)
	_add_btn(_menu, "물러난다", _act_flee)
	_refresh()
	if _auto and not _over:
		_queue_auto()


func _toggle_auto() -> void:
	_auto = not _auto
	AudioManager.ui_click()
	_show_menu()


## 자동일 때 잠깐 뒤 스스로 기본 공격을 날린다. 사람이 그사이 목록을
## 펼쳐 고르는 중이면(`_list.visible`) 끼어들지 않는다 - 고르다 말고
## 화면이 저절로 넘어가면 뺏긴 느낌이 든다. 그때는 조용히 건너뛴다 -
## 어차피 사람이 고른 다음 `_show_menu()` 가 다시 예약한다.
func _queue_auto() -> void:
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and _auto and not _busy and not _over \
				and not _list.visible:
			_act_skill(AUTO_SKILL))


func _open_skills() -> void:
	_fill_list(func(box: VBoxContainer) -> void:
		for id in Battle.skills():
			_add_skill_btn(box, id))


## 스킬 버튼 하나. 글자는 그대로("이름 (마음력 N) *약점") 두고, **버튼
## 아래쪽에 얇은 띠**를 하나 더 얹는다 — 숫자만으로는 "이게 마음력을
## 크게 쓰는 기술인지" 가 한눈에 안 들어온다. 마음력 최대치에서 이
## 기술이 차지하는 몫이 클수록 길고 붉다(포켓몬 골드의 PP 칸과 같은 자리,
## 다만 "몇 번 남았나" 대신 "얼마나 크게 쓰나" 를 보여 준다).
func _add_skill_btn(box: VBoxContainer, id: String) -> Button:
	var s: Dictionary = Battle.SKILLS[id]
	var cost_n := int(s["mp"])
	var mark := "  *약점" if Battle.found_weak 		and Battle.weak_of(Battle.kind) == id else ""
	var cost := "   (마음력 %d)" % cost_n if cost_n > 0 else ""
	var b := _add_btn(box, "%s%s%s" % [String(s["name"]), cost, mark],
		_act_skill.bind(id))
	# 못 쓰는 것은 **지우지 않고 흐리게** 둔다. 목록에서 사라지면
	# 그런 수가 있다는 것 자체를 잊는다.
	if Battle.mp < cost_n:
		b.disabled = true
		b.modulate.a = 0.45
	if cost_n > 0:
		_add_cost_gauge(b, cost_n)
	return b


## 마음력 최대치 대비 몫만큼 채운 얇은 띠. 버튼 안쪽 아래 여백에 붙는다
## (mouse_filter 를 꺼서 누름은 그대로 버튼이 받는다).
func _add_cost_gauge(btn: Button, cost: int) -> void:
	var k: float = clampf(float(cost) / maxf(1.0, float(Battle.mp_max())),
		0.0, 1.0)
	var g := Control.new()
	g.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	g.offset_left = 16
	g.offset_right = -16
	g.offset_top = -13
	g.offset_bottom = -7
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 싸면 마음력 파랑, 크게 쓸수록 옅은 붉은빛으로 — 지출이 크다는
	# 인상만 준다. 실제 판정은 여전히 숫자(마음력 부족 시 흐리게)다.
	var col := Color("#7FA8D8").lerp(Color("#D9705A"), k)
	g.draw.connect(func() -> void:
		g.draw_rect(Rect2(Vector2.ZERO, g.size), Color(0, 0, 0, 0.24))
		g.draw_rect(Rect2(0, 0, g.size.x * k, g.size.y), col))
	btn.add_child(g)


func _open_items() -> void:
	_fill_list(func(box: VBoxContainer) -> void:
		var got := Battle.usable_items()
		if got.is_empty():
			var l := _label(22, DIM)
			l.text = "손에 쥘 것이 없다"
			box.add_child(l)
			return
		# **받은 먹을 것이 앞에 온다.** 할 일과 그늘에게서 받은 것(`b-*`)이
		# 주운 것보다 훨씬 잘 듣는다 - 쓸 만한 것이 목록 아래에 묻히면 안 된다.
		got.sort_custom(func(a: String, b: String) -> bool:
			return (a.begins_with("b-") and not b.begins_with("b-")) \
				or (a.begins_with("b-") == b.begins_with("b-") and a < b))
		for id in got:
			var what := Catalog.effect_text(id)
			_add_btn(box, "%s x%d   (%s)" % [
				Catalog.name_of(id),
				JourneyState.count(id), what], _act_item.bind(id)))


## 목록 판을 열고 `build` 가 채우게 한다. 맨 아래엔 늘 "그만두기".
func _fill_list(build: Callable) -> void:
	AudioManager.ui_click()
	_menu.visible = false
	for c in _list_box.get_children():
		c.queue_free()
	build.call(_list_box)
	_add_btn(_list_box, "그만두기", _show_menu)
	_list.visible = true
	_fit_list()


## 목록이 담긴 만큼만 높이를 잡는다. 화면을 넘으면 거기서 멎고 굴린다.
func _fit_list() -> void:
	var need: float = _list_box.get_combined_minimum_size().y + 8.0
	var room: float = maxf(200.0, _root.size.y - 120.0)
	_list.offset_top = -(minf(need, room) + 26.0)


func _add_btn(box: VBoxContainer, text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 22)
	Paper.button(b, Color("#F4EDE2"), Color("#8C7B68"), Color("#3A2C2C"), 14)
	b.pressed.connect(on)
	box.add_child(b)
	return b


func _hide_choices() -> void:
	_menu.visible = false
	_list.visible = false


# ── 하기 ─────────────────────────────────────────────────────────────

func _act_skill(id: String) -> void:
	if _busy:
		return
	AudioManager.ui_confirm()
	_play(Battle.player_use_skill(id))


func _act_item(id: String) -> void:
	if _busy:
		return
	AudioManager.pickup()
	_play(Battle.player_use_item(id))


func _act_flee() -> void:
	if _busy:
		return
	AudioManager.page_turn()
	_play(Battle.player_flee())


func _play(evs: Array) -> void:
	if evs.is_empty():
		return
	_busy = true
	_hide_choices()
	for e in evs:
		await _one(e)
	_busy = false
	_refresh()
	if _over:
		_show_result()
	else:
		_show_menu()


func _one(e: Dictionary) -> void:
	match String(e["kind"]):
		"line":
			_log.text = String(e["text"])
		"damage":
			var to_enemy: bool = String(e["to"]) == "enemy"
			var weak: bool = bool(e.get("weak", false))
			_log.text = "%s %d" % ["그늘에게" if to_enemy else "나에게",
				int(e["amount"])]
			_pop(to_enemy, "-%d" % int(e["amount"]),
				Color("#FFB4B4") if not to_enemy else Color("#FFE39A"), weak)
			if to_enemy:
				# **때린 쪽 반응.** 주인공이 앞으로 나서고(위쪽 그늘
				# 쪽으로), 그늘은 하얗게 한 번 번쩍이고 흔들리고
				# 파편이 튄다 — 약점을 찌른 것이면 다 조금씩 더 크게.
				_hero_attack()
				var finished_it: bool = int(Battle.enemy.get("hp", 1)) <= 0
				# **번쩍임과 스러짐은 같은 속성(modulate)을 다툰다.**
				# 마지막 한 방이면 번쩍이는 대신 곧장 스러지기 시작한다 —
				# 뒤이어 "옅어졌다" 는 말이 뜨는 동안 그림도 같이 옅어져야
				# 말과 그림이 따로 놀지 않는다.
				if finished_it:
					_defeat_enemy_visual()
				else:
					_flash_white(_pic)
				_shake(_pic)
				_burst(_pic.get_global_rect().get_center(),
					Color("#FFE9A8") if weak else Color("#FFC8A0"),
					10 if weak else 6, 58.0 if weak else 42.0)
				if weak:
					AudioManager.battle_weak_hit()
				else:
					AudioManager.battle_hit()
				# **죽는소리.** 마지막 한 방이면 타격음 위에 스러지는
				# 소리를 얹는다 - 통쾌한 "처치음" 이 아니라 잦아드는
				# 여운을 준다(그늘은 적이 아니라 마음의 그림자다).
				if finished_it:
					AudioManager.battle_defeat()
			else:
				# **맞은 쪽 반응.** 그늘이 화면 쪽으로 한 번 다가왔다
				# 물러나고(공격 동작), 주인공은 움츠러들며 흔들리고,
				# 화면이 붉게 스치고 살짝 떨린다.
				_lunge(_pic)
				_hero_hurt()
				_flash()
				_shake_root()
				AudioManager.battle_hurt()
		"heal":
			if int(e["amount"]) > 0:
				_pop(false, "+%d" % int(e["amount"]), Color("#B4FFC8"), false)
				_burst(Vector2(_root.size.x * 0.22, _root.size.y - 150.0),
					Color("#B4FFC8"), 5, 26.0)
				AudioManager.battle_heal()
		"status":
			_pop(String(e["to"]) == "enemy", String(e["text"]),
				Color("#C8E6FF"), false)
		"xp":
			_log.text = "마음이 조금 자랐다  (+%d)" % int(e["amount"])
		"level_up":
			_log.text = "LV %d" % int(e["level"])
			if String(e.get("skill", "")) != "":
				_log.text += " - '%s' 를 쓸 수 있게 됐다" % String(e["skill"])
			AudioManager.souvenir_get()
		"victory":
			_over = true
			_won = true
		"defeat", "fled":
			_over = true
			_won = false
	_refresh()
	if step_secs > 0.0:
		await get_tree().create_timer(step_secs).timeout


# ── 연출 ─────────────────────────────────────────────────────────────

func _pop(on_enemy: bool, text: String, col: Color, big: bool) -> void:
	var l := _label(34 if big else 28, col)
	l.text = text
	l.size = Vector2(240, 40)
	var mid: Vector2
	if on_enemy:
		mid = _pic.get_global_rect().get_center()
	else:
		mid = Vector2(_root.size.x * 0.22, _root.size.y - 230.0)
	l.position = mid - Vector2(120, 20)
	_root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 54.0, 0.7) \
		.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func _shake(n: Control) -> void:
	var home := n.offset_left
	var tw := create_tween()
	for i in 3:
		tw.tween_property(n, "offset_left", home + 7.0, 0.04)
		tw.tween_property(n, "offset_left", home - 7.0, 0.04)
	tw.tween_property(n, "offset_left", home, 0.04)


## `hero-walk.png` 시트에서 한 칸을 오린다. `QuoSprite` 와 같은 규칙
## (가로 4프레임 x 세로 3방향) — 여기선 위를 보는 줄(2)만 쓴다.
## 적이 위쪽에 있으니 그쪽을 보고 서야 마주 선 그림이 된다.
func _hero_frame(row: int, frame: int) -> AtlasTexture:
	if _hero_tex == null:
		_hero_tex = load("res://assets/sprites/hero-walk.png")
	var fw := _hero_tex.get_width() / 4.0
	var fh := _hero_tex.get_height() / 3.0
	var at := AtlasTexture.new()
	at.atlas = _hero_tex
	at.region = Rect2(float(frame) * fw, float(row) * fh, fw, fh)
	return at


## 주인공이 때린다 — 적 쪽(위)으로 한 번 다가섰다 물러나며, 내딛는
## 걸음 그림으로 잠깐 바뀐다. 그늘의 `_lunge()` 와 대칭이다(그쪽은
## 아래로, 이쪽은 위로).
func _hero_attack() -> void:
	if _hero == null:
		return
	var top := _hero.offset_top
	var bottom := _hero.offset_bottom
	var d := -20.0
	_hero.texture = _hero_frame(2, 2)
	var tw := create_tween()
	tw.tween_property(_hero, "offset_top", top + d, 0.08).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_hero, "offset_bottom", bottom + d, 0.08) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_hero, "offset_top", top, 0.16).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_hero, "offset_bottom", bottom, 0.16) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(_hero):
			_hero.texture = _hero_frame(2, 0))


## 주인공이 맞는다 — 살짝 움츠러드는 그림으로 바뀌고 흔들린다.
func _hero_hurt() -> void:
	if _hero == null:
		return
	_hero.texture = _hero_frame(2, 1)
	_shake(_hero)
	var tw := create_tween()
	tw.tween_interval(0.28)
	tw.tween_callback(func():
		if is_instance_valid(_hero):
			_hero.texture = _hero_frame(2, 0))


## 하얗게 한 번 번쩍였다 돌아온다 — 맞았다는 걸 색으로도 알린다.
## Godot 의 `modulate` 는 1을 넘겨도 잘려 나가지 않고 그만큼 밝아지므로,
## 셰이더 없이 "번쩍"을 흉내 낼 수 있다.
func _flash_white(n: CanvasItem) -> void:
	var tw := create_tween()
	tw.tween_property(n, "modulate", Color(2.6, 2.6, 2.6, 1.0), 0.045)
	tw.tween_property(n, "modulate", Color.WHITE, 0.12)


func _flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1.0, 0.45, 0.45, 0.30)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.28)
	tw.tween_callback(f.queue_free)


## 그늘이 화면 쪽으로 한 번 다가섰다 물러난다 — 이 화면엔 그늘 그림
## 하나뿐이라(내 쪽은 그림이 없다), "그늘이 나를 쳤다" 는 이 동작
## 하나로 전해야 한다. `_shake()` 처럼 오프셋을 직접 민다 — Control 은
## 앵커가 매겨진 rect 를 매 배치마다 오프셋으로 다시 계산하므로,
## `position` 을 직접 트윈하면 다음 배치에서 되돌아갈 수 있다.
func _lunge(n: Control) -> void:
	var top := n.offset_top
	var bottom := n.offset_bottom
	var d := 20.0
	var tw := create_tween()
	tw.tween_property(n, "offset_top", top + d, 0.09).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "offset_bottom", bottom + d, 0.09) 		.set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "offset_top", top, 0.16).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "offset_bottom", bottom, 0.16) 		.set_ease(Tween.EASE_IN)


## 화면 전체가 잠깐 떨린다 — 색 번쩍임(`_flash`)만으로는 "닿았다" 는
## 느낌이 얕다. 두어 번, 몇 픽셀만 흔든다 - 놀이가 아니라 **느낌**만
## 준다.
func _shake_root() -> void:
	var tw := create_tween()
	for i in 2:
		tw.tween_property(_root, "position",
			Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0)), 0.035)
	tw.tween_property(_root, "position", Vector2.ZERO, 0.035)


## 닿는 자리에서 조각 몇 개가 흩어진다. 그림(`.png`)을 새로 그리는 대신
## 작은 사각형을 코드로 던진다 — 이 게임의 다른 화면들이 다 그렇게
## 짓듯(막대·고리·점 전부 `_draw()`), 여기도 그림 파일을 안 늘린다.
func _burst(at: Vector2, col: Color, n: int = 8, spread: float = 46.0) -> void:
	for i in n:
		var r := ColorRect.new()
		var sz := randf_range(4.0, 8.0)
		r.color = col
		r.size = Vector2(sz, sz)
		r.position = at - Vector2(sz, sz) * 0.5
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(r)
		var ang := (TAU / float(n)) * float(i) + randf_range(-0.3, 0.3)
		var dist := randf_range(spread * 0.5, spread)
		var to := r.position + Vector2.from_angle(ang) * dist
		var tw := create_tween()
		tw.tween_property(r, "position", to, 0.32).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(r, "modulate:a", 0.0, 0.34)
		tw.tween_callback(r.queue_free)


## 마지막 한 방을 맞은 자리에서 그림이 스러진다. **세계에 선 그늘**
## (`Shade.dissolve()`, `place.gd`)이 전투가 끝난 뒤 사라지는 것과는
## 다른 자리다 — 이건 전투 화면 안 그림이 죽는 순간 옅어지는 것이고,
## 그건 마을로 돌아갔을 때 그 자리가 빈 것이다. 둘 다 있어야 한다.
func _defeat_enemy_visual() -> void:
	_pic.pivot_offset = _pic.size * 0.5
	var tw := create_tween()
	tw.tween_property(_pic, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_pic, "scale", Vector2(1.1, 0.5), 0.5) 		.set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_pic, "offset_top", _pic.offset_top + 26.0, 0.5)


# ── 끝 ───────────────────────────────────────────────────────────────

func _show_result() -> void:
	_intent.text = ""
	for c in _menu.get_children():
		c.queue_free()
	_menu.visible = true
	_list.visible = false
	_add_btn(_menu, "돌아가기", _finish)


func _finish() -> void:
	if not _won:
		Battle.recover_after_loss()
	closed.emit(_won)
	queue_free()

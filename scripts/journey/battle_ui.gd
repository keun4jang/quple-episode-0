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

const BAR_W := 360.0
const MY_BAR_W := 300.0
const INK := Color("#F4EDE2")
const DIM := Color("#A79A8A")


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

	_e_bar = _bar(_root, Control.PRESET_CENTER_TOP, -BAR_W * 0.5, 300,
		BAR_W, 22, Color("#C8788A"))
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


func _fill_to(fill: ColorRect, now: int, most: int, w: float) -> void:
	var k: float = clampf(float(now) / maxf(1.0, float(most)), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fill, "offset_right", w * k, 0.22)


# ── 새로 고치기 ──────────────────────────────────────────────────────

func _refresh() -> void:
	var e := Battle.enemy
	if not e.is_empty():
		_fill_to(_e_fill, int(e["hp"]), int(e["hp_max"]), BAR_W)
		_e_num.text = "%d / %d" % [int(e["hp"]), int(e["hp_max"])]
		_e_st.text = _status_text(Battle.enemy_status, Battle.ENEMY_STATUSES)
	_fill_to(_hp_fill, Battle.hp, Battle.hp_max(), MY_BAR_W)
	_fill_to(_mp_fill, Battle.mp, Battle.mp_max(), MY_BAR_W)
	_hp_num.text = "체력  %d / %d" % [Battle.hp, Battle.hp_max()]
	_mp_num.text = "마음력  %d / %d" % [Battle.mp, Battle.mp_max()]
	_lv.text = "LV %d" % Battle.level
	_my_st.text = _status_text(Battle.my_status, Battle.STATUSES)
	_intent.text = ("▸ " + Battle.intent()) if Battle.in_battle else ""


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
	_add_btn(_menu, "마음을 쓴다", _open_skills)
	_add_btn(_menu, "손에 쥔다", _open_items)
	_add_btn(_menu, "물러난다", _act_flee)


func _open_skills() -> void:
	_fill_list(func(box: VBoxContainer) -> void:
		for id in Battle.skills():
			var s: Dictionary = Battle.SKILLS[id]
			var mark := "  ◆약점" if Battle.found_weak \
				and Battle.weak_of(Battle.kind) == id else ""
			var cost := "   (마음력 %d)" % int(s["mp"]) if int(s["mp"]) > 0 else ""
			var b := _add_btn(box, "%s%s%s"
				% [String(s["name"]), cost, mark], _act_skill.bind(id))
			# 못 쓰는 것은 **지우지 않고 흐리게** 둔다. 목록에서 사라지면
			# 그런 수가 있다는 것 자체를 잊는다.
			if Battle.mp < int(s["mp"]):
				b.disabled = true
				b.modulate.a = 0.45)


func _open_items() -> void:
	_fill_list(func(box: VBoxContainer) -> void:
		var got := Battle.usable_items()
		if got.is_empty():
			var l := _label(22, DIM)
			l.text = "손에 쥘 것이 없다"
			box.add_child(l)
			return
		for id in got:
			var f: Dictionary = Battle.FOODS[id]
			var what := "체력 +%d" % int(f["hp"]) if f.has("hp") \
				else "마음력 +%d" % int(f["mp"])
			_add_btn(box, "%s x%d   (%s)" % [
				String(JourneyHud.NAMES.get(id, id)),
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
			_log.text = "%s %d" % ["그늘에게" if to_enemy else "나에게",
				int(e["amount"])]
			_pop(to_enemy, "-%d" % int(e["amount"]),
				Color("#FFB4B4") if not to_enemy else Color("#FFE39A"),
				bool(e.get("weak", false)))
			if to_enemy:
				_shake(_pic)
			else:
				_flash()
			AudioManager.touch_tap()
		"heal":
			if int(e["amount"]) > 0:
				_pop(false, "+%d" % int(e["amount"]), Color("#B4FFC8"), false)
		"status":
			_pop(String(e["to"]) == "enemy", String(e["text"]),
				Color("#C8E6FF"), false)
		"xp":
			_log.text = "마음이 조금 자랐다  (+%d)" % int(e["amount"])
		"level_up":
			_log.text = "LV %d" % int(e["level"])
			if String(e.get("skill", "")) != "":
				_log.text += " — '%s' 를 쓸 수 있게 됐다" % String(e["skill"])
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


func _flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1.0, 0.45, 0.45, 0.30)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.28)
	tw.tween_callback(f.queue_free)


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

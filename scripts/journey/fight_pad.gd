class_name FightPad
extends Control
## 오른쪽 아래 공격 버튼과 스킬 칸, 왼쪽 아래 LV·체력·마음력·경험 막대.
##
## **바람의나라·메이플스토리처럼 버튼을 눌러 직접 때린다.** 큰 [공격] 은
## 톡 치기(마음력 0, 든 무기의 속성) - 꾹 누르면 연타다. 그 왼쪽에 **배운
## 스킬이 한 칸씩** 붙는다 (`Battle.slot_skills` - 직업과 레벨에 따라 바뀐다).
## 칸 테두리는 그 스킬의 속성 빛깔이다. 다시 쓰기까지의 틈은 칸 위에 어두운
## 부채꼴로 줄어든다.
##
## **대결이 성사될 때만** 뜬다 (`Place.in_fight`, `JourneyHud._process`).
##
## 키보드: Z 공격, 1~7 스킬 차례대로.

const ATTACK := 128.0
const SKILL := 80.0
const GAP := 10.0
const EDGE := 32.0
const SLOT_MAX := 7
const KEYS := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6}

var _attack: Button
var _skills: Dictionary = {}     # id → Button
var _slot_ids: Array = []
var _vitals: Control
var _lv: Label


func _ready() -> void:
	# `set_anchors_preset` 만 부르면 크기가 0 인 채로 남아, 오른쪽 아래에
	# 붙인 버튼들이 화면 왼쪽 위 바깥(-160,-160)으로 나갔다. 여백까지 맞춘다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack = _round_btn("tap", ATTACK, Color("#FF9A8A"), Color("#8C4B3F"))
	_attack.name = "Attack"
	_attack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_attack.offset_left = -EDGE - ATTACK
	_attack.offset_top = -EDGE - ATTACK
	_attack.offset_right = -EDGE
	_attack.offset_bottom = -EDGE
	var al := _btn_label(_attack, "공격", 32, Color("#3A1E1A"))
	al.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebuild()
	_build_vitals()


## 스킬 칸을 다시 세운다 - 배운 스킬이 바뀌었을 때만 (레벨업·전직).
func _rebuild() -> void:
	for id in _skills:
		(_skills[id] as Node).queue_free()
	_skills.clear()
	_slot_ids = Battle.slot_skills().slice(0, SLOT_MAX)
	for i in _slot_ids.size():
		var id: String = _slot_ids[i]
		var sk: Dictionary = Battle.SKILLS[id]
		var col := Battle.elem_col(Battle.skill_elem(id))
		if String(sk["type"]) == "heal":
			col = Color("#63E6BE")
		elif String(sk["type"]) == "buff":
			col = Color("#FFD43B")
		var b := _round_btn(id, SKILL, Color("#F4EDE2"), col.darkened(0.15))
		b.name = "Skill_" + id
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		var right := -EDGE - ATTACK - GAP - float(i) * (SKILL + GAP)
		b.offset_right = right
		b.offset_left = right - SKILL
		b.offset_bottom = -EDGE - 6.0
		b.offset_top = -EDGE - 6.0 - SKILL
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", -4)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(box)
		var name_s := String(sk["name"])
		# 이름이 길면 두 줄로 - 칸이 80 이라 넉 자까지만 한 줄에 든다.
		if name_s.length() > 4 and name_s.contains(" "):
			name_s = name_s.replace(" ", "\n")
		var nm := _btn_label(box, name_s, 16 if name_s.length() > 3 else 18,
			Color("#3A2C2C"))
		nm.name = "Name"
		var cost := _btn_label(box, "마음 %d" % int(sk["mp"]), 12, Color("#6B5A48"))
		cost.name = "Cost"
		_skills[id] = b
		move_child(b, 0)


func _round_btn(id: String, sz: float, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(sz * 0.5))
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = bg.lightened(0.25)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pivot_offset = Vector2(sz, sz) * 0.5
	# 틈이 남은 만큼 어두운 부채꼴이 덮는다.
	var cd := Control.new()
	cd.name = "Cooldown"
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.draw.connect(func() -> void:
		var k := Field.cd_ratio(id)
		if k <= 0.0:
			return
		var c := cd.size * 0.5
		var r := minf(c.x, c.y) - 2.0
		var pts := PackedVector2Array([c])
		var steps := maxi(3, int(32.0 * k))
		for s in steps + 1:
			var a := -PI * 0.5 + TAU * k * float(s) / float(steps)
			pts.append(c + Vector2.from_angle(a) * r)
		cd.draw_colored_polygon(pts, Color(0.1, 0.08, 0.12, 0.55)))
	b.add_child(cd)
	b.button_down.connect(func() -> void: b.scale = Vector2(0.9, 0.9))
	b.button_up.connect(func() -> void: _pop(b))
	b.pressed.connect(func() -> void: press(id))
	add_child(b)
	return b


func _btn_label(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 왼쪽 아래 - LV 와 체력·마음력. 싸우는 동안 눈이 가는 곳은 아래라
## 왼쪽 위 메뉴 쪽이 아니라 여기에 둔다.
func _build_vitals() -> void:
	_vitals = Control.new()
	_vitals.name = "Vitals"
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vitals.offset_left = 128
	_vitals.offset_right = 128 + 300
	_vitals.offset_top = -102
	_vitals.offset_bottom = -22
	add_child(_vitals)
	_lv = Label.new()
	_lv.add_theme_font_size_override("font_size", 20)
	_lv.add_theme_color_override("font_color", Color("#FFE39A"))
	_lv.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_lv.add_theme_constant_override("outline_size", 6)
	_lv.position = Vector2(0, -4)
	_lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.add_child(_lv)
	var bars := Control.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bars.draw.connect(func() -> void:
		var font := bars.get_theme_default_font()
		_bar(bars, font, 26.0, float(Battle.hp) / maxf(1.0, float(Battle.hp_max())),
			Color("#7FCB8F"), "체력 %d / %d" % [Battle.hp, Battle.hp_max()])
		_bar(bars, font, 50.0, float(Battle.mp) / maxf(1.0, float(Battle.mp_max())),
			Color("#7FB0E6"), "마음력 %d / %d" % [Battle.mp, Battle.mp_max()])
		# 경험 - 얇은 노란 띠. 찰 때마다 눈에 들어와야 한 마리 더 잡는다.
		var k := float(Battle.xp) / maxf(1.0, float(Battle.xp_need()))
		bars.draw_rect(Rect2(0, 73, 300, 7), Color(0.12, 0.09, 0.14, 0.85))
		bars.draw_rect(Rect2(1, 74, 298.0 * clampf(k, 0.0, 1.0), 5), Color("#FFD43B")))
	bars.name = "Bars"
	_vitals.add_child(bars)


func _bar(c: Control, font: Font, y: float, k: float, col: Color, text: String) -> void:
	var w := 300.0
	c.draw_rect(Rect2(0, y, w, 20), Color(0.12, 0.09, 0.14, 0.85))
	c.draw_rect(Rect2(2, y + 2, (w - 4) * clampf(k, 0.0, 1.0), 16), col)
	if font != null:
		c.draw_string_outline(font, Vector2(8, y + 16), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15, 4, Color(0.12, 0.09, 0.14))
		c.draw_string(font, Vector2(8, y + 16), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15, Color("#FFFDF6"))


func _pop(b: Control) -> void:
	if not is_instance_valid(b):
		return
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _process(_delta: float) -> void:
	if not visible:
		return
	_lv.text = "LV %d  %s" % [Battle.level, Battle.job_name()]
	# **꾹 누르고 있으면 계속 때린다** (메이플처럼). 틈(`Battle.SKILLS` 의 cd)이
	# 박자를 정하므로 매 프레임 불러도 된다.
	if _attack.is_pressed():
		press("tap")
	if Battle.slot_skills().slice(0, SLOT_MAX) != _slot_ids:
		_rebuild()
	_vitals.get_node("Bars").queue_redraw()
	_attack.get_node("Cooldown").queue_redraw()
	for id in _skills:
		var b: Button = _skills[id]
		if not is_instance_valid(b):
			continue
		b.get_node("Cooldown").queue_redraw()
		# 마음력이 모자라면 흐리게 - 눌러도 안 된다는 걸 먼저 보여 준다.
		b.modulate.a = 0.45 if Battle.mp < int(Battle.SKILLS[id]["mp"]) else 1.0


func _place() -> Node:
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud == null or not hud.has_method("_place"):
		return null
	return hud._place()


## 누른다. 부르는 곳은 셋 - 버튼, 걷는 손가락과 따로 누른 손가락
## (`try_touch`), 키보드.
func press(id: String) -> bool:
	var p := _place()
	if p == null or not p.has_method("field_use"):
		return false
	return p.field_use(id)


func buttons() -> Array:
	var out: Array = [_attack]
	for id in _slot_ids:
		if _skills.has(id) and is_instance_valid(_skills[id]):
			out.append(_skills[id])
	return out


## 걸으면서 다른 손가락으로 누른 것 (`JourneyHud.try_touch` 와 같은 까닭).
func try_touch(pos: Vector2) -> bool:
	if not visible:
		return false
	for b in buttons():
		if b.visible and b.get_global_rect().has_point(pos):
			b.pressed.emit()
			b.scale = Vector2(0.9, 0.9)
			_pop(b)
			return true
	return false


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if k == KEY_Z:
		press("tap")
		get_viewport().set_input_as_handled()
	elif KEYS.has(k):
		var i: int = KEYS[k]
		if i < _slot_ids.size():
			press(String(_slot_ids[i]))
			get_viewport().set_input_as_handled()

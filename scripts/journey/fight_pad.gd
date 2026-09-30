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
## **[공격] 은 몬스터가 서는 곳이면 늘 떠 있다** - 가까이 없어도 눌러서 휘둘러
## 볼 수 있다 ("몬스터에 가까이 가지 않아도 공격 제스처를"). 스킬 칸과 왼쪽 아래
## 체력·마음력은 **대결이 성사될 때만** 스르르 뜬다 (`set_engaged`, `Place.in_fight`) -
## 늘 떠 있으면 버튼 일곱과 막대 둘이 마을을 가린다.
##
## 키보드: Z 공격, 1~9·0 스킬 차례대로.

const ATTACK := 128.0
const SKILL := 80.0
const GAP := 10.0
const SKILL_SMALL := 72.0
const GAP_SMALL := 8.0
## 아홉 칸 넘게 (LV 30·40 스킬이 생긴 뒤) - 더 작게.
const SKILL_TINY := 60.0
const GAP_TINY := 6.0
const EDGE := 32.0
## 스킬 칸 수. **마법사가 가장 많다** - 심호흡·몸통 박치기·원소 다섯·무지개 한 방·별똥별·꿈의 폭풍으로
## 열이다 (0.1.196 에는 여덟이었다 - 7 칸일 때 LV 22 의 무지개 한 방은 버튼도 키도 없었다).
## 한 줄에 열 칸이어도 칸을 60 으로 줄이면 오른쪽에서 830px 남짓이라 왼쪽 아래 막대와 안 겹친다.
const SLOT_MAX := 10
const KEYS := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6, KEY_8: 7,
	KEY_9: 8, KEY_0: 9}

var _attack: Button
var _skills: Dictionary = {}     # id → Button
var _slot_ids: Array = []
var _vitals: Control
var _lv: Label
## 연타 수 - 공격 버튼 위에 크게. 이어질수록 빛깔이 달아오른다.
var _combo: Label
var _combo_seen := 0


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
	# 피버 게이지 - 공격 버튼을 두르는 고리. 차오를수록 주황 호가 길어지고,
	# 피버 동안은 무지개로 돈다 (`Loop.fever`).
	var ring := Control.new()
	ring.name = "FeverRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.draw.connect(func() -> void:
		var c := Vector2(ATTACK, ATTACK) * 0.5
		var r := ATTACK * 0.5 + 9.0
		ring.draw_arc(c, r, 0.0, TAU, 48, Color(0.12, 0.09, 0.14, 0.55), 8.0)
		if Loop.fever_on():
			var t := float(Time.get_ticks_msec()) / 1000.0
			var k := Loop.fever_t / Loop.FEVER_SECS
			for i in 24:
				var a0 := -PI * 0.5 + TAU * k * float(i) / 24.0
				var a1 := -PI * 0.5 + TAU * k * float(i + 1) / 24.0
				ring.draw_arc(c, r, a0, a1, 4,
					Color.from_hsv(fmod(t + float(i) / 24.0, 1.0), 0.6, 1.0), 7.0)
		elif Loop.fever > 0.0:
			var k2 := Loop.fever / Loop.FEVER_MAX
			ring.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k2, 40,
				Color("#FFB347") if k2 < 0.8 else Color("#FFE066"), 6.0))
	_attack.add_child(ring)
	_rebuild()
	_build_vitals()
	_combo = Label.new()
	_combo.name = "Combo"
	_combo.add_theme_font_size_override("font_size", 40)
	_combo.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_combo.add_theme_constant_override("outline_size", 12)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_combo.offset_left = -520
	_combo.offset_right = -EDGE
	_combo.offset_top = -EDGE - ATTACK - 110
	_combo.offset_bottom = -EDGE - ATTACK - 50
	_combo.pivot_offset = Vector2(460, 30)
	_combo.visible = false
	add_child(_combo)


## 스킬 칸을 다시 세운다 - 배운 스킬이 바뀌었을 때만 (레벨업·전직).
func _rebuild() -> void:
	for id in _skills:
		(_skills[id] as Node).queue_free()
	_skills.clear()
	_slot_ids = Battle.slot_skills().slice(0, SLOT_MAX)
	# 여덟 칸(마법사)이면 조금 작게 - 80 으로 두면 맨 왼쪽 칸이 체력·마음력 막대를 덮었다.
	var n := _slot_ids.size()
	var sz := SKILL if n <= 7 else (SKILL_SMALL if n == 8 else SKILL_TINY)
	var gap := GAP if n <= 7 else (GAP_SMALL if n == 8 else GAP_TINY)
	var tiny := n > 8
	for i in _slot_ids.size():
		var id: String = _slot_ids[i]
		var sk: Dictionary = Battle.SKILLS[id]
		var col := Battle.elem_col(Battle.skill_elem(id))
		if String(sk["type"]) == "heal":
			col = Color("#63E6BE")
		elif String(sk["type"]) == "buff":
			col = Color("#FFD43B")
		var b := _round_btn(id, sz, Color("#F4EDE2"), col.darkened(0.15))
		b.name = "Skill_" + id
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		var right := -EDGE - ATTACK - GAP - float(i) * (sz + gap)
		b.offset_right = right
		b.offset_left = right - sz
		b.offset_bottom = -EDGE - 6.0
		b.offset_top = -EDGE - 6.0 - sz
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", -4)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(box)
		var name_s := String(sk["name"])
		# 이름이 길면 두 줄로 - 칸이 80 이라 넉 자까지만 한 줄에 든다.
		# 첫 띄어쓰기에서만 - 다 바꾸면 "무지개 한 방" 이 세 줄로 쪼개졌다.
		if name_s.length() > 4 and name_s.contains(" "):
			var cut := name_s.find(" ")
			name_s = name_s.substr(0, cut) + "\n" + name_s.substr(cut + 1)
		var nm := _btn_label(box, name_s, (14 if tiny else 16) if name_s.length() > 3 else (16 if tiny else 18),
			Color("#3A2C2C"))
		nm.name = "Name"
		var cost := _btn_label(box, "마음 %d" % int(sk["mp"]), 13 if tiny else 15, Color("#6B5A48"))
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
	_vitals.offset_top = -112
	_vitals.offset_bottom = -36
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
		# 경험은 화면 맨 아래 긴 막대가 늘 보여 준다 (`XpBar`).
		pass)
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


## 대결 중인가 - 스킬 칸과 체력·마음력을 띄울지.
var _engaged_a := 0.0


func set_engaged(on: bool, delta: float) -> void:
	_engaged_a = move_toward(_engaged_a, 1.0 if on else 0.0, delta * 6.0)
	var show := _engaged_a > 0.0
	_vitals.visible = show
	_vitals.modulate.a = _engaged_a
	for id in _skills:
		var b: Button = _skills[id]
		if is_instance_valid(b):
			b.visible = show
	

func engaged() -> bool:
	return _engaged_a > 0.0


func _process(_delta: float) -> void:
	if not visible:
		return
	_lv.text = "LV %d  %s" % [Battle.level, Battle.job_name()]
	# **꾹 누르고 있으면 계속 때린다** (메이플처럼). 틈(`Battle.SKILLS` 의 cd)이
	# 박자를 정하므로 매 프레임 불러도 된다.
	if _attack.is_pressed():
		press("tap")
	_tick_combo()
	if Battle.slot_skills().slice(0, SLOT_MAX) != _slot_ids:
		_rebuild()
	_vitals.get_node("Bars").queue_redraw()
	_attack.get_node("Cooldown").queue_redraw()
	_attack.get_node("FeverRing").queue_redraw()
	for id in _skills:
		var b: Button = _skills[id]
		if not is_instance_valid(b):
			continue
		b.get_node("Cooldown").queue_redraw()
		# 마음력이 모자라면 흐리게 - 눌러도 안 된다는 걸 먼저 보여 준다.
		b.modulate.a = (0.45 if Battle.mp < int(Battle.SKILLS[id]["mp"]) else 1.0) * _engaged_a


func _tick_combo() -> void:
	var n := Loop.combo
	_combo.visible = n >= 2
	if n < 2:
		_combo_seen = 0
		return
	var bonus := Loop.combo_bonus()
	_combo.text = "%d 연타%s" % [n, ("  경험 x%s" % str(bonus)) if bonus > 1.0 else ""]
	var col := Color("#FFFDF6")
	if n >= 50:
		col = Color.from_hsv(fmod(Time.get_ticks_msec() / 600.0, 1.0), 0.6, 1.0)
	elif n >= 30:
		col = Color("#FF8A5C")
	elif n >= 10:
		col = Color("#FFD43B")
	_combo.add_theme_color_override("font_color", col)
	if n != _combo_seen:
		_combo_seen = n
		_combo.scale = Vector2(1.35, 1.35)
		var tw := create_tween()
		tw.tween_property(_combo, "scale", Vector2.ONE, 0.15)


func _place() -> Node:
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud == null or not hud.has_method("_place"):
		return null
	return hud._place()


## 누른다. 부르는 곳은 셋 - 버튼, 걷는 손가락과 따로 누른 손가락
## (`try_touch`), 키보드.
## 스킬 칸 하나를 몇 번 부풀려 눈에 띄게 한다 (`Place._maybe_skill_hint`).
## 몇 번째 칸인지 돌려준다 - PC 에선 그 숫자 키를 같이 알린다 (없으면 -1).
func pulse_skill(id: String) -> int:
	var i := _slot_ids.find(id)
	if i < 0 or not _skills.has(id) or not is_instance_valid(_skills[id]):
		return -1
	var b: Control = _skills[id]
	b.pivot_offset = b.size * 0.5
	var tw := create_tween()
	for n in 4:
		tw.tween_property(b, "scale", Vector2(1.22, 1.22), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	return i


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

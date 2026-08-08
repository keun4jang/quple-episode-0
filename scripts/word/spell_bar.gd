class_name SpellBar
extends VBoxContainer
## 마법을 거는 곳. 철자를 순서대로 놓아 단어를 완성한다.
##
## 마법천자문에서 획순대로 한자를 쓰듯, 여기서는 철자를 순서대로 놓는다.
## 영어에서 제일 지루한 게 스펠링 외우기인데, 그걸 **손으로 놓는 일**로
## 바꾸는 것이 이 게임의 전부다.
##
## 끌어다 놓기(drag)는 쓰지 않는다. 손이 작으면 못 한다. 탭 두 번이면 된다 —
## 철자를 누르면 앞에서부터 빈칸이 채워지고, 칸을 누르면 도로 빠진다.

signal completed(word: String)
signal wrong_letter()

const SLOT := Vector2(104, 104)      # 여섯 살 손가락 기준 (실제 폰에서 약 11mm)
const KEY := Vector2(96, 96)

## 빈칸에 정답 글자를 **흐리게 미리 써 둔다.**
##
## 모르면 막히고, 막히면 끈다. 특히 스펠링은 "알듯 말듯"이 없다 — 알거나
## 모르거나 둘 중 하나다. 그래서 답을 아예 보여 주되, 손으로는 직접 놓게
## 한다. 따라 쓰는 사이에 손이 먼저 외운다.
##
## 단계가 올라갈수록 흐려지고, 산 단계는 처음엔 아예 안 보인다.
const HINT_ALPHA := [0.50, 0.34, 0.20, 0.0]
## 틀릴 때마다 진해진다. 벌 대신 도움을 준다.
const HINT_STEP := 0.26
const HINT_MAX := 0.72

var _word := ""
var _tier := 0
var _slots: Array[int] = []          # 비워 둔 자리
var _filled: Dictionary = {}         # 자리 → 철자
var _extra: Array = []
var _keys: HBoxContainer
var _row: HBoxContainer
var _locked := false


func setup(word: String, tier: int, extra: Array = []) -> void:
	_word = word
	_tier = tier
	_extra = extra
	_slots = WordData.blank_slots(word, tier)
	_filled.clear()
	_locked = false
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_CENTER

	# ── 단어 칸 ──
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)

	for i in _word.length():
		var blank := _slots.has(i)
		var b := Button.new()
		b.custom_minimum_size = SLOT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 58)
		b.text = "" if blank else _word[i].to_upper()
		b.disabled = not blank
		_style(b, blank)
		if blank:
			b.pressed.connect(_on_slot_pressed.bind(i))
			_add_ghost(b, _word[i].to_upper())
		_row.add_child(b)

	# ── 고를 철자 ──
	_keys = HBoxContainer.new()
	_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	_keys.add_theme_constant_override("separation", 14)
	add_child(_keys)

	var pool := WordData.letter_pool(_word, _tier, _extra)
	for ch in pool:
		var k := Button.new()
		k.custom_minimum_size = KEY
		k.focus_mode = Control.FOCUS_NONE
		k.text = ch
		k.add_theme_font_size_override("font_size", 52)
		_style(k, true)
		k.pressed.connect(_on_key_pressed.bind(k))
		_keys.add_child(k)


## 빈칸 안에 흐린 정답 글자를 깔아 둔다. 글자가 놓이면 가려진다.
func _add_ghost(slot: Button, ch: String) -> void:
	var g := Label.new()
	g.name = "Ghost"
	g.text = ch
	g.add_theme_font_size_override("font_size", 58)
	g.add_theme_color_override("font_color", Color("#3A2C2C"))
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.modulate.a = _hint_base()
	slot.add_child(g)


func _hint_base() -> float:
	if _tier >= 0 and _tier < HINT_ALPHA.size():
		return float(HINT_ALPHA[_tier])
	return 0.0


func _ghost(i: int) -> Label:
	var b := _slot_button(i)
	return b.get_node_or_null("Ghost") as Label if b != null else null


## 막히면 힌트를 진하게 해 준다. 몇 번을 틀려도 게임은 잃는 게 없다.
func _brighten_hint() -> void:
	var i := _next_slot()
	if i < 0:
		return
	var g := _ghost(i)
	if g == null:
		return
	var a: float = minf(g.modulate.a + HINT_STEP, HINT_MAX)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", a, 0.18)
	# 두 번 넘게 틀리면 눌러야 할 철자를 직접 반짝여 준다.
	if a >= HINT_MAX - 0.001:
		_pulse_key(_word[i].to_upper())


func _pulse_key(ch: String) -> void:
	if _keys == null:
		return
	for k in _keys.get_children():
		if k is Button and k.text == ch and k.visible:
			var tw := create_tween().set_loops(3)
			tw.tween_property(k, "modulate", Color(1.0, 0.92, 0.5), 0.24)
			tw.tween_property(k, "modulate", Color.WHITE, 0.24)
			return


func _style(b: Button, active: bool) -> void:
	# 폰트는 전역 테마(굵은 Jua)를 그대로 쓴다. 크기만 만진다.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F4EDE2") if active else Color("#CFC6BA")
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(6)
	sb.border_color = Color("#8C7B68") if active else Color("#A79A8A")
	b.add_theme_stylebox_override("normal", sb)
	var press := sb.duplicate() as StyleBoxFlat
	press.bg_color = Color("#FFE39A")
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_color", Color("#3A2C2C"))
	b.add_theme_color_override("font_disabled_color", Color("#3A2C2C"))


## 앞에서부터 비어 있는 첫 칸
func _next_slot() -> int:
	for i in _slots:
		if not _filled.has(i):
			return i
	return -1


func _on_key_pressed(key: Button) -> void:
	if _locked:
		return
	var i := _next_slot()
	if i < 0:
		return
	var want := _word[i].to_upper()
	if key.text != want:
		# 틀려도 벌은 없다. 흔들어 보여 주고, 힌트를 한 단계 진하게 한다.
		wrong_letter.emit()
		_shake(key)
		_brighten_hint()
		return
	_filled[i] = key.text
	_slot_button(i).text = key.text
	var g := _ghost(i)
	if g != null:
		g.visible = false
	key.visible = false
	key.set_meta("slot", i)
	if _next_slot() < 0:
		_locked = true
		completed.emit(_word)


func _on_slot_pressed(i: int) -> void:
	if _locked or not _filled.has(i):
		return
	_filled.erase(i)
	_slot_button(i).text = ""
	var g := _ghost(i)
	if g != null:
		g.visible = true
	for k in _keys.get_children():
		if k is Button and k.get_meta("slot", -1) == i:
			k.visible = true
			k.set_meta("slot", -1)
			break


func _slot_button(i: int) -> Button:
	return _row.get_child(i) as Button


func _shake(n: Control) -> void:
	var x := n.position.x
	var tw := create_tween()
	tw.tween_property(n, "position:x", x - 10, 0.05)
	tw.tween_property(n, "position:x", x + 10, 0.05)
	tw.tween_property(n, "position:x", x, 0.05)


## 씨앗 단계 — 철자 대신 그림 셋 중에서 고른다.
func setup_choices(choices: Array, answer: String) -> void:
	for c in get_children():
		c.queue_free()
	_word = answer
	_locked = false
	alignment = BoxContainer.ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	for c in choices:
		var b := Button.new()
		b.custom_minimum_size = Vector2(196, 196)
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s\n%s" % [c.get("emoji", ""), c.get("ko", "")]
		b.add_theme_font_size_override("font_size", 46)
		_style(b, true)
		b.pressed.connect(_on_choice.bind(String(c.get("word", "")), b))
		row.add_child(b)


func _on_choice(word: String, b: Button) -> void:
	if _locked:
		return
	if word.to_lower() != _word.to_lower():
		wrong_letter.emit()
		_shake(b)
		return
	_locked = true
	completed.emit(_word)

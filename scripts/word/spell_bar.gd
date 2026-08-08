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
		# 틀려도 벌은 없다. 흔들어 보여 주기만 한다.
		wrong_letter.emit()
		_shake(key)
		return
	_filled[i] = key.text
	_slot_button(i).text = key.text
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

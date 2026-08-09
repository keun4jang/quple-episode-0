class_name JourneySay
extends CanvasLayer
## 여행 중의 대화창.
##
## 기존 `dialogue_box.gd` 를 쓰려다 말았다. 그건 옛 터치 버튼 위치를 물어
## 폭을 재는 구조라 여기 UI 와 안 맞고, 붙이면 양쪽이 서로를 잡아끈다.
## 여행 쪽은 필요한 게 훨씬 적다 — 이름, 한 줄, 넘기기.
##
## 말한 사람 얼굴은 안 띄운다. 탑다운이라 **화면에 이미 서 있다.**

signal finished

const SPEED := 0.028          # 한 글자에 걸리는 시간

var _panel: PanelContainer
var _who: Label
var _line: Label
var _more: Label
var _queue: Array[String] = []
var _full := ""
var _shown := 0
var _t := 0.0
var _busy := false


func _ready() -> void:
	layer = 10
	add_to_group("journey_say")
	_build()
	visible = false
	set_process_unhandled_input(true)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.border_color = Color("#5A4A44")
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -170
	_panel.offset_bottom = -34
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 26)
	_who.add_theme_color_override("font_color", Color("#8C7B68"))
	box.add_child(_who)

	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 38)
	_line.add_theme_color_override("font_color", Color("#3A2C2C"))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 84)
	_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_line)

	_more = Label.new()
	_more.text = "▼"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_font_size_override("font_size", 24)
	_more.add_theme_color_override("font_color", Color("#8C7B68"))
	_more.visible = false
	box.add_child(_more)


## 여러 줄을 한 번에 준다. 다 넘기면 finished.
func say(who: String, lines: Array) -> void:
	_who.text = who
	_queue.clear()
	for l in lines:
		_queue.append(String(l))
	_busy = true
	visible = true
	_next()


func is_busy() -> bool:
	return _busy


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		visible = false
		finished.emit()
		return
	_full = _queue.pop_front()
	_shown = 0
	_t = 0.0
	_line.text = ""
	_more.visible = false


func _process(delta: float) -> void:
	if not _busy or _shown >= _full.length():
		return
	_t += delta
	while _t >= SPEED and _shown < _full.length():
		_t -= SPEED
		_shown += 1
	_line.text = _full.substr(0, _shown)
	if _shown >= _full.length():
		_more.visible = true


## 한 번 누르면 마저 찍고, 다 찍혔으면 다음 줄로.
func advance() -> void:
	if not _busy:
		return
	if _shown < _full.length():
		_shown = _full.length()
		_line.text = _full
		_more.visible = true
	else:
		_next()


func _unhandled_input(e: InputEvent) -> void:
	if not _busy:
		return
	# e 는 InputEvent 라 e.pressed 가 Variant 다. 타입을 적어 준다 —
	# 안 적으면 추론이 안 돼 파일 전체가 컴파일에 실패한다.
	var tap: bool = (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed
			and e.button_index == MOUSE_BUTTON_LEFT) \
		or e.is_action_pressed("ui_accept")
	if tap:
		advance()
		get_viewport().set_input_as_handled()

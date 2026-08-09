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
var _more: Control
var _queue: Array[String] = []
var _who_queue: Array[String] = []
var _default_who := ""
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
	root.add_child(_panel)
	# 높이는 여기서 정하지 않는다. `_fit()` 이 내용에 맞춰 위로 늘린다 —
	# 예전엔 136px 로 못 박아 놨는데 내용이 180px 이라 창이 화면 아래로
	# 잘려 나갔다. 두 줄짜리 대사면 더 나갔다.
	_panel.resized.connect(_fit)

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

	# "다음" 표시는 글자가 아니라 **직접 그린 세모**다.
	# 본문 폰트(PoorStory)에 ▼ 가 없어서 글자로 쓰면 폰에서 네모 상자가 뜬다.
	_more = Control.new()
	_more.custom_minimum_size = Vector2(0, 22)
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.visible = false
	_more.draw.connect(func() -> void:
		var w := _more.size.x
		var pts := PackedVector2Array([
			Vector2(w - 30, 6), Vector2(w - 10, 6), Vector2(w - 20, 18)])
		_more.draw_colored_polygon(pts, Color("#8C7B68")))
	box.add_child(_more)


## 창을 내용에 맞춰 위로 늘린다. 아래 여백은 기기 안전영역 바깥으로 안 나간다.
func _fit() -> void:
	if _panel == null:
		return
	var need: float = maxf(_panel.get_combined_minimum_size().y, 136.0)
	var safe := JourneyHud.safe_insets(get_viewport())
	var bottom := 34.0 + safe.w
	_panel.offset_bottom = -bottom
	_panel.offset_top = -(bottom + need)
	# 좌우도 비켜 준다. 가로로 들면 노치가 짧은 변, 즉 좌우에 온다.
	_panel.offset_left = 40.0 + safe.x
	_panel.offset_right = -(40.0 + safe.z)



## 여러 줄을 한 번에 준다. 다 넘기면 finished.
##
## 줄 하나는 두 가지 모양 중 하나다 —
##   `"대사"`              말한 사람은 `who`
##   `["누구", "대사"]`    그 줄만 다른 사람이 말한다
##
## 두 번째가 필요한 이유: 재회도 인사도 **주고받는 말**인데, 이름 하나만
## 찍혀 있으면 혼잣말로 읽힌다. 경비 아저씨의 "오늘도 늦었네" 와
## 쿼카의 "…네. 근데 오늘이 마지막이에요." 는 서로 다른 사람이 해야 한다.
func say(who: String, lines: Array) -> void:
	_default_who = who
	_queue.clear()
	_who_queue.clear()
	for l in lines:
		if l is Array and l.size() >= 2:
			_who_queue.append(String(l[0]))
			_queue.append(String(l[1]))
		else:
			_who_queue.append(who)
			_queue.append(String(l))
	_busy = true
	visible = true
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud != null and hud.has_method("set_buttons_visible"):
		hud.set_buttons_visible(false)
	_next()


func is_busy() -> bool:
	return _busy


## 안드로이드 뒤로가기가 부른다. 남은 줄을 버리고 대화를 끝낸다.
func close() -> void:
	if not _busy:
		return
	_queue.clear()
	_who_queue.clear()
	_shown = _full.length()
	_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		visible = false
		var hud := get_tree().get_first_node_in_group("journey_hud")
		if hud != null and hud.has_method("set_buttons_visible"):
			hud.set_buttons_visible(true)
		finished.emit()
		return
	_full = _queue.pop_front()
	_who.text = _who_queue.pop_front() if not _who_queue.is_empty() else _default_who
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
		_more.queue_redraw()


## 한 번 누르면 마저 찍고, 다 찍혔으면 다음 줄로.
func advance() -> void:
	if not _busy:
		return
	AudioManager.touch_tap()
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

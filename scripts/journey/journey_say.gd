class_name JourneySay
extends CanvasLayer
## 여행 중의 대화창.
##
## 말한 사람 얼굴은 안 띄운다. 탑다운이라 **화면에 이미 서 있다.**
##
## **작게 만든다.** 한동안 글자 38px 에 창이 화면 아래를 가로질렀는데,
## 읽히기는 해도 조용한 게임에 안 어울렸다 — 창이 크면 대사가 통보처럼
## 읽힌다. 읽히는 선까지만 줄인다.

signal finished

const SPEED := 0.028          # 한 글자에 걸리는 시간
## 창이 이보다 넓어지지 않는다. 큰 화면에서 한 줄이 가로로 끝없이
## 늘어나면 눈이 따라가느라 피곤하다.
const MAX_WIDTH := 560.0
## 이보다 좁으면 "이전" 버튼과 이름이 부딪혀 오히려 어색해진다.
const MIN_WIDTH := 150.0

var _panel: PanelContainer
var _who: Label
var _line: Label
var _prev_btn: Button
## 이번 대화에서 오간 말 전부. [{who, text}, ...]
var _said: Array = []
var _at := -1
var _full := ""
var _shown := 0
var _t := 0.0
var _busy := false
var _size_tw: Tween


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
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color("#5A4A44")
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# **창 자신도 눌러진다.** PanelContainer 는 기본으로 누름을 삼키는데,
	# 이 창은 화면 아래 한가운데 — 엄지가 제일 먼저 가는 자리다.
	# "아무 데나 누르면 넘어간다" 면서 창만 예외면 멈춘 것으로 읽힌다.
	# ("이전" 버튼은 제 스스로 받으니 그대로 눌린다.)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	# 높이는 여기서 정하지 않는다. `_fit()` 이 내용에 맞춰 위로 늘린다 —
	# 예전엔 못 박아 놨는데 내용이 더 커서 창이 화면 아래로 잘려 나갔다.
	_panel.resized.connect(_fit)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)

	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 15)
	_who.add_theme_color_override("font_color", Color("#8C7B68"))
	box.add_child(_who)

	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 21)
	_line.add_theme_color_override("font_color", Color("#3A2C2C"))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_line)

	# 이전 · 다음.
	#
	# 화면 아무 데나 눌러도 다음으로 넘어가는 건 그대로다. 버튼을 다는 건
	# **되돌아갈 수 있게** 하기 위해서다 — 빨리 눌러 지나친 말을 다시
	# 볼 방법이 지금까지 없었다.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	# **"다음" 은 안 단다.** 오른쪽 아래 큰 버튼이 이미 그 일을 하고,
	# 화면 아무 데나 눌러도 넘어간다. 같은 일을 하는 버튼이 크기와 자리만
	# 다르게 둘 있으면 어느 쪽이 진짜인지 헷갈린다.
	# 여기 남는 건 **되돌아가는 길** 하나다 — 그건 다른 데 없다.
	_prev_btn = _small_btn("이전", _back)
	row.add_child(_prev_btn)


func _small_btn(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 30)
	b.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F1E9DA")
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color("#B9A88F")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color("#FFE39A")
	b.add_theme_stylebox_override("pressed", pr)
	var dis := sb.duplicate() as StyleBoxFlat
	dis.bg_color = Color("#EFEAE1")
	dis.border_color = Color("#DCD3C4")
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", Color("#5A4A44"))
	b.add_theme_color_override("font_disabled_color", Color("#C6BCAC"))
	b.pressed.connect(fn)
	return b


## 창을 내용에 맞춰 위로 늘린다. 화면 가장자리 안전영역 바깥으로 안 나간다.
func _fit() -> void:
	if _panel == null:
		return
	var safe := JourneyHud.safe_insets(get_viewport())
	var vp := get_viewport().get_visible_rect().size
	# **말 길이에 맞춰 줄인다.** 폭을 고정해 두면 "응." 한 마디에도 창이
	# 화면을 가로지르고, 남은 자리가 전부 빈 종이가 된다.
	var f := _line.get_theme_font("font")
	var fs := _line.get_theme_font_size("font_size")
	# **줄마다 따로 잰다.** `_full` 을 통째로 재면 엽서처럼 `\n` 이 든 글에서
	# 두 줄을 이어 붙인 길이가 나온다 — 폭은 두 배로 잡히고, 높이는 타자가
	# `\n` 에 닿는 순간 25px 튀어 오른다. 평상에서 엽서를 넘길 때마다
	# 창이 두 번씩 덜컹거렸다. 하필 이 게임의 마지막 장면이다.
	var need_w := 0.0
	if f != null:
		for one in _full.split("\n"):
			need_w = maxf(need_w,
				f.get_string_size(one, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var room := vp.x - 64.0 - safe.x - safe.z
	var inner: float = clampf(need_w + 4.0, MIN_WIDTH, minf(MAX_WIDTH, room))
	# 줄 수만큼 높이를 미리 잡아 둔다. 안 그러면 타자가 둘째 줄에 닿는
	# 순간 창이 커진다.
	var lines: int = maxi(1, _full.split("\n").size())
	_line.custom_minimum_size = Vector2(inner, float(lines) * (fs + 8))
	var w: float = _panel.get_combined_minimum_size().x
	var h: float = _panel.get_combined_minimum_size().y
	var bottom := 22.0 + safe.w
	var mid := (vp.x + safe.x - safe.z) * 0.5
	var l := mid - w * 0.5
	var r := mid + w * 0.5 - vp.x
	var t := -(bottom + h)
	# 첫 줄은 그냥 놓고, 줄이 바뀔 때만 부드럽게 옮긴다. 창이 그 프레임에
	# 폭 241px 씩 튀면 덜컹거리는 것으로 보인다.
	if not _panel.visible or _size_tw == null:
		_panel.offset_left = l
		_panel.offset_right = r
		_panel.offset_bottom = -bottom
		_panel.offset_top = t
		_size_tw = create_tween()
		_size_tw.kill()
		return
	if _size_tw != null and _size_tw.is_valid():
		_size_tw.kill()
	_size_tw = create_tween().set_parallel(true)
	for pair in [["offset_left", l], ["offset_right", r],
			["offset_top", t], ["offset_bottom", -bottom]]:
		_size_tw.tween_property(_panel, String(pair[0]), pair[1], 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


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
	_said.clear()
	for l in lines:
		if l is Array and l.size() >= 2:
			_said.append({"who": String(l[0]), "text": String(l[1])})
		else:
			_said.append({"who": who, "text": String(l)})
	if _said.is_empty():
		return
	_at = -1
	_busy = true
	visible = true
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud != null and hud.has_method("set_buttons_visible"):
		hud.set_buttons_visible(false)
	_go(0)


func is_busy() -> bool:
	return _busy


## 안드로이드 뒤로가기가 부른다. 대화를 끝낸다.
func close() -> void:
	if not _busy:
		return
	_finish()


func _finish() -> void:
	_busy = false
	visible = false
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud != null and hud.has_method("set_buttons_visible"):
		hud.set_buttons_visible(true)
	finished.emit()


## i 번째 말을 띄운다. 이미 지나온 말은 찍는 시늉 없이 통째로 보여 준다 —
## 되돌아가서 다시 읽는 사람을 기다리게 할 이유가 없다.
func _go(i: int, instant := false) -> void:
	var back := i <= _at
	_at = clampi(i, 0, _said.size() - 1)
	var m: Dictionary = _said[_at]
	_who.text = String(m.get("who", ""))
	_full = String(m.get("text", ""))
	if instant or back:
		_shown = _full.length()
		_line.text = _full
	else:
		_shown = 0
		_t = 0.0
		_line.text = ""
	_refresh_buttons()
	_fit()


func _refresh_buttons() -> void:
	if _prev_btn != null:
		_prev_btn.disabled = _at <= 0


## 한 번 누르면 마저 찍고, 다 찍혔으면 다음 줄로.
func advance() -> void:
	if not _busy:
		return
	AudioManager.touch_tap()
	if _shown < _full.length():
		_shown = _full.length()
		_line.text = _full
		return
	if _at >= _said.size() - 1:
		_finish()
	else:
		_go(_at + 1)


## 방금 지나친 말을 다시 본다.
func _back() -> void:
	if not _busy or _at <= 0:
		return
	AudioManager.touch_tap()
	_go(_at - 1, true)


func _process(delta: float) -> void:
	if not _busy or _shown >= _full.length():
		return
	_t += delta
	while _t >= SPEED and _shown < _full.length():
		_t -= SPEED
		_shown += 1
	_line.text = _full.substr(0, _shown)


func _unhandled_input(e: InputEvent) -> void:
	if not _busy:
		return
	# 한 번 누른 것이 터치와 흉내낸 마우스로 두 번 온다. 그대로 두면
	# **한 번 눌러 두 줄씩** 넘어간다.
	if JourneyHud.is_echo(e):
		return
	# 버튼 위를 눌렀으면 버튼이 먼저 받는다. 여기까지 온 것은 빈 곳이다.
	#
	# e 는 InputEvent 라 e.pressed 가 Variant 다. 타입을 적어 준다 —
	# 안 적으면 추론이 안 돼 파일 전체가 컴파일에 실패한다.
	var tap: bool = (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed
			and e.button_index == MOUSE_BUTTON_LEFT) \
		or e.is_action_pressed("ui_accept")
	if tap:
		advance()
		get_viewport().set_input_as_handled()

extends CanvasLayer

@onready var label: Label = $PanelRect/MarginContainer/VBoxContainer/Label
@onready var panel_rect = $PanelRect

# DialogueBox.tscn 의 MarginContainer·테두리와 같은 값이어야 한다
const MARGIN_H := 22.0
const MARGIN_V := 12.0
const BORDER := 2.0
const BOTTOM_GAP := 24.0

# 타자기 효과 변수
var _typewriter_text: String = ""
var _typewriter_pos: int = 0
var _typewriter_timer: float = 0.0
var _typewriter_speed: float = 0.035
var _typewriter_active: bool = false

func _ready() -> void:
	add_to_group("dialogue_box")
	visible = false

## 대화창 폭을 문장 길이에 맞춘다.
##
## 화면 폭을 꽉 채우면 짧은 한 마디에도 검은 띠가 화면을 가로지른다.
## 글자는 왼쪽 끝에 붙고 오른쪽은 텅 비어서, 읽는 눈이 매번 멀리 이동한다.
## 문장만큼만 잡고 가운데 두면 시선이 캐릭터 바로 아래에 머문다.
## 반환값은 **줄바꿈을 넣은 대사**다. 그대로 화면에 찍으면 된다.
func _fit_to_text(text: String) -> String:
	if panel_rect == null or label == null:
		return text
	var vp := get_viewport().get_visible_rect().size
	var fs: int = label.get_theme_font_size("font_size")
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	# 좌우 여백(패널 안쪽 22 + 테두리) 을 더하고, 화면을 넘지 않게 자른다.
	# 너무 좁으면 한 글자짜리 대사에서 알약처럼 보이므로 하한도 둔다.
	var w: float = clampf(text_w + 96.0, 320.0, vp.x * 0.84)

	# 가운데 정렬이라 폭이 커지면 양쪽으로 자란다. 오른쪽에는 터치 버튼이 있고,
	# 글자를 30pt 로 올린 뒤로는 긴 대사가 '다음' 버튼 밑으로 100px 넘게 파고들었다.
	# 버튼이 실제로 어디 있는지 물어보고 그 앞에서 멈춘다.
	var right_limit := vp.x - 24.0
	var tc := get_tree().get_first_node_in_group("touch_controls")
	if tc != null and tc.visible and ("_buttons" in tc):
		for a in tc._buttons:
			# BaseButton 으로 받는다. 3D 조작은 Button, 옆맵 조작은
			# TextureButton 이라 Button 으로 받으면 옆맵에서 대입이 죽고,
			# 그 자리에서 함수가 끊겨 **대사 글자가 한 글자도 안 찍혔다.**
			var b: BaseButton = tc._buttons[a]
			if b != null and b.is_visible_in_tree():
				right_limit = minf(right_limit, b.get_global_rect().position.x - 20.0)
	# 가운데에 두면서 오른쪽 끝이 저 선을 넘지 않는 최대 폭
	w = minf(w, maxf((right_limit - vp.x * 0.5) * 2.0, 320.0))

	panel_rect.anchor_left = 0.5
	panel_rect.anchor_right = 0.5
	panel_rect.offset_left = -w * 0.5
	panel_rect.offset_right = w * 0.5

	# 높이도 맞춘다.
	#
	# 폭만 맞추고 높이는 88px 로 못 박혀 있었다. 30pt 글자 한 줄과 ▼ 힌트가
	# 이미 그 높이를 다 쓰므로 **둘째 줄이 들어갈 자리가 없었다.**
	# 긴 대사는 문장이 끝나기 전에 잘렸다 — 읽기 불편한 게 아니라 이야기가 사라졌다.
	# 상자는 아래를 고정하고 위로 자란다.
	var inner_w: float = maxf(w - MARGIN_H * 2.0 - BORDER * 2.0, 80.0)
	var wrapped := _wrap_by_word(text, inner_w, font, fs)
	var text_h: float = font.get_multiline_string_size(
		wrapped, HORIZONTAL_ALIGNMENT_CENTER, inner_w, fs).y

	var extra := MARGIN_V * 2.0 + BORDER * 2.0
	var vbox := label.get_parent() as VBoxContainer
	var hint := _hint_label()
	if hint != null and hint.visible:
		extra += font.get_height(hint.get_theme_font_size("font_size"))
		if vbox != null:
			extra += float(vbox.get_theme_constant("separation"))

	# 화면의 절반을 넘기지 않는다. 그 위로 가면 상자가 아니라 벽이다.
	var h: float = clampf(text_h + extra, 88.0, vp.y * 0.5)
	panel_rect.offset_top = -(h + BOTTOM_GAP)
	panel_rect.offset_bottom = -BOTTOM_GAP
	return wrapped


## 어절 단위로 줄을 나눈다.
##
## Godot 의 자동 줄바꿈에 맡기면 한국어가 **낱말 가운데서 끊긴다.** 유니코드
## 줄바꿈 규칙이 한글 음절 사이를 전부 끊어도 되는 자리로 보기 때문이다.
## 실제로 "사라지면" 이 `사라지` / `면` 으로, "아무" 가 `아` / `무` 로 갈라졌다.
## `AUTOWRAP_WORD` 로 바꿔도 마찬가지다 — 그 규칙 자체가 그렇다.
##
## 그래서 띄어쓰기에서 직접 끊는다. 라벨의 자동 줄바꿈은 그대로 켜 둔다.
## 한 어절이 통째로 폭보다 길면(아주 긴 지명 같은 것) 그때만 대신 끊어 준다.
func _wrap_by_word(text: String, width: float, font: Font, fs: int) -> String:
	if width <= 0.0:
		return text
	var out := ""
	for para in text.split("\n"):
		if out != "":
			out += "\n"
		var line := ""
		for word in para.split(" ", false):
			var probe: String = word if line == "" else line + " " + word
			if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
				line = probe
			else:
				if line != "":
					out += line + "\n"
				line = word
		out += line
	return out


func _hint_label() -> Label:
	return panel_rect.get_node_or_null(
		"MarginContainer/VBoxContainer/HintLabel") as Label


func show_text(text: String) -> void:
	# 타자기 효과 시작. 찍는 것은 **줄바꿈까지 넣은** 대사다 —
	# 원본을 찍으면 상자 높이를 잰 것과 줄 나눔이 달라진다.
	_typewriter_pos = 0
	_typewriter_timer = 0.0
	_typewriter_active = true
	label.text = ""
	_typewriter_text = _fit_to_text(text)
	visible = true
	# 슬라이드업 애니메이션: 아래에서 위로 올라오기
	if panel_rect:
		var original_y = panel_rect.position.y
		panel_rect.position.y = original_y + 200.0
		var tw = create_tween()
		tw.tween_property(panel_rect, "position:y", original_y, 0.25).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	_typewriter_timer += delta
	if _typewriter_timer >= _typewriter_speed:
		_typewriter_timer = 0.0
		_typewriter_pos += 1
		label.text = _typewriter_text.substr(0, _typewriter_pos)
		# 타자기 완료 확인
		if _typewriter_pos >= _typewriter_text.length():
			_typewriter_active = false

func hide_box() -> void:
	_typewriter_active = false
	visible = false

func is_open() -> bool:
	return visible

## 대화상자가 열려 있는 동안 interact 는 "대화 넘기기" 하나만 뜻한다.
##
## _unhandled_input 이 아니라 _input 을 쓴다. _unhandled_input 은 노드 순서대로
## 도는데, 시작 지점에 겹쳐 있는 Interactable 이 같은 입력을 먼저 먹고
## set_input_as_handled() 를 불러 버려서 대화상자가 영영 안 닫혔다.
## (키보드로도 첫 대사에서 못 움직이던 원인이 이거다.)
## _input 은 모든 _unhandled_input 보다 먼저 도므로 순서가 확실하다.
var _tap_index := -1
var _tap_from := Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# 폰에서는 화면 아무 데나 톡 치면 넘어가야 한다. 대사를 넘기려고
	# 매번 오른쪽 아래 버튼까지 손을 옮기는 건 성가시다.
	# 단 "톡 친 것" 만 센다 — 끌면 카메라를 돌리려는 것이다.
	if event is InputEventScreenTouch:
		if event.pressed:
			_tap_index = event.index
			_tap_from = event.position
		elif event.index == _tap_index:
			_tap_index = -1
			if event.position.distance_to(_tap_from) < 24.0:
				_advance()
				get_viewport().set_input_as_handled()
		return
	elif event is InputEventScreenDrag and event.index == _tap_index:
		if event.position.distance_to(_tap_from) >= 24.0:
			_tap_index = -1          # 끌기로 판정. 넘기지 않는다.
		return

	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


## 한 번 넘기기 — 찍는 중이면 완성, 다 찍혔으면 닫는다
func _advance() -> void:
	if _typewriter_active:
		label.text = _typewriter_text
		_typewriter_pos = _typewriter_text.length()
		_typewriter_active = false
	else:
		hide_box()

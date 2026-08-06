extends CanvasLayer

@onready var label: Label = $PanelRect/MarginContainer/VBoxContainer/Label
@onready var panel_rect = $PanelRect

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
func _fit_to_text(text: String) -> void:
	if panel_rect == null or label == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var fs: int = label.get_theme_font_size("font_size")
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	# 좌우 여백(패널 안쪽 22 + 테두리) 을 더하고, 화면을 넘지 않게 자른다.
	# 너무 좁으면 한 글자짜리 대사에서 알약처럼 보이므로 하한도 둔다.
	var w: float = clampf(text_w + 96.0, 320.0, vp.x * 0.84)

	panel_rect.anchor_left = 0.5
	panel_rect.anchor_right = 0.5
	panel_rect.offset_left = -w * 0.5
	panel_rect.offset_right = w * 0.5


func show_text(text: String) -> void:
	# 타자기 효과 시작
	_typewriter_text = text
	_typewriter_pos = 0
	_typewriter_timer = 0.0
	_typewriter_active = true
	label.text = ""
	_fit_to_text(text)
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

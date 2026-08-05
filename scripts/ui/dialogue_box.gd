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

func show_text(text: String) -> void:
	# 타자기 효과 시작
	_typewriter_text = text
	_typewriter_pos = 0
	_typewriter_timer = 0.0
	_typewriter_active = true
	label.text = ""
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
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		if _typewriter_active:
			# 아직 찍는 중이면 먼저 전체 텍스트를 보여준다
			label.text = _typewriter_text
			_typewriter_pos = _typewriter_text.length()
			_typewriter_active = false
		else:
			# 다 읽었으면 닫는다
			hide_box()
		get_viewport().set_input_as_handled()

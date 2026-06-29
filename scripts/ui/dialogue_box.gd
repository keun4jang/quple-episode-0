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

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# 스페이스/엔터로 타자기 스킵
	if event.is_action_pressed("ui_accept"):
		if _typewriter_active:
			# 전체 텍스트 즉시 표시
			label.text = _typewriter_text
			_typewriter_active = false

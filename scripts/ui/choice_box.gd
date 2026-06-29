extends CanvasLayer

signal choice_made(index: int)

@onready var btn0: Button = $Panel/VBoxContainer/Button0
@onready var btn1: Button = $Panel/VBoxContainer/Button1

var _selected: int = 0

func _ready() -> void:
	add_to_group("choice_box")
	visible = false
	btn0.pressed.connect(func(): _on_choice(0))
	btn1.pressed.connect(func(): _on_choice(1))

func show_choices(option0: String, option1: String) -> void:
	btn0.text = option0
	btn1.text = option1
	_selected = 0
	_update_highlight()
	visible = true
	# 버튼 순차 페이드인 + 슬라이드업 애니메이션 (0.08초 간격 지연)
	_animate_button(btn0, 0.0)
	_animate_button(btn1, 0.08)

# 버튼 페이드인 + 슬라이드업 애니메이션
func _animate_button(btn: Button, delay: float) -> void:
	var original_y = btn.position.y
	btn.modulate.a = 0.0
	btn.position.y = original_y + 12.0  # 살짝 아래에서 올라오기
	var tw = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	# 투명도: 0 -> 1
	tw.tween_property(btn, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	# 위치: 아래 -> 원래 위치 (동시에 진행)
	tw.parallel().tween_property(btn, "position:y", original_y, 0.15).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_selected = 0
		_update_highlight()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_selected = 1
		_update_highlight()
	elif event.is_action_pressed("ui_accept"):
		_on_choice(_selected)

func _update_highlight() -> void:
	btn0.modulate = Color(1.0, 0.92, 0.35) if _selected == 0 else Color(0.75, 0.75, 0.75)
	btn1.modulate = Color(1.0, 0.92, 0.35) if _selected == 1 else Color(0.75, 0.75, 0.75)

func _on_choice(index: int) -> void:
	visible = false
	choice_made.emit(index)

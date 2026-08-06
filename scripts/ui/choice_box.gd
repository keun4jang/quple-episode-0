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
	# position 을 건드리면 안 된다. 이 버튼들은 VBoxContainer 의 자식이고,
	# 컨테이너가 자리를 잡기 **전에** position.y 를 읽으면 둘 다 0 이다.
	# 거기로 트윈을 걸면 컨테이너 배치를 덮어써서 두 선택지가 같은 자리에
	# 겹쳐 그려진다. 실제로 폰에서 선택지 하나만 보이던 원인이 이거였다.
	#
	# 그래서 컨테이너가 관여하지 않는 것만 움직인다 — 투명도와 크기.
	btn.modulate.a = 0.0
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(0.96, 0.96)
	var tw = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(btn, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		_selected = 0
		_update_highlight()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		_selected = 1
		_update_highlight()
	elif event.is_action_pressed("interact"):
		_on_choice(_selected)

func _update_highlight() -> void:
	btn0.modulate = Color(1.0, 0.92, 0.35) if _selected == 0 else Color(0.75, 0.75, 0.75)
	btn1.modulate = Color(1.0, 0.92, 0.35) if _selected == 1 else Color(0.75, 0.75, 0.75)

func _on_choice(index: int) -> void:
	visible = false
	choice_made.emit(index)

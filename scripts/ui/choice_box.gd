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

## 선택지 상자도 대사창과 같은 문제를 갖는다 — 폭 고정인데 버튼 글자가
## 줄바꿈 없이 한 줄이라 패널이 양쪽으로 자라 터치 버튼을 덮는다.
func _fit_panel() -> void:
	var panel := get_node_or_null("Panel") as Control
	if panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var right_limit := vp.x - 24.0
	var tc := get_tree().get_first_node_in_group("touch_controls")
	if tc != null and tc.visible and ("_buttons" in tc):
		for a in tc._buttons:
			# 3D 는 Button, 옆맵은 TextureButton — 공통 조상으로 받는다.
			var b: BaseButton = tc._buttons[a]
			if b != null and b.is_visible_in_tree():
				right_limit = minf(right_limit, b.get_global_rect().position.x - 20.0)
	var half: float = maxf(right_limit - vp.x * 0.5, 200.0)
	panel.offset_left = -half
	panel.offset_right = half


func show_choices(option0: String, option1: String) -> void:
	btn0.text = option0
	btn1.text = option1
	_selected = 0
	_update_highlight()
	visible = true
	# 버튼 순차 페이드인 + 슬라이드업 애니메이션 (0.08초 간격 지연)
	_fit_panel()
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

## 선택지가 떠 있는 동안 이 입력들은 여기서 끝난다.
##
## 예전에는 확정 입력이 그대로 아래로 흘러가 발밑의 자리(말 걸기 등)에도
## 들어갔다. 지금은 그 상태에 해당하는 자리가 없어 우연히 아무 일도
## 안 일어나지만, 자리 하나만 더 놓으면 한 번 누른 것이 두 번 먹는다.
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
	else:
		return
	get_viewport().set_input_as_handled()

func _update_highlight() -> void:
	btn0.modulate = Color(1.0, 0.92, 0.35) if _selected == 0 else Color(0.75, 0.75, 0.75)
	btn1.modulate = Color(1.0, 0.92, 0.35) if _selected == 1 else Color(0.75, 0.75, 0.75)

func _on_choice(index: int) -> void:
	visible = false
	choice_made.emit(index)

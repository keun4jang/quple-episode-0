extends CanvasLayer
## 바람 노트 = 현재 목표. D 로 열고 닫는다. 왼쪽 위에 작게 항상 표시된다.

@onready var mini: PanelContainer = $Mini
@onready var mini_label: Label = $Mini/Margin/MiniLabel
@onready var full: PanelContainer = $Full
@onready var full_label: Label = $Full/Margin/Body/FullLabel

var _objective: String = "쿼카전자 안으로 들어가기"

func _ready() -> void:
	add_to_group("wind_note")
	full.visible = false
	_refresh()

func set_objective(text: String) -> void:
	_objective = text
	_refresh()
	# 목표가 바뀌면 잠깐 강조
	mini.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(mini, "scale", Vector2(1.06, 1.06), 0.12)
	tw.tween_property(mini, "scale", Vector2.ONE, 0.18)

func get_objective() -> String:
	return _objective

func _refresh() -> void:
	mini_label.text = "🍃  " + _objective
	full_label.text = _objective

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("wind_note"):
		full.visible = not full.visible
		get_viewport().set_input_as_handled()
	elif full.visible and event.is_action_pressed("cancel"):
		full.visible = false
		get_viewport().set_input_as_handled()

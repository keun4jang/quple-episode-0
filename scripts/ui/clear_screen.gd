extends CanvasLayer
## 0편 클리어 화면.

@onready var title: Label = $Root/Center/Body/TitleLabel
@onready var quote: Label = $Root/Center/Body/QuoteLabel
@onready var hint: Label = $Root/Center/Body/HintLabel
@onready var glow: ColorRect = $Root/Glow

var _t: float = 0.0

func _ready() -> void:
	add_to_group("clear_screen")
	# 등장 연출
	var body: VBoxContainer = $Root/Center/Body
	body.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(body, "modulate", Color(1, 1, 1, 1), 0.9)

func _process(delta: float) -> void:
	_t += delta
	if glow:
		glow.modulate.a = 0.16 + sin(_t * 1.4) * 0.05

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		# 0편이 끝나면 본편(여행 허브)으로 이어진다
		SceneTransition.go_to("res://scenes/travel/TravelHub.tscn", "hopeful")
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		get_tree().quit()

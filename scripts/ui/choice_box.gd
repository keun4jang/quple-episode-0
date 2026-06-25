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

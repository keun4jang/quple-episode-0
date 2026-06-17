extends CanvasLayer

signal choice_made(index: int)

@onready var btn0: Button = $Panel/VBoxContainer/Button0
@onready var btn1: Button = $Panel/VBoxContainer/Button1

func _ready() -> void:
	add_to_group("choice_box")
	visible = false
	btn0.pressed.connect(func(): _on_choice(0))
	btn1.pressed.connect(func(): _on_choice(1))

func show_choices(option0: String, option1: String) -> void:
	btn0.text = option0
	btn1.text = option1
	visible = true

func _on_choice(index: int) -> void:
	visible = false
	choice_made.emit(index)

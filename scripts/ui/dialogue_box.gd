extends CanvasLayer

@onready var label: Label = $PanelRect/MarginContainer/VBoxContainer/Label

func _ready() -> void:
	add_to_group("dialogue_box")
	visible = false

func show_text(text: String) -> void:
	label.text = text
	visible = true

func hide_box() -> void:
	visible = false

func is_open() -> bool:
	return visible

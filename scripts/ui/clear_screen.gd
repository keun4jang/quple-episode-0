extends CanvasLayer

func _ready() -> void:
	add_to_group("clear_screen")
	visible = false

func show_clear() -> void:
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_tree().quit()

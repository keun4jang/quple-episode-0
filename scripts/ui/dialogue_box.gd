extends CanvasLayer

@onready var label: Label = $PanelRect/MarginContainer/VBoxContainer/Label
@onready var panel_rect = $PanelRect

var _full_text: String = ""
var _display_index: int = 0
var _char_timer: float = 0.0
var _is_typing: bool = false
const CHAR_DELAY: float = 0.03

func _ready() -> void:
	add_to_group("dialogue_box")
	visible = false

func show_text(text: String) -> void:
	_full_text = text
	_display_index = 0
	_char_timer = 0.0
	_is_typing = true
	label.text = ""
	visible = true
	# slide up animation
	if panel_rect:
		panel_rect.position.y = 80
		var tw = create_tween()
		tw.tween_property(panel_rect, "position:y", 0.0, 0.18).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not _is_typing:
		return
	_char_timer += delta
	if _char_timer >= CHAR_DELAY:
		_char_timer = 0.0
		_display_index = min(_display_index + 1, _full_text.length())
		label.text = _full_text.substr(0, _display_index)
		if _display_index >= _full_text.length():
			_is_typing = false

func hide_box() -> void:
	_is_typing = false
	visible = false

func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _is_typing:
			# skip to full text
			_is_typing = false
			label.text = _full_text
			_display_index = _full_text.length()

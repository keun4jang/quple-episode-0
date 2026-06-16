extends CanvasLayer

@onready var prompt_label: Label = $PanelRect/MarginContainer/VBoxContainer/PromptLabel
@onready var options_container: VBoxContainer = $PanelRect/MarginContainer/VBoxContainer/OptionsContainer

const SELECTED_COLOR := Color(0.99, 0.93, 0.85, 1)
const UNSELECTED_COLOR := Color(0.68, 0.62, 0.58, 1)

var options: Array[String] = []
var selected_index: int = 0
var callback: Callable = Callable()

func _ready() -> void:
	add_to_group("choice_box")
	visible = false

func show_choices(prompt: String, choice_options: Array[String], on_selected: Callable) -> void:
	prompt_label.text = prompt
	options = choice_options
	selected_index = 0
	callback = on_selected
	_refresh_options()
	visible = true

func _refresh_options() -> void:
	for child in options_container.get_children():
		child.queue_free()

	for i in options.size():
		var option_label := Label.new()
		var prefix := "▶ " if i == selected_index else "   "
		option_label.text = prefix + options[i]
		option_label.add_theme_color_override(
			"font_color",
			SELECTED_COLOR if i == selected_index else UNSELECTED_COLOR
		)
		option_label.add_theme_font_size_override("font_size", 20)
		options_container.add_child(option_label)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_up"):
		selected_index = (selected_index - 1 + options.size()) % options.size()
		_refresh_options()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		selected_index = (selected_index + 1) % options.size()
		_refresh_options()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var chosen_index := selected_index
		var chosen_callback := callback
		visible = false
		get_viewport().set_input_as_handled()
		if chosen_callback.is_valid():
			chosen_callback.call(chosen_index)

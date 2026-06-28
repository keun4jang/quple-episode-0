extends CanvasLayer

@onready var resume_btn: Button = $Panel/VBox/ResumeBtn
@onready var settings_btn: Button = $Panel/VBox/SettingsBtn
@onready var menu_btn: Button = $Panel/VBox/MenuBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_btn.pressed.connect(_resume)
	settings_btn.pressed.connect(_open_settings)
	menu_btn.pressed.connect(_to_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_resume()
		else:
			_open()

func _open() -> void:
	visible = true
	get_tree().paused = true

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _open_settings() -> void:
	var s = get_tree().get_first_node_in_group("settings_ui")
	if s:
		s.open()

func _to_menu() -> void:
	get_tree().paused = false
	SceneTransition.go_to("res://scenes/menu/MainMenu3D.tscn", "normal")

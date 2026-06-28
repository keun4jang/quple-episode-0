extends CanvasLayer

signal interact_pressed

@onready var joystick_base: Control = $JoystickBase
@onready var stick: ColorRect = $JoystickBase/StickCircle
@onready var interact_btn: Button = $InteractBtn

var _touch_index: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _stick_offset: Vector2 = Vector2.ZERO
var _max_radius: float = 80.0
var input_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	_base_center = Vector2(100, 100)
	interact_btn.pressed.connect(func(): interact_pressed.emit())
	_style_buttons()

func _style_buttons() -> void:
	# Style interact button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#FFD76D")
	btn_style.corner_radius_top_left = 50
	btn_style.corner_radius_top_right = 50
	btn_style.corner_radius_bottom_left = 50
	btn_style.corner_radius_bottom_right = 50
	interact_btn.add_theme_stylebox_override("normal", btn_style)
	interact_btn.add_theme_color_override("font_color", Color("#1A1412"))
	interact_btn.add_theme_font_size_override("font_size", 36)
	# Round the joystick base visually
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(1, 1, 1, 0.12)
	base_style.corner_radius_top_left = 100
	base_style.corner_radius_top_right = 100
	base_style.corner_radius_bottom_left = 100
	base_style.corner_radius_bottom_right = 100
	if $JoystickBase/BaseCircle is ColorRect:
		pass  # ColorRect doesn't support StyleBox

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var base_rect = joystick_base.get_global_rect()
		if event.pressed and base_rect.has_point(event.position) and _touch_index == -1:
			_touch_index = event.index
			_base_center = base_rect.get_center()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_stick_offset = Vector2.ZERO
			input_vector = Vector2.ZERO
			_update_stick()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var offset = event.position - _base_center
		if offset.length() > _max_radius:
			offset = offset.normalized() * _max_radius
		_stick_offset = offset
		input_vector = offset / _max_radius
		_update_stick()

func _update_stick() -> void:
	var base_size = joystick_base.size
	stick.position = (base_size / 2.0 - stick.size / 2.0) + _stick_offset

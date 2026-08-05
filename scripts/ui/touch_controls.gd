extends CanvasLayer
## 모바일 터치 조작.
##
## 게임 코드는 하나도 고치지 않는다. 터치를 기존 입력 액션
## (move_left/right/up/down, interact, photo, wind_note, album, cancel) 으로
## 바꿔 넣기 때문에, 키보드로 만든 모든 로직이 그대로 동작한다.
##
## 왼손: 가상 조이스틱 (아날로그 — 살살 밀면 천천히 걷는다)
## 오른손: 동작 버튼

const STICK_RADIUS := 118.0        # 조이스틱 바깥 원 반지름
const KNOB_RADIUS := 56.0
const DEAD_ZONE := 0.16           # 이 안에서는 안 움직인다 (손 떨림 방지)
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

@onready var root: Control = $Root
@onready var stick_base: TextureRect = $Root/Stick/Base
@onready var stick_knob: TextureRect = $Root/Stick/Knob
@onready var buttons: VBoxContainer = $Root/Buttons

var _stick_touch := -1            # 조이스틱을 잡고 있는 손가락 id
var _stick_origin := Vector2.ZERO
var _held_actions: Array[String] = []
var _pressed: Dictionary = {}     # 지금 우리가 누르고 있다고 보고한 액션들


## 액션을 "진짜 입력 이벤트" 로 흘려보낸다.
##
## Input.action_press() 만 쓰면 안 된다. 그건 내부 상태만 바꿀 뿐
## InputEvent 를 만들지 않아서, event.is_action_pressed() 로 입력을 받는 코드
## (대화상자 닫기, 선택지 이동, 앨범 넘기기) 가 전부 반응하지 않는다.
## 실제로 폰에서 대화상자가 안 닫혀 아무것도 못 하는 버그가 여기서 났다.
static func _emit(action: String, pressed: bool, strength := 1.0) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength if pressed else 0.0
	Input.parse_input_event(ev)


## 상태와 이벤트를 둘 다 챙긴다.
##
## parse_input_event() 는 다음 프레임에 처리돼서 is_action_pressed() 가 한 박자
## 늦는다. 그래서 상태는 action_press/release 로 그 자리에서 바꾸고,
## 눌림/뗌이 바뀌는 순간에만 이벤트를 따로 보낸다.
func _set_action(action: String, strength: float) -> void:
	var was: bool = _pressed.get(action, false)
	var now := strength > 0.0
	if now:
		Input.action_press(action, strength)
		if not was:
			_pressed[action] = true
			_emit(action, true, strength)
	elif was:
		_pressed.erase(action)
		Input.action_release(action)
		_emit(action, false)

func _ready() -> void:
	add_to_group("touch_controls")
	layer = 8
	_style_stick()
	_build_buttons()
	visible = _should_show()
	_sync_key_guide()
	# 대화상자 등이 우리보다 늦게 준비될 수 있어 한 프레임 뒤 한 번 더 맞춘다
	get_tree().process_frame.connect(_sync_key_guide, CONNECT_ONE_SHOT)
	# 터치가 한 번이라도 들어오면 그때부터 보여준다 (PC 에서는 계속 숨김)
	set_process_input(true)

## 모바일이거나, 터치 화면이 있으면 보여준다
func _should_show() -> bool:
	if OS.get_environment("QUPLE_TOUCH") != "":
		return true                      # 테스트용 강제 표시
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return DisplayServer.is_touchscreen_available()

func _input(event: InputEvent) -> void:
	# PC 에서도 실제로 손가락이 닿으면 그때 켠다
	if not visible and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		visible = true
		_sync_key_guide()

	if event is InputEventScreenTouch:
		if event.pressed:
			# 화면 왼쪽 절반에서 시작한 터치만 조이스틱으로 쓴다
			if _stick_touch == -1 and event.position.x < root.size.x * 0.5:
				_stick_touch = event.index
				_stick_origin = event.position
				_place_stick(event.position)
				stick_base.modulate.a = 0.75
		elif event.index == _stick_touch:
			_release_stick()
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_update_stick(event.position)

## 조이스틱을 손가락 위치로 옮긴다 (고정 위치보다 어디를 잡아도 되는 쪽이 편하다)
func _place_stick(pos: Vector2) -> void:
	var st: Control = $Root/Stick
	st.position = pos - Vector2(STICK_RADIUS, STICK_RADIUS)
	stick_knob.position = Vector2(STICK_RADIUS - KNOB_RADIUS, STICK_RADIUS - KNOB_RADIUS)

func _update_stick(pos: Vector2) -> void:
	var delta := pos - _stick_origin
	var dist := delta.length()
	var dir := delta / dist if dist > 0.001 else Vector2.ZERO
	var clamped: float = minf(dist, STICK_RADIUS)
	stick_knob.position = Vector2(STICK_RADIUS - KNOB_RADIUS, STICK_RADIUS - KNOB_RADIUS) \
		+ dir * clamped
	var strength := clamped / STICK_RADIUS
	if strength < DEAD_ZONE:
		_release_move()
		return
	# 아날로그 세기를 그대로 넘긴다. 살살 밀면 천천히 걷는다.
	_feed_move(dir * strength)

func _feed_move(v: Vector2) -> void:
	_set_action("move_left",  maxf(0.0, -v.x))
	_set_action("move_right", maxf(0.0,  v.x))
	_set_action("move_up",    maxf(0.0, -v.y))
	_set_action("move_down",  maxf(0.0,  v.y))

func _release_move() -> void:
	for a in MOVE_ACTIONS:
		_set_action(a, 0.0)

func _release_stick() -> void:
	_stick_touch = -1
	_release_move()
	stick_base.modulate.a = 0.35
	stick_knob.position = Vector2(STICK_RADIUS - KNOB_RADIUS, STICK_RADIUS - KNOB_RADIUS)

func _exit_tree() -> void:
	# 씬이 바뀔 때 눌린 채로 남지 않게 정리한다
	# 씬이 바뀔 때 조이스틱을 잡은 채로 남으면 다음 씬에서 못 움직인다
	_stick_touch = -1
	_release_move()
	for a in _held_actions:
		Input.action_release(a)
		_emit(a, false)
	_held_actions.clear()

# ── 겉모습 ──────────────────────────────────────────────────────────────

func _style_stick() -> void:
	stick_base.texture = _ring(int(STICK_RADIUS * 2), Color(1, 0.95, 0.82))
	stick_base.modulate.a = 0.35
	stick_knob.texture = _disc(int(KNOB_RADIUS * 2), Color(1, 0.88, 0.60))
	stick_knob.modulate.a = 0.8
	stick_knob.position = Vector2(STICK_RADIUS - KNOB_RADIUS, STICK_RADIUS - KNOB_RADIUS)

## 동작 버튼. 누르는 동안 해당 키를 누른 것으로 만든다.
func _build_buttons() -> void:
	for c in buttons.get_children():
		c.queue_free()
	var defs := [
		["interact", "조사", Color(1.0, 0.78, 0.52), 132],
		["photo", "📷", Color(0.72, 0.86, 0.96), 104],
		["wind_note", "🍃", Color(0.70, 0.90, 0.74), 104],
		["album", "📖", Color(0.86, 0.78, 0.96), 104],
	]
	for d in defs:
		buttons.add_child(_action_button(str(d[0]), str(d[1]), d[2], int(d[3])))

func _action_button(action: String, label: String, tint: Color, size_px: int) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.focus_mode = Control.FOCUS_NONE   # 포커스를 뺏어 키 입력을 먹지 않게
	b.add_theme_font_size_override("font_size", 30 if size_px > 110 else 38)
	b.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.80)
	sb.set_corner_radius_all(size_px / 2)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = Color(tint.r, tint.g, tint.b, 0.98)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb2)
	# 버튼을 누르고 있는 동안 그 키가 눌린 것으로 만든다
	b.button_down.connect(func():
		Input.action_press(action)
		_emit(action, true)
		if not _held_actions.has(action):
			_held_actions.append(action))
	b.button_up.connect(func():
		Input.action_release(action)
		_emit(action, false)
		_held_actions.erase(action))
	return b

## 속이 빈 원 (조이스틱 바깥)
func _ring(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := 0.0
			if d < 1.0:
				a = 0.10                       # 안쪽은 아주 옅게
				if d > 0.86:
					a = 0.85 * (1.0 - (d - 0.86) / 0.14)   # 테두리
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

## 꽉 찬 원 (손잡이)
func _disc(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clampf((1.0 - d) * 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


## 터치로 조작할 때는 키 안내를 감춘다. 모바일에는 키보드가 없다.
##
## 화면 구석의 조작 안내판(key_guide)뿐 아니라 대화상자의 "Space" 처럼
## 문구 안에 박힌 힌트(key_hint)도 같이 감춘다.
func _sync_key_guide() -> void:
	var kg := get_tree().get_first_node_in_group("key_guide")
	if kg and kg is CanvasLayer:
		kg.visible = not visible
	for h in get_tree().get_nodes_in_group("key_hint"):
		if h is CanvasItem:
			h.visible = not visible

extends CanvasLayer
class_name SideTouch
## 옆에서 보는 맵의 폰 조작.
##
## 3D 쪽 터치 조작(TouchControls)은 아날로그 스틱이라 어느 방향으로든
## 갈 수 있어야 하는 화면에 맞춰져 있다. 옆에서 보는 맵은 다르다 —
## 갈 수 있는 방향이 넷뿐이고, **점프가 따로 있어야 한다.** 스틱으로
## 점프를 시키면 위를 누를 때마다 사다리와 헷갈린다.
##
## 그래서 왼손에 방향 십자, 오른손에 점프. 옆에서 보는 게임이 수십 년째
## 이 배치를 쓰는 데는 이유가 있다.

## 버튼 지름(픽셀). 엄지로 눌러야 하니 넉넉히 잡는다.
const R := 76
## 화면 가장자리에서 띄우는 거리.
const PAD := 56
## 눌렸을 때 얼마나 진해지는가.
const LIT := Color(1, 1, 1, 0.92)
const DIM := Color(1, 1, 1, 0.44)

var _btns: Dictionary = {}      # action -> TextureButton
## 손가락 하나가 어느 버튼을 누르고 있는지. 두 손가락을 따로 따라간다.
var _touch: Dictionary = {}     # finger index -> action


func _ready() -> void:
	add_to_group("side_touch")
	layer = 8
	_build()
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	# 왼손 — 방향. 위·아래는 사다리와 엘리베이터에 쓴다.
	for spec in [
		{"a": "move_left", "s": "◀"},
		{"a": "move_right", "s": "▶"},
		{"a": "move_up", "s": "▲"},
		{"a": "move_down", "s": "▼"},
		{"a": "jump", "s": "점프"},
	]:
		var b := TextureButton.new()
		b.name = spec["a"]
		b.texture_normal = _disc(R * 2, Color(0.12, 0.11, 0.17))
		b.modulate = DIM
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(R * 2, R * 2)
		b.size = Vector2(R * 2, R * 2)
		# 버튼 자체는 눌림을 안 받는다. 손가락을 직접 따라가야 두 개를
		# 동시에 누르는 것(걸으면서 점프) 이 된다.
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)

		var l := Label.new()
		l.text = spec["s"]
		l.add_theme_font_size_override("font_size", 32 if spec["a"] == "jump" else 40)
		l.add_theme_color_override("font_color", Color("#FDFBD4"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		_btns[spec["a"]] = b


func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cx := PAD + R * 2.1          # 십자 가운데
	var cy := vp.y - PAD - R * 1.9
	var g := R * 1.95                # 버튼 사이 간격
	_at("move_left", Vector2(cx - g, cy))
	_at("move_right", Vector2(cx + g, cy))
	_at("move_up", Vector2(cx, cy - g * 0.92))
	_at("move_down", Vector2(cx, cy + g * 0.92))
	_at("jump", Vector2(vp.x - PAD - R * 1.2, cy))


func _at(action: String, center: Vector2) -> void:
	var b: TextureButton = _btns.get(action)
	if b != null:
		b.position = center - Vector2(R, R)


## 손가락이 어느 버튼 위에 있는지 찾는다. 없으면 빈 문자열.
func _hit(pos: Vector2) -> String:
	for a in _btns:
		var b: TextureButton = _btns[a]
		if pos.distance_to(b.position + Vector2(R, R)) <= R * 1.08:
			return a
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var a := _hit(e.position)
			if a != "":
				_press(e.index, a)
				get_viewport().set_input_as_handled()
		else:
			_release(e.index)
	elif event is InputEventScreenDrag:
		# 손가락이 버튼 사이를 미끄러지면 따라간다. 방향을 바꿀 때마다
		# 손을 떼야 하면 걷다가 자꾸 멈춘다.
		var e2 := event as InputEventScreenDrag
		var a2 := _hit(e2.position)
		if _touch.get(e2.index, "") != a2:
			_release(e2.index)
			if a2 != "":
				_press(e2.index, a2)


func _press(finger: int, action: String) -> void:
	_touch[finger] = action
	Input.action_press(action)
	var b: TextureButton = _btns.get(action)
	if b != null:
		b.modulate = LIT


func _release(finger: int) -> void:
	var action: String = _touch.get(finger, "")
	if action == "":
		return
	_touch.erase(finger)
	# 같은 버튼을 다른 손가락이 아직 누르고 있으면 놓지 않는다.
	if not _touch.values().has(action):
		Input.action_release(action)
		var b: TextureButton = _btns.get(action)
		if b != null:
			b.modulate = DIM


func _exit_tree() -> void:
	for a in _btns:
		Input.action_release(a)


## 가운데가 차 있고 테두리가 있는 원.
func _disc(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 0.90:
				img.set_pixel(x, y, Color(0.99, 0.98, 0.83, 0.95))
			else:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.62))
	return ImageTexture.create_from_image(img)

extends CanvasLayer
class_name SideTouch
## 옆에서 보는 맵의 폰 조작. 왼손 조이스틱, 오른손 점프·조사.
##
## 처음에는 방향 버튼 넷을 십자로 깔았는데, 화면의 반을 먹고도 손에는
## 3D 화면에서 쓰던 조이스틱보다 못했다. 같은 스틱으로 돌아간다 —
## 좌우는 걷기, 위아래는 사다리·엘리베이터.
##
## 오른손에는 버튼이 둘이다. 점프, 그리고 **조사**. 문에 들어가고 물건을
## 줍고 말을 거는 것이 전부 조사다. 위를 밀어도 되지만, 눈앞에 "무엇을
## 할 수 있다" 가 떠 있을 때 누를 것이 손에 잡히는 편이 훨씬 낫다.

## 스틱 바탕 반지름(픽셀).
const STICK_R := 130
## 스틱을 이만큼 기울여야 방향으로 친다. 작으면 스치기만 해도 걷는다.
const DEAD := 0.32
## 위아래로 치려면 이만큼은 밀어야 한다.
const DEAD_Y := 0.55
## 그리고 가로보다 세로가 이 배 이상 커야 한다. 1.4 면 수평에서 약
## 55도 위로 올라가야 "위" 로 친다 — 걷는 손짓과 오르는 손짓이 갈린다.
const VERT_BIAS := 1.4
## 큰 버튼(선택) 반지름. 메이플의 공격 버튼 자리다 — 우리 게임의 그 자리는
## 공격이 아니라 **선택**이다. 문에 들어가고, 말을 걸고, 물건을 줍는다.
const MAIN_R := 118
## 위성 버튼(점프) 반지름. 큰 버튼 둘레에 붙는다.
const BTN_R := 80
const PAD := 48

var _stick_base: Control
var _stick_knob: Control
var _stick_center := Vector2.ZERO
var _stick_finger := -1

var _btns: Dictionary = {}       # action -> TextureButton
## 바깥에서 부르는 이름. 3D 쪽 TouchControls 와 맞춰 둔다 — 대사창이
## "버튼을 피해 폭을 줄이는" 계산에 이 이름으로 접근한다.
var _buttons: Dictionary:
	get: return _btns
var _touch: Dictionary = {}      # finger -> action
var _held: Dictionary = {}       # 스틱이 누르고 있는 액션들


func _ready() -> void:
	add_to_group("side_touch")
	# 3D 쪽 조작과 같은 그룹에도 든다. 대사창·선택지·앨범이 이 그룹을 찾아
	# **조작을 피하거나 감춘다.** 옆맵만 다른 이름을 쓰는 바람에 그 회피가
	# 통째로 죽어 있었고, 선택지 패널이 화면 끝까지 자라 버튼을 덮었다 —
	# 두 번째 선택지를 누르면 버튼이 먼저 먹어서 첫 번째가 골라졌다.
	add_to_group("touch_controls")
	layer = 8
	_build()
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	_stick_base = _disc_node(STICK_R * 2, Color(0.10, 0.09, 0.15), 0.38)
	add_child(_stick_base)
	_stick_knob = _disc_node(int(STICK_R * 0.95), Color(0.85, 0.80, 0.62), 0.55)
	add_child(_stick_knob)

	for spec in [
		{"a": "jump", "s": "점프", "r": BTN_R},
		{"a": "interact", "s": "선택", "r": MAIN_R},
	]:
		var r: int = spec["r"]
		var b := TextureButton.new()
		b.name = spec["a"]
		b.texture_normal = _disc_tex(r * 2, Color(0.12, 0.11, 0.17))
		b.modulate = Color(1, 1, 1, 0.5)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.size = Vector2(r * 2, r * 2)
		b.set_meta("r", r)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		var l := Label.new()
		l.text = spec["s"]
		l.add_theme_font_size_override("font_size", 44 if spec["a"] == "interact" else 32)
		l.add_theme_color_override("font_color", Color("#FDFBD4"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		_btns[spec["a"]] = b


func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	_stick_center = Vector2(PAD + STICK_R * 1.5, vp.y - PAD - STICK_R * 1.4)
	_stick_base.position = _stick_center - Vector2(STICK_R, STICK_R)
	_knob_to(Vector2.ZERO)
	# 메이플 배치: 큰 선택 버튼이 오른쪽 아래 구석, 점프는 그 왼쪽 위
	# 둘레에 위성으로 붙는다.
	var main := Vector2(vp.x - PAD - MAIN_R, vp.y - PAD - MAIN_R)
	_at("interact", main)
	_at("jump", main + Vector2(-MAIN_R - BTN_R * 1.35, -MAIN_R * 0.35))


func _at(action: String, center: Vector2) -> void:
	var b: TextureButton = _btns[action]
	var r: float = b.get_meta("r")
	b.position = center - Vector2(r, r)


## 조사할 것이 있을 때 조사 버튼을 밝힌다. SideEpisode 가 부른다.
func highlight_interact(on: bool) -> void:
	var b: TextureButton = _btns.get("interact")
	if b != null:
		b.modulate = Color(1, 1, 0.85, 0.95) if on else Color(1, 1, 1, 0.5)


# ─────────────────────────────── 입력 ───────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _hit_button(e.position) != "":
				_press(e.index, _hit_button(e.position))
				get_viewport().set_input_as_handled()
			elif _stick_finger < 0 \
					and e.position.distance_to(_stick_center) < STICK_R * 1.7:
				_stick_finger = e.index
				_stick_update(e.position)
				get_viewport().set_input_as_handled()
		else:
			if e.index == _stick_finger:
				_stick_release()
			_release(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_update(d.position)


func _hit_button(pos: Vector2) -> String:
	for a in _btns:
		var b: TextureButton = _btns[a]
		var r: float = b.get_meta("r")
		if pos.distance_to(b.position + Vector2(r, r)) <= r * 1.15:
			return a
	return ""


func _press(finger: int, action: String) -> void:
	_touch[finger] = action
	Input.action_press(action)
	# action_press 는 눌림 "상태"만 바꾼다. 문·말걸기·줍기는 상태가 아니라
	# **눌린 순간의 이벤트**(_unhandled_input)를 듣는다. 이벤트를 같이
	# 만들어 주지 않으면 — 실제로 폰에서 문 앞에 서서 선택을 아무리
	# 눌러도 안 들어가졌다. 시뮬레이터는 이벤트를 직접 넣어서 통과했고,
	# 그래서 이 구멍이 시뮬에는 안 걸렸다.
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	(_btns[action] as TextureButton).modulate = Color(1, 1, 1, 0.95)


func _release(finger: int) -> void:
	var action: String = _touch.get(finger, "")
	if action == "":
		return
	_touch.erase(finger)
	if not _touch.values().has(action):
		Input.action_release(action)
		var ev := InputEventAction.new()
		ev.action = action
		Input.parse_input_event(ev)
		(_btns[action] as TextureButton).modulate = Color(1, 1, 1, 0.5)
		if action == "interact":
			highlight_interact(false)


# ─────────────────────────────── 스틱 ───────────────────────────────

func _stick_update(pos: Vector2) -> void:
	var v := (pos - _stick_center) / float(STICK_R)
	if v.length() > 1.0:
		v = v.normalized()
	_knob_to(v * STICK_R)

	# 축을 따로 보면 대각선에서 위아래가 너무 쉽게 켜진다. 최대로 기울인
	# 45도에서 세로 성분이 0.707 이라, 수평에서 33도만 내려가도 "아래" 가
	# 됐다 — 걸으면서 점프하려다 발판 아래로 떨어지는 일이 잦았다.
	# 그래서 위아래는 **각도로** 판단한다: 세로에 가까울 때만 받는다.
	var want := {}
	if v.x < -DEAD: want["move_left"] = true
	elif v.x > DEAD: want["move_right"] = true
	if v.length() > DEAD_Y and absf(v.y) > absf(v.x) * VERT_BIAS:
		want["move_up" if v.y < 0.0 else "move_down"] = true

	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if want.has(a) and not _held.has(a):
			Input.action_press(a)
			_held[a] = true
		elif not want.has(a) and _held.has(a):
			Input.action_release(a)
			_held.erase(a)


func _stick_release() -> void:
	_stick_finger = -1
	_knob_to(Vector2.ZERO)
	for a in _held:
		Input.action_release(a)
	_held.clear()


func _knob_to(offset: Vector2) -> void:
	var r := STICK_R * 0.95 * 0.5
	_stick_knob.position = _stick_center + offset - Vector2(r, r)


## 누르고 있던 것을 전부 놓는다. 조작을 감추기 전에 반드시 불러야 한다 —
## 감춰진 버튼은 손을 떼는 것을 볼 수 없어서, 누른 채로 사라지면 그대로
## 눌린 상태가 남는다.
func release_all() -> void:
	_stick_release()
	for f in _touch.keys():
		Input.action_release(_touch[f])
	_touch.clear()
	for a in _btns:
		(_btns[a] as TextureButton).modulate = Color(1, 1, 1, 0.5)


func _exit_tree() -> void:
	release_all()


# ─────────────────────────────── 그리기 ───────────────────────────────

func _disc_node(size: int, col: Color, alpha: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _disc_tex(size, col)
	tr.modulate = Color(1, 1, 1, alpha)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(size, size)
	return tr


func _disc_tex(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 0.92:
				img.set_pixel(x, y, Color(0.99, 0.98, 0.83, 0.9))
			else:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.62))
	return ImageTexture.create_from_image(img)

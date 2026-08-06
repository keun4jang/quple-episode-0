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

## UI 규칙은 한 곳에서 가져온다. 색·둥글기·글자 크기를 여기서 직접 정하지 않는다.
const D := preload("res://scripts/ui/design.gd")

@onready var root: Control = $Root
@onready var stick_base: TextureRect = $Root/Stick/Base
@onready var stick_knob: TextureRect = $Root/Stick/Knob
@onready var buttons: VBoxContainer = $Root/Buttons

var _stick_touch := -1            # 조이스틱을 잡고 있는 손가락 id
var _stick_origin := Vector2.ZERO
var _held_actions: Array[String] = []
var _pressed: Dictionary = {}     # 지금 우리가 누르고 있다고 보고한 액션들
var _buttons: Dictionary = {}     # 액션 이름 → Button
var _avail: Dictionary = {}       # 액션 이름 → 지금 쓸 수 있는가
var _label: Label                 # 조사 대상 이름
var _recenter: Button             # 카메라를 원래 각도로
var _settings_btn: Button         # 환경설정 열기
var _refresh_t := 0.0


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
	_make_target_label()
	_make_recenter()
	_make_settings()
	# 터치가 한 번이라도 들어오면 그때부터 보여준다 (PC 에서는 계속 숨김)
	set_process_input(true)
	set_process(true)
	_refresh_availability()


## 눌러도 아무 일이 없는 버튼은 "고장난 게임" 으로 읽힌다.
## 지금 쓸 수 있는 버튼만 또렷하게 두고 나머지는 흐리게 한다.
## 매 프레임 돌 필요는 없다. 0.2 초면 사람 눈에는 즉각이다.
func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh_availability()


func _refresh_availability() -> void:
	for action in _buttons:
		var can := _can_use(action)
		if _avail.get(action) == can:
			continue
		_avail[action] = can
		var b: Button = _buttons[action]
		b.modulate = Color(1, 1, 1, 1) if can else Color(1, 1, 1, 0.62)
		b.disabled = not can
		if can:
			# 막 쓸 수 있게 된 버튼은 한 번 부풀려 알려준다
			var tw := create_tween()
			tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.10)
			tw.tween_property(b, "scale", Vector2.ONE, 0.16)
	_refresh_target_label()
	_refresh_interact_text()


## 씬이 직접 판단하고 싶으면 "action_availability" 그룹에 노드를 넣고
## can_use(action) 을 구현하면 된다. 없으면 아래 기본 규칙을 쓴다.
func _can_use(action: String) -> bool:
	var p := get_tree().get_first_node_in_group("action_availability")
	if p != null and p.has_method("can_use"):
		return p.can_use(action)

	match action:
		"wind_note":
			return true                      # 목표 확인은 언제나 된다
		"interact":
			var db := get_tree().get_first_node_in_group("dialogue_box")
			if db != null and db.has_method("is_open") and db.is_open():
				return true                  # 대사 넘기기
			return _interact_target() != null
		"photo":
			var st := get_node_or_null("/root/Episode0State")
			if st == null:
				return true                  # 여행 씬 등 에피소드 밖
			return st.current_state >= st.State.FIRST_PHOTO
		"album":
			var st2 := get_node_or_null("/root/Episode0State")
			if st2 == null:
				return true
			return st2.current_state >= st2.State.ALBUM_CREATED
	return true


## 이 자리에서 시작한 드래그를 둘러보기로 써도 되는가.
## 버튼과 조이스틱 위에서 시작한 손가락은 카메라를 돌리면 안 된다.
func blocks_look(pos: Vector2) -> bool:
	if not visible:
		return false
	for a in _buttons:
		var b: Button = _buttons[a]
		if b.get_global_rect().grow(10.0).has_point(pos):
			return true
	if _settings_btn != null and _settings_btn.get_global_rect().grow(10.0).has_point(pos):
		return true
	if _recenter != null and _recenter.get_global_rect().grow(10.0).has_point(pos):
		return true
	return false


## 지금 조사할 수 있는 대상. 없으면 null.
func _interact_target() -> Node:
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not ("nearby_interactables" in pl):
		return null
	var list: Array = pl.nearby_interactables
	return list[0] if list.size() > 0 else null


func _make_target_label() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", D.TEXT_S)
	_label.add_theme_color_override("font_color", D.ACCENT_SOFT)
	_label.add_theme_color_override("font_outline_color", D.OUTLINE)
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position = Vector2(0, -210)
	_label.visible = false
	root.add_child(_label)


## 둘러보다 방향을 잃었을 때 돌아올 곳. 360° 로 돌릴 수 있게 하면 반드시 필요하다.
func _make_recenter() -> void:
	var b := Button.new()
	# ⟲ 역시 폰트에 없는 글자다. 글자로 쓴다.
	b.text = "정면"
	b.custom_minimum_size = Vector2(96, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.78)
	sb.set_corner_radius_all(48)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = Color(1, 1, 1, 0.85)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb2)
	b.anchor_left = 0.0; b.anchor_right = 0.0
	b.anchor_top = 0.0;  b.anchor_bottom = 0.0
	b.offset_left = 48.0;   b.offset_right = 144.0
	b.offset_top = 124.0;   b.offset_bottom = 220.0
	b.pressed.connect(func():
		var fl := get_tree().get_first_node_in_group("free_look")
		if fl != null and fl.has_method("recenter"):
			fl.recenter())
	root.add_child(b)
	_recenter = b


## 게임 화면의 환경설정 버튼.
##
## 지금까지 게임 안에는 설정도, 나가는 길도 없었다. 메인화면에만 있었다.
## 소리를 줄이려면 앱을 죽였다가 다시 켜야 했다.
## 설정 창은 맵 씬에 없으므로 여기서 한 번 만들어 붙인다.
func _make_settings() -> void:
	var b := Button.new()
	b.name = "SettingsBtn"
	b.text = "설정"
	b.custom_minimum_size = Vector2(96, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.78)
	sb.set_corner_radius_all(48)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = Color(1, 1, 1, 0.95)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb2)
	# 오른쪽 위. preset + position 으로 잡으면 폭이 앵커 밖으로 삐져나가
	# 화면 오른쪽이 잘린다 (버전 토스트가 같은 실수로 잘려 있었다).
	# 오프셋을 직접 준다.
	b.anchor_left = 0.0; b.anchor_right = 0.0
	b.anchor_top = 0.0;  b.anchor_bottom = 0.0
	b.offset_left = 160.0;  b.offset_right = 256.0
	b.offset_top = 124.0;   b.offset_bottom = 220.0
	b.pressed.connect(_open_settings)
	root.add_child(b)
	_settings_btn = b


## 설정 창을 찾아 연다. 맵 씬에는 없으므로 없으면 만들어 둔다.
func _open_settings() -> void:
	var sv := get_tree().get_first_node_in_group("settings_ui")
	if sv == null:
		var packed := load("res://scenes/ui/SettingsUI.tscn")
		if packed == null:
			return
		sv = packed.instantiate()
		var scene := get_tree().current_scene
		if scene == null:
			return
		scene.add_child(sv)
		await get_tree().process_frame
	if sv.has_method("open"):
		sv.open()


## 버튼에 쓸 짧은 동사. "쿼카전자로 들어가기" → "들어가기".
## 너무 짧으면("찍기") 앞 낱말을 하나 더 붙여 "사진 찍기" 로 만든다.
## 동사로 끝나면 뒤에서 잘라 쓰고, 아니면 무엇을 할지 붙여 준다.
##
## 처음엔 뒤 낱말부터 4자가 될 때까지 붙였는데 두 가지가 깨졌다.
##   "[ 첫 골목 ]" → "골목 ]"   대괄호 조각이 남았다
##   "오래된 카메라"  → "오래된 카메라"  명사만 남아 무슨 일이 일어날지 알 수 없다
## 버튼은 **무엇이 일어나는지** 를 말해야 한다.
static func short_verb(prompt: String) -> String:
	# 기념품 제목은 "[ 첫 골목 ]" 형식이다. 장식 기호를 먼저 걷어낸다.
	var clean := prompt.strip_edges().replace("[", "").replace("]", "").strip_edges()
	var parts := clean.split(" ", false)
	if parts.is_empty():
		return "조사"

	# 동사로 끝나는가. "~기" 로 끝나면 이미 행동을 말하고 있다.
	var last: String = parts[parts.size() - 1]
	if last.ends_with("기"):
		var out := last
		var i := parts.size() - 2
		while out.length() < 4 and i >= 0:
			out = parts[i] + " " + out
			i -= 1
		return out if out.length() <= 7 else last

	# 명사다. 무엇을 할지 붙인다.
	return "살펴보기"


## 지금 무엇을 하는 버튼인지 글자를 바꾼다.
## 문 앞인데 "조사" 라고 적혀 있으면 무엇이 일어날지 알 수 없다.
func _refresh_interact_text() -> void:
	var b: Button = _buttons.get("interact")
	if b == null:
		return
	var want := "조사"
	var db := get_tree().get_first_node_in_group("dialogue_box")
	if db != null and db.has_method("is_open") and db.is_open():
		want = "다음"
	else:
		var t := _interact_target()
		if t != null and ("prompt_text" in t) and str(t.prompt_text) != "":
			want = short_verb(str(t.prompt_text))
	if b.text != want:
		b.text = want
		# 글자가 길어지면 작게. 동그라미를 넘치면 안 된다.
		# 지름 138px 안에 들어와야 한다. 단계가 둘뿐일 때 8자가 원을 넘쳤다.
		var n := want.length()
		var fs := 30 if n <= 4 else (26 if n <= 5 else (23 if n <= 6 else 20))
		b.add_theme_font_size_override("font_size", fs)


func _refresh_target_label() -> void:
	if _label == null:
		return
	var t := _interact_target()
	if t == null:
		_label.visible = false
		return
	var name_text := ""
	if "label" in t and str(t.label) != "":
		name_text = str(t.label)
	elif "prompt" in t and str(t.prompt) != "":
		name_text = str(t.prompt)
	if name_text == "":
		_label.visible = false
		return
	_label.text = name_text
	_label.visible = true

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
				stick_base.modulate.a = 0.62
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
	stick_base.modulate.a = 0.34
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
	stick_base.modulate.a = 0.34
	stick_knob.texture = _disc(int(KNOB_RADIUS * 2), Color(1, 0.88, 0.60))
	stick_knob.modulate.a = 0.45
	stick_knob.position = Vector2(STICK_RADIUS - KNOB_RADIUS, STICK_RADIUS - KNOB_RADIUS)

## 동작 버튼. 누르는 동안 해당 키를 누른 것으로 만든다.
func _build_buttons() -> void:
	for c in buttons.get_children():
		c.queue_free()
	# 글자로 쓴다. 예전에는 📷 🍃 📖 이모지 하나뿐이었는데, 이 글자들은
	# **우리 폰트에 없어서 기기의 시스템 폰트로 대신 그려진다.** 기기에 따라
	# 모양이 다르고, 없는 기기에서는 네 버튼이 전부 □ 가 된다.
	# 뜻을 전부 담은 자리를 기기 사정에 맡길 수는 없다.
	var defs := [
		["photo", "사진", Color(0.72, 0.86, 0.96), 112],
		["wind_note", "바람", Color(0.70, 0.90, 0.74), 112],
		["album", "앨범", Color(0.86, 0.78, 0.96), 112],
		["interact", "조사", Color(1.0, 0.78, 0.52), 138],
	]
	for d in defs:
		var b := _action_button(str(d[0]), str(d[1]), d[2], int(d[3]))
		buttons.add_child(b)
		_buttons[str(d[0])] = b

func _action_button(action: String, label: String, tint: Color, size_px: int) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(size_px, size_px)
	# 컨테이너 폭에 늘어나면 원이 알약이 된다. 자기 크기를 지키게 한다.
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.focus_mode = Control.FOCUS_NONE   # 포커스를 뺏어 키 입력을 먹지 않게
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
	var sb := D.round_button(tint, size_px)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = Color(tint.r, tint.g, tint.b, 0.98)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb2)
	# 지금 못 쓰는 버튼도 같은 동그라미여야 한다. 이걸 안 주면 기본 테마의
	# 네모 패널이 나와서 "버튼이 깨졌다" 로 보인다.
	var sb3 := D.round_button(tint, size_px, 0.30)
	sb3.border_color = Color(1, 1, 1, 0.42)
	b.add_theme_stylebox_override("disabled", sb3)
	# 어두운 배경 위에서도 형태가 남게 밝은 크림으로. 어둡게 흐리면 버그처럼 보인다.
	b.add_theme_color_override("font_disabled_color", Color(0.99, 0.97, 0.88, 0.92))
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
				a = 0.03                       # 안쪽은 거의 비운다
				if d > 0.86:
					a = 0.95 * (1.0 - (d - 0.86) / 0.14)   # 테두리
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

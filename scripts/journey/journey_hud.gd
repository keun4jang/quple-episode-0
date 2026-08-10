class_name JourneyHud
extends CanvasLayer
## 화면에 늘 떠 있는 것. **시각과 배낭뿐이다.**
##
## `docs/redesign-journey.md` 9절 — 체력바도 돈도 경험치도 퀘스트 목록도
## 없다. 여행자가 늘 알고 싶은 건 지금 몇 시인지 하나다.

signal bag_toggled(open: bool)
signal shutter

var _clock: Label
var _bag_btn: TextureButton
var _bag_panel: PanelContainer
var _bag_grid: GridContainer
var _hint: Label
var _cam_btn: TextureButton
var _tabs: HBoxContainer
var _tab := 0                     # 0 배낭 · 1 사진첩 · 2 편지 · 3 행복첩
var _dot: Control                 # 안 읽은 편지 표시 (직접 그린 점)
var _flash: ColorRect
var _root: Control
var _pad_cam: Control
var _pad_bag: Control
var _buttons_hidden := false

## 아이템 이름 → 사람이 읽는 이름
const NAMES := {
	"p-persimmon": "감", "p-pebble": "조약돌", "p-flower": "들꽃",
	"p-pinecone": "솔방울", "p-acorn": "도토리", "p-feather": "깃털",
	"p-shell": "조개", "p-seaglass": "바다유리",
}


func _ready() -> void:
	layer = 5
	add_to_group("journey_hud")
	_build()
	JourneyState.picked.connect(_on_picked)
	set_process(true)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root = root
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

	# 시각 — 왼쪽 위, 얇게
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 30)
	_clock.add_theme_color_override("font_color", Color("#FFFDF6"))
	_clock.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_clock.add_theme_constant_override("outline_size", 8)
	_clock.position = Vector2(28, 18)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_clock)

	# 배낭 — 오른쪽 아래. 엄지가 닿는 곳
	_bag_btn = TextureButton.new()
	_bag_btn.texture_normal = load("res://assets/sprites/i-pack.png")
	_bag_btn.ignore_texture_size = true
	_bag_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_bag_btn.custom_minimum_size = Vector2(96, 96)
	_bag_btn.size = Vector2(96, 96)
	_bag_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bag_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_bag_btn.offset_left = -128
	_bag_btn.offset_top = -128
	_bag_btn.offset_right = -32
	_bag_btn.offset_bottom = -32
	_bag_btn.pressed.connect(toggle_bag)
	_press_feedback(_bag_btn)
	root.add_child(_bag_btn)

	# 무엇을 주웠는지 잠깐 알려 주는 줄
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 30)
	_hint.add_theme_color_override("font_color", Color("#FFF2C8"))
	_hint.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = 90
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	# 두 버튼 뒤에 받침을 깐다.
	#
	# 카메라 아이콘이 어두운 갈색이라 윤슬 왼쪽 아래의 쓰러진 나무·우물과
	# 겹치면 버튼인지 배경 소품인지 갈리지 않았다. 아이콘을 다시 그리는
	# 대신 뒤에 옅은 원판을 깐다 — 어떤 배경 위에서도 "누르는 것"으로 읽힌다.
	_pad_cam = _make_pad(root, Control.PRESET_BOTTOM_LEFT, 20, -140, 140, -20)
	_pad_bag = _make_pad(root, Control.PRESET_BOTTOM_RIGHT, -140, -140, -20, -20)

	# 사진 — 왼쪽 아래. 배낭과 반대쪽이라 헷갈리지 않는다
	_cam_btn = TextureButton.new()
	_cam_btn.texture_normal = load("res://assets/sprites/i-camera.png")
	_cam_btn.ignore_texture_size = true
	_cam_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_cam_btn.custom_minimum_size = Vector2(96, 96)
	_cam_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cam_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_cam_btn.offset_left = 32
	_cam_btn.offset_top = -128
	_cam_btn.offset_right = 128
	_cam_btn.offset_bottom = -32
	_cam_btn.pressed.connect(func(): shutter.emit())
	_press_feedback(_cam_btn)
	root.add_child(_cam_btn)

	# 안 읽은 편지가 있으면 배낭에 점이 하나 붙는다. 숫자도 느낌표도 안 쓴다.
	# 점은 글자가 아니라 **직접 그린다.** 본문 폰트(PoorStory)에 ● 가 없어서
	# 글자로 쓰면 폰에서 네모 상자가 뜬다. 도형은 폰트를 안 탄다.
	_dot = Control.new()
	_dot.custom_minimum_size = Vector2(22, 22)
	_dot.size = Vector2(22, 22)
	_dot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dot.offset_left = -46
	_dot.offset_top = -134
	_dot.offset_right = -24
	_dot.offset_bottom = -112
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	_dot.draw.connect(func() -> void:
		_dot.draw_circle(Vector2(11, 11), 11.0, Color(0.16, 0.13, 0.18))
		_dot.draw_circle(Vector2(11, 11), 8.5, Color("#E4785F")))
	root.add_child(_dot)

	# 사진 찍을 때 화면이 한 번 하얘진다
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_build_bag(root)


func _build_bag(root: Control) -> void:
	_bag_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.18, 0.94)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_bag_panel.add_theme_stylebox_override("panel", sb)
	_bag_panel.set_anchors_preset(Control.PRESET_CENTER)
	_bag_panel.offset_left = -320
	_bag_panel.offset_right = 320
	_bag_panel.offset_top = -220
	_bag_panel.offset_bottom = 220
	_bag_panel.visible = false
	root.add_child(_bag_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_bag_panel.add_child(box)

	# 넷을 한 창에 모은다. 화면을 늘리지 않는다.
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 8)
	box.add_child(_tabs)
	for i in 4:
		var b := Button.new()
		b.text = ["배낭", "사진첩", "편지", "행복첩"][i]
		b.custom_minimum_size = Vector2(126, 60)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_pick_tab.bind(i))
		_tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_bag_grid = GridContainer.new()
	_bag_grid.columns = 4
	_bag_grid.add_theme_constant_override("h_separation", 18)
	_bag_grid.add_theme_constant_override("v_separation", 14)
	_bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bag_grid)


## 누르면 살짝 눌리게 한다.
##
## `TextureButton` 에 pressed 그림이 따로 없어서, 지금까지 눌렸다는 걸
## 알 수 있는 건 결과(배낭이 열림·플래시)뿐이었다. 결과가 늦으면 고장으로
## 읽힌다. 그림을 더 그리는 대신 크기로 알린다.
func _press_feedback(b: BaseButton) -> void:
	b.pivot_offset = b.custom_minimum_size * 0.5
	b.button_down.connect(func(): b.scale = Vector2(0.88, 0.88))
	b.button_up.connect(func(): _pop(b))


func _pop(b: Control) -> void:
	if not is_instance_valid(b):
		return
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _make_pad(root: Control, preset: int, l: float, t: float,
		r: float, b: float) -> Control:
	var c := Control.new()
	c.set_anchors_preset(preset)
	c.offset_left = l; c.offset_top = t
	c.offset_right = r; c.offset_bottom = b
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var mid := c.size * 0.5
		var rad: float = minf(mid.x, mid.y)
		c.draw_circle(mid, rad, Color(0.16, 0.13, 0.18, 0.26))
		c.draw_circle(mid, rad - 3.0, Color(1.0, 0.99, 0.94, 0.20)))
	root.add_child(c)
	return c


## 배낭 안에 글자 한 줄을 넣는다.
##
## **폭을 직접 준다.** autowrap 을 켠 Label 은 최소폭이 0 이라, 격자가
## 폭을 못 얻으면 1px 기준으로 줄을 바꾼다 — 편지 한 통이
## "엄/마/(/6/일/째/)" 처럼 글자마다 한 줄로 쏟아져 읽을 수가 없었다.
const BAG_LINE_WIDTH := 560.0

func _bag_line(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(BAG_LINE_WIDTH, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func toggle_bag() -> void:
	AudioManager.page_turn()
	_bag_panel.visible = not _bag_panel.visible
	if _bag_panel.visible:
		_refill_bag()
	bag_toggled.emit(_bag_panel.visible)


func _pick_tab(i: int) -> void:
	_tab = i
	if i == 2:
		# 열어 봤으면 읽은 것이다
		JourneyState.read_letters()
	_refill_bag()


## 사진을 찍었다. 화면이 한 번 하얘진다.
func flash() -> void:
	_flash.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)


func bag_open() -> bool:
	return _bag_panel != null and _bag_panel.visible


func _refill_bag() -> void:
	for c in _bag_grid.get_children():
		c.queue_free()
	for i in _tabs.get_child_count():
		var b := _tabs.get_child(i) as Button
		b.modulate = Color.WHITE if i == _tab else Color(0.7, 0.68, 0.74)

	match _tab:
		1: _fill_photos()
		2: _fill_letters()
		3: _fill_postcards()
		_: _fill_bag()


func _empty(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color("#A79A8A"))
	_bag_grid.add_child(l)


func _fill_bag() -> void:
	_bag_grid.columns = 4
	if JourneyState.bag.is_empty():
		_empty("아직 아무것도 없어요")
		return
	for item in JourneyState.bag:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var pic := TextureRect.new()
		pic.texture = load("res://assets/sprites/%s.png" % item)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(84, 84)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cell.add_child(pic)
		var name := Label.new()
		name.text = "%s %d" % [NAMES.get(item, item), JourneyState.count(item)]
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 24)
		name.add_theme_color_override("font_color", Color("#E4DCCF"))
		cell.add_child(name)
		_bag_grid.add_child(cell)


## 사진첩. 그림을 저장하지 않는다 — **어디서 언제 무엇을 봤는지**만 적는다.
## 픽셀 화면을 통째로 저장하면 용량이 금방 불고, 사실 남는 건 그 한 줄이다.
func _fill_photos() -> void:
	_bag_grid.columns = 1
	if JourneyState.photos.is_empty():
		_empty("아직 찍은 사진이 없어요")
		return
	for i in range(JourneyState.photos.size() - 1, -1, -1):
		var p: Dictionary = JourneyState.photos[i]
		_bag_grid.add_child(_bag_line("%s  %d일째 %s  ·  %s" % [
			p.get("place", ""), int(p.get("day", 1)),
			p.get("time", ""), p.get("subject", "")], 26, Color("#E4DCCF")))


func _fill_letters() -> void:
	_bag_grid.columns = 1
	if JourneyState.letters.is_empty():
		_empty("아직 온 편지가 없어요")
		return
	for i in range(JourneyState.letters.size() - 1, -1, -1):
		var m: Dictionary = JourneyState.letters[i]
		_bag_grid.add_child(_bag_line("엄마 (%d일째)\n  %s" % [
			int(m.get("day", 1)), m.get("text", "")], 28, Color("#FFF2C8")))


## 행복첩 — 마음 다섯 칸을 채운 인연에게서 받은 엽서.
## 이름을 "인연"이라 안 쓴다 (`docs/world-quo.md` 1절).
func _fill_postcards() -> void:
	_bag_grid.columns = 1
	if JourneyState.postcards.is_empty():
		_empty("아직 받은 엽서가 없어요")
		return
	for id in JourneyState.postcards:
		_bag_grid.add_child(
			_bag_line(JourneyState.postcard_text(id), 30, Color("#E4DCCF")))


## 받침을 보고 을/를 을 골라 붙인다.
##
## 화면에 "조개 을(를) 주웠어요" 라고 그대로 찍히고 있었다. 이름이 여덟
## 개뿐이라 표를 만들 것도 없다 — 한글 마지막 글자에서 받침만 보면 된다.
func _with_josa(word: String) -> String:
	if word.is_empty():
		return word
	var c := word.unicode_at(word.length() - 1)
	if c < 0xAC00 or c > 0xD7A3:
		return word + "를"            # 한글이 아니면 아쉬운 대로
	return word + ("을" if (c - 0xAC00) % 28 != 0 else "를")


func _on_picked(item: String, _total: int) -> void:
	_hint.text = "%s 주웠어요" % _with_josa(String(NAMES.get(item, item)))
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)
	if _bag_panel.visible:
		_refill_bag()


func _process(_delta: float) -> void:
	if _clock != null:
		_clock.text = "%s   %d일째" % [JourneyState.time_text(), JourneyState.day]
	if _dot != null:
		_dot.visible = JourneyState.unread_letters() > 0 and not bag_open() \
			and not _buttons_hidden


# ── 안전영역 ──────────────────────────────────────────────────────────
#
# 몰입 모드라 앱이 화면 전체를 받는다. 그 안에는 펀치홀·둥근 모서리·
# 제스처 바가 같이 들어 있다. 배낭 버튼이 아래에서 48px 이었으니
# 제스처 바와 겹쳤다 — 배낭을 누르려다 홈으로 나가는 오작동이 난다.
#
# **다만 이 값을 그대로 믿으면 안 된다.** 데스크톱·헤드리스에서는
# `get_display_safe_area()` 가 창이 아니라 화면 전체를 돌려주기도 해서,
# 처음 붙였을 때 HUD 가 1600x720 대신 853x683 으로 쪼그라들었다.
# 그래서 두 겹으로 막는다 — **안드로이드에서만** 적용하고, 한 변당
# 최대 10% 까지만 민다. 어느 쪽이 이상해도 화면이 무너지지는 않는다.
const SAFE_MAX := 0.10

## [왼쪽, 위, 오른쪽, 아래] 여백을 캔버스 단위로.
static func safe_insets(vp: Viewport) -> Vector4:
	if vp == null or OS.get_name() != "Android":
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var canvas := vp.get_visible_rect().size
	var kx := canvas.x / float(win.x)
	var ky := canvas.y / float(win.y)
	return Vector4(
		clampf(maxf(0.0, float(safe.position.x)) * kx, 0.0, canvas.x * SAFE_MAX),
		clampf(maxf(0.0, float(safe.position.y)) * ky, 0.0, canvas.y * SAFE_MAX),
		clampf(maxf(0.0, float(win.x - (safe.position.x + safe.size.x))) * kx,
			0.0, canvas.x * SAFE_MAX),
		clampf(maxf(0.0, float(win.y - (safe.position.y + safe.size.y))) * ky,
			0.0, canvas.y * SAFE_MAX))


## 이 Control 을 안전영역만큼 안쪽으로 민다.
static func inset_safe(c: Control) -> void:
	if c == null:
		return
	var v := safe_insets(c.get_viewport())
	c.offset_left = v.x
	c.offset_top = v.y
	c.offset_right = -v.z
	c.offset_bottom = -v.w


func _apply_safe_area() -> void:
	inset_safe(_root)


## 대화 중에는 배낭·사진 버튼을 치운다.
##
## 대화창이 화면 아래를 통째로 쓰기 때문에 버튼이 그 뒤에 숨어 있었고,
## 창이 탭을 먹어서 눌리지도 않았다. 안 보이는 버튼을 남겨 두느니
## 대화 동안은 아예 비켜 준다 — 대화 중에 사진을 찍을 일도 없다.
func set_buttons_visible(on: bool) -> void:
	_buttons_hidden = not on
	for n in [_bag_btn, _cam_btn, _pad_bag, _pad_cam]:
		if n != null:
			n.visible = on


## 걷는 손가락과 상관없이 버튼을 눌러 준다.
##
## `TextureButton` 은 **터치에서 흉내낸 마우스**로만 눌리는데, 엔진은 그
## 흉내를 첫 번째 손가락 하나에만 건다. 그 손가락은 걷기가 쓰고 있으니
## 걸으면서 다른 손가락으로 셔터를 누르면 아무 일도 안 일어났다.
## 걷기 쪽(`journey_touch`)이 손가락을 집기 전에 여기로 먼저 물어본다.
func try_touch(pos: Vector2) -> bool:
	if _buttons_hidden:
		return false
	if _bag_panel != null and _bag_panel.visible:
		return false                       # 배낭이 열려 있으면 창이 알아서 받는다
	for b in [_cam_btn, _bag_btn]:
		if b != null and b.visible and b.get_global_rect().has_point(pos):
			b.pressed.emit()
			b.scale = Vector2(0.88, 0.88)     # 손가락으로 직접 눌렀을 때도
			_pop(b)
			return true
	return false


## 뒤로가기가 부른다. 열려 있던 배낭을 닫고 닫았는지 알려 준다.
func close_bag() -> bool:
	if _bag_panel != null and _bag_panel.visible:
		toggle_bag()
		return true
	return false

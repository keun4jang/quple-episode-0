class_name JourneyHud
extends CanvasLayer
## 화면에 늘 떠 있는 것. **시각과 배낭뿐이다.**
##
## `docs/redesign-journey.md` 9절 — 체력바도 돈도 경험치도 퀘스트 목록도
## 없다. 여행자가 늘 알고 싶은 건 지금 몇 시인지 하나다.

signal bag_toggled(open: bool)
signal shutter
## "이 마을에서" 탭을 열어 봤다. 안내(`Guide`)가 이걸로 다음 줄로 넘어간다.
signal quest_tab_opened
## 오른쪽 아래 큰 버튼을 눌렀다. 무슨 뜻인지는 `Place` 가 정한다.
signal acted

var _clock: Label
var _place_title: Label
var _title_tw: Tween
var _bag_btn: TextureButton
var _bag_panel: PanelContainer
var _bag_grid: GridContainer
var _hint: Label
var _cam_btn: TextureButton
var _tabs: HBoxContainer
var _tab := 0                     # 0 배낭 · 1 사진첩 · 2 편지 · 3 행복첩 · 4 이 마을에서
## 배낭에 안 본 것이 있다는 표시(직접 그린 점, 편지든 할 일이든).
##
## 한동안 편지(주황)·할 일(초록) 점을 따로 뒀는데, 밖에서 신호 둘이
## 뜨면 "뭐가 중요한 신호인지" 흐려진다는 지적을 받았다. 바깥은 "뭔가
## 있다" 는 것만 알리고, 무엇인지는 배낭을 열어야 안다 — 그게 탭 안의
## 내용(체크 표시·편지 목록)이 이미 하고 있는 일이다.
var _dot: Control
## 배낭이 어디 있는지 가리키는 고리. 길잡이가 "배낭을 열어 보세요" 줄을
## 띄우고 있는 동안만 켠다 — 글자로 "여기" 라고 쓰는 대신 **직접 그린다.**
var _bag_ring: Control
var _ring_t := 0.0
var _flash: ColorRect
var _root: Control
var _pad_cam: Control
var _pad_bag: Control
var _act_btn: Button
var _act_kind := ""
var _act_shown := false
var _act_tw: Tween
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
	# 대사(21)보다 크면 위계가 뒤집힌다. 시계는 늘 떠 있을 뿐이다.
	_clock.add_theme_font_size_override("font_size", 24)
	_clock.add_theme_color_override("font_color", Color("#FFFDF6"))
	_clock.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_clock.add_theme_constant_override("outline_size", 8)
	_clock.position = Vector2(28, 18)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_clock)

	# 마을 이름표. 도착하거나 이어하기로 들어오면 가운데 크게 떴다 없어진다.
	_place_title = Label.new()
	_place_title.add_theme_font_size_override("font_size", 52)
	_place_title.add_theme_color_override("font_color", Color("#FFFDF6"))
	_place_title.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_place_title.add_theme_constant_override("outline_size", 10)
	_place_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_title.set_anchors_preset(Control.PRESET_CENTER)
	_place_title.offset_left = -400
	_place_title.offset_right = 400
	_place_title.offset_top = -34
	_place_title.offset_bottom = 34
	_place_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_title.modulate.a = 0.0
	root.add_child(_place_title)

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

	# ── 선택 버튼 ──
	#
	# 오른쪽 아래, 배낭 위. **하나로 여러 일을 한다** — 말 걸기, 자기,
	# 떠나기, 대화 넘기기. 지금 할 수 있는 일이 없으면 사라진다.
	#
	# 화면을 눌러서도 다 되는 일들이지만, 누를 곳을 찾는 것과 누를 것이
	# 거기 있는 것은 다르다. 처음 잡는 사람에게는 **버튼 하나가 있는 쪽**이
	# 훨씬 친절하다.
	_act_btn = Button.new()
	_act_btn.name = "ActionBtn"
	_act_btn.focus_mode = Control.FOCUS_NONE
	# 안내가 일부러 가르치는 버튼이 세 모서리 중 제일 작으면 앞뒤가 안
	# 맞다. 148x72 캔버스 = 1.5배 폰에서 222x108, 48dp 를 넘는다.
	_act_btn.custom_minimum_size = Vector2(148, 72)
	_act_btn.add_theme_font_size_override("font_size", 26)
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color("#FFE39A")
	asb.set_corner_radius_all(30)
	asb.set_border_width_all(3)
	asb.border_color = Color("#8C6E3F")
	_act_btn.add_theme_stylebox_override("normal", asb)
	_act_btn.add_theme_stylebox_override("hover", asb)
	var apr := asb.duplicate() as StyleBoxFlat
	apr.bg_color = Color("#FFD166")
	_act_btn.add_theme_stylebox_override("pressed", apr)
	_act_btn.add_theme_color_override("font_color", Color("#4A3A22"))
	_act_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_act_btn.offset_left = -180
	_act_btn.offset_top = -234
	_act_btn.offset_right = -32
	_act_btn.offset_bottom = -162
	_act_btn.visible = false
	_act_btn.pressed.connect(func(): acted.emit())
	_press_feedback(_act_btn)
	root.add_child(_act_btn)

	# 무엇을 주웠는지 잠깐 알려 주는 줄
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", Color("#FFF2C8"))
	_hint.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# "고갯마루 전망 바위까지 가서 사진 찍기, 다 했어요" 같은 긴 줄이
	# 있어서 600px 로는 넘친다. 넓히고 줄바꿈도 켠다.
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.offset_left = -380
	_hint.offset_right = 380
	_hint.offset_top = 90
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	# 두 버튼 뒤에 받침을 깐다.
	#
	# 카메라 아이콘이 어두운 갈색이라 윤슬 왼쪽 아래의 쓰러진 나무·우물과
	# 겹치면 버튼인지 배경 소품인지 갈리지 않았다. 아이콘을 다시 그리는
	# 대신 뒤에 옅은 원판을 깐다 — 어떤 배경 위에서도 "누르는 것"으로 읽힌다.
	# **버튼과 같은 중심에 둔다.** 받침 원이 버튼보다 12px 바깥으로
	# 밀려 있어서, 아이콘이 원 안에서 한쪽으로 치우쳐 보였다 — 좌우
	# 두 버튼이 서로 반대쪽으로 쏠려 더 어긋나 보였다.
	# 버튼 중심은 좌우 다 화면 끝에서 80px, 위로 80px.
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

	# 안 읽은 편지나 남은 할 일이 있으면 배낭에 점이 하나 붙는다.
	# 숫자도 느낌표도 안 쓴다. 점은 글자가 아니라 **직접 그린다.**
	# 본문 폰트(PoorStory)에 ● 가 없어서 글자로 쓰면 폰에서 네모
	# 상자가 뜬다. 도형은 폰트를 안 탄다.
	_dot = Control.new()
	_dot.custom_minimum_size = Vector2(22, 22)
	_dot.size = Vector2(22, 22)
	_dot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 배낭 원 테두리 위 오른쪽 45도. 예전엔 위로 너무 떠 있었다.
	_dot.offset_left = -57
	_dot.offset_top = -125
	_dot.offset_right = -35
	_dot.offset_bottom = -103
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	_dot.draw.connect(func() -> void:
		_dot.draw_circle(Vector2(11, 11), 11.0, Color(0.16, 0.13, 0.18))
		_dot.draw_circle(Vector2(11, 11), 8.5, Color("#FFD166")))
	root.add_child(_dot)

	# 배낭을 가리키는 고리. 배낭 버튼과 같은 자리에 겹쳐 두고 테두리만 그린다.
	_bag_ring = Control.new()
	_bag_ring.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_bag_ring.offset_left = -136
	_bag_ring.offset_top = -136
	_bag_ring.offset_right = -24
	_bag_ring.offset_bottom = -24
	_bag_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_ring.visible = false
	_bag_ring.draw.connect(func() -> void:
		var mid := _bag_ring.size * 0.5
		# 숨쉬듯 굵기와 크기가 오간다. 깜빡이면 급해 보인다.
		var p := 0.5 + 0.5 * sin(_ring_t * 3.0)
		var rad: float = minf(mid.x, mid.y) - 6.0 + p * 5.0
		_bag_ring.draw_arc(mid, rad, 0.0, TAU, 48,
			Color(1.0, 0.82, 0.40, 0.45 + p * 0.45), 4.0 + p * 2.0, true))
	root.add_child(_bag_ring)

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
	_bag_panel.offset_left = -360
	_bag_panel.offset_right = 360
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
	# **다섯 칸이 판 밖으로 넘쳤다.** "이 마을에서" 는 여섯 글자라 제 칸을
	# 넘겨 잡는데, 다섯을 나란히 놓으니 합이 판 안폭보다 넓어 **마지막
	# 칸이 오른쪽으로 잘렸다** — 하필 할 일이 든, 제일 자주 열 칸이었다.
	# 판을 넓히고 이름을 "이 마을" 로 줄인다.
	for i in 5:
		var b := Button.new()
		b.text = ["배낭", "사진첩", "편지", "행복첩", "이 마을"][i]
		b.custom_minimum_size = Vector2(112, 60)
		b.add_theme_font_size_override("font_size", 24)
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
const BAG_LINE_WIDTH := 620.0

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
		# **막혔을 때 "행복첩을 보면 된다" 는 걸 몸에 남기려면, 배낭을
		# 열었을 때 바로 그 화면이 보여야 한다.** 이 마을에 할 일이
		# 남아 있으면 "이 마을에서" 탭으로 먼저 연다 — 다섯째 탭에
		# 묻혀 있어서 못 찾겠다는 게 제일 큰 지적이었다.
		var left := false
		for q in Quests.quest_list(JourneyState.here):
			if not bool(q.get("done", false)):
				left = true
				break
		_tab = 4 if left else 0
		_refill_bag()
		# **저절로 열린 것도 연 것이다.** 여기서 `_tab` 만 바꾸고 지나가는
		# 바람에 `quest_tab_opened` 가 안 울렸다. 길잡이 첫 줄이 이 신호를
		# 기다리는데 영영 안 오니, 배낭을 열어 할 일까지 다 읽은 사람도
		# 안내가 그 줄에 멈춰 다음(걷기)으로 넘어가질 못했다.
		if _tab == 4:
			quest_tab_opened.emit()
	bag_toggled.emit(_bag_panel.visible)


func _pick_tab(i: int) -> void:
	_tab = i
	if i == 2:
		# 열어 봤으면 읽은 것이다
		JourneyState.read_letters()
	if i == 4:
		quest_tab_opened.emit()
	_refill_bag()


## 마을 이름을 가운데에 크게 띄웠다 지운다. 장소가 바뀌거나(도착),
## 이어하기로 그 씬이 막 시작할 때 한 번 부른다 — 안내 문구가 아니라
## **여기가 어디인지**만 조용히 알려 준다.
func announce_place(text: String) -> void:
	if _place_title == null:
		return
	_place_title.text = text
	if _title_tw != null and _title_tw.is_valid():
		_title_tw.kill()
	_place_title.modulate.a = 0.0
	_title_tw = create_tween()
	_title_tw.tween_property(_place_title, "modulate:a", 1.0, 0.5)
	_title_tw.tween_interval(1.3)
	_title_tw.tween_property(_place_title, "modulate:a", 0.0, 0.7)


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
		4: _fill_quests()
		_: _fill_bag()
	_fit_bag_panel()


## 창을 내용 높이에 맞춘다.
##
## 640x440 으로 못 박아 두니 빈 배낭에서 "아직 아무것도 없어요" 한 줄
## 밑으로 검은 판이 4분의 3 이었다. 내용만큼만 쓰고, 길면 440 에서
## 멈추고 굴린다. 라벨이 자리를 잡은 다음 프레임에 재야 값이 맞다.
func _fit_bag_panel() -> void:
	await get_tree().process_frame
	if _bag_panel == null or not _bag_panel.visible:
		return
	# 위 한계가 440 이라 항목이 일곱만 돼도 "길잡이 다시 보기" 가 접힌
	# 자리 아래로 밀렸다 — 막힌 사람이 찾아올 버튼인데 안 보였다.
	# 화면 높이를 따라가되 너무 커지진 않게 한다.
	var vp := get_viewport().get_visible_rect().size
	var content: float = _bag_grid.get_combined_minimum_size().y
	var need: float = clampf(content + 168.0, 236.0, minf(vp.y * 0.82, 580.0))
	_bag_panel.offset_top = -need * 0.5
	_bag_panel.offset_bottom = need * 0.5


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
		# 옛 편지(이 갱신 전 세이브)는 보낸 사람이 없다 — 그때는 늘 엄마였다.
		var who: String = String(m.get("who", "엄마"))
		_bag_grid.add_child(_bag_line("%s (%d일째)\n  %s" % [
			who, int(m.get("day", 1)), m.get("text", "")], 28, Color("#FFF2C8")))


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


## "이 마을에서" — 지금 있는 마을의 할 일 목록.
##
## 숫자(3/5)는 안 보여 준다 (`docs/quest-journey.md` 2절). 다 한 건
## **조용해지는 것**으로 안다 — 다녀온 여행지를 흐리게 보여 주는 것과
## 같은 결이다. 새로 만든 판정이 없다 — `Quests.quest_list()` 가 이미
## 있는 기록을 그대로 다시 읽어 올 뿐이다.
## 이 HUD 를 안고 있는 마을. 할 일이 지도 위 어디인지는 마을만 안다.
func _place() -> Node:
	var p := get_parent()
	return p if p != null and p.has_method("goal_world") else null


## 눌러서 지도에 접어 둘 수 있는 할 일 한 줄.
##
## 누르면 배낭을 닫는다 — 표시가 미니맵에 뜨는데 배낭이 덮고 있으면
## 아무 일도 안 일어난 것처럼 보인다. "여기로 가세요" 라고 시키지 않고
## **접어 뒀다**고만 말한다.
func _quest_row(text: String, col: Color, item: Dictionary, place: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(BAG_LINE_WIDTH, 0)
	b.add_theme_font_size_override("font_size", 28)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_color_override("font_%s_color" % st, col)
	b.add_theme_color_override("font_color", col)
	# 다 한 줄은 Label 이고 남은 줄은 Button 이라, 버튼 안여백만큼 글이
	# 밀려 두 줄이 안 맞았다. 여백을 0 으로 두고 나란히 세운다.
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func() -> void:
		place.set_goal(item)
		if _bag_panel != null and _bag_panel.visible:
			toggle_bag()
		_say_hint("지도에 살짝 접어 두었어요."))
	return b


func _fill_quests() -> void:
	_bag_grid.columns = 1
	var list := Quests.quest_list(JourneyState.here)
	if list.is_empty():
		_empty("여기서는 딱히 할 일이 없어요")
	var place := _place()
	var tappable := false
	for q in list:
		var done: bool = q.get("done", false)
		var label := String(q.get("label", ""))
		var text := label + ("  (다 했어요)" if done else "")
		var col := Color("#A79A8A") if done else Color("#FFF2C8")
		# **아직 안 한 것은 눌러서 지도에 접어 둘 수 있다.** 목록과 지도가
		# 서로 남이면 "무엇을" 은 알아도 "어디로" 를 모른다. 다 한 것은
		# 그냥 글자로 둔다 — 눌러 봐야 갈 데가 없다.
		if not done and place != null and place.goal_world(q) != Vector2.INF:
			tappable = true
			_bag_grid.add_child(_quest_row(text, col, q, place))
		else:
			_bag_grid.add_child(_bag_line(text, 28, col))
	# 눌러도 된다는 걸 아무도 모른다 — 줄이 그냥 글자로 보인다. 한 번만
	# 조용히 알려 준다. 시키는 말이 아니라 그렇게 할 수 있다는 말로.
	if tappable:
		_bag_grid.add_child(
			_bag_line("할 일을 톡 누르면 지도에 접어 둬요.", 22, Color("#A79A8A")))
	# **길잡이를 다시 볼 곳.** 처음 안내는 한 줄, 한 번만 뜨고 사라진다 —
	# 놓치면 못 본다는 게 친구들 피드백이었다. 여기, 막혔을 때 오는
	# 바로 그 탭에 다시 볼 수 있는 버튼을 둔다.
	var gb := Button.new()
	gb.text = "길잡이 다시 보기"
	gb.custom_minimum_size = Vector2(0, 64)
	gb.add_theme_font_size_override("font_size", 24)
	gb.pressed.connect(_open_guide_recap)
	_bag_grid.add_child(gb)


## "길잡이 다시 보기" 판. 처음 봤던 안내를 순서대로 다시 보여준다.
## 지금 막힌 사람에게는 **아직 안 한 것 중 가장 앞선 줄**이 먼저,
## 그 아래 전체 목록이 따라온다 — "지금 뭐부터?" 와 "전체 흐름" 을
## 한 화면에 같이 준다.
func _open_guide_recap() -> void:
	if _bag_panel != null:
		_bag_panel.visible = false
	AudioManager.page_turn()
	var layer := CanvasLayer.new()
	layer.layer = 11
	# **뒤로가기가 닫을 수 있어야 한다.** 화면을 통째로 덮는 것이 이 그룹에
	# 없으면 뒤로가기가 아무것도 못 닫고, 그 누름이 그대로 종료 카운터에
	# 쌓여 **두 번째 누름에 앱이 꺼진다** (`back_handler.gd` 가 경고하는 사고).
	layer.add_to_group("overlay")
	# 닫히는 길이 어디로 나든(닫기 버튼·바깥 누르기·뒤로가기) 배낭은
	# 되돌려 놓는다. 나가는 길목 하나에 모아 둬야 빠뜨리지 않는다.
	layer.tree_exiting.connect(func() -> void:
		if _bag_panel != null and is_instance_valid(_bag_panel):
			_bag_panel.visible = true)
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.09, 0.12, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# 바깥을 눌러도 닫힌다 — 펼친 미니맵·크레딧과 같은 결이다.
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if is_echo(e):
			return
		var tap: bool = (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventMouseButton and e.pressed)
		if tap:
			layer.queue_free())
	layer.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var vp := get_viewport().get_visible_rect().size
	var h: float = clampf(vp.y * 0.78, 400.0, 700.0)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5
	dim.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "길잡이"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#3A2C2C"))
	box.add_child(title)

	var step: int = SaveManager.get_flag(Guide.STEP_FLAG, Guide.STEPS.size())
	var finished: bool = SaveManager.get_flag(Guide.FLAG, false) or step >= Guide.STEPS.size()
	if not finished:
		var now := Label.new()
		# 줄표(—)를 쓰면 안 된다. PoorStory 에 없어서 폰에서 네모 상자가
		# 뜬다 (`CLAUDE.md` 폰트 규칙). 가운뎃점은 들어 있다.
		now.text = "지금은 · " + String(Guide.STEPS[step][1])
		now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		now.custom_minimum_size = Vector2(500, 0)
		now.add_theme_font_size_override("font_size", 26)
		now.add_theme_color_override("font_color", Color("#8C6E3F"))
		box.add_child(now)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in Guide.STEPS.size():
		var l := Label.new()
		l.text = String(Guide.STEPS[i][1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(500, 0)
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color",
			Color("#A79A8A") if i < step else Color("#4A3A22"))
		list.add_child(l)

	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 68)
	close.add_theme_font_size_override("font_size", 26)
	# 배낭 되돌리기는 위의 `tree_exiting` 이 맡는다 — 여기선 닫기만 한다.
	close.pressed.connect(layer.queue_free)
	box.add_child(close)


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


## 가운데 위에 한 줄 띄웠다 지운다. 주운 것·마친 일이 같은 자리를 쓴다.
##
## **줄을 세운다.** 마지막 것을 주우면 "조약돌 주웠어요" 와 "떨어진 것 다
## 줍기, 다 했어요" 가 같은 프레임에 겹쳐, 앞엣것이 뜨자마자 지워졌다.
## 하나씩 차례로 보여 준다.
var _hint_queue: Array[String] = []
var _hint_busy := false

func _say_hint(text: String) -> void:
	if _hint == null:
		return
	_hint_queue.append(text)
	if not _hint_busy:
		_drain_hints()


func _drain_hints() -> void:
	if _hint == null or not is_instance_valid(_hint):
		return
	if _hint_queue.is_empty():
		_hint_busy = false
		return
	_hint_busy = true
	_hint.text = _hint_queue.pop_front()
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_drain_hints)


func _on_picked(item: String, _total: int) -> void:
	_say_hint("%s 주웠어요" % _with_josa(String(NAMES.get(item, item))))
	if _bag_panel.visible:
		_refill_bag()


## 배낭이 어디 있는지 가리킬까. 길잡이가 부른다.
func point_at_bag(on: bool) -> void:
	if _bag_ring == null:
		return
	if on and (_buttons_hidden or bag_open()):
		on = false      # 배낭이 이미 열려 있거나 버튼이 치워졌으면 가릴 것이 없다
	_bag_ring.visible = on


# ── 하나 마쳤을 때 ────────────────────────────────────────────────────
#
# **팝업도 뻥튀기도 없다.** 지금까지는 다 하면 목록이 조용해질 뿐이라,
# 방금 그게 끝난 건지 몰랐다 — 특히 "가게 들어가 보기" 처럼 딴 일을
# 하다 저절로 끝나는 것들이 그랬다. 주운 것 알림과 **같은 자리, 같은
# 크기**로 한 줄만 띄웠다 지운다. 창을 안 띄우고, 진행도를 안 세고,
# 손을 멈추게 하지 않는다.
#
# 마을이 바뀌면 조용히 기준만 새로 잡는다 — 안 그러면 도착하자마자
# 이미 해 둔 것들이 우르르 다시 뜬다.
var _done_seen: Dictionary = {}
var _done_place := ""

## 항목을 가리키는 이름. 종류만으로는 인사 둘을 못 가른다
## (`Place._goal_id` 와 같은 규칙).
func _goal_id(item: Dictionary) -> String:
	return "%s:%s" % [item.get("kind", ""), item.get("key", "")]

func _watch_done(list: Array) -> void:
	if JourneyState.here != _done_place:
		_done_place = JourneyState.here
		_done_seen.clear()
		for q in list:
			if bool(q.get("done", false)):
				_done_seen[_goal_id(q)] = true
		return
	var left := 0
	var just: Array[String] = []
	for q in list:
		var id := _goal_id(q)
		if not bool(q.get("done", false)):
			left += 1
			_done_seen.erase(id)      # 되돌아간 것(새 날 등)도 다시 셀 수 있게
			continue
		if not _done_seen.has(id):
			_done_seen[id] = true
			just.append(String(q.get("label", "")))
	if just.is_empty():
		return
	for label in just:
		_say_hint("%s, 다 했어요" % label)
	# 마지막 하나였으면 한 줄 더. 다음 마을이 열렸다는 말은 안 한다 —
	# 여행판에서 알아채면 된다 (`docs/quest-journey.md` 6절).
	if left == 0:
		_say_hint("이 마을에서 해볼 일을 다 했어요.")
	AudioManager.ui_confirm()


func _process(delta: float) -> void:
	if _bag_ring != null and _bag_ring.visible:
		_ring_t += delta
		_bag_ring.queue_redraw()
	if _clock != null:
		_clock.text = "%s   %d일째" % [JourneyState.time_text(), JourneyState.day]
	var list := Quests.quest_list(JourneyState.here)
	_watch_done(list)
	if _dot != null:
		var left := false
		for q in list:
			if not bool(q.get("done", false)):
				left = true
				break
		var news := JourneyState.unread_letters() > 0 or left
		_dot.visible = news and not bag_open() and not _buttons_hidden
	# 카메라를 받기 전엔 셔터 버튼이 없다 (`docs/quest-journey.md` 3.5절).
	# 대화 중 버튼을 숨기는 `set_buttons_visible()` 와 겹쳐도, 여기서
	# 매 프레임 다시 확인하므로 카메라 없는 사람에게 다시 뜨는 일이 없다.
	var cam_ok := JourneyState.count("camera") > 0
	if _cam_btn != null:
		_cam_btn.visible = cam_ok and not _buttons_hidden
	if _pad_cam != null:
		_pad_cam.visible = cam_ok and not _buttons_hidden


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

## 손가락 하나가 **두 번**으로 오는 것을 걸러 낸다.
##
## 엔진이 터치를 마우스로도 흉내내 준다. 그래서 `_unhandled_input` 은
## 같은 탭을 `InputEventScreenTouch` 로 한 번, `InputEventMouseButton`
## 으로 또 한 번 받는다. 그대로 두면 미니맵이 켜졌다 바로 꺼지고,
## 대화는 **한 번 눌러 두 줄씩 넘어간다.** 흉내낸 쪽은 `device == -1` 이다.
static func is_echo(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.device == -1


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


## 지금 할 수 있는 일을 버튼에 적는다. 없으면 빈 문자열.
func set_action(kind: String, label: String) -> void:
	if _act_btn == null:
		return
	_act_kind = kind
	var want := label != ""
	if want:
		_act_btn.text = label
	if want == _act_shown:
		return
	# **툭 나타나고 툭 사라지지 않게.** 마을길을 한 번 걷는 8초 동안
	# 다섯 번 켜졌다 꺼지는데, 전환이 없으면 화면이 깜빡이는 것으로 보인다.
	_act_shown = want
	if _act_tw != null and _act_tw.is_valid():
		_act_tw.kill()
	if want:
		_act_btn.visible = true
		_act_btn.modulate.a = 0.0
	_act_tw = create_tween()
	_act_tw.tween_property(_act_btn, "modulate:a", 1.0 if want else 0.0, 0.16)
	if not want:
		_act_tw.tween_callback(func(): _act_btn.visible = false)


func action_kind() -> String:
	return _act_kind


## 대화 중에는 배낭·사진만 숨기고 **선택 버튼은 남긴다** — 대화를
## 넘기는 것도 이 버튼이 하는 일이다.
func _buttons_hidden_act() -> bool:
	return false


## 걷는 손가락과 상관없이 버튼을 눌러 준다.
##
## `TextureButton` 은 **터치에서 흉내낸 마우스**로만 눌리는데, 엔진은 그
## 흉내를 첫 번째 손가락 하나에만 건다. 그 손가락은 걷기가 쓰고 있으니
## 걸으면서 다른 손가락으로 셔터를 누르면 아무 일도 안 일어났다.
## 걷기 쪽(`journey_touch`)이 손가락을 집기 전에 여기로 먼저 물어본다.
func try_touch(pos: Vector2) -> bool:
	if _buttons_hidden and (_act_btn == null or not _act_btn.visible):
		return false
	if _bag_panel != null and _bag_panel.visible:
		return false                       # 배낭이 열려 있으면 창이 알아서 받는다
	for b in [_act_btn, _cam_btn, _bag_btn]:
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

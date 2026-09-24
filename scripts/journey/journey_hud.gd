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
## 도착 카드(마을 이름 + 해볼 일)가 지금 화면에 떠 있나. 카드가 완전히
## 사라진 뒤(꺼지는 트윈까지 끝난 뒤)에만 거짓이 된다 - 알파값을 매
## 프레임 재는 것보다 또렷하다.
var _arrival_card_up := false
## 도착하자마자 가운데 크게 뜨는 "지금 해볼 일" 한 줄.
## "해볼 일" 딱지 — `_arrive_task`(실제 문장)보다 옅은 색이라 구별된다.
var _arrive_task_tag: Label
var _arrive_task: Label
## 첫 마을 동안 화면 위에 늘 떠 있는 안내줄.
var _task_strip: Label
var _title_tw: Tween
var _bag_panel: PanelContainer
var _bag_grid: GridContainer
var _hint: Label
var _cam_btn: TextureButton
## 오른쪽 아래 공격·스킬 버튼과 체력·마음력 막대 (`FightPad`).
var fight: FightPad
var _bag_title: Label
var _tab := 0        # 0 배낭 · 1 사진첩 · 2 편지 · 3 행복첩 · 4 이 마을 · 5 마음
## 배낭에서 눌러 본 물건. 위에 설명 판이 뜬다.
var _bag_sel := ""
## 배낭 대신 도감을 보고 있나.
var _bag_dex := false
## 배낭(도감) 몇째 쪽을 보고 있나. 굴리지 않고 방향 버튼으로 넘긴다.
var _bag_page := 0
## 캐릭터 창의 칸 - 0 능력치 · 1 스킬 · 2 장비. 장비 칸에서 고른 한 벌.
var _char_tab := 0
var _gear_sel := -1
## 화면 왼쪽 위 메뉴 버튼 다섯(배낭·사진첩·편지·행복첩·이 마을)과
## 그 뒤에 깔리는 받침, 그리고 편지·할 일 위에 뜨는 알림 점.
##
## 한동안 배낭 하나에 점 하나만 붙여 "뭔가 새것이 있다" 까지만 알렸다.
## 신호 둘이 밖에 뜨면 흐려진다고 봤기 때문인데, 그건 **누를 것이 배낭
## 하나뿐일 때** 맞는 말이었다. 이제 눌러야 할 자리가 다섯이라, 점이
## 어느 버튼에 붙었는지가 곧 "어디를 눌러야 하는지" 다.
var _menu_btns: Array = []      # 칸 번호 순서 그대로 (0 배낭 … 4 이 마을)
var _menu_pads: Array = []
var _dot_letter: Control
var _dot_task: Control
## "이 마을" 버튼을 가리키는 고리. 길잡이가 그 줄을 띄우고 있는 동안만
## 켠다 — 글자로 "여기" 라고 쓰는 대신 **직접 그린다.**
var _hint_ring: Control
var _ring_t := 0.0
## 얻은 것을 그림과 함께 보여 주는 카드.
var _got: Control
var _got_art: TextureRect
var _got_text: Label
var _cele: Control
var _cele_rays: Node2D
var _cele_big: Label
var _cele_sub: Label
var _cele_queue: Array = []
var _cele_busy := false
var _got_queue: Array = []
var _got_busy := false
var _got_tw: Tween
var _flash: ColorRect
var _root: Control
var _pad_cam: Control
var _act_btn: Button
var _act_kind := ""
var _act_shown := false
var _act_tw: Tween
var _buttons_hidden := false
var _reward_t := 0.0

## 물건 이름·그림은 `Catalog` 한 곳에 있다. 여기 따로 두던 표(NAMES/
## ICONS)는 옮겼다 - 백 가지가 넘으면 두 곳을 맞춰 두다 한쪽이 빠진다.


func _ready() -> void:
	layer = 5
	add_to_group("journey_hud")
	_build()
	JourneyState.picked.connect(_on_picked)
	# 편지가 온 걸 알 길이 소리 하나뿐이었다 — 도착 연출과 겹치면
	# 그마저 묻힌다. 한 줄로 조용히 알린다. 배낭 점도 같이 켜진다.
	# 편지는 마을에 닿는 순간에 오므로 **덮개가 걷힐 때까지 기다린다**
	# (`_say_hint` 의 patient) - 안 그러면 도착 카드 밑에 깔린다.
	JourneyState.letter_came.connect(
		func(_t: String) -> void:
			_say_hint("편지가 왔어요. 배낭에 넣어 뒀어요.", true, 2.2))
	# 엽서도 마찬가지였다 - `postcard_came` 를 듣는 화면이 코드 전체에
	# 하나도 없었다. 효과음 하나뿐인데 그 순간은 대화창이 막 열려
	# 소리도 묻히기 쉽다. 대화 중에 오므로(도착 연출과 안 겹친다)
	# 편지처럼 기다릴 필요는 없다.
	JourneyState.postcard_came.connect(
		func(folk_id: String) -> void:
			var who := String(JourneyState.postcards.get(folk_id, {}).get("who", ""))
			_say_hint("%s에게서 엽서가 왔어요. 행복첩에 넣어 뒀어요."
				% (who if who != "" else "여행에서 만난 이")))
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

	# 마을 이름 바로 아래. 이름표와 같이 떴다 같이 사라진다.
	#
	# **"해볼 일" 딱지와 그 뒤 문장이 한 색이라 구별이 안 됐다.** 딱지가
	# 문장의 일부처럼 읽혀서 "해볼 일 · 나루 가게 아저씨와 인사하기"가
	# 전부 한 덩어리 문장처럼 보였다. 딱지는 옅은 색으로 한 줄 따로
	# 올리고, 진짜 문장만 도드라진 금색으로 그 아래 둔다.
	_arrive_task_tag = Label.new()
	_arrive_task_tag.add_theme_font_size_override("font_size", 22)
	_arrive_task_tag.add_theme_color_override("font_color", Color("#A79A8A"))
	_arrive_task_tag.add_theme_color_override("font_outline_color",
		Color(0.16, 0.13, 0.18))
	_arrive_task_tag.add_theme_constant_override("outline_size", 8)
	_arrive_task_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrive_task_tag.set_anchors_preset(Control.PRESET_CENTER)
	_arrive_task_tag.offset_left = -420
	_arrive_task_tag.offset_right = 420
	_arrive_task_tag.offset_top = 38
	_arrive_task_tag.offset_bottom = 64
	_arrive_task_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrive_task_tag.modulate.a = 0.0
	root.add_child(_arrive_task_tag)

	_arrive_task = Label.new()
	_arrive_task.add_theme_font_size_override("font_size", 32)
	_arrive_task.add_theme_color_override("font_color", Color("#FFE39A"))
	_arrive_task.add_theme_color_override("font_outline_color",
		Color(0.16, 0.13, 0.18))
	_arrive_task.add_theme_constant_override("outline_size", 10)
	_arrive_task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrive_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arrive_task.set_anchors_preset(Control.PRESET_CENTER)
	_arrive_task.offset_left = -420
	_arrive_task.offset_right = 420
	_arrive_task.offset_top = 66
	_arrive_task.offset_bottom = 166
	_arrive_task.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrive_task.modulate.a = 0.0
	root.add_child(_arrive_task)

	# **첫 마을 동안만 늘 떠 있는 줄.** 처음 잡은 사람은 뭘 하다가도
	# "그래서 지금 뭘 하라는 거지" 로 돌아온다. 첫 여행지를 떠나고 나면
	# 조용해진다 — 그때쯤이면 배낭을 열 줄 안다.
	_task_strip = Label.new()
	_task_strip.add_theme_font_size_override("font_size", 24)
	_task_strip.add_theme_color_override("font_color", Color("#FFE39A"))
	_task_strip.add_theme_color_override("font_outline_color",
		Color(0.16, 0.13, 0.18))
	_task_strip.add_theme_constant_override("outline_size", 8)
	_task_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_task_strip.offset_left = -360
	_task_strip.offset_right = 360
	_task_strip.offset_top = 22
	_task_strip.offset_bottom = 78
	_task_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_strip.visible = false
	root.add_child(_task_strip)

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
	# **넘치면 자른다.** 조용한 문의 라벨은 "갯바위로 내려가기" 처럼
	# 7~11자라, 자르지 않으면 버튼의 계산된 최소 폭이 148px 을 넘어
	# 앵커 오프셋을 무시하고 오른쪽 화면 밖으로 자라 마지막 글자가
	# 깨진 채 미니맵을 덮었다 (여행판의 잠긴 줄과 같은 원인).
	_act_btn.clip_text = true
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color("#FFE39A")
	asb.set_corner_radius_all(30)
	asb.set_border_width_all(3)
	asb.border_color = Color("#8C6E3F")
	Paper.lift(asb)
	_act_btn.add_theme_stylebox_override("normal", asb)
	_act_btn.add_theme_stylebox_override("hover", asb)
	var apr := asb.duplicate() as StyleBoxFlat
	apr.bg_color = Color("#FFD166")
	_act_btn.add_theme_stylebox_override("pressed", Paper.press(apr))
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

	# 공격·스킬 버튼. 선택 버튼(위)보다 먼저 깔아야 겹칠 때 선택 버튼이 위다.
	fight = FightPad.new()
	fight.visible = false
	root.add_child(fight)
	root.move_child(fight, _act_btn.get_index())

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

	# 아이콘 버튼 뒤에 받침을 깐다.
	#
	# 카메라 아이콘이 어두운 갈색이라 윤슬 왼쪽 아래의 쓰러진 나무·우물과
	# 겹치면 버튼인지 배경 소품인지 갈리지 않았다. 아이콘을 다시 그리는
	# 대신 뒤에 옅은 원판을 깐다 — 어떤 배경 위에서도 "누르는 것"으로 읽힌다.
	# **버튼과 같은 중심에 둔다.** 받침 원이 버튼보다 12px 바깥으로
	# 밀려 있어서, 아이콘이 원 안에서 한쪽으로 치우쳐 보였다 — 좌우
	# 두 버튼이 서로 반대쪽으로 쏠려 더 어긋나 보였다.
	# 버튼 중심은 좌우 다 화면 끝에서 80px, 위로 80px.
	# **작게 줄였다** (96 → 72). "왼쪽 버튼들이 맵을 가린다" 는 말을 들었다.
	_pad_cam = _make_pad(root, Control.PRESET_BOTTOM_LEFT, 20, -116, 116, -20)

	# 사진 — 왼쪽 아래. 배낭과 반대쪽이라 헷갈리지 않는다
	_cam_btn = TextureButton.new()
	_cam_btn.texture_normal = load("res://assets/sprites/i-camera.png")
	_cam_btn.ignore_texture_size = true
	_cam_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_cam_btn.custom_minimum_size = Vector2(72, 72)
	_cam_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cam_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_cam_btn.offset_left = 32
	_cam_btn.offset_top = -104
	_cam_btn.offset_right = 104
	_cam_btn.offset_bottom = -32
	_cam_btn.pressed.connect(func(): shutter.emit())
	_press_feedback(_cam_btn)
	root.add_child(_cam_btn)

	_build_menu(root)

	# ── 얻은 것 카드 ──
	#
	# 화면 가운데에 **그림과 함께** 잠깐 보여 준다. 위쪽 한 줄로만
	# 알리던 때는 지도·카메라 같은 중요한 것을 받고도 그냥 지나갔다 —
	# 무엇을 얻었는지 눈으로 봐야 손에 쥔 느낌이 난다.
	_got = Control.new()
	_got.set_anchors_preset(Control.PRESET_CENTER)
	_got.offset_left = -220
	_got.offset_right = 220
	_got.offset_top = -150
	_got.offset_bottom = 60
	_got.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_got.modulate.a = 0.0
	root.add_child(_got)

	_got_art = TextureRect.new()
	_got_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_got_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_got_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_got_art.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_got_art.offset_top = 0
	_got_art.offset_bottom = 140
	_got_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_got.add_child(_got_art)

	_got_text = Label.new()
	_got_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_got_text.add_theme_font_size_override("font_size", 34)
	_got_text.add_theme_color_override("font_color", Color("#FFF2C8"))
	_got_text.add_theme_color_override("font_outline_color",
		Color(0.16, 0.13, 0.18))
	_got_text.add_theme_constant_override("outline_size", 10)
	_got_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_got_text.offset_top = -56
	_got_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_got.add_child(_got_text)

	# 할 일 하나를 마쳤을 때 가운데서 터지는 축하. 잔치 소품(빛살)은
	# 폰트에 없는 글자 대신 직접 그린다.
	_cele = Control.new()
	_cele.set_anchors_preset(Control.PRESET_CENTER)
	_cele.offset_left = -280
	_cele.offset_right = 280
	_cele.offset_top = -120
	_cele.offset_bottom = 80
	_cele.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cele.modulate.a = 0.0
	root.add_child(_cele)

	_cele_rays = Node2D.new()
	_cele_rays.position = Vector2(280, 70)
	_cele_rays.set_meta("t", 0.0)
	_cele_rays.draw.connect(func() -> void:
		var t: float = _cele_rays.get_meta("t", 0.0)
		if t <= 0.0 or t >= 1.0:
			return
		var a := 1.0 - t
		_cele_rays.draw_arc(Vector2.ZERO, 26.0 + 96.0 * t, 0.0, TAU, 40,
			Color(1.0, 0.83, 0.35, a * 0.55), 3.0)
		for i in 10:
			var ang := TAU * float(i) / 10.0 + 0.3
			var at := Vector2.from_angle(ang) * (30.0 + 110.0 * t)
			_cele_rays.draw_circle(at, lerpf(4.5, 1.5, t),
				Color(1.0, 0.9, 0.55, a)))
	_cele.add_child(_cele_rays)

	_cele_big = Label.new()
	_cele_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cele_big.add_theme_font_size_override("font_size", 46)
	_cele_big.add_theme_color_override("font_color", Color("#FFE39A"))
	_cele_big.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_cele_big.add_theme_constant_override("outline_size", 12)
	_cele_big.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_cele_big.offset_top = 20
	_cele_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cele.add_child(_cele_big)

	_cele_sub = Label.new()
	_cele_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cele_sub.add_theme_font_size_override("font_size", 24)
	_cele_sub.add_theme_color_override("font_color", Color("#FFF2C8"))
	_cele_sub.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_cele_sub.add_theme_constant_override("outline_size", 8)
	_cele_sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cele_sub.offset_top = -66
	_cele_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cele_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cele.add_child(_cele_sub)

	# "이 마을" 버튼을 가리키는 고리. 그 버튼과 같은 자리에 겹쳐 두고
	# 테두리만 그린다. (예전엔 오른쪽 아래 배낭을 둘렀다 — 할 일이
	# 배낭 안에 있었으니까.)
	_hint_ring = Control.new()
	_hint_ring.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var ring_at := menu_rect(4).grow(8.0)
	_hint_ring.offset_left = ring_at.position.x
	_hint_ring.offset_top = ring_at.position.y
	_hint_ring.offset_right = ring_at.end.x
	_hint_ring.offset_bottom = ring_at.end.y
	_hint_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_ring.visible = false
	_hint_ring.draw.connect(func() -> void:
		var mid := _hint_ring.size * 0.5
		# 숨쉬듯 굵기와 크기가 오간다. 깜빡이면 급해 보인다.
		var p := 0.5 + 0.5 * sin(_ring_t * 3.0)
		var rad: float = minf(mid.x, mid.y) - 6.0 + p * 5.0
		_hint_ring.draw_arc(mid, rad, 0.0, TAU, 48,
			Color(1.0, 0.82, 0.40, 0.45 + p * 0.45), 4.0 + p * 2.0, true))
	root.add_child(_hint_ring)

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

	# **판 머리에는 지금 보고 있는 칸의 이름만 적는다.**
	#
	# 여태는 여기에 탭 다섯이 나란히 있었다. 배낭을 눌렀는데 사진첩·
	# 편지·행복첩·이 마을이 같이 딸려 나오니, 배낭을 연 것이 아니라
	# **메뉴를 연 것**처럼 보였다. 다섯은 이제 화면 왼쪽 위에 제 그림
	# 버튼으로 나와 있으므로 판이 다시 들고 있을 까닭이 없다.
	#
	# 대신 이름은 있어야 한다 — 버튼이 그림뿐이라, 누른 것이 무엇이었는지
	# 여기서 배운다.
	_bag_title = Label.new()
	_bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_title.add_theme_font_size_override("font_size", 30)
	_bag_title.add_theme_color_override("font_color", Color("#FFE39A"))
	box.add_child(_bag_title)

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


## 메뉴 버튼 오른쪽 위에 붙는 알림 점.
##
## 숫자도 느낌표도 안 쓴다. 점은 글자가 아니라 **직접 그린다** — 본문
## 폰트(PoorStory)에 ● 가 없어서 글자로 쓰면 폰에서 네모 상자가 뜬다.
## 도형은 폰트를 안 탄다.
##
## 예전엔 배낭에 점 하나만 붙여 "뭔가 새것이 있다" 까지만 알렸다.
## 그때는 편지든 할 일이든 배낭을 열어 탭을 뒤져야 무엇인지 알았다.
## 이제 점이 붙은 자리가 곧 눌러야 할 자리다.
func _make_menu_dot(root: Control, at: Rect2) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(22, 22)
	d.size = Vector2(22, 22)
	d.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# **제 버튼 안쪽 모서리에 붙인다.** 버튼 밖으로 내밀었더니 점이
	# 두 칸 사이에 떠서, 왼쪽 버튼 것인지 오른쪽 버튼 것인지 갈리지
	# 않았다 (두 칸씩 놓은 배치라 옆 칸이 바로 붙어 있다).
	d.offset_left = at.end.x - 20.0
	d.offset_top = at.position.y - 4.0
	d.offset_right = d.offset_left + 22.0
	d.offset_bottom = d.offset_top + 22.0
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.visible = false
	d.draw.connect(func() -> void:
		d.draw_circle(Vector2(11, 11), 11.0, Color(0.16, 0.13, 0.18))
		d.draw_circle(Vector2(11, 11), 8.5, Color("#FFD166")))
	root.add_child(d)
	return d


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


## ── 왼쪽 위 메뉴 다섯 ────────────────────────────────────────────────
##
## **다섯이 배낭 안에 숨어 있었다.** 배낭을 열어야 탭으로 갈아 끼우는
## 구조라, 편지가 왔다는 점을 보고도 어디를 눌러야 편지가 나오는지
## 몰랐다. 먼저 넷을 왼쪽 아래에 글자 버튼으로 세웠는데, 이번엔
## **배낭만 그림이고 나머지는 글자**라 한 줄로 안 읽혔다.
##
## 이제 다섯을 **다 그림으로, 왼쪽 위 한자리에** 모은다.
## 자리를 그렇게 잡은 이유:
## - 가로 한 줄(다섯 나란히)은 가운데 위에 뜨는 안내·알림(`_hint`,
##   길잡이 판)과 x 가 겹친다. 2칸씩 세 줄이면 x 는 210 에서 끝나고
##   그것들은 260 부터 시작해 안 부딪힌다.
## - 아래는 이미 차 있다 — 왼쪽 아래 사진, 오른쪽 아래 선택 버튼.
## - 세로 한 줄(다섯)은 480px 이라 화면 왼쪽을 통째로 덮는다.
##
## 차례는 판 안 차례 그대로다(배낭·사진첩·편지·행복첩·이 마을).
## 글자가 없으니 무엇이 무엇인지는 **열어 보면 판 머리에 이름이 적혀**
## 알게 된다.
const MENU := [
	["배낭", "i-pack"], ["사진첩", "i-album"], ["편지", "i-letter"],
	["행복첩", "i-heartbook"], ["이 마을", "i-list"], ["캐릭터", "i-mind"],
]
const MENU_AT := Vector2(24, 62)   # 시계(28,18)와 안 겹치게 그 아래부터
## **88 에서 64 로 줄였다.** 여섯이 두 칸씩 세 줄로 서면 화면 왼쪽
## 위가 통째로 가려져 "버튼 때문에 맵이 안 보인다" 는 말을 들었다.
## 폭 220 → 164, 높이 366 → 288. 손끝 기준(`Paper` 의 48dp)보다는 작지만
## 그림 버튼이라 받침 원까지 눌리는 자리로 친다 (아래 `_make_pad`).
const MENU_BTN := 64.0
## 받침 원이 버튼보다 사방 `MENU_PAD` 만큼 크다. 사이가 받침 둘을 합친
## 것보다 좁으면 옆 받침과 겹쳐서 여섯이 한 덩어리로 보인다 — 10/8 로
## 뒀다가 그랬다. 버튼을 줄이면서 받침도 같이 줄였다 (12 > 5+5).
const MENU_GAP := 12.0
const MENU_PAD := 5.0
const MENU_COLS := 2


## i 번째 버튼이 앉을 자리. 고리·점도 같은 셈을 써서 어긋나지 않는다.
func menu_rect(i: int) -> Rect2:
	var col := i % MENU_COLS
	var row := i / MENU_COLS
	return Rect2(
		MENU_AT + Vector2(float(col), float(row)) * (MENU_BTN + MENU_GAP),
		Vector2(MENU_BTN, MENU_BTN))


func _build_menu(root: Control) -> void:
	for i in MENU.size():
		var at := menu_rect(i)
		_menu_pads.append(_make_pad(root, Control.PRESET_TOP_LEFT,
			at.position.x - MENU_PAD, at.position.y - MENU_PAD,
			at.end.x + MENU_PAD, at.end.y + MENU_PAD))

		var b := TextureButton.new()
		b.name = "MenuBtn%d" % i
		b.texture_normal = load("res://assets/sprites/%s.png" % MENU[i][1])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = at.size
		b.size = at.size
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.offset_left = at.position.x
		b.offset_top = at.position.y
		b.offset_right = at.end.x
		b.offset_bottom = at.end.y
		b.pressed.connect(open_tab.bind(i))
		_press_feedback(b)
		root.add_child(b)
		_menu_btns.append(b)

		# 편지와 이 마을에는 알림 점이 붙는다 — 오른쪽 위 모서리.
		if i == 2:
			_dot_letter = _make_menu_dot(root, at)
		elif i == 4:
			_dot_task = _make_menu_dot(root, at)


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
		# **밝은 낮 배경 위에서 받침이 통째로 사라졌었다** (0.26/0.20).
		# 어두운 밤 화면만 보고 맞춘 값이라, 윤슬 아침의 모랫길 위에서는
		# 아이콘이 배경에 둥둥 뜬 그림이 됐다. 다섯이 나란히 선 지금은
		# 더 잘 보인다 — 테두리를 진하게, 안쪽 종이를 두껍게 한다.
		c.draw_circle(mid, rad, Color(0.16, 0.13, 0.18, 0.42))
		c.draw_circle(mid, rad - 3.0, Color(1.0, 0.99, 0.94, 0.56)))
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
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.custom_minimum_size = Vector2(BAG_LINE_WIDTH, 0)
	# 폭을 먼저 정해 두고 넣는다 - `Wrap` 이 그 폭으로 접는다.
	Wrap.put(l, text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 화면의 메뉴 버튼이 부르는 길. 판을 열고 그 칸을 편다.
##
## 이미 그 칸이 펴진 채 열려 있으면 닫는다 — 같은 버튼을 다시 누르면
## 닫히는 게 버튼 하나짜리 창의 상식이다.
func open_tab(i: int) -> void:
	if _bag_panel.visible and _tab == i:
		toggle_bag()
		return
	if not _bag_panel.visible:
		AudioManager.page_turn()
		_bag_panel.visible = true
		bag_toggled.emit(true)
	_pick_tab(i)


func toggle_bag() -> void:
	AudioManager.page_turn()
	_bag_panel.visible = not _bag_panel.visible
	if _bag_panel.visible:
		# **배낭은 배낭을 연다.** 여태는 할 일이 남아 있으면 "이 마을"
		# 칸부터 열었다 — 그 칸이 다섯째 탭에 묻혀 못 찾겠다는 지적을
		# 그렇게 막았었다. 이제 다섯이 다 화면에 제 버튼으로 나와 있으니
		# 숨길 것이 없고, 배낭을 눌렀는데 다른 칸이 열리는 쪽이 오히려
		# 어리둥절하다.
		_tab = 0
		_bag_sel = ""
		_bag_dex = false
		_bag_page = 0
		_gear_sel = -1
		_refill_bag()
	bag_toggled.emit(_bag_panel.visible)


func _pick_tab(i: int) -> void:
	_tab = i
	_bag_sel = ""
	_bag_dex = false
	_bag_page = 0
	_gear_sel = -1
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
	# **이름만 띄우고 끝내지 않는다.** 도착하자마자 화면 가운데에 크게
	# "지금 해볼 일" 하나를 같이 보여 준다 — 배낭을 열어 봐야 아는 것과
	# 도착하는 순간 눈에 들어오는 것은 다르다. 하나만 적는다. 목록을
	# 통째로 늘어놓으면 숙제장이 된다.
	if _arrive_task != null:
		var goal := _first_task()
		# 한글은 음절 사이가 다 줄바꿈 자리라 라벨에 맡기면 낱말이
		# 갈린다 (`Wrap` 주석). 띄어쓰기에서만 끊는다.
		#
		# **딱지("해볼 일")와 문장을 따로 둔다.** 한 줄에 이어 붙이면
		# 색을 나눠도 딱지만 옅어질 뿐 여전히 한 문장으로 읽힌다 -
		# 아예 줄을 갈라야 "이건 안내, 이건 내용"이 눈에 들어온다.
		if _arrive_task_tag != null:
			_arrive_task_tag.text = "해볼 일" if goal != "" else ""
			_arrive_task_tag.visible = goal != ""
		Wrap.put(_arrive_task, goal)
		_arrive_task.visible = goal != ""
	_place_title.text = text
	if _title_tw != null and _title_tw.is_valid():
		_title_tw.kill()
	_place_title.modulate.a = 0.0
	# 할 일을 읽을 시간이 있어야 하니 이름만 띄울 때보다 조금 더 머문다.
	_arrive_task.modulate.a = 0.0
	if _arrive_task_tag != null:
		_arrive_task_tag.modulate.a = 0.0
	_arrival_card_up = true
	_title_tw = create_tween().set_parallel(true)
	_title_tw.tween_property(_place_title, "modulate:a", 1.0, 0.5)
	_title_tw.tween_property(_arrive_task, "modulate:a", 1.0, 0.5)
	if _arrive_task_tag != null:
		_title_tw.tween_property(_arrive_task_tag, "modulate:a", 1.0, 0.5)
	_title_tw.chain().tween_interval(2.4)
	_title_tw.chain().tween_property(_place_title, "modulate:a", 0.0, 0.7)
	_title_tw.tween_property(_arrive_task, "modulate:a", 0.0, 0.7)
	if _arrive_task_tag != null:
		_title_tw.tween_property(_arrive_task_tag, "modulate:a", 0.0, 0.7)
	_title_tw.chain().tween_callback(func(): _arrival_card_up = false)


## 사진을 찍었다. 화면이 한 번 하얘진다.
func flash() -> void:
	_flash.color = Color(1, 1, 1, 0.85)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)


## 스킬을 쓰면 화면이 그 빛깔로 한 번 물든다 (`Place.field_use`).
func tint_flash(c: Color, a: float, secs := 0.3) -> void:
	if _flash == null:
		return
	_flash.color = Color(c.r, c.g, c.b, a)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, secs)


func bag_open() -> bool:
	return _bag_panel != null and _bag_panel.visible


func _refill_bag() -> void:
	for c in _bag_grid.get_children():
		c.queue_free()
	_bag_title.text = String(MENU[_tab][0]) if _tab < MENU.size() else ""
	# 배낭만 옆으로 넓다 (`BAG_WIDE` 주석). 채우기 전에 폭부터 정한다.
	var half := (BAG_WIDE if _tab in [0, 5] else BAG_NARROW) * 0.5
	_bag_panel.offset_left = -half
	_bag_panel.offset_right = half

	match _tab:
		1: _fill_photos()
		2: _fill_letters()
		3: _fill_postcards()
		4: _fill_quests()
		5: _fill_mind()
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
	# 위 한계가 440 이라 항목이 일곱만 돼도 "조작 안내 다시 보기" 가 접힌
	# 자리 아래로 밀렸다 — 막힌 사람이 찾아올 버튼인데 안 보였다.
	# 화면 높이를 따라가되 너무 커지진 않게 한다.
	var vp := get_viewport().get_visible_rect().size
	var content: float = _bag_grid.get_combined_minimum_size().y
	# 머리에 있던 탭 줄(60px)이 빠지고 이름 한 줄만 남았다. 그만큼
	# 덜 잡는다 — 안 줄이면 물건 둘짜리 배낭이 또 반쯤 빈 판이 된다.
	# 배낭은 **굴리지 않고 쪽을 넘기므로** 한 쪽이 통째로 들어갈 만큼
	# 더 잡는다 - 설명 판 + 칸 세 줄 + 쪽 넘기기 줄.
	var cap := 760.0 if _tab in [0, 5] else 580.0
	var need: float = clampf(content + 110.0, 190.0, minf(vp.y * 0.82, cap))
	_bag_panel.offset_top = -need * 0.5
	_bag_panel.offset_bottom = need * 0.5
	# 110 은 어림이다 - 제목 줄 높이가 폰트마다 몇 px 씩 달라 한 쪽이
	# 4px 모자라 굴림막대가 떴다. 자리를 잡은 뒤 모자란 만큼만 더 편다.
	await get_tree().process_frame
	if _bag_panel == null or not _bag_panel.visible:
		return
	var scroll := _bag_grid.get_parent() as Control
	var short: float = _bag_grid.get_combined_minimum_size().y - scroll.size.y
	if short > 0.0:
		var h: float = minf(_bag_panel.size.y + short, minf(vp.y * 0.82, cap))
		_bag_panel.offset_top = -h * 0.5
		_bag_panel.offset_bottom = h * 0.5


func _empty(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color("#A79A8A"))
	_bag_grid.add_child(l)


## 배낭 — 가진 것. **칸을 누르면 무엇인지 위에 뜬다.**
##
## 여태 칸은 그림과 개수뿐이라 눌러도 아무 일이 없었다. 백 가지 가까이
## 되면 이름만으로는 무엇에 쓰는지 모른다 - 설명 판에 어디서 난 것인지,
## 먹으면 무엇이 되는지, 지니면 어떤 힘이 붙는지를 적는다. 먹을 것이면
## 그 자리에서 **먹을 수 있다** (전투 밖에서도).
##
## 차례는 쓸모 순이다 - 먹을 것, 기념품, 도장, 조각, 도구, 주운 것.
##
## **굴리지 않고 쪽을 넘긴다.** 칸이 150x128 에 넷씩이라 물건이 스무 개만
## 넘어도 판 아래로 밀려 손가락으로 굴려야 했다 - 폰에서는 칸을 누르려다
## 굴러가고, 굴리려다 칸이 눌렸다. 칸을 줄여 한 쪽(`bag_page_size`)을 다
## 보이게 하고, 나머지는 아래 방향 버튼으로 넘긴다.
##
## 폰을 눕혀 쓰므로 **높이가 모자라고 너비는 남는다.** 그래서 배낭 칸일
## 때만 판을 옆으로 넓혀(`BAG_WIDE`) 한 줄에 여덟 칸을 두고, 줄 수는 화면
## 높이에서 설명 판·쪽 넘기기 줄을 빼고 남는 만큼만(`_bag_rows`) 둔다.
## 설명 판 자리는 **늘 같은 높이로 비워 둔다** - 칸을 누를 때마다 줄 수가
## 바뀌면 같은 쪽에 있던 물건이 딴 쪽으로 가 버린다.
const BAG_COLS := 8
const BAG_CELL := Vector2(100, 100)
const BAG_GAP := 8
const BAG_CARD_H := 128.0
const BAG_WIDE := 920.0
const BAG_NARROW := 720.0


## 한 쪽에 몇 줄. 판 최대 높이 - 제목·여백(98) - 설명 판 - 쪽 넘기기 줄(64)
## - 사이 간격 셋(14씩).
func _bag_rows() -> int:
	var vp := get_viewport().get_visible_rect().size
	var room: float = minf(vp.y * 0.82, 760.0) - 98.0 - BAG_CARD_H - 64.0 - 42.0
	return clampi(int((room + BAG_GAP) / (BAG_CELL.y + BAG_GAP)), 2, 4)


func bag_page_size() -> int:
	return BAG_COLS * _bag_rows()


func _fill_bag() -> void:
	_bag_grid.columns = 1
	if _bag_dex:
		_fill_dex()
		return
	if JourneyState.bag.is_empty():
		_empty("아직 아무것도 없어요")
		return
	elif _bag_sel != "" and JourneyState.count(_bag_sel) > 0:
		_bag_grid.add_child(_item_card(_bag_sel, true))
	else:
		_bag_grid.add_child(_card_box(_bag_line("칸을 누르면 무엇인지 볼 수 있어요.",
			22, Color("#A79A8A"))))
	var items := _bag_sorted()
	var per := bag_page_size()
	var pages := maxi(1, ceili(float(items.size()) / per))
	_bag_page = clampi(_bag_page, 0, pages - 1)
	var cells := GridContainer.new()
	cells.name = "BagCells"
	cells.columns = BAG_COLS
	cells.add_theme_constant_override("h_separation", BAG_GAP)
	cells.add_theme_constant_override("v_separation", BAG_GAP)
	var from := _bag_page * per
	for i in range(from, mini(from + per, items.size())):
		cells.add_child(_bag_cell(String(items[i])))
	_bag_grid.add_child(cells)
	_bag_grid.add_child(_pager(pages, _paper_btn("도감 보기", func() -> void:
		AudioManager.page_turn()
		_bag_dex = true
		_bag_sel = ""
		_bag_page = 0
		_refill_bag())))


## 쪽 넘기기 줄: [왼쪽] 1 / 3 [오른쪽] ...... [덧붙일 버튼].
##
## 화살표는 **글자가 아니라 그린다** - 본문 폰트에 ◀ ▶ 가 없어 폰에서
## 네모 상자가 뜬다 (알림 점과 같은 까닭).
func _pager(pages: int, extra: Control = null) -> Control:
	var row := HBoxContainer.new()
	row.name = "Pager"
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(BAG_LINE_WIDTH, 0)
	var prev := _arrow_btn(-1, _bag_page > 0)
	prev.name = "PagePrev"
	row.add_child(prev)
	var at := Label.new()
	at.name = "PageAt"
	at.text = "%d / %d" % [_bag_page + 1, pages]
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	at.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	at.custom_minimum_size = Vector2(96, 0)
	at.add_theme_font_size_override("font_size", 26)
	at.add_theme_color_override("font_color", Color("#E4DCCF"))
	row.add_child(at)
	var next := _arrow_btn(1, _bag_page < pages - 1)
	next.name = "PageNext"
	row.add_child(next)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	if extra != null:
		extra.custom_minimum_size = Vector2(180, 64)
		row.add_child(extra)
	return row


## 방향 버튼 하나. `dir` -1 은 앞 쪽, 1 은 뒤 쪽. 갈 데가 없으면 흐리다.
func _arrow_btn(dir: int, can: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 64)
	Paper.button(b, Color("#F4EDE2"), Color("#8C7B68"), Color("#3A2C2C"))
	b.disabled = not can
	b.modulate.a = 1.0 if can else 0.35
	var tri := Control.new()
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tri.set_anchors_preset(Control.PRESET_FULL_RECT)
	tri.draw.connect(func() -> void:
		var c := tri.size * 0.5
		var w := 14.0 * dir
		tri.draw_colored_polygon(PackedVector2Array([
			c + Vector2(w, 0), c + Vector2(-w, -16), c + Vector2(-w, 16)]),
			Color("#3A2C2C")))
	b.add_child(tri)
	b.pressed.connect(func() -> void:
		AudioManager.page_turn()
		_bag_page += dir
		_bag_sel = ""
		_refill_bag())
	return b


## 배낭 속 물건을 쓸모 순으로.
func _bag_sorted() -> Array:
	var out: Array = JourneyState.bag.keys()
	var order := ["snack", "keep", "stamp", "shade", "tool", "pick", "food"]
	out.sort_custom(func(a, b) -> bool:
		var ka := order.find(Catalog.kind_of(String(a)))
		var kb := order.find(Catalog.kind_of(String(b)))
		if ka != kb:
			return (ka if ka >= 0 else 99) < (kb if kb >= 0 else 99)
		return String(a) < String(b))
	return out


## 배낭 한 칸 - 그림과 이름·개수. 누르면 위 설명 판이 그 물건으로 바뀐다.
func _bag_cell(item: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = BAG_CELL
	var sel := item == _bag_sel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.14 if sel else 0.05)
	sb.set_corner_radius_all(10)
	sb.border_color = Color("#FFE39A")
	sb.set_border_width_all(2 if sel else 0)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(cell)
	var pic := TextureRect.new()
	# **그림 이름은 `Catalog` 를 거친다.** 주운 것(`p-*`)은 제 이름이 곧
	# 그림 이름이지만 받는 물건은 아니다 — 지도는 `i-notebook` 을 빌려
	# 쓴다. 표를 안 보고 `map.png` 를 찾다 못 찾아 **지도·카메라 칸이
	# 빈 채로** 뜬 적이 있다.
	pic.texture = load(Catalog.icon_path(item))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(52, 52)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(pic)
	var name := Label.new()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", Color("#E4DCCF"))
	name.custom_minimum_size = Vector2(BAG_CELL.x - 6, 0)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Wrap.put(name, Catalog.name_of(item))
	cell.add_child(name)
	# 개수는 그림 오른쪽 아래에 따로 - 이름과 이어 붙이면 두 줄로 접혀
	# 칸이 들쭉날쭉해진다.
	var n := JourneyState.count(item)
	if n > 1:
		var cnt := Label.new()
		cnt.text = "%d" % n
		cnt.add_theme_font_size_override("font_size", 18)
		cnt.add_theme_color_override("font_color", Color("#FFE39A"))
		cnt.add_theme_color_override("font_outline_color", Color("#1A1418"))
		cnt.add_theme_constant_override("outline_size", 5)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cnt.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cnt.offset_left = -34
		cnt.offset_right = -6
		cnt.offset_top = 2
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(cnt)
	b.pressed.connect(func() -> void:
		AudioManager.ui_click()
		_bag_sel = "" if _bag_sel == item else item
		_refill_bag())
	return b


## 물건 설명 판. 배낭(`can_use`)에서는 먹을 것에 [먹기] 가 붙고, 도감에서는
## 설명만 보여 준다.
## 설명 판의 틀. 배낭에서는 늘 같은 높이(`BAG_CARD_H`)라 칸이 들썩이지 않는다.
func _card_box(inner: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(BAG_LINE_WIDTH, BAG_CARD_H)
	if inner != null:
		if inner is Label:
			(inner as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(inner)
	return panel


func _item_card(item: String, can_use: bool) -> Control:
	var panel := _card_box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var pic := TextureRect.new()
	pic.texture = load(Catalog.icon_path(item))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(88, 88)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var w := BAG_LINE_WIDTH - 88.0 - 14.0 - 28.0
	if can_use and Catalog.edible(item):
		w -= 164.0
	# 넓은 배낭 판에서는 글줄도 그만큼 넓게 - 좁게 접으면 판 높이를 넘는다.
	if _tab in [0, 5]:
		w += BAG_WIDE - BAG_NARROW
	var kind := Catalog.kind_of(item)
	var at := String(Catalog.of(item).get("at", ""))
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Color("#FFE39A"))
	head.text = Catalog.name_of(item)
	col.add_child(head)
	var sub := String(Catalog.KIND_NAME.get(kind, ""))
	if at != "":
		sub += "  ·  %s에서" % at
	var l1 := Label.new()
	l1.add_theme_font_size_override("font_size", 18)
	l1.add_theme_color_override("font_color", Color("#A79A8A"))
	l1.text = sub
	col.add_child(l1)
	var l2 := Label.new()
	l2.add_theme_font_size_override("font_size", 20)
	l2.add_theme_color_override("font_color", Color("#E4DCCF"))
	l2.custom_minimum_size = Vector2(w, 0)
	Wrap.put(l2, String(Catalog.of(item).get("desc", "")))
	col.add_child(l2)
	var eff := Catalog.effect_text(item)
	if eff != "":
		var l3 := Label.new()
		l3.add_theme_font_size_override("font_size", 20)
		l3.add_theme_color_override("font_color", Color("#B4E6C0"))
		l3.custom_minimum_size = Vector2(w, 0)
		var pre := "지니고 있으면 · " if kind in ["keep", "stamp", "shade"] else "먹으면 · "
		Wrap.put(l3, pre + eff)
		col.add_child(l3)
	# [먹기] 는 글 밑이 아니라 **오른쪽에** - 밑에 달면 판이 64px 커져
	# 아래 칸들이 한 줄 밀린다.
	if can_use and Catalog.edible(item):
		var eat := _paper_btn("먹기", func() -> void: _eat(item))
		eat.custom_minimum_size = Vector2(150, 64)
		eat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(eat)
	return panel


## 배낭에서 먹는다. 다 차 있으면 안 먹는다 - 먹어 봤자 없어지기만 한다.
func _eat(item: String) -> void:
	var said := Battle.eat(item)
	if said == "":
		_say_hint("지금은 배가 불러요.", false, 1.6)
		return
	AudioManager.battle_heal()
	_say_hint(said, false, 2.0)
	if JourneyState.count(item) <= 0:
		_bag_sel = ""
	_refill_bag()


## 도감 — 이 게임의 물건 전부. 얻은 적 있는 것은 그림, 아직인 것은 어두운 칸.
##
## "12가지 중 5" 를 적는다. 퀘스트 진행률을 숫자로 안 보여 주는 원칙
## (`docs/quest-journey.md` 2절)은 **해야 할 일 목록**에 대한 것이다 - 도감은
## 할 일이 아니라 모은 것의 기록이다 (`docs/items-rewards.md` 4절).
func _fill_dex() -> void:
	if _bag_sel != "":
		if Catalog.found(_bag_sel):
			_bag_grid.add_child(_item_card(_bag_sel, false))
		else:
			_bag_grid.add_child(_bag_line("아직 못 만난 것이에요. 여행을 하다 보면 만나요.",
				20, Color("#A79A8A")))
	# 한 쪽에 한 종류. 일곱 종류를 한 판에 늘어놓으니 굴려야만 끝이 보였다.
	var pages: int = Catalog.KIND_ORDER.size()
	_bag_page = clampi(_bag_page, 0, pages - 1)
	var kind: String = Catalog.KIND_ORDER[_bag_page]
	var ids := Catalog.ids_of(kind)
	var got := 0
	for id in ids:
		if Catalog.found(String(id)):
			got += 1
	_bag_grid.add_child(_bag_line("%s  ·  %d가지 중 %d" % [
		String(Catalog.KIND_NAME[kind]), ids.size(), got], 24, Color("#FFE39A")))
	var cells := GridContainer.new()
	cells.columns = 8
	cells.add_theme_constant_override("h_separation", 8)
	cells.add_theme_constant_override("v_separation", 8)
	for id in ids:
		cells.add_child(_dex_cell(String(id)))
	_bag_grid.add_child(cells)
	_bag_grid.add_child(_pager(pages, _paper_btn("배낭 보기", func() -> void:
		AudioManager.page_turn()
		_bag_dex = false
		_bag_sel = ""
		_bag_page = 0
		_refill_bag())))


func _dex_cell(id: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(68, 68)
	var sel := id == _bag_sel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06)
	sb.set_corner_radius_all(10)
	sb.border_color = Color("#FFE39A")
	sb.set_border_width_all(2 if sel else 0)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var pic := TextureRect.new()
	pic.texture = load(Catalog.icon_path(id))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 6
	pic.offset_top = 6
	pic.offset_right = -6
	pic.offset_bottom = -6
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 아직 못 만난 것은 **그림자만** - 무엇인지 모르게, 있다는 것만 알게.
	if not Catalog.found(id):
		pic.modulate = Color(0, 0, 0, 0.45)
	b.add_child(pic)
	b.pressed.connect(func() -> void:
		AudioManager.ui_click()
		_bag_sel = "" if _bag_sel == id else id
		_refill_bag())
	return b


## 판 안의 종이 버튼 (조작 안내 다시 보기와 같은 결).
func _paper_btn(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	Paper.button(b, Color("#F4EDE2"), Color("#8C7B68"), Color("#3A2C2C"))
	b.pressed.connect(fn)
	return b


## 마음 — 지금 어디까지 왔나, 무엇을 쓸 수 있나.
##
## **전투 밖에서 볼 자리가 있어야 한다.** 레벨과 배운 것이 전투 화면
## 안에만 있으면, 다음에 무엇이 풀리는지 모른 채 그냥 싸우게 된다.
## 잠긴 것도 흐리게 같이 적는 이유다 — 있다는 걸 알아야 기다린다.
func _fill_mind() -> void:
	_bag_grid.columns = 1
	var need := Battle.xp_need()
	var tail := "경험 %d / %d" % [Battle.xp, need] if Battle.level < Battle.LEVEL_MAX \
		else "끝까지 왔다"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for i in 3:
		var names := ["능력치", "스킬", "장비"]
		var label := String(names[i])
		if i == 0 and Battle.ap > 0:
			label += " (%d)" % Battle.ap
		elif i == 1 and Battle.sp > 0:
			label += " (%d)" % Battle.sp
		var tb := _paper_btn(label, func() -> void:
			AudioManager.page_turn()
			_char_tab = i
			_gear_sel = -1
			_bag_page = 0
			_refill_bag())
		tb.custom_minimum_size = Vector2(150, 52)
		if i == _char_tab:
			tb.modulate = Color(1.15, 1.1, 0.8)
		else:
			tb.modulate = Color(0.75, 0.75, 0.75)
		tabs.add_child(tb)
	# LV·직업·경험은 칸 줄 오른쪽에 - 따로 한 줄을 쓰면 장비 칸이 판을 넘친다.
	var head := Label.new()
	head.text = "LV %d  %s   %s" % [Battle.level, Battle.job_name(), tail]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color("#FFE39A"))
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(head)
	_bag_grid.add_child(tabs)
	match _char_tab:
		1: _fill_skills()
		2: _fill_gear()
		_: _fill_stats()


## 능력치 - 체력·공격력…, 힘·민첩·지능·행운 나누기, 전직.
func _fill_stats() -> void:
	# **전직.** LV 10 이 되면 여기서 넷 중 하나를 고른다.
	if Battle.job == "novice":
		if Battle.level >= Battle.JOB_LV:
			_bag_grid.add_child(_bag_line("전직할 수 있어요! 직업을 골라요.", 26,
				Color("#FFD43B")))
			var row := GridContainer.new()
			row.columns = 2
			row.add_theme_constant_override("h_separation", 10)
			row.add_theme_constant_override("v_separation", 10)
			for j in Battle.JOB_ORDER:
				var jd: Dictionary = Battle.JOBS[j]
				var jb := _paper_btn("%s  -  %s" % [String(jd["name"]),
					String(Gear.WEAPONS[String(jd["weapon"])])], func() -> void:
						if Battle.set_job(String(j)):
							AudioManager.ui_confirm()
							_celebrate("%s이(가) 되었어요!" % Battle.job_name(),
								"%s을(를) 받았어요" % Gear.name_of(Gear.worn("weapon")))
							SaveManager.save_now()
							_refill_bag())
				jb.custom_minimum_size = Vector2(420, 60)
				jb.name = "Job_" + String(j)
				jb.tooltip_text = String(jd["desc"])
				row.add_child(jb)
			_bag_grid.add_child(row)
			for j in Battle.JOB_ORDER:
				_bag_grid.add_child(_bag_line("%s - %s" % [String(Battle.JOBS[j]["name"]),
					String(Battle.JOBS[j]["desc"])], 18, Color("#C9BFB2")))
		else:
			_bag_grid.add_child(_bag_line("LV %d 에 전직해요 - 전사 · 마법사 · 궁수 · 도적"
				% Battle.JOB_LV, 20, Color("#A79A8A")))
	_bag_grid.add_child(_bag_line("체력 %d / %d   ·   마음력 %d / %d"
		% [Battle.hp, Battle.hp_max(), Battle.mp, Battle.mp_max()], 22, Color("#B4E6C0")))
	_bag_grid.add_child(_bag_line("공격력 %d   ·   방어력 %d   ·   치명타 %d 퍼센트 (x%.1f)"
		% [Battle.attack_power(), Battle.defense(), int(Battle.crit_rate() * 100.0),
			Battle.crit_mult()], 22, Color("#E4DCCF")))
	_bag_grid.add_child(_bag_line("남은 능력치 점수 %d" % Battle.ap, 22,
		Color("#FFE39A") if Battle.ap > 0 else Color("#A79A8A")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	var what := {"str": "근접 공격 · 체력", "dex": "원거리 · 치명타",
		"int": "마법 · 마음력", "luk": "치명타 피해 · 드랍"}
	var main := String(Battle.JOBS[Battle.job]["main"])
	for st in Battle.STAT_ORDER:
		var l := _bag_line("%s %d  (%s)%s" % [String(Battle.STAT_NAME[st]), Battle.stat(st),
			String(what[st]), "  - 주 능력치" if st == main else ""], 22,
			Color("#FFFDF6") if st == main else Color("#E4DCCF"))
		l.custom_minimum_size = Vector2(560, 0)
		grid.add_child(l)
		var plus := _paper_btn("+1", func() -> void:
			if Battle.spend_ap(String(st)):
				AudioManager.ui_click()
				_refill_bag())
		plus.custom_minimum_size = Vector2(90, 48)
		plus.disabled = Battle.ap <= 0
		plus.name = "Plus_" + String(st)
		grid.add_child(plus)
	_bag_grid.add_child(grid)
	var auto := _paper_btn("자동 배분 %s" % ("켜짐" if Battle.auto_ap else "꺼짐"), func() -> void:
		Battle.auto_ap = not Battle.auto_ap
		if Battle.auto_ap:
			Battle.auto_spend_ap()
		AudioManager.ui_click()
		_refill_bag())
	auto.name = "AutoAP"
	_bag_grid.add_child(auto)
	# 칭호·연타 기록 - 모은 것이 보여야 더 모은다.
	if not Loop.titles.is_empty() or Loop.best_combo > 0:
		_bag_grid.add_child(_bag_line("칭호 %d개%s   ·   가장 긴 연타 %d" % [Loop.titles.size(),
			("  (%s)" % Loop.title) if Loop.title != "" else "", Loop.best_combo], 19,
			Color("#FFD43B")))
	# 지닌 기념품·도장이 보태는 힘도 여기서 보인다.
	var parts: Array = []
	for st2 in ["hp", "mp", "atk", "def"]:
		var n := Catalog.bonus(st2)
		if n > 0:
			parts.append("%s +%d" % [String(Catalog.STAT_NAME[st2]), n])
	if not parts.is_empty():
		_bag_grid.add_child(_bag_line("지닌 것 덕분에 · " + " · ".join(parts),
			19, Color("#B4E6C0")))


## 스킬 - 배운 것과 배울 것, 스킬 점수로 레벨 올리기.
func _fill_skills() -> void:
	_bag_grid.add_child(_bag_line("남은 스킬 점수 %d   ·   스킬 레벨 한 칸마다 10퍼센트 세진다"
		% Battle.sp, 21, Color("#FFE39A") if Battle.sp > 0 else Color("#A79A8A")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for id in Battle.job_skills():
		var sk: Dictionary = Battle.SKILLS[id]
		var slv := int(Battle.skill_lv.get(id, 0))
		var bits: Array = []
		if String(sk["type"]) == "attack":
			bits.append("%s 속성" % Battle.elem_name(Battle.skill_elem(id)))
			bits.append("x%.1f" % (float(sk["mult"]) * Battle.skill_power(id)))
			if int(sk.get("hits", 1)) > 1:
				bits.append("%d번" % int(sk["hits"]))
			if sk.has("aoe"):
				bits.append("범위")
			if sk.has("range"):
				bits.append("원거리")
		elif String(sk["type"]) == "heal":
			bits.append("회복")
		else:
			bits.append("버프")
		for key in ["foe", "grants"]:
			if sk.has(key):
				var tbl: Dictionary = Battle.ENEMY_STATUSES if key == "foe" else Battle.STATUSES
				bits.append(String(tbl[String(sk[key])]["name"]))
		bits.append("마음 %d" % int(sk["mp"]))
		var head := "%s  Lv %d" % [String(sk["name"]), slv] if slv > 0 \
			else "%s  (LV %d 에 배움)" % [String(sk["name"]), int(sk["lv"])]
		var l := _bag_line("%s   %s" % [head, " · ".join(bits)], 20,
			Battle.elem_col(Battle.skill_elem(id)).lightened(0.3) if slv > 0 else Color("#7E7468"))
		l.custom_minimum_size = Vector2(740, 0)
		grid.add_child(l)
		var plus := _paper_btn("+1", func() -> void:
			if Battle.spend_sp(String(id)):
				AudioManager.ui_click()
				_refill_bag())
		plus.custom_minimum_size = Vector2(80, 44)
		plus.disabled = Battle.sp <= 0 or slv <= 0 or slv >= Battle.SKILL_MAX
		grid.add_child(plus)
	_bag_grid.add_child(grid)
	var auto := _paper_btn("자동 배분 %s" % ("켜짐" if Battle.auto_sp else "꺼짐"), func() -> void:
		Battle.auto_sp = not Battle.auto_sp
		if Battle.auto_sp:
			Battle.auto_spend_sp()
		AudioManager.ui_click()
		_refill_bag())
	_bag_grid.add_child(auto)


const GEAR_PAGE := 4


## 장비 - 입은 여섯 칸, 가진 것 목록(쪽 넘기기), 고른 한 벌의 설명·입기·강화·팔기.
func _fill_gear() -> void:
	_bag_grid.add_child(_bag_line("꿈조각 %d   ·   강화석 %d" % [Gear.coins, Gear.stones],
		22, Color("#FFE39A")))
	var sel := Gear.get_item(_gear_sel)
	if not sel.is_empty():
		_bag_grid.add_child(_gear_card(sel))
	# 입은 것 - 두 줄 세 칸. 한 벌을 골라 설명 판이 떠 있는 동안은 접는다
	# (판 높이를 넘으면 목록과 쪽 넘기기가 아래로 밀려 안 보인다).
	if not sel.is_empty():
		_gear_list()
		return
	var worn := GridContainer.new()
	worn.columns = 3
	worn.add_theme_constant_override("h_separation", 8)
	worn.add_theme_constant_override("v_separation", 6)
	for slot in Gear.SLOTS:
		var it := Gear.worn(String(slot))
		var txt := "%s  -  %s" % [String(Gear.SLOT_NAME[slot]),
			Gear.name_of(it) if not it.is_empty() else "비어 있음"]
		var b := _gear_btn(txt, it, 280.0)
		worn.add_child(b)
	_bag_grid.add_child(worn)
	_gear_list()


## 가진 장비 (입지 않은 것) - 등급 높은 것부터, 쪽 넘기기.
func _gear_list() -> void:
	var list: Array = []
	for it in Gear.items:
		if not Gear.is_worn(int(it["uid"])):
			list.append(it)
	list.sort_custom(func(a, b) -> bool:
		if int(a["rar"]) != int(b["rar"]):
			return int(a["rar"]) > int(b["rar"])
		return Gear.score(a) > Gear.score(b))
	if list.is_empty():
		_bag_grid.add_child(_bag_line("가방에 다른 장비가 없어요. 몬스터가 떨어뜨려요.", 19,
			Color("#A79A8A")))
		return
	var pages := maxi(1, ceili(float(list.size()) / GEAR_PAGE))
	_bag_page = clampi(_bag_page, 0, pages - 1)
	var cells := GridContainer.new()
	cells.columns = 2
	cells.add_theme_constant_override("h_separation", 8)
	cells.add_theme_constant_override("v_separation", 6)
	for i in range(_bag_page * GEAR_PAGE, mini((_bag_page + 1) * GEAR_PAGE, list.size())):
		var it2: Dictionary = list[i]
		var tag := ""
		if not Gear.can_wield(it2):
			tag = "  (못 듦)"
		elif Gear.better(it2):
			tag = "  (더 좋음)"
		var b2 := _gear_btn("%s [%s]%s" % [Gear.name_of(it2),
			String(Gear.RARITY[int(it2["rar"])]["name"]), tag], it2, 425.0)
		cells.add_child(b2)
	_bag_grid.add_child(cells)
	_bag_grid.add_child(_pager(pages, _paper_btn("일반·고급 팔기", func() -> void:
		var got := Gear.sell_junk(1)
		if got > 0:
			AudioManager.ui_confirm()
			_say_hint("꿈조각 +%d" % got, false, 1.4)
		_gear_sel = -1
		_refill_bag())))


func _gear_btn(text: String, it: Dictionary, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12 if not it.is_empty() and int(it["uid"]) == _gear_sel else 0.05)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.border_color = Gear.rarity_col(it) if not it.is_empty() else Color("#5C5470")
	sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var col := Gear.rarity_col(it) if not it.is_empty() else Color("#7E7468")
	for st2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st2, col)
	# 그림 - 무채색으로 찍어 두고 단계 빛깔을 입힌다 (`HeldWeapon.METAL`).
	if not it.is_empty():
		var ic := "w-%s" % String(it["kind"]) if String(it["slot"]) == "weapon" \
			else "a-%s" % String(it["slot"])
		var path := "res://assets/sprites/%s.png" % ic
		if ResourceLoader.exists(path):
			b.icon = load(path)
			b.expand_icon = true
			var tint := Color(String(HeldWeapon.METAL[clampi(int(it["tier"]), 0, 4)]))
			for st3 in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
					"icon_focus_color"]:
				b.add_theme_color_override(st3, tint)
	if not it.is_empty():
		var uid := int(it["uid"])
		b.pressed.connect(func() -> void:
			AudioManager.ui_click()
			_gear_sel = -1 if _gear_sel == uid else uid
			_refill_bag())
	return b


## 고른 장비 설명 - 수치, 그리고 입기·벗기·강화·팔기.
func _gear_card(it: Dictionary) -> Control:
	var panel := _card_box()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Gear.rarity_col(it))
	head.text = "%s  (%s · %s)" % [Gear.name_of(it), String(Gear.RARITY[int(it["rar"])]["name"]),
		String(Gear.SLOT_NAME[String(it["slot"])])]
	col.add_child(head)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("#E4DCCF"))
	l.text = "   ".join(Gear.lines_of(it))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(820, 0)
	col.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var uid := int(it["uid"])
	if Gear.is_worn(uid):
		row.add_child(_small_btn("벗기", func() -> void:
			Gear.unequip(String(it["slot"]))
			_gear_sel = -1
			_refill_bag()))
	elif Gear.can_wield(it):
		# 입으면 판을 접고 입은 칸을 보여 준다 - 무엇이 바뀌었는지 바로 보이게.
		row.add_child(_small_btn("입기", func() -> void:
			if Gear.equip(uid):
				AudioManager.ui_confirm()
				_gear_sel = -1
			_refill_bag()))
	if int(it["plus"]) < Gear.PLUS_MAX:
		var eb := _small_btn("강화 (%d · 강화석 1 · %d 퍼센트)" % [Gear.plus_cost(it),
			int(Gear.plus_rate(it) * 100.0)], func() -> void:
				var r := Gear.enhance(uid)
				if bool(r["ok"]) or bool(r.get("tried", false)):
					Loop.note("enhance")
				if bool(r["ok"]):
					AudioManager.ui_confirm()
					_celebrate("강화 성공!", Gear.name_of(Gear.get_item(uid)))
				elif bool(r.get("tried", false)):
					AudioManager.battle_hurt()
					_say_hint("강화 실패... 수치는 그대로예요", false, 1.6)
				else:
					_say_hint(String(r["why"]), false, 1.4)
				SaveManager.save_now()
				_refill_bag())
		eb.custom_minimum_size = Vector2(360, 48)
		row.add_child(eb)
	if not Gear.is_worn(uid):
		row.add_child(_small_btn("팔기 %d" % Gear.sell_price(it), func() -> void:
			Gear.sell(uid)
			_gear_sel = -1
			AudioManager.ui_click()
			_refill_bag()))
	return panel


func _small_btn(text: String, fn: Callable) -> Button:
	var b := _paper_btn(text, fn)
	b.custom_minimum_size = Vector2(140, 48)
	b.add_theme_font_size_override("font_size", 19)
	return b


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
## 이 화면이 보여 줄 할 일이 **어느 마을 것인가.** 실내에서는 들어온
## 마을 것을 이어 본다 (`Place.quest_village`).
func _quest_village() -> String:
	var pl := _place()
	if pl != null and pl.has_method("quest_village"):
		return String(pl.quest_village())
	return JourneyState.here


## 이 HUD 를 안고 있는 마을. 할 일이 지도 위 어디인지는 마을만 안다.
func _place() -> Node:
	var p := get_parent()
	return p if p != null and p.has_method("goal_world") else null


## 눌러서 지도에 접어 둘 수 있는 할 일 한 줄.
##
## 누르면 배낭을 닫는다 — 표시가 미니맵에 뜨는데 배낭이 덮고 있으면
## 아무 일도 안 일어난 것처럼 보인다. "여기로 가세요" 라고 시키지 않고
## **접어 뒀다**고만 말한다.
func _quest_row(text: String, col: Color, item: Dictionary, place: Node,
		size: int = 28) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(BAG_LINE_WIDTH, 0)
	b.add_theme_font_size_override("font_size", size)
	Wrap.put(b, text)
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
	# **오늘의 임무** - 맨 위에. 날짜가 바뀌면 새로 셋 (`Loop.ensure_daily`).
	Loop.ensure_daily()
	_bag_grid.add_child(_bag_line("오늘의 임무  ·  날마다 새로  ·  하나에 꿈조각 %d · 강화석 1"
		% int(Loop.daily_reward()["coins"]), 22, Color("#FFD43B")))
	for q in Loop.daily.get("list", []):
		var done := int(q["have"]) >= int(q["need"])
		var tail := "받았어요" if bool(q["claimed"]) else ("%d / %d" % [int(q["have"]), int(q["need"])])
		_bag_grid.add_child(_bag_line("%s  (%s)" % [String(q["label"]), tail], 21,
			Color("#A79A8A") if bool(q["claimed"]) else (Color("#B4E6C0") if done
				else Color("#FFF2C8"))))
	var village := _quest_village()
	var list := Quests.quest_list(village)
	if list.is_empty():
		_empty("여기서는 딱히 할 일이 없어요")
	else:
		# **"해야 하는 이유를 모르겠다"는 말을 들었다.** 목록만 있고
		# 마치면 뭐가 되는지가 어디에도 안 적혀 있었다. 마을 종류에 따라
		# 답이 다르니 한 줄로만 답한다 - 숫자(3/5)는 여전히 안 보여 준다
		# (`docs/quest-journey.md` 2절), 그래서 정확한 개수 대신
		# "몇 가지"·"둘" 처럼 이미 다른 곳에서도 알려 준 말만 쓴다
		# (`_maybe_explain_sides` 의 "둘만 골라도" 와 같은 말).
		var why := "여기 있는 할 일을 마치면 다음 마을이 열려요."
		if Quests.KNOT.has(village):
			why = "이야기를 이어가고 샛길을 둘만 골라도 다음 마을이 열려요."
		elif not Quests.ORDER.has(village):
			why = "다 안 해도 괜찮아요 - 그냥 둘러보면 돼요."
		_bag_grid.add_child(_bag_line(why, 22, Color("#A79A8A")))
	var place := _place()
	var tappable := false
	for q in list:
		var done: bool = q.get("done", false)
		var label := String(q.get("label", ""))
		# **"이야기"와 "샛길" 줄이 똑같이 생겨 체크리스트로 읽혔다.**
		# 이야기는 지금 이어가는 단 한 걸음이라 도드라져야 하고, 샛길은
		# 위에서 이미 한 번 설명했으니 줄마다 또 "샛길 · " 를 반복하지
		# 않는다 - 다만 목록 줄이라는 표시로 옅은 점 하나만 남긴다.
		var is_story := label.begins_with("이야기 ")
		if not is_story and label.begins_with("샛길 · "):
			label = "· " + label.substr("샛길 · ".length())
		var text := label + ("  (다 했어요)" if done else "")
		# **아직 안 한 것은 눌러서 지도에 접어 둘 수 있다.** 목록과 지도가
		# 서로 남이면 "무엇을" 은 알아도 "어디로" 를 모른다. 다 한 것은
		# 그냥 글자로 둔다 — 눌러 봐야 갈 데가 없다.
		var can_tap: bool = not done and place != null and place.goal_world(q) != Vector2.INF
		# **누를 수 있는 줄만 다른 색을 준다.** 여태는 눌리는 줄(Button)과
		# 그냥 글자인 줄(Label)이 폰트 크기·색·여백까지 같아서 눌러
		# 보기 전엔 구별이 안 됐다 - 이 씬에 자리가 없는 남의 마을 줄을
		# 눌러도 아무 일이 없어 고장으로 읽혔다. 여기만 선택 버튼과
		# 같은 금색을 쓴다.
		var col := Color("#A79A8A") if done else \
			(Color("#FFE39A") if can_tap else Color("#FFF2C8"))
		var size := 30 if is_story else 26
		if can_tap:
			tappable = true
			_bag_grid.add_child(_quest_row(text, col, q, place, size))
		else:
			_bag_grid.add_child(_bag_line(text, size, col))
		_reward_line(village, Rewards.for_row(village, q), done)
	# 마을을 다 돌면 받는 도장. 목록 끝에 한 줄 - 끝까지 가 볼 이유가 된다.
	if Rewards.VILLAGE.has(village) and not list.is_empty():
		var stamp := {"item": Rewards.item_for(village, Rewards.VILLAGE_KEY),
			"xp": Rewards.XP_VILLAGE}
		var cleared := Rewards.claimed(village, Rewards.VILLAGE_KEY)
		_bag_grid.add_child(_bag_line(
			("받았어요 · %s" if cleared else "다 돌면 · %s · 경험 %d")
				% ([Catalog.name_of(String(stamp["item"]))] if cleared
					else [Catalog.name_of(String(stamp["item"])), int(stamp["xp"])]),
			22, Color("#7E7468") if cleared else Color("#E8C46A")))
	# **그늘 퇴치.** 따로 한 칸 - 다음 마을을 잠그지 않는다는 걸 머리에
	# 적어 둔다 (`Quests.hunt_list` 주석). 수는 날을 넘겨 쌓인다.
	var hunts := Quests.hunt_list(village)
	if not hunts.is_empty():
		_bag_grid.add_child(_bag_line(" ", 8, Color("#A79A8A")))
		_bag_grid.add_child(_bag_line("그늘 퇴치  ·  안 해도 다음 마을은 열려요", 24,
			Color("#F2A0A0")))
		for h in hunts:
			var hd: bool = bool(h["done"])
			var ht := "%s  (%s)" % [String(h["label"]),
				"다 했어요" if hd else "%d/%d" % [int(h["have"]), int(h["need"])]]
			_bag_grid.add_child(_bag_line(ht, 26,
				Color("#A79A8A") if hd else Color("#FFD0C0")))
			_reward_line(village, {"item": Rewards.item_for(village, String(h["key"])),
				"xp": Rewards.xp_for(village, String(h["key"]))}, hd)
	# 눌러도 된다는 걸 아무도 모른다 — 줄이 그냥 글자로 보인다. 한 번만
	# 조용히 알려 준다. 시키는 말이 아니라 그렇게 할 수 있다는 말로.
	if tappable:
		_bag_grid.add_child(
			_bag_line("할 일을 톡 누르면 지도에 접어 둬요.", 22, Color("#A79A8A")))
	# **길잡이를 다시 볼 곳.** 처음 안내는 한 줄, 한 번만 뜨고 사라진다 —
	# 놓치면 못 본다는 게 친구들 피드백이었다. 여기, 막혔을 때 오는
	# 바로 그 탭에 다시 볼 수 있는 버튼을 둔다.
	# **이름은 "길잡이" 가 아니라 "조작 안내" 로 적는다.** "길잡이가
	# 뭔지 모르겠다"는 말을 들었다 - 게임 안 어디에도 그 낱말을 설명한
	# 적이 없다. 걷기·말 걸기·상호작용 같은 **조작을 알려 주는 것**이라고
	# 있는 그대로 적으면 처음 보는 사람도 뭘 누르는지 안다.
	var gb := Button.new()
	gb.text = "조작 안내 다시 보기"
	gb.custom_minimum_size = Vector2(0, 64)
	gb.add_theme_font_size_override("font_size", 24)
	# **배경이 없었다.** 배낭 목록의 다른 줄들은 색·정렬을 다 맞췄는데
	# 이 버튼만 엔진 기본 회색 사각형이라 붕 떠 보였다.
	Paper.button(gb, Color("#F4EDE2"), Color("#8C7B68"), Color("#3A2C2C"))
	gb.pressed.connect(_open_guide_recap)
	_bag_grid.add_child(gb)

	# **화면 보는 법도 여기 바로 둔다.** 길잡이 판 안에 한 번 더
	# 들어가야 나오면 못 찾는다 — 막혔을 때 오는 자리에 바로 있어야 한다.
	var hb := Button.new()
	hb.text = "화면 보는 법"
	hb.custom_minimum_size = Vector2(0, 64)
	hb.add_theme_font_size_override("font_size", 24)
	Paper.button(hb, Color("#F4EDE2"), Color("#8C7B68"), Color("#3A2C2C"))
	hb.pressed.connect(func() -> void:
		toggle_bag()
		HowToPlay.open(get_tree()))
	_bag_grid.add_child(hb)


## 할 일 줄 밑에 붙는 **받는 것** 한 줄 (`Rewards`).
##
## 뭘 받는지 알아야 하고 싶어진다 - 여태 할 일을 마쳐도 받는 게 없어
## "왜 해야 하는지 모르겠다" 는 말을 들었다. 다 한 줄은 받은 것을 적는다.
func _reward_line(village: String, r: Dictionary, done: bool) -> void:
	var item := String(r.get("item", ""))
	if item == "" and int(r.get("xp", 0)) <= 0:
		return
	var nm := Catalog.name_of(item) if item != "" else ""
	var text := ""
	if done:
		text = "    받았어요 · %s" % nm if nm != "" else ""
	else:
		text = "    받는 것 · %s · 경험 %d" % [nm, int(r["xp"])] if nm != "" \
			else "    받는 것 · 경험 %d" % int(r["xp"])
	if text == "":
		return
	_bag_grid.add_child(_bag_line(text, 20,
		Color("#7E7468") if done else Color("#C9B37A")))


## "조작 안내 다시 보기" 판. 처음 봤던 안내를 순서대로 다시 보여준다.
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
	panel.add_theme_stylebox_override("panel", Paper.lift(sb))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var vp := get_viewport().get_visible_rect().size
	# 자리를 우선 넉넉히 잡아 둔다 - 아래서 내용 높이를 잰 다음 다시 맞춘다.
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
	title.text = "조작 안내"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#3A2C2C"))
	box.add_child(title)

	var step: int = SaveManager.get_flag(Guide.STEP_FLAG, Guide.STEPS.size())
	var finished: bool = SaveManager.get_flag(Guide.FLAG, false) or step >= Guide.STEPS.size()
	var now: Label = null
	if not finished:
		now = Label.new()
		# 줄표(—)를 쓰면 안 된다. PoorStory 에 없어서 폰에서 네모 상자가
		# 뜬다 (`CLAUDE.md` 폰트 규칙). 가운뎃점은 들어 있다.
		now.custom_minimum_size = Vector2(500, 0)
		now.add_theme_font_size_override("font_size", 26)
		Wrap.put(now, "지금은 · " + String(Guide.STEPS[step][1]))
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
		l.custom_minimum_size = Vector2(500, 0)
		l.add_theme_font_size_override("font_size", 24)
		Wrap.put(l, String(Guide.STEPS[i][1]))
		l.add_theme_color_override("font_color",
			Color("#A79A8A") if i < step else Color("#4A3A22"))
		list.add_child(l)

	# **화면 보는 법을 다시 볼 자리.** 처음 한 번 뜨고 마는 판이라,
	# 나중에 "이 버튼이 뭐였지" 하고 돌아올 곳이 있어야 한다.
	var howto := Button.new()
	howto.text = "화면 보는 법"
	howto.custom_minimum_size = Vector2(0, 68)
	howto.add_theme_font_size_override("font_size", 26)
	# **배경이 없었다.** 종이 질감으로 정성껏 만든 판(`Paper.lift`) 안에
	# 배경 없는 엔진 기본 버튼 둘이 떠 있었다.
	Paper.button(howto, Color("#F4EDE2"), Color("#8C7B68"), Color("#3A2C2C"))
	howto.pressed.connect(func() -> void:
		layer.queue_free()
		HowToPlay.open(get_tree()))
	box.add_child(howto)

	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 68)
	close.add_theme_font_size_override("font_size", 26)
	Paper.button(close, Color("#FFE39A"), Color("#8C6E3F"), Color("#4A3A22"))
	# 배낭 되돌리기는 위의 `tree_exiting` 이 맡는다 — 여기선 닫기만 한다.
	close.pressed.connect(layer.queue_free)
	box.add_child(close)

	# **판 높이를 내용에 맞춘다** (`_fit_bag_panel()` 과 같은 방식). 화면
	# 높이의 78% 로 고정해 뒀더니, 가로가 넓고 세로가 짧은 폰(세로 720
	# 안팎)에서는 튜토리얼이 진행 중일 때(안내 7줄 + "지금은" 줄 + 버튼
	# 둘)이 다 안 들어가 스크롤 목록 마지막 줄이 글자 중간에서 잘려
	# "화면 보는 법" 버튼과 맞닿아 보였다. 실제 내용 높이를 잰 다음
	# 화면이 허락하는 만큼 넉넉히 늘려 잡는다 - 그래도 못 담으면 그때
	# 스크롤이 받는다.
	await get_tree().process_frame
	var sep: float = box.get_theme_constant("separation")
	var chrome: float = title.get_combined_minimum_size().y \
		+ howto.get_combined_minimum_size().y + close.get_combined_minimum_size().y \
		+ sep * 3
	if now != null:
		chrome += now.get_combined_minimum_size().y + sep
	var content: float = list.get_combined_minimum_size().y
	var need: float = clampf(chrome + content + 44.0, 400.0, minf(vp.y * 0.92, 760.0))
	panel.offset_top = -need * 0.5
	panel.offset_bottom = need * 0.5


## 받침을 보고 을/를 을 골라 붙인다. `Wrap.with_josa` 로 옮겼다 -
## 여기 하나뿐이던 걸 `Quests` 의 "%s와 인사하기" 도 써야 했다.
func _with_josa(word: String) -> String:
	return Wrap.with_josa(word)


## 가운데 위에 한 줄 띄웠다 지운다. 주운 것·마친 일이 같은 자리를 쓴다.
##
## **줄을 세운다.** 마지막 것을 주우면 "조약돌 주웠어요" 와 "떨어진 것 다
## 줍기, 다 했어요" 가 같은 프레임에 겹쳐, 앞엣것이 뜨자마자 지워졌다.
## 하나씩 차례로 보여 준다.
## [{text, patient, hold}]
var _hint_queue: Array = []
var _hint_busy := false

## 한 줄 띄웠다 지운다.
##
## `patient` 은 **화면 가운데가 덮여 있으면 걷힐 때까지 기다린다**는 뜻이다.
## 마을에 닿자마자 뜨는 안내(재회·편지)가 그렇다 — 그때 화면은 씬 전환
## 암전이 덜 걷혔고, 마을 이름과 해볼 일을 적은 도착 카드가 3.6초 동안
## 가운데를 덮고 있다. 그 밑에서 1.6초를 떴다 지는 바람에, **게임의
## 심장인 재회를 알리는 유일한 표시**가 아무도 못 보고 사라졌다.
## 얻은 것·축하 카드는 이미 같은 게이트를 쓴다 (`_center_covered`).
##
## 기본값이 `false` 인 이유: 배낭을 열어 할 일을 접었을 때의
## "지도에 살짝 접어 두었어요" 처럼 **덮인 채로 떠야 맞는** 안내가 있다.
## 그 답을 배낭이 닫힐 때까지 미루면 누른 보람이 사라진다.
func _say_hint(text: String, patient := false, hold := 1.1) -> void:
	if _hint == null:
		return
	_hint_queue.append({"text": text, "patient": patient, "hold": hold})
	if not _hint_busy:
		_drain_hints()


func _drain_hints() -> void:
	if _hint == null or not is_instance_valid(_hint):
		return
	if _hint_queue.is_empty():
		_hint_busy = false
		return
	# **줄에서 첫째만 보지 않는다.** 도착하자마자 편지가 오면(patient)
	# 그 줄이 덮개가 걷힐 때까지 큐 맨 앞에 버티고 서서, 뒤이어 들어온
	# 급한 안내(부두에 닿았을 때의 한 줄 등, patient가 아닌 것들)까지
	# 같이 막아 버렸다 - 도착 카드가 떠 있는 3.6초 동안 그 사이에 생긴
	# 어떤 안내도 못 뜨는 셈이었다. 지금 띄울 수 있는 **첫째**를 찾는다.
	var i := 0
	while i < _hint_queue.size():
		var cand: Dictionary = _hint_queue[i]
		if bool(cand.get("patient", false)) and _center_covered():
			i += 1
			continue
		break
	if i >= _hint_queue.size():
		# 아직 다 덮여 있다. 줄을 그대로 두고 물러난다 — `_process` 가
		# 덮개가 걷힌 프레임에 다시 부른다.
		_hint_busy = false
		return
	var head: Dictionary = _hint_queue[i]
	_hint_busy = true
	_hint_queue.remove_at(i)
	Wrap.put(_hint, String(head.get("text", "")))
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(float(head.get("hold", 1.1)))
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_drain_hints)


func _on_picked(item: String, _total: int) -> void:
	show_got(item)
	if _bag_panel.visible:
		_refill_bag()


## 무엇을 얻었는지 그림과 함께 가운데에 띄웠다 지운다.
##
## 주운 것은 "주웠어요", 받은 것은 "받았어요" — 줍는 것(`p-*`)과
## 누가 건네주는 것은 결이 다르다.
## 화면 가운데는 **한 번에 하나만.** 지도를 받는 순간이 곧 "인사하고
## 지도 받기" 를 마치는 순간이라, 얻은 것 카드와 축하가 같은 자리에
## 겹쳐 떠서 그림과 글자가 서로 뭉갰다 (폰에서 확인). 둘을 한 줄에
## 세워 차례로 보여 준다.
func show_got(item: String) -> void:
	if _got == null:
		return
	_got_queue.append(item)
	_drain_center()


func _drain_center() -> void:
	if _got_busy or _cele_busy:
		return
	# **덮여 있으면 기다린다.** 정류장에서 떠날 때의 축하는 여행판 뒤에,
	# 문을 지날 때의 축하는 씬 전환 암전 뒤에 통째로 가려 한 번도 못
	# 봤다. 덮개가 걷힌 뒤에 띄운다 (`_tick_center_gate` 가 다시 부른다).
	if _center_covered():
		return
	if not _got_queue.is_empty():
		_show_got_now(String(_got_queue.pop_front()))
	elif not _cele_queue.is_empty():
		_show_cele_now(_cele_queue.pop_front())


## 화면 가운데를 덮고 있는 것이 있나. 있으면 축하를 미룬다.
func _center_covered() -> bool:
	var tr := get_node_or_null("/root/SceneTransition")
	if tr != null and bool(tr.get("is_transitioning")):
		return true
	for g in ["travel_board", "journey_say", "overlay"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is CanvasItem and (n as CanvasItem).visible:
				return true
			if n is CanvasLayer and (n as CanvasLayer).visible:
				return true
	if bag_open():
		return true
	# 도착 카드(마을 이름 + 해볼 일)도 같은 자리를 쓴다.
	if _arrival_card_up:
		return true
	# **펼친 큰 지도도 덮개로 친다.** 여태는 안 쳐서, 지도를 펼치면
	# 그 위로 도착 카드의 큰 글자와 안내 한 줄이 그대로 겹쳐 그려져
	# 지도도 글자도 안 읽혔다.
	for n in get_tree().get_nodes_in_group("mini_map"):
		if n.has_method("is_big") and n.is_big():
			return true
	return false


func _show_got_now(item: String) -> void:
	_got_busy = true
	var art := Catalog.icon_of(item)
	var path := "res://assets/sprites/%s.png" % art
	_got_art.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_got_art.visible = _got_art.texture != null
	var nm := Catalog.name_of(item)
	var verb := "주웠어요" if item.begins_with("p-") else "받았어요"
	_got_text.text = "%s %s" % [_with_josa(nm), verb]
	if _got_tw != null and _got_tw.is_valid():
		_got_tw.kill()
	_got.modulate.a = 0.0
	_got.scale = Vector2(0.88, 0.88)
	_got.pivot_offset = _got.size * 0.5
	_got_tw = create_tween().set_parallel(true)
	_got_tw.tween_property(_got, "modulate:a", 1.0, 0.22)
	_got_tw.tween_property(_got, "scale", Vector2.ONE, 0.28) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_got_tw.chain().tween_interval(1.25)
	_got_tw.chain().tween_property(_got, "modulate:a", 0.0, 0.45)
	_got_tw.chain().tween_callback(func() -> void:
		_got_busy = false
		_drain_center())


## 할 일이 어디 있는지 가리킬까. 길잡이가 부른다.
func point_at_tasks(on: bool) -> void:
	if _hint_ring == null:
		return
	if on and (_buttons_hidden or bag_open()):
		on = false      # 판이 이미 열려 있거나 버튼이 치워졌으면 가릴 것이 없다
	_hint_ring.visible = on


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
## 어디까지 알렸는지는 `JourneyState.announced` 가 들고 있다 — 화면이
## 갈려도 남아야 하기 때문이다(문을 지나며 끝나는 할 일이 있다).

## 항목을 가리키는 이름. 종류만으로는 인사 둘을 못 가른다
## (`Place._goal_id` 와 같은 규칙).
func _goal_id(item: Dictionary) -> String:
	return Quests.row_id(item)

## 지금 해볼 일 하나. 마을이 가리키는 것을 그대로 따른다 —
## 미니맵이 짚는 것과 같은 항목이어야 헷갈리지 않는다.
func _first_task() -> String:
	var place := _place()
	if place != null:
		var now: Dictionary = place.current_goal()
		if not now.is_empty():
			return String(now.get("label", ""))
		# **실내가 일부러 조용하면 그대로 조용히 둔다.** 그늘 자리
		# (`ShadeSpot`) 처럼 `open_goals()` 를 일부러 비워 둔 곳에서
		# 마을(바깥) 할 일로 떨어지면, "여기서는 그냥 쉬어요" 옆에
		# 엉뚱하게 바깥 마을의 남은 할 일이 뜬다 - 그 자리에서 할 수도
		# 없는 일이다.
		if place.is_indoors():
			return ""
	for q in Quests.quest_list(_quest_village()):
		if not bool(q.get("done", false)):
			return String(q.get("label", ""))
	return ""


## 첫 마을 동안만 안내줄을 켠다.
##
## 첫 여행지를 떠나기 전까지 — 프롤로그(잿마루)와 첫 여행지(윤슬)다.
## `departures` 는 정류장에서 실제로 떠날 때마다 는다. 둘째 떠남
## (=윤슬을 떠남) 뒤에는 조용해진다.
const STRIP_UNTIL_DEPARTURES := 2

func _tick_task_strip() -> void:
	if _task_strip == null:
		return
	# 첫 마을 동안, 그리고 **마을 이야기(매듭)를 이어가는 동안**에는
	# 위쪽에 지금 단계를 늘 띄운다 — 하루를 넘겨 이어지는 약속이라
	# "내가 뭘 하던 중이었지" 가 사라지면 안 된다 (오늘의 약속).
	var v2 := _quest_village()
	var early: bool = JourneyState.departures < STRIP_UNTIL_DEPARTURES \
		or (Quests.KNOT.has(v2) and not Quests.knot_done(v2))
	var goal := _first_task() if early else ""
	# **도착 카드가 떠 있는 동안은 위쪽 줄을 겹쳐 안 띄운다.** 마을에
	# 들어서면 가운데에 마을 이름 + "해볼 일 · ..." 이 이미 크게 뜨는데,
	# 위쪽에도 똑같은 문구가 떠서 같은 정보가 두 번 보이고 화면 절반이
	# 글자였다 (`announce_place`).
	var show: bool = early and goal != "" and not bag_open() \
		and not _buttons_hidden and not _arrival_card_up
	_task_strip.visible = show
	if show:
		# **지금 할 수 없는 것에 "지금 해볼 일" 이라 쓰지 않는다.**
		#
		# 남은 것이 죄다 때를 기다리는 것일 때가 있다 - 아침에
		# 부두를 다녀왔으면 그 줄은 저녁까지 할 것이 없다. 그런데도
		# "지금 해볼 일" 이라 적으면, 시키는 대로 갔는데 아무 일도
		# 안 일어난다. 그때는 말투를 바꾼다.
		Wrap.put(_task_strip,
			("기다릴 일 · " if _waiting_now() else "지금 해볼 일 · ") + goal)


## 지금 짚고 있는 것이 "때를 기다리는" 것인가.
func _waiting_now() -> bool:
	var place := _place()
	if place == null:
		return false
	var now: Dictionary = place.current_goal()
	return not now.is_empty() and bool(now.get("waiting", false))


## "샛길은 둘만 해도 다음 마을이 열려요" — 한 번은 알려 준다.
##
## `Quests.SIDES_NEEDED` 는 코드 주석에만 있었다. 목록은 이야기 한 줄과
## 샛길 줄을 똑같은 모양으로 늘어놓아 전부 필수 체크리스트로 읽혔고,
## "샛길" 이라는 낱말 자체도 설명이 없어 상단 목표줄에선 장소 이름처럼
## 읽혔다. 마을마다 한 번, 처음 샛길 줄이 보이는 순간에만 말해 준다.
func _maybe_explain_sides(list: Array) -> void:
	var v := _quest_village()
	if not Quests.KNOT.has(v):
		return
	var flag := "%s:샛길설명" % v
	if JourneyState.quest_done(flag):
		return
	for q in list:
		if String(q.get("id", "")).contains(":샛길:"):
			JourneyState.mark_quest(flag)
			# **patient.** `_process` 가 매 프레임 부르는 함수라, 마침 배낭의
			# "이 마을에서" 탭을 펼쳐 둔 채로 샛길 항목이 막 나타나는 순간과
			# 겹칠 수 있다. 안 기다리면 위쪽 고정 자리(_hint)가 그 아래 펼쳐진
			# 배낭판과 같은 자리를 다퉈, 짧고 넓은 화면에서 글자가 탭 줄
			# 사이로 배어났다. 이 안내는 사용자가 막 누른 것에 대한 응답이
			# 아니라 상태 변화로 뜨는 것이라 배낭이 닫힐 때까지 미뤄도 된다.
			_say_hint("샛길은 이름 그대로 - 둘만 골라 해도 다음 마을이 열려요.", true)
			return


func _watch_done(list: Array) -> void:
	# 앱을 켜자마자 이미 해 둔 것이 우르르 뜨지 않게, 첫 한 번은 조용히
	# 기준만 잡는다.
	if not JourneyState.announce_ready:
		JourneyState.announce_ready = true
		for q in list:
			if bool(q.get("done", false)):
				JourneyState.announced[_goal_id(q)] = true
		return
	var left := 0
	var just: Array[String] = []
	for q in list:
		var id := _goal_id(q)
		if not bool(q.get("done", false)):
			left += 1
			JourneyState.announced.erase(id)   # 되돌아간 것도 다시 셀 수 있게
			continue
		if not JourneyState.announced.has(id):
			JourneyState.announced[id] = true
			just.append(String(q.get("label", "")))
	if just.is_empty():
		return
	# 한 줄 알림에서 **가운데 잔치**로 바꿨다 — 하나 마칠 때마다
	# 손맛이 있어야 다음 것도 하고 싶어진다는 요청. 창을 안 띄우고
	# 손을 안 멈추게 하는 건 그대로다 (눌리지 않는 그림일 뿐이다).
	for label in just:
		_celebrate("다 했어요!", String(label))
	# 마지막 하나였으면 한 번 더 크게.
	if left == 0:
		_celebrate("이 마을을 다 돌았어요!", "해볼 일을 모두 마쳤어요")
	# **다음 마을이 열린 순간은 따로 알린다.** 매듭 마을(윤슬)은
	# "샛길은 둘만 해도 된다" 는 완화가 있어서, 목록이 아직 다
	# 안 끝났는데도(`left > 0`) 이미 열려 있을 수 있다 - 그 규칙 자체가
	# 화면 어디에도 안 적혀 있고, 열려도 신호가 하나도 없어서 여행판을
	# 우연히 열어야만 알았다. `village_cleared()` 로 직접 재서, 목록이
	# 다 안 끝나도 열린 그 순간을 잡는다.
	var v := _quest_village()
	if Quests.ORDER.has(v) and Quests.village_cleared(v):
		var flag := "%s:해금알림" % v
		if not JourneyState.quest_done(flag):
			JourneyState.mark_quest(flag)
			var idx := Quests.ORDER.find(v)
			var nxt := String(Quests.ORDER[idx + 1]) if idx + 1 < Quests.ORDER.size() else ""
			_celebrate("다음 마을로 가는 길이 열렸어요!",
				"%s 갈 수 있어요" % Wrap.with_josa(nxt, Wrap.Josa.TO) if nxt != "" else "")


## 마친 일의 보상을 받는다 (`Rewards`).
##
## 목록 줄이 끝나면 "다 했어요!" 는 `_watch_done` 이 이미 띄운다 - 여기선
## 받은 것 카드(`JourneyState.pick` 이 저절로 띄운다)만 뒤따른다. 목록 줄이
## 아닌 것(이야기 단계, 마을 다 돌기)은 여기서 잔치도 같이 띄운다.
##
## 마을마다 **이번 실행에서 처음 볼 때**는 밀린 것을 조용히 챙긴다 -
## 옛 세이브로 들어서자마자 카드가 우르르 뜨지 않게, 한 줄로만 알린다.
func claim_rewards() -> void:
	# 오늘의 임무 - 마을과 상관없이 어디서나 받는다.
	for d in Loop.claim_ready():
		_celebrate("오늘의 임무 완료!", "%s  ·  꿈조각 +%d · 강화석 +%d" % [String(d["label"]),
			int(d["coins"]), int(d["stones"])])
		for ev in d["events"]:
			if String(ev.get("kind", "")) == "level_up":
				_celebrate("LV %d!" % int(ev["level"]), "능력치가 올랐어요")
	var v := _quest_village()
	if v == "":
		return
	var quiet := not JourneyState.reward_base.has(v)
	JourneyState.reward_base[v] = true
	var got_quiet := 0
	for e in Rewards.unclaimed(v):
		var evs := Rewards.claim(v, e, quiet)
		if quiet:
			got_quiet += 1
		elif bool(e.get("step", false)):
			_celebrate("이야기 한 걸음!", String(e["label"]))
		elif String(e["key"]) == Rewards.VILLAGE_KEY:
			_celebrate("여행 도장을 받았어요!",
				Catalog.name_of(String(e["item"])))
		elif bool(e.get("hunt", false)):
			_celebrate("퇴치 완료!", String(e["label"]))
		for ev in evs:
			if String(ev.get("kind", "")) == "level_up" and not quiet:
				var sk := String(ev.get("skill", ""))
				_celebrate("LV %d!" % int(ev["level"]),
					("%s을(를) 쓸 수 있게 됐어요" % sk) if sk != "" else "마음이 한 뼘 자랐어요")
	if got_quiet > 0:
		_say_hint("지난 여행에서 받을 것을 배낭에 챙겨 뒀어요.", true, 2.6)
		if _bag_panel != null and _bag_panel.visible:
			_refill_bag()


func _celebrate(big: String, sub: String) -> void:
	if _cele == null:
		return
	_cele_queue.append([big, sub])
	_drain_center()


func _show_cele_now(next: Array) -> void:
	if _cele == null or not is_instance_valid(_cele):
		return
	_cele_busy = true
	_cele_big.text = String(next[0])
	Wrap.put(_cele_sub, String(next[1]))
	AudioManager.ui_confirm()
	_cele.modulate.a = 0.0
	_cele.scale = Vector2(0.7, 0.7)
	_cele.pivot_offset = _cele.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cele, "modulate:a", 1.0, 0.18)
	tw.tween_property(_cele, "scale", Vector2.ONE, 0.38) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(t: float) -> void:
		_cele_rays.set_meta("t", t)
		_cele_rays.queue_redraw(), 0.0, 1.0, 0.8)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(_cele, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void:
		_cele_busy = false
		_drain_center())


func _process(delta: float) -> void:
	if _hint_ring != null and _hint_ring.visible:
		_ring_t += delta
		_hint_ring.queue_redraw()
	if _clock != null:
		_clock.text = "%s   %d일째" % [JourneyState.time_text(), JourneyState.day]
	if (not _got_queue.is_empty() or not _cele_queue.is_empty()) \
			and not _got_busy and not _cele_busy:
		_drain_center()          # 덮개가 걷혔으면 그때 띄운다
	if not _hint_queue.is_empty() and not _hint_busy:
		_drain_hints()           # 기다리던 안내도 같이 (patient)
	var list := Quests.quest_list(_quest_village())
	_maybe_explain_sides(list)
	_watch_done(list)
	# 보상은 매 프레임이 아니라 조금씩 끊어 본다 - 목록을 한 번 더 셈해야
	# 해서다. 0.3초 늦게 받아도 잔치 뒤에 오니 모른다.
	_reward_t += delta
	if _reward_t >= 0.3:
		_reward_t = 0.0
		claim_rewards()
	_tick_task_strip()
	# 점은 **어느 버튼을 눌러야 하는지까지** 알린다. 배낭에 점 하나로
	# "뭔가 새것이 있다" 만 알리던 때는, 그게 편지인지 할 일인지 알려면
	# 배낭을 열어 탭을 뒤져야 했다. 그 합친 점은 없앴다.
	var left := false
	for q in list:
		if not bool(q.get("done", false)):
			left = true
			break
	var show := not bag_open() and not _buttons_hidden
	if _dot_letter != null:
		_dot_letter.visible = JourneyState.unread_letters() > 0 and show
	if _dot_task != null:
		_dot_task.visible = left and show
	# 카메라를 받기 전엔 셔터 버튼이 없다 (`docs/quest-journey.md` 3.5절).
	# 대화 중 버튼을 숨기는 `set_buttons_visible()` 와 겹쳐도, 여기서
	# 매 프레임 다시 확인하므로 카메라 없는 사람에게 다시 뜨는 일이 없다.
	var cam_ok := JourneyState.count("camera") > 0
	if _cam_btn != null:
		_cam_btn.visible = cam_ok and not _buttons_hidden
	if _pad_cam != null:
		_pad_cam.visible = cam_ok and not _buttons_hidden
	if fight != null:
		var p := _place()
		# **붙었을 때만 뜬다** (`Place.in_fight`). 늘 떠 있으면 버튼 일곱과
		# 막대 둘이 마을을 가렸다. 툭 켜지지 않게 스르르.
		var want: bool = p != null and p.has_method("in_fight") and p.in_fight() \
			and not _buttons_hidden and not bag_open()
		if want:
			fight.visible = true
		fight.modulate.a = move_toward(fight.modulate.a, 1.0 if want else 0.0, delta * 6.0)
		if not want and fight.modulate.a <= 0.0:
			fight.visible = false


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


## 대화 중에는 메뉴·사진 버튼을 치운다.
##
## 대화창이 화면 아래를 통째로 쓰기 때문에 버튼이 그 뒤에 숨어 있었고,
## 창이 탭을 먹어서 눌리지도 않았다. 안 보이는 버튼을 남겨 두느니
## 대화 동안은 아예 비켜 준다 — 대화 중에 사진을 찍을 일도 없다.
func set_buttons_visible(on: bool) -> void:
	_buttons_hidden = not on
	for n in [_cam_btn, _pad_cam]:
		if n != null:
			n.visible = on
	# 왼쪽 위 메뉴 다섯도 같이. 말풍선 위에 이름표가 뜨고 화면 위쪽까지
	# 글이 올라오는 장면이 있어서, 버튼이 남아 있으면 그 글을 가린다.
	for a in [_menu_btns, _menu_pads]:
		for n in a:
			if is_instance_valid(n):
				n.visible = on
	for d in [_dot_letter, _dot_task]:
		if d != null and not on:
			d.visible = false


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
	# 메뉴 다섯도 `TextureButton` 이라 여기 같이 들어와야 한다 — 안 그러면
	# 걸으면서 다른 손가락으로 누른 것이 그냥 없던 일이 된다.
	if fight != null and fight.try_touch(pos):
		return true
	var targets: Array = [_act_btn, _cam_btn]
	targets.append_array(_menu_btns)
	for b in targets:
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

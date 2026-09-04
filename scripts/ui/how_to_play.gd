class_name HowToPlay
extends CanvasLayer
## "화면 보는 법" — 처음 한 번, 그리고 언제든 다시 볼 수 있는 안내판.
##
## 단계별 안내(`Guide`)는 **하면서 익히게** 하는 것이라 한 번에 한 줄만
## 나온다. 그런데 폰에서 처음 잡아 보면 그전에 막히는 게 있다 —
## **네 귀퉁이에 뭐가 있는지를 모른다.** 시계가 어디고 배낭이 어딘지
## 몰라서, 알려 줄 것도 없이 헤맨다.
##
## 그래서 딱 한 장. 화면을 잠깐 어둡게 하고 **실제 그 자리에** 고리를
## 그려서 이름을 붙인다. 글로 "오른쪽 아래" 라고 쓰는 것보다 그 자리에
## 점을 찍는 편이 빠르다.
##
## 지키는 선은 `Guide` 와 같다 — 한 번만 나오고, 아무 벌이 없고,
## 언제든 다시 볼 수 있다 (배낭 > 이 마을 > 길잡이 다시 보기).

const FLAG := "how_to_play_done"

signal closed

## [화면 어느 쪽, 가로 치우침, 세로 치우침, 이름, 한 줄 설명, (옆에 붙임), (보임 확인 키)]
## 치우침은 그 귀퉁이에서 안쪽으로 얼마나 들어오는지(px).
##
## **보임 확인 키**가 있는 셋("작은 지도"·"행동"·"사진")은 카드가
## 뜨는 그 순간 실제로 화면에 있을 때만 그린다. 지도를 받기 전엔
## 미니맵 자체가 안 보이고, 카메라가 없으면 사진 버튼이 숨고, 가까이
## 간 것이 없으면 행동 버튼도 없다 - 없는 자리에 고리만 뜨면 처음
## 잡은 사람은 없는 것을 찾아 누르게 된다 (`_visible_now`).
const SPOTS := [
	[Control.PRESET_TOP_LEFT, 56, 40, "지금 시각", "걷는 동안 하루가 흘러요"],
	# **고리 옆에 붙인다.** 실제 설정 버튼(place.gd)의 중심은 -80 인데
	# 여기 -60 이라 고리가 버튼과 어긋나 있었다(수치를 맞춰 고쳤다).
	# 게다가 바로 아래 "작은 지도" 고리와 가로 97px 밖에 안 떨어져 있어
	# 이름을 아래에 붙이면(2줄, 48px) 둘 사이 빈 틈(29px)에 안 들어가고
	# 어느 한쪽 고리와 겹친다 - 배낭·행동 쌍과 같은 사고라 같은 해법을
	# 쓴다: 아래 대신 옆에 붙인다.
	[Control.PRESET_TOP_RIGHT, -80, 60, "설정", "소리와 되돌리기", true],
	[Control.PRESET_TOP_RIGHT, -175, 155, "작은 지도", "누르면 크게 봐요", false, "map"],
	# 배낭은 이름을 **고리 옆**에 붙인다. 위로 올리면 바로 위 "행동"
	# 고리와 겹친다 (오른쪽 아래는 둘이 세로로 붙어 있다).
	[Control.PRESET_BOTTOM_RIGHT, -80, -80, "배낭", "해볼 일과 가진 것", true],
	[Control.PRESET_BOTTOM_RIGHT, -107, -198, "행동", "가까이 가면 떠요", false, "act"],
	[Control.PRESET_BOTTOM_LEFT, 80, -80, "사진", "카메라를 받으면 켜져요", false, "cam"],
]

const HOWS := [
	"가고 싶은 곳을 톡 누르면 그리로 걸어가요.",
	"인연이나 문을 누르면 다가가서 저절로 해요.",
	"두 손가락으로 벌리면 가까이, 오므리면 멀리 봐요.",
]


## 지금 띄운다. 이미 떠 있으면 아무것도 안 한다.
static func open(tree: SceneTree) -> HowToPlay:
	if tree.get_first_node_in_group("how_to_play") != null:
		return null
	var h := HowToPlay.new()
	tree.current_scene.add_child(h)
	return h


## 가려 둔 HUD 글자를 되살릴 때 쓴다.
var _hidden_texts: Array = []

func _ready() -> void:
	layer = 11
	add_to_group("how_to_play")
	# 안드로이드 뒤로가기가 이걸 먼저 닫는다 (`back_handler.gd`).
	add_to_group("overlay")
	_hide_hud_texts()
	_build()


## **덮개가 화면을 어둡게만 깔고 글자는 안 지운다.** 그 밑에 시계·
## "지금 해볼 일" 줄이 그대로 있어서, "지금 시각" 이라 적은 설명과
## 실제 시계 글자가 겹쳐 보였다. 이 카드가 떠 있는 동안은 조용히
## 숨겨 뒀다가 닫힐 때 되돌린다.
func _hide_hud_texts() -> void:
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud == null:
		return
	for name in ["_clock", "_task_strip", "_place_title", "_arrive_task"]:
		var n = hud.get(name)
		if n != null and n is CanvasItem and (n as CanvasItem).visible:
			_hidden_texts.append(n)
			(n as CanvasItem).visible = false


func _restore_hud_texts() -> void:
	for n in _hidden_texts:
		if is_instance_valid(n):
			(n as CanvasItem).visible = true
	_hidden_texts.clear()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.09, 0.12, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 바깥을 눌러도 닫힌다. 읽을 만큼 읽었으면 아무 데나 누르면 된다.
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
			_close()
		elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close())
	root.add_child(dim)

	for s in SPOTS:
		if s.size() > 6 and not _visible_now(String(s[6])):
			continue
		root.add_child(_marker(_placed(s)))

	# 가운데 — 무엇을 눌러서 무엇을 하는지 세 줄
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var title := Label.new()
	title.text = "화면 보는 법"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#FFE39A"))
	title.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	for line in HOWS:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color("#FFF2C8"))
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
		l.add_theme_constant_override("outline_size", 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)

	var tail := Label.new()
	tail.text = "배낭에서 언제든 다시 볼 수 있어요."
	tail.add_theme_font_size_override("font_size", 20)
	tail.add_theme_color_override("font_color", Color("#A79A8A"))
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tail)

	var btn := Button.new()
	btn.text = "알겠어요"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(220, 72)
	btn.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFE39A")
	sb.set_corner_radius_all(30)
	sb.set_border_width_all(3)
	sb.border_color = Color("#8C6E3F")
	Paper.lift(sb)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color("#FFD166")
	btn.add_theme_stylebox_override("pressed", Paper.press(pr))
	btn.add_theme_color_override("font_color", Color("#4A3A22"))
	btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.offset_left = -110
	btn.offset_right = 110
	btn.offset_top = -140
	btn.offset_bottom = -68
	btn.pressed.connect(_close)
	root.add_child(btn)


## "작은 지도" 자리를 실제 미니맵 위치로 맞춘다.
##
## 미니맵 폭은 지도 칸 비율에 따라 마을마다 달라진다(`MiniMap._fit`).
## 한 값으로 못 박아 두면 어느 마을에선 맞고 어느 마을에선 어긋난다 -
## 실제로 재 보니 고리 중심이 실제 자리보다 69px 오른쪽에 있었다.
## 그려지는 그 순간의 진짜 자리를 물어서 맞춘다.
func _placed(s: Array) -> Array:
	if s.size() <= 6 or String(s[6]) != "map":
		return s
	var mm := _find_minimap()
	if mm == null:
		return s
	var vp := get_viewport().get_visible_rect().size
	var c := mm.get_global_rect().get_center()
	var spot := s.duplicate()
	spot[1] = c.x - vp.x   # 오른쪽 귀퉁이 기준 - 화면 오른쪽 끝에서 얼마나 왼쪽인지
	spot[2] = c.y
	return spot


func _find_minimap() -> Control:
	for n in get_tree().get_nodes_in_group("mini_map"):
		if n is Control and (n as Control).visible:
			return n
	return null


## 그 자리가 지금 실제로 화면에 있나. "map"·"act"·"cam" 셋만 쓴다 -
## 나머지(시계·설정·배낭)는 늘 있다.
func _visible_now(key: String) -> bool:
	match key:
		"map":
			for n in get_tree().get_nodes_in_group("mini_map"):
				if n is CanvasItem:
					return (n as CanvasItem).visible
			return false
		"act", "cam":
			var hud := get_tree().get_first_node_in_group("journey_hud")
			if hud == null:
				return false
			var btn = hud.get(("_act_btn" if key == "act" else "_cam_btn"))
			return btn != null and btn.visible
	return true


## 귀퉁이 하나. **그 자리에** 고리를 그리고 곁에 이름을 붙인다.
func _marker(s: Array) -> Control:
	var c := Control.new()
	c.set_anchors_preset(int(s[0]))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.offset_left = float(s[1]) - 40.0
	c.offset_top = float(s[2]) - 40.0
	c.offset_right = float(s[1]) + 40.0
	c.offset_bottom = float(s[2]) + 40.0
	# 폰트에 없는 그림글자는 못 쓴다 (`CLAUDE.md`). 고리는 직접 그린다.
	c.draw.connect(func() -> void:
		var mid := Vector2(40, 40)
		# 어두운 판 위에 밝은 고리. 어느 바닥 위에서도 읽힌다.
		c.draw_circle(mid, 34.0, Color(0.16, 0.13, 0.18, 0.55))
		c.draw_arc(mid, 34.0, 0.0, TAU, 48, Color(1.0, 0.89, 0.60, 0.95), 3.0))


	# **글자가 화면 밖으로 안 나가게** 고리 안쪽으로 붙인다. 왼쪽
	# 귀퉁이면 오른쪽으로 뻗고, 오른쪽 귀퉁이면 왼쪽으로 뻗는다 —
	# 가운데 정렬로 두면 모서리에서 절반이 잘린다.
	var to_right: bool = int(s[0]) == Control.PRESET_TOP_LEFT \
		or int(s[0]) == Control.PRESET_BOTTOM_LEFT
	# 위 귀퉁이면 이름을 고리 아래에, 아래 귀퉁이면 위에 붙인다 —
	# 화면 밖으로 안 나가게.
	var below: bool = int(s[0]) == Control.PRESET_TOP_LEFT \
		or int(s[0]) == Control.PRESET_TOP_RIGHT
	var w := 250.0
	var lx: float = (40.0 - 22.0) if to_right else (40.0 + 22.0 - w)
	var align: int = HORIZONTAL_ALIGNMENT_LEFT if to_right \
		else HORIZONTAL_ALIGNMENT_RIGHT
	# 고리는 항상 반지름 34(로컬 y 6~74)로 그려진다. below=true 쪽은
	# 54 로 잡혀 있어 고리 아래쪽 호와 20px 겹쳐 글자 위로 테두리가
	# 지나갔다 - 고리 아래로 내린다.
	var top_y: float = 78.0 if below else -74.0
	# 옆에 붙이라고 적힌 것은 고리 높이에 나란히 둔다
	var beside: bool = s.size() > 5 and bool(s[5])
	if beside:
		lx = 40.0 - 52.0 - w
		top_y = 14.0

	var n := Label.new()
	n.text = String(s[3])
	n.add_theme_font_size_override("font_size", 22)
	n.add_theme_color_override("font_color", Color("#FFE39A"))
	n.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	n.add_theme_constant_override("outline_size", 8)
	n.horizontal_alignment = align
	n.size = Vector2(w, 26)
	n.position = Vector2(lx, top_y)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(n)

	var d := Label.new()
	d.text = String(s[4])
	d.add_theme_font_size_override("font_size", 17)
	d.add_theme_color_override("font_color", Color("#FFF2C8"))
	d.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	d.add_theme_constant_override("outline_size", 7)
	d.horizontal_alignment = align
	d.size = Vector2(w, 22)
	d.position = Vector2(lx, top_y + 26.0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(d)
	return c


## 안드로이드 뒤로가기는 `close()` 가 없으면 그냥 `queue_free()` 를
## 부른다(`back_handler.gd`) - `_close()` 를 거치지 않고 사라질 수
## 있으므로, 가려 둔 글자를 되살리는 건 **어떻게 없어지든** 불리는
## `_exit_tree()` 에 둔다.
func _exit_tree() -> void:
	_restore_hud_texts()


func _close() -> void:
	SaveManager.set_flag(FLAG, true)
	closed.emit()
	queue_free()

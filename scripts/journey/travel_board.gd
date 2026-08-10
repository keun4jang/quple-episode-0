class_name TravelBoard
extends CanvasLayer
## 떠나는 자리에서 뜨는 판. 어디로 갈지 고른다.
##
## 지도를 안 만든다 (`docs/redesign-journey.md` 4절). 목록 하나면 된다 —
## 1탄은 다섯 곳뿐이고, 지도를 만들면 그걸 읽는 법을 또 가르쳐야 한다.
##
## 다녀온 곳도 목록에 그대로 둔다. **돌아갈 수 있어야 한다** — 특히 고향은.

signal chose(scene_path: String)
signal closed

## 이름 → [씬 경로, 한 줄]
##
## **잿마루은 없다.** 회사는 한 번 나오면 돌아가지 않는다.
const PLACES := {
	"윤슬": ["res://scenes/journey/Yunseul.tscn", "바다와 등대"],
	"볕뉘": ["res://scenes/journey/Byeotnwi.tscn", "낮은 기와지붕"],
	"가풀재": ["res://scenes/journey/Gapuljae.tscn", "비탈진 항구"],
	"하늬섬": ["res://scenes/journey/Hanuiseom.tscn", "검은 돌담과 바람"],
	"고향": ["res://scenes/journey/Home.tscn", ""],
}

var _panel: PanelContainer
var _list: VBoxContainer
var _from := ""


func _ready() -> void:
	layer = 12
	add_to_group("travel_board")
	visible = false
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.09, 0.12, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "어디로 갈까"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#3A2C2C"))
	box.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	box.add_child(_list)

	var back := Button.new()
	back.text = "아직 더 있을래"
	back.custom_minimum_size = Vector2(0, 76)
	back.add_theme_font_size_override("font_size", 28)
	_style(back, false)
	back.pressed.connect(close)
	box.add_child(back)


func _style(b: Button, strong: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F4EDE2") if strong else Color("#E7E0D6")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color("#FFE39A")
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_color_override("font_color", Color("#3A2C2C"))


func open(from_place: String) -> void:
	_from = from_place
	for c in _list.get_children():
		c.queue_free()
	for name in PLACES:
		if name == _from:
			continue                      # 여기 있는데 여기로 갈 순 없다
		var entry: Array = PLACES[name]
		var b := Button.new()
		var been := JourneyState.visited.has(name)
		var unlocked := Quests.is_unlocked(name)
		# 다녀온 곳은 조용히 표시한다. 안 가 본 곳을 굳이 부추기지 않는다.
		var tail := "  ·  " + String(entry[1]) if String(entry[1]) != "" else ""
		if not unlocked:
			# **지운 게 아니라 흐리게.** 다음이 있다는 걸 알아야 기대가
			# 생긴다 — 아예 안 보이면 그냥 이 마을이 끝인 줄 안다.
			tail = "  ·  아직 더 볼 게 있는 것 같다"
		b.text = name + tail
		b.custom_minimum_size = Vector2(0, 84)
		b.add_theme_font_size_override("font_size", 32)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style(b, not been)
		if unlocked:
			b.pressed.connect(_pick.bind(String(entry[0])))
		else:
			# 눌러도 화나지 않게 — 에러도, 안내 팝업도 없이 그냥 그대로다.
			b.disabled = true
			b.modulate.a = 0.55
		_list.add_child(b)
	visible = true


func close() -> void:
	visible = false
	closed.emit()


## 씬 경로로 여행지 이름을 되찾는다.
func _place_name_of(path: String) -> String:
	for n in PLACES:
		if String(PLACES[n][0]) == path:
			return n
	return ""


func _pick(path: String) -> void:
	visible = false
	# 내가 떠나면 여행자도 떠난다.
	JourneyState.move_wanderer(_place_name_of(path), _from)
	# 다음 마을에는 아침에 닿는다. `Place` 가 지도를 깔면서 처리한다.
	JourneyState.arriving = true
	# **도착지**를 적어야 한다. `save_now()` 는 지금 씬을 보는데, 여기서는
	# 아직 떠나기 전 장소다. 그대로 두면 앱이 죽었을 때 이어하기가 방금
	# 떠나온 곳으로 되돌아간다.
	SaveManager.save_game(path)
	chose.emit(path)
	# **페이드를 거쳐 간다.** 게임에서 실제로 쓰는 씬 이동은 여기 하나뿐인데,
	# 이것만 `change_scene_to_file` 로 곧장 넘어가 한 프레임에 툭 바뀌었다.
	# `SceneTransition` 안의 문 여는 소리도 그래서 한 번도 안 났다.
	var st := get_node_or_null("/root/SceneTransition")
	if st != null and st.has_method("go_to"):
		st.go_to(path, "normal")
	else:
		get_tree().change_scene_to_file(path)

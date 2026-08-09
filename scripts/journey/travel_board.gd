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
## **쿼울은 없다.** 회사는 한 번 나오면 돌아가지 않는다.
const PLACES := {
	"쿼릉": ["res://scenes/journey/Gwaeleung.tscn", "바다와 등대"],
	"쿼주": ["res://scenes/journey/Gwaeju.tscn", "낮은 기와지붕"],
	"쿼산": ["res://scenes/journey/Gwaesan.tscn", "비탈진 항구"],
	"쿼도": ["res://scenes/journey/Gwaedo.tscn", "검은 돌담과 바람"],
	"고향": ["res://scenes/journey/Home.tscn", ""],
}

var _panel: PanelContainer
var _list: VBoxContainer
var _from := ""


func _ready() -> void:
	layer = 12
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
		# 다녀온 곳은 조용히 표시한다. 안 가 본 곳을 굳이 부추기지 않는다.
		var tail := "  ·  " + String(entry[1]) if String(entry[1]) != "" else ""
		b.text = ("🏡 " if name == "고향" else "") + name + tail
		b.custom_minimum_size = Vector2(0, 84)
		b.add_theme_font_size_override("font_size", 32)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style(b, not been)
		b.pressed.connect(_pick.bind(String(entry[0])))
		_list.add_child(b)
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _pick(path: String) -> void:
	visible = false
	# 내가 떠나면 여행자도 떠난다.
	JourneyState.move_wanderer()
	SaveManager.save_now()
	chose.emit(path)
	get_tree().change_scene_to_file(path)

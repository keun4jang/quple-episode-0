class_name JourneyHud
extends CanvasLayer
## 화면에 늘 떠 있는 것. **시각과 배낭뿐이다.**
##
## `docs/redesign-journey.md` 9절 — 체력바도 돈도 경험치도 퀘스트 목록도
## 없다. 여행자가 늘 알고 싶은 건 지금 몇 시인지 하나다.

signal bag_toggled(open: bool)

var _clock: Label
var _bag_btn: TextureButton
var _bag_panel: PanelContainer
var _bag_grid: GridContainer
var _hint: Label

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
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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

	var title := Label.new()
	title.text = "배낭"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#FFFDF6"))
	box.add_child(title)

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


func toggle_bag() -> void:
	_bag_panel.visible = not _bag_panel.visible
	if _bag_panel.visible:
		_refill_bag()
	bag_toggled.emit(_bag_panel.visible)


func bag_open() -> bool:
	return _bag_panel != null and _bag_panel.visible


func _refill_bag() -> void:
	for c in _bag_grid.get_children():
		c.queue_free()
	if JourneyState.bag.is_empty():
		var empty := Label.new()
		empty.text = "아직 아무것도 없어요"
		empty.add_theme_font_size_override("font_size", 28)
		empty.add_theme_color_override("font_color", Color("#A79A8A"))
		_bag_grid.add_child(empty)
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


func _on_picked(item: String, _total: int) -> void:
	_hint.text = "%s 을(를) 주웠어요" % NAMES.get(item, item)
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)
	if _bag_panel.visible:
		_refill_bag()


func _process(_delta: float) -> void:
	if _clock != null:
		_clock.text = "%s   %d일째" % [JourneyState.time_text(), JourneyState.day]

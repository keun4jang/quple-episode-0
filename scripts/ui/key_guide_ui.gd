extends CanvasLayer
## 오른쪽 아래 키 안내. 키보드 전용 게임이므로 항상 보인다.

const KEYS := [
	["Space", "조사 / 대화 / 확인"],
	["F", "사진"],
	["D", "바람 노트"],
	["B", "앨범"],
	["Esc", "메뉴"],
]

func _ready() -> void:
	add_to_group("key_guide")
	_build()
	if not SaveManager.game_saved.is_connected(_on_saved):
		SaveManager.game_saved.connect(_on_saved)

## 자동 저장 알림 — 잠깐 떴다가 사라진다
func _on_saved() -> void:
	var toast := Label.new()
	toast.text = "여행 기록 저장 완료"
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color("#FFD76D"))
	toast.add_theme_color_override("font_outline_color", Color(0.09, 0.13, 0.16, 0.9))
	toast.add_theme_constant_override("outline_size", 6)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -120.0
	toast.offset_right = 120.0
	toast.offset_top = 64.0
	toast.offset_bottom = 92.0
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate = Color(1, 1, 1, 0)
	add_child(toast)
	var tw := create_tween()
	tw.tween_property(toast, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.tween_interval(1.6)
	tw.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_callback(toast.queue_free)

func _build() -> void:
	var rows: VBoxContainer = $Panel/Margin/Rows
	for child in rows.get_children():
		child.queue_free()
	for pair in KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var key := Label.new()
		key.text = pair[0]
		key.custom_minimum_size = Vector2(58, 0)
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", Color("#FFD76D"))
		row.add_child(key)
		var desc := Label.new()
		desc.text = pair[1]
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color("#FFF1D0"))
		row.add_child(desc)
		rows.add_child(row)

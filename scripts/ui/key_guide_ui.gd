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

class_name BlessPick
extends CanvasLayer
## 꿈의 탑 - 층을 넘으면 **축복 셋 중 하나**를 고른다 (`Loop.BLESSINGS`).
## 고른 것은 이번에 오르는 동안 쌓인다. 뒤로가기로 닫으면 안 고른 것이다.

signal picked(id: String)

var offer: Array = []


func _ready() -> void:
	layer = 13
	add_to_group("overlay")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.10, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)
	var title := Label.new()
	title.text = "축복을 하나 고르세요"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#B5E3FF"))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "이번에 탑을 오르는 동안 계속 쌓여요  ·  지금 %d개" % Loop.blessings.size()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("#C9BFB2"))
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	box.add_child(row)
	for id in offer:
		var e: Dictionary = Loop.BLESSINGS[String(id)]
		var b := Button.new()
		b.name = "Bless_" + String(id)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(300, 220)
		Paper.button(b, Color("#EAF6FF"), Color("#5AB8FF"), Color("#1E2A3A"))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 14)
		b.add_child(v)
		var have := Loop.blessings.count(String(id))
		for t in [[String(e["name"]) + ("  x%d" % (have + 1) if have > 0 else ""), 30, "#1E4A7A"],
				[String(e["desc"]), 22, "#3A2C2C"]]:
			var l := Label.new()
			l.text = String(t[0])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(270, 0)
			l.add_theme_font_size_override("font_size", int(t[1]))
			l.add_theme_color_override("font_color", Color(String(t[2])))
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
		var which := String(id)
		b.pressed.connect(func() -> void: choose(which))
		row.add_child(b)
	# 들어올 때 살짝 튀어 오른다.
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)


func choose(id: String) -> void:
	AudioManager.ui_confirm()
	Loop.add_blessing(id)
	picked.emit(id)
	queue_free()


## 뒤로가기 - 안 고르고 닫는다.
func close() -> void:
	queue_free()

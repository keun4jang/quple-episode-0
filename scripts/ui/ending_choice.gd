class_name EndingChoice
extends CanvasLayer
## 야근 대마왕을 쓰러뜨리고 깨어난 뒤의 선택 (`docs/redesign-dream.md` 2절 "결").
##
##   사직서를 쓴다    → 현실의 여행으로 (고향 평상 - "진짜 행복" 의 두 번째 자리)
##   오늘도 출근한다  → 꿈결로 돌아가 계속 모험한다 (끝판 뒤의 반복 놀이)
##
## 어느 쪽이 정답이라고 말하지 않는다. 둘 다 이어서 할 수 있다.

signal chose(which: String)


func _ready() -> void:
	layer = 20
	add_to_group("overlay")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)
	for t in [["꿈결 온라인  -  클리어", 48, "#FFD43B"],
			["새벽 여섯 시. 책상 위에서 눈을 떴다.", 28, "#FFF2C8"],
			["손에 반짝이는 조각 하나가 쥐여 있다.", 24, "#C9BFB2"],
			["이제 어떻게 할까?", 30, "#FFFDF6"]]:
		var l := Label.new()
		l.text = String(t[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(t[1]))
		l.add_theme_color_override("font_color", Color(String(t[2])))
		box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	for c in [["사직서를 쓴다", "quit", "#F4EDE2"], ["오늘도 출근한다", "work", "#FFE39A"]]:
		var b := Button.new()
		b.name = "Choice_" + String(c[1])
		b.text = String(c[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(360, 96)
		b.add_theme_font_size_override("font_size", 32)
		Paper.button(b, Color(String(c[2])), Color("#8C7B68"), Color("#3A2C2C"))
		var which := String(c[1])
		b.pressed.connect(func() -> void:
			AudioManager.ui_confirm()
			chose.emit(which)
			queue_free())
		row.add_child(b)
	var sub := Label.new()
	sub.text = "사직서 - 현실로 떠나는 진짜 여행      출근 - 꿈결로 돌아가 계속 모험"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("#A79A8A"))
	box.add_child(sub)

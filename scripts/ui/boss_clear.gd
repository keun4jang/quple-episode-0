class_name BossClear
extends CanvasLayer
## 구역 우두머리를 **처음** 쓰러뜨렸을 때의 승리 판 (`docs/game-design.md` 1절).
##
## 끄는 순간 셋 중 하나가 "번거로울 때" 다 - 우두머리를 잡고 나서 방 → 길 → 마을 →
## 정류장을 되짚어 걸어야 다음 구역에 갔다. 여기서 **바로 다음 구역으로** 간다.
## 받은 것과 다음 장(몇 장·어느 우두머리·권장 레벨)을 보여 줘서, 멈출 틈 없이 다음으로.

signal chose(go_next: bool)

var chapter := 1
var boss_name := ""
var rewards: Array = []        # 한 줄씩
var next_title := ""           # "4장 · 하늬섬 — 태풍 갈매기 (LV 21)" 또는 ""


func _ready() -> void:
	layer = 14
	add_to_group("overlay")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)
	_line(box, "%d장 클리어!" % chapter, 54, "#FFD43B")
	_line(box, "%s 을(를) 쓰러뜨렸어요" % boss_name, 26, "#FFF2C8")
	for r in rewards:
		_line(box, String(r), 22, "#B4E6C0")
	if next_title != "":
		_line(box, " ", 8, "#000000")
		_line(box, "다음  ·  " + next_title, 26, "#8FD0FF")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	box.add_child(row)
	if next_title != "":
		_btn(row, "Next", "다음 구역으로 바로 가기", "#FFE39A", true)
	_btn(row, "Stay", "조금 더 둘러보기" if next_title != "" else "좋아요", "#F4EDE2", false)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)


func _line(box: Control, t: String, size: int, col: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(col))
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
	l.add_theme_constant_override("outline_size", 8)
	box.add_child(l)


func _btn(row: Control, nm: String, t: String, col: String, go: bool) -> void:
	var b := Button.new()
	b.name = nm
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(340, 92)
	b.add_theme_font_size_override("font_size", 28)
	Paper.button(b, Color(col), Color("#8C7B68"), Color("#3A2C2C"))
	b.pressed.connect(func() -> void: pick(go))
	row.add_child(b)


func pick(go_next: bool) -> void:
	AudioManager.ui_confirm()
	chose.emit(go_next)
	queue_free()


## 뒤로가기 - 여기 남는다.
func close() -> void:
	pick(false)

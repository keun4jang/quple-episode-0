class_name FeverFrame
extends Control
## 피버 타임 동안 화면 테두리가 무지개로 돌고, 위에 남은 초가 뜬다 (`Loop.fever_t`).
## 입력은 안 받는다.

const W := 10.0

var _t := 0.0
var _label: Label


func _ready() -> void:
	name = "FeverFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_label.add_theme_constant_override("outline_size", 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -200
	_label.offset_right = 200
	_label.offset_top = 150
	_label.offset_bottom = 190
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	visible = Loop.fever_on()
	if not visible:
		return
	_t += delta
	_label.text = "피버 타임  %d" % int(ceil(Loop.fever_t))
	_label.add_theme_color_override("font_color", Color.from_hsv(fmod(_t * 0.6, 1.0), 0.55, 1.0))
	var s := 1.0 + 0.06 * sin(_t * 10.0)
	_label.pivot_offset = Vector2(200, 20)
	_label.scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var a := 0.55 + 0.25 * sin(_t * 8.0)
	# 네 변을 조각내 빛깔을 흘린다.
	var n := 24
	for i in n:
		var c := Color.from_hsv(fmod(_t * 0.5 + float(i) / n, 1.0), 0.65, 1.0, a)
		var fx := r.size.x / n
		var fy := r.size.y / n
		draw_rect(Rect2(fx * i, 0, fx + 1, W), c)
		draw_rect(Rect2(fx * i, r.size.y - W, fx + 1, W), c)
		draw_rect(Rect2(0, fy * i, W, fy + 1), c)
		draw_rect(Rect2(r.size.x - W, fy * i, W, fy + 1), c)

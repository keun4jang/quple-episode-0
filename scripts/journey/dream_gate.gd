class_name DreamGate
extends Node2D
## 마을 한쪽에 열린 **꿈의 틈** - 우두머리의 길(`BossRoad`)이나 꿈의 탑
## (`TowerFloor`)으로 들어가는 자리. 그림 파일 없이 코드로 그린다.
##
## 가게나 등대처럼 건물이 있는 문이 아니라서, 멀리서도 "저기 뭔가 있다"
## 가 보여야 한다. 그래서 늘 천천히 돌고 빛난다:
##   boss   붉은 틈 + 금관 - 우두머리가 기다린다
##   tower  푸른 틈 + 층층이 쌓인 네모 - 올라가는 곳

## "boss" 또는 "tower".
var kind := "boss"
## 머리 위 이름표.
var title := ""

var _t := 0.0


func _ready() -> void:
	z_index = 2
	var l := Label.new()
	l.name = "GateTag"
	l.text = title
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color",
		Color("#FFB3B3") if kind == "boss" else Color("#B5E3FF"))
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(120, 14)
	l.position = Vector2(-60, -52)
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var core := Color("#3A0F2A") if kind == "boss" else Color("#10213F")
	var rim := Color("#FF5A6E") if kind == "boss" else Color("#5AB8FF")
	var glow := Color(rim.r, rim.g, rim.b, 0.22 + 0.10 * sin(_t * 2.4))
	# 바닥에 드리운 빛 - 틈이 땅에 서 있다.
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 16.0, Color(rim.r, rim.g, rim.b, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 세로로 긴 타원 틈 - 바깥 빛, 테두리, 속.
	var c := Vector2(0, -18)
	draw_set_transform(c, 0.0, Vector2(0.62, 1.0))
	draw_circle(Vector2.ZERO, 20.0, glow)
	draw_circle(Vector2.ZERO, 16.0, rim)
	draw_circle(Vector2.ZERO, 14.0, core)
	# 안에서 도는 소용돌이 - 점 여섯이 두 바퀴 돈다.
	for i in 6:
		var a := _t * 1.8 + TAU * float(i) / 6.0
		var r := 5.0 + 4.0 * float(i % 3)
		draw_circle(Vector2(cos(a), sin(a)) * r, 1.6,
			Color(rim.r, rim.g, rim.b, 0.55 + 0.4 * float(i % 2)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 위에 얹는 표시.
	var top := Vector2(0, -40 + sin(_t * 2.0) * 1.5)
	if kind == "boss":
		# 금관 - 우두머리 몬스터들이 쓴 것과 같은 모양.
		var gold := Color("#FFD43B")
		var crown := PackedVector2Array([
			top + Vector2(-7, 4), top + Vector2(-7, -3), top + Vector2(-3.5, 0),
			top + Vector2(0, -5), top + Vector2(3.5, 0), top + Vector2(7, -3),
			top + Vector2(7, 4)])
		var shadow := PackedVector2Array()
		for p in crown:
			shadow.append(p + Vector2(0, 1.2))
		draw_colored_polygon(shadow, Color(0.12, 0.09, 0.14))
		draw_colored_polygon(crown, gold)
	else:
		# 층층이 쌓인 네모 셋 - 탑.
		for i in 3:
			var w := 12.0 - 3.0 * float(i)
			var r2 := Rect2(top + Vector2(-w * 0.5, 3.0 - 4.0 * float(i)), Vector2(w, 3.5))
			draw_rect(r2.grow(0.8), Color(0.12, 0.09, 0.14))
			draw_rect(r2, Color("#B5E3FF"))

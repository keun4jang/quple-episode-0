extends RefCounted
class_name SideParts
## 옆에서 본 맵을 이루는 조각들. 발판·사다리·계단·엘리베이터·문.
##
## 씬 파일 대신 코드로 세운다. 맵 하나가 파일 스무 개로 흩어지면 고치기가
## 더 어렵고, 이 조각들은 전부 사각형 몇 개와 충돌체 하나가 전부다.

const GRASS := Color("#96C47C")
const SOIL := Color("#A88D62")
const SOIL_DARK := Color("#8C6A4E")
const WOOD := Color("#B08968")
const METAL := Color("#7C8AA0")
const CREAM := Color("#FDFBD4")

## 물리 레이어. 1=지형, 2=한 방향 발판
const L_SOLID := 1
const L_ONEWAY := 2


static func _rect(parent: Node, pos: Vector2, size: Vector2, col: Color, name := "") -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = size
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if name != "":
		r.name = name
	parent.add_child(r)
	return r


## ─── 발판 ───
## 위는 풀·아래는 흙. 이 두 겹이 있어야 "딛는 곳" 으로 읽힌다.
## one_way 면 아래에서 뛰어올라 통과할 수 있다.
## show_art 가 false 면 충돌만 두고 아무것도 그리지 않는다.
##
## 그려 받은 배경에는 바닥이 이미 그려져 있다. 그 위에 코드로 또 바닥을
## 깔면 그림 위에 색 띠가 하나 더 얹힌다 — 복도에서 실제로 갈색 카펫
## 위에 파란 띠가 그어졌다. 딛는 자리는 있어야 하니 충돌만 남긴다.
static func platform(parent: Node, x: float, y: float, w: float, h: float,
		one_way := false, top := GRASS, body := SOIL, show_art := true) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.name = "Platform"
	b.position = Vector2(x, y)
	b.collision_layer = L_ONEWAY if one_way else L_SOLID
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	# 한 방향 발판은 얇게 잡는다. 두꺼우면 밑에서 머리가 걸린다.
	var ch := 16.0 if one_way else h
	rs.size = Vector2(w, ch)
	cs.shape = rs
	cs.position = Vector2(w * 0.5, ch * 0.5)
	cs.one_way_collision = one_way
	b.add_child(cs)
	parent.add_child(b)

	if not show_art:
		return b

	var art := Node2D.new()
	art.name = "Art"
	b.add_child(art)
	if one_way:
		# 공중 발판. 풀만 한 줄 그으면 초록 막대로 보인다 — 밑에 흙을
		# 조금 붙여야 "떠 있는 땅" 으로 읽히고, 두께가 생겨 눈이 딛는
		# 자리를 찾는다.
		_draw_box(art, Vector2(0, 0), Vector2(w, 46), SOIL)
		_draw_box(art, Vector2(0, 30), Vector2(w, 16), SOIL_DARK)
		_draw_box(art, Vector2(0, 0), Vector2(w, 20), top)
		_draw_box(art, Vector2(5, 3), Vector2(w - 10, 6), Color(1, 1, 1, 0.26))
		# 양 끝을 살짝 깎아 막대 느낌을 없앤다
		_draw_box(art, Vector2(0, 36), Vector2(18, 10), Color(0, 0, 0, 0))
		for i in range(int(w / 150.0) + 1):
			_draw_box(art, Vector2(30 + i * 150, 40), Vector2(26, 22), SOIL_DARK)
	else:
		_draw_box(art, Vector2(0, 0), Vector2(w, h), body)
		_draw_box(art, Vector2(0, h * 0.55), Vector2(w, h * 0.45), SOIL_DARK)
		_draw_box(art, Vector2(0, 0), Vector2(w, 26), top)
		_draw_box(art, Vector2(6, 3), Vector2(w - 12, 7), Color(1, 1, 1, 0.22))
	return b


## ─── 계단 ───
## 비스듬한 발판. 진짜 층계를 하나씩 놓으면 걸을 때마다 덜컹거려서,
## 겉모습만 층계로 그리고 실제로 밟는 것은 매끈한 경사면으로 둔다.
static func stairs(parent: Node, x: float, y: float, w: float, h: float,
		steps := 6, up_right := true, top := GRASS, body := SOIL) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.name = "Stairs"
	b.position = Vector2(x, y)
	b.collision_layer = L_SOLID
	var cs := CollisionPolygon2D.new()
	if up_right:
		cs.polygon = PackedVector2Array([Vector2(0, h), Vector2(w, 0), Vector2(w, h + 40), Vector2(0, h + 40)])
	else:
		cs.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, h), Vector2(w, h + 40), Vector2(0, h + 40)])
	b.add_child(cs)
	parent.add_child(b)

	var art := Node2D.new()
	b.add_child(art)
	var sw := w / float(steps)
	var sh := h / float(steps)
	for i in range(steps):
		var sx := i * sw
		var sy := (h - (i + 1) * sh) if up_right else (i * sh)
		_draw_box(art, Vector2(sx, sy), Vector2(sw + 2, h + 40 - sy), body)
		_draw_box(art, Vector2(sx, sy), Vector2(sw + 2, 16), top)
	return b


## ─── 사다리 ───
static func ladder(parent: Node, x: float, top_y: float, height: float, width := 84.0) -> Area2D:
	var a := Area2D.new()
	a.name = "Ladder"
	a.position = Vector2(x, top_y)
	a.monitoring = false      # 사다리는 감지당하는 쪽이다
	a.monitorable = true
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(width * 0.55, height)
	cs.shape = rs
	cs.position = Vector2(0, height * 0.5)
	a.add_child(cs)
	parent.add_child(a)

	var art := Node2D.new()
	a.add_child(art)
	_draw_box(art, Vector2(-width * 0.5, 0), Vector2(14, height), WOOD)
	_draw_box(art, Vector2(width * 0.5 - 14, 0), Vector2(14, height), WOOD)
	var rung := 46.0
	var n := int(height / rung)
	for i in range(n):
		_draw_box(art, Vector2(-width * 0.5, 20 + i * rung), Vector2(width, 12), Color("#C79E76"))
	return a


## ─── 엘리베이터 ───
## 위·아래 두 층을 오간다. 안에서 위나 아래를 누르면 움직인다.
static func elevator(parent: Node, x: float, top_y: float, bottom_y: float, w := 240.0,
		body_col := METAL, hi_col := Color("#9FB0C6"), rail_col := Color("#5E6C80")) -> AnimatableBody2D:
	var b := AnimatableBody2D.new()
	b.name = "Elevator"
	b.position = Vector2(x, bottom_y)
	b.collision_layer = L_SOLID
	b.sync_to_physics = true
	b.set_script(load("res://scripts/side/elevator.gd"))
	b.set("top_y", top_y)
	b.set("bottom_y", bottom_y)

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, 20)
	cs.shape = rs
	b.add_child(cs)

	var art := Node2D.new()
	b.add_child(art)
	_draw_box(art, Vector2(-w * 0.5, -10), Vector2(w, 22), body_col)
	_draw_box(art, Vector2(-w * 0.5, -10), Vector2(w, 7), hi_col)
	_draw_box(art, Vector2(-w * 0.5 + 6, -150), Vector2(10, 142), rail_col)
	_draw_box(art, Vector2(w * 0.5 - 16, -150), Vector2(10, 142), rail_col)

	var rider := Area2D.new()
	rider.name = "Rider"
	rider.collision_mask = 4      # 캐릭터 레이어
	var rcs := CollisionShape2D.new()
	var rrs := RectangleShape2D.new()
	rrs.size = Vector2(w * 0.8, 130)
	rcs.shape = rrs
	rcs.position = Vector2(0, -70)
	rider.add_child(rcs)
	b.add_child(rider)

	parent.add_child(b)
	return b


## ─── 문 ───
## 다음 맵으로 나가는 자리. 밟고 위를 누르면 열린다.
static func door(parent: Node, x: float, floor_y: float, label := "다음 길") -> Area2D:
	var a := Area2D.new()
	a.name = "Door"
	a.position = Vector2(x, floor_y)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(150, 230)
	cs.shape = rs
	cs.position = Vector2(0, -115)
	a.add_child(cs)

	var art := Node2D.new()
	a.add_child(art)
	_draw_box(art, Vector2(-84, -252), Vector2(168, 252), Color("#B08A60"))
	_draw_box(art, Vector2(-66, -232), Vector2(132, 232), Color("#7A96AC"))
	_draw_box(art, Vector2(-52, -214), Vector2(104, 118), Color("#A8C6D6"))
	var l := Label.new()
	l.text = "▲ " + label
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.14))
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(-110, -330)
	l.size = Vector2(220, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.add_child(l)

	parent.add_child(a)
	return a


## Node2D 밑에 색 사각형을 그린다. ColorRect 는 Control 이라 Node2D 밑에서도
## 좌표가 그대로 통한다 — 맵 조각 정도에는 이게 제일 짧다.
static func _draw_box(parent: Node, pos: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

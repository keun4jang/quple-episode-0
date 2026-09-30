class_name WornGear
extends Node2D
## 쿼카가 몸에 걸친 것 (`Gear.worn`) - 모자·옷·장갑·신발·반지·목걸이·팔찌·망토.
##
## **입은 것이 몸에서 보여야 한다.** 무기만 그려졌을 때 "전설을 뽑았는데 캐릭터가 똑같다"는
## 말이 나왔다. 그림 파일 없이 작은 도형으로 덧그린다 (`HeldWeapon` 과 같은 방식). 걷기 그림은
## 17 x 25 이고 발끝이 원점이다 - 머리 꼭대기는 y -24, 어깨 -14, 손 -8, 발 0.
##
## 빛깔은 **단계**(나무·쇠·은빛·용맹·꿈결)가, 보석 반짝임은 **등급** 빛깔이 정한다.
## 망토는 몸 **뒤에** 그린다(앞·옆) - 뒷모습에서는 등을 덮는다.

## 단계마다 천·가죽 빛깔.
const CLOTH := ["#B98B5E", "#8FA3B8", "#B7C9E8", "#E8B84A", "#B79BEB"]
const EDGE := Color(0.12, 0.09, 0.14, 0.9)

var _sig := ""
var _back: Node2D


func _ready() -> void:
	name = "WornGear"
	# 망토는 몸 **뒤에** - 부모가 Y 정렬이라 z_index 는 안 통하고(바닥 밑으로 들어간다),
	# 스프라이트보다 **먼저** 놓인 노드여야 뒤에 깔린다 (`QuoWalker` 테두리와 같은 까닭).
	_back = Node2D.new()
	_back.name = "WornCape"
	_back.draw.connect(_draw_back)
	_attach_back.call_deferred()
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_back):
			_back.queue_free())


func _attach_back() -> void:
	var w := get_parent() as QuoWalker
	if w == null or w.sprite == null or not is_instance_valid(_back):
		return
	w.add_child(_back)
	w.move_child(_back, w.sprite.get_index())


func _process(_delta: float) -> void:
	var w := get_parent() as QuoWalker
	if w == null or w.sprite == null:
		return
	var parts: Array = [w.sprite.row(), w.sprite.flip_h]
	var shiny := false
	for slot in Gear.SLOTS:
		if slot == "weapon":
			continue
		var it := Gear.worn(String(slot))
		if it.is_empty():
			parts.append("-")
			continue
		parts.append("%s.%s.%s" % [it.get("tier", 0), it.get("rar", 0), it.get("plus", 0)])
		if int(it.get("rar", 0)) >= 3:
			shiny = true
	var sig := "|".join(parts.map(func(x): return str(x)))
	if sig != _sig or shiny:
		_sig = sig
		queue_redraw()
		_back.queue_redraw()


func _row() -> int:
	var w := get_parent() as QuoWalker
	return w.sprite.row() if w != null and w.sprite != null else QuoSprite.ROW_DOWN


## 옆모습에서 바라보는 쪽 (+1 오른쪽, -1 왼쪽).
func _side() -> float:
	var w := get_parent() as QuoWalker
	if w == null or w.sprite == null:
		return 1.0
	return 1.0 if w.sprite.flip_h else -1.0


func _col(slot: String) -> Color:
	var it := Gear.worn(slot)
	if it.is_empty():
		return Color.TRANSPARENT
	return Color(String(CLOTH[clampi(int(it["tier"]), 0, CLOTH.size() - 1)]))


func _gem(slot: String) -> Color:
	var it := Gear.worn(slot)
	var c := Gear.rarity_col(it) if not it.is_empty() else Color.WHITE
	# 등급이 높을수록 반짝인다.
	var rar := int(it.get("rar", 0)) if not it.is_empty() else 0
	if rar >= 3:
		c = c.lightened(0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)))
	return c


func _shoe(at: Vector2, c: Color) -> void:
	draw_rect(Rect2(at.x - 2.6, at.y - 1.2, 5.2, 3.2), EDGE)
	draw_rect(Rect2(at.x - 2.1, at.y - 0.8, 4.2, 2.4), c)
	draw_rect(Rect2(at.x - 2.1, at.y + 1.0, 4.2, 0.8), c.darkened(0.35))


# ── 몸 뒤 (망토) ─────────────────────────────────────────────────────

func _draw_back() -> void:
	var c := _col("cape")
	if c.a == 0.0:
		return
	var row := _row()
	if row == QuoSprite.ROW_UP:
		return   # 뒷모습에서는 몸 위에 그린다 (`_draw`)
	var e := c.darkened(0.35)
	if row == QuoSprite.ROW_SIDE:
		# 걷는 반대쪽으로 자락이 늘어진다.
		var s := -_side()
		var pts := PackedVector2Array([Vector2(s * 1.0, -14), Vector2(s * 3.0, -14),
			Vector2(s * 10.5, -4), Vector2(s * 4.0, -2)])
		_back.draw_colored_polygon(pts, c)
		_back.draw_polyline(PackedVector2Array([pts[1], pts[2], pts[3]]), e, 1.0)
	else:
		var pts := PackedVector2Array([Vector2(-5, -14), Vector2(5, -14),
			Vector2(9.5, -2.5), Vector2(-9.5, -2.5)])
		_back.draw_colored_polygon(pts, c)
		_back.draw_polyline(PackedVector2Array([pts[0], pts[3], pts[2], pts[1]]), e, 1.0)


# ── 몸 앞 ────────────────────────────────────────────────────────────

func _draw() -> void:
	var row := _row()
	var side := row == QuoSprite.ROW_SIDE
	var s := _side()
	# 옷 - 몸통을 덮는 조끼.
	var top := _col("top")
	if top.a > 0.0 and row != QuoSprite.ROW_UP:
		var half := 3.6 if side else 5.0
		var r := Rect2(-half, -13.5, half * 2.0, 6.5)
		draw_rect(r, Color(top, 0.62))
		draw_rect(r, top.darkened(0.4), false, 1.0)
		draw_line(Vector2(0, -13.5), Vector2(0, -7), top.darkened(0.3), 1.0)
	elif top.a > 0.0:
		var rb := Rect2(-5.0, -13.5, 10.0, 6.5)
		draw_rect(rb, Color(top, 0.7))
		draw_rect(rb, top.darkened(0.4), false, 1.0)
	# 망토 - 뒷모습에서는 등을 덮는다.
	var cape := _col("cape")
	if cape.a > 0.0 and row == QuoSprite.ROW_UP:
		var pts := PackedVector2Array([Vector2(-5.5, -14), Vector2(5.5, -14),
			Vector2(9.0, -2.5), Vector2(-9.0, -2.5)])
		draw_colored_polygon(pts, cape)
		draw_polyline(PackedVector2Array([pts[0], pts[3], pts[2], pts[1], pts[0]]),
			cape.darkened(0.4), 1.0)
	# 신발
	var shoes := _col("shoes")
	if shoes.a > 0.0:
		if side:
			_shoe(Vector2(s * 1.5, -1.5), shoes)
		else:
			_shoe(Vector2(-3.4, -1.5), shoes)
			_shoe(Vector2(3.4, -1.5), shoes)
	# 장갑 · 팔찌 · 반지 - 손 자리
	var hands: Array = []
	if side:
		hands = [Vector2(-s * 0.5, -8.5)]
	elif row == QuoSprite.ROW_UP:
		hands = [Vector2(-6.6, -8.5), Vector2(6.6, -8.5)]
	else:
		hands = [Vector2(-6.8, -8.5), Vector2(6.8, -8.5)]
	var gl := _col("gloves")
	var wr := _col("wrist")
	var rg := _col("ring")
	for i in hands.size():
		var h: Vector2 = hands[i]
		if gl.a > 0.0:
			draw_circle(h, 2.2, EDGE)
			draw_circle(h, 1.7, gl)
		if wr.a > 0.0:
			draw_line(h + Vector2(-2, -1.6), h + Vector2(2, -1.6), EDGE, 2.2)
			draw_line(h + Vector2(-1.8, -1.6), h + Vector2(1.8, -1.6), wr.lightened(0.15), 1.2)
			if i == hands.size() - 1:
				draw_circle(h + Vector2(0, -1.6), 0.9, _gem("wrist"))
		if rg.a > 0.0 and i == 0:
			# 반지는 아주 작은 알 하나 - 손 아래 가락지.
			draw_circle(h + Vector2(0, 1.6), 1.0, EDGE)
			draw_circle(h + Vector2(0, 1.6), 0.6, _gem("ring"))
	# 목걸이 - 목에 두른 줄과 알.
	var nk := _col("neck")
	if nk.a > 0.0 and row != QuoSprite.ROW_UP:
		var cx := -s * 0.6 if side else 0.0
		draw_arc(Vector2(cx, -15.2), 3.4, 0.25, PI - 0.25, 8, EDGE, 2.0)
		draw_arc(Vector2(cx, -15.2), 3.4, 0.25, PI - 0.25, 8, nk.lightened(0.2), 1.0)
		draw_circle(Vector2(cx, -11.6), 1.5, EDGE)
		draw_circle(Vector2(cx, -11.6), 1.0, _gem("neck"))
	# 모자 - 머리 위에 얹는다 (걷기 그림의 모자 위에 한 겹 더).
	var hat := _col("hat")
	if hat.a > 0.0:
		var hw := 5.0 if not side else 4.2
		var cxh := 0.0
		draw_rect(Rect2(cxh - hw - 1.0, -24.0, hw * 2.0 + 2.0, 2.0), EDGE)
		draw_rect(Rect2(cxh - hw - 0.5, -24.0, hw * 2.0 + 1.0, 1.4), hat.darkened(0.15))
		draw_rect(Rect2(cxh - hw + 1.0, -27.0, hw * 2.0 - 2.0, 3.4), EDGE)
		draw_rect(Rect2(cxh - hw + 1.6, -26.4, hw * 2.0 - 3.2, 2.6), hat)
		if row != QuoSprite.ROW_UP:
			draw_circle(Vector2(cxh, -25.0), 0.8, _gem("hat"))

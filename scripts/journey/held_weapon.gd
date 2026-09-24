class_name HeldWeapon
extends Node2D
## 쿼카가 손에 든 무기 (`Gear.worn("weapon")`).
##
## **무엇을 들었는지 몸에서 보여야 한다** - 장비 창에서만 보이면 새 무기를
## 들어도 달라진 게 없다. 그림 파일 없이 선과 원으로 그린다: 막대기·검·
## 지팡이·활·단검. 쇠붙이 빛깔은 단계(나무·쇠·은빛·용맹·꿈결), 끝의 빛은
## 속성 빛깔이다. 공격하면 한 번 크게 휘두른다(`swing`).
##
## 보는 쪽에 따라 자리를 옮긴다 - 뒤를 보면 몸 뒤로 숨는다.

## 단계마다 쇠붙이 빛깔.
const METAL := ["#C8A77A", "#ADB5BD", "#E7F5FF", "#FFD43B", "#D0BFFF"]

var _swing := 0.0
var _sig := ""


func _ready() -> void:
	name = "HeldWeapon"
	z_as_relative = true


func swing() -> void:
	_swing = 1.0


func _process(delta: float) -> void:
	_swing = maxf(0.0, _swing - delta / 0.2)
	var w := get_parent() as QuoWalker
	if w == null or w.sprite == null:
		return
	var row := w.sprite.row()
	var face := 0.0
	match row:
		QuoSprite.ROW_UP:
			position = Vector2(-5, -9)
			z_index = -1
			face = -0.3
		QuoSprite.ROW_SIDE:
			var right := w.sprite.flip_h
			position = Vector2(6 if right else -6, -8)
			z_index = 1
			face = 0.6 if right else -0.6
		_:
			position = Vector2(6, -7)
			z_index = 1
			face = 0.35
	# 휘두름: 뒤로 젖혔다가 앞으로 내리친다.
	var s := _swing
	var arc := 0.0
	if s > 0.0:
		arc = (-1.4 + 2.6 * (1.0 - s)) * (1.0 if face >= 0.0 else -1.0)
	rotation = face + arc
	var it := Gear.worn("weapon")
	var sig := "%s|%s|%s" % [it.get("kind", ""), it.get("tier", 0), it.get("elem", "")]
	if sig != _sig or s > 0.0:
		_sig = sig
		queue_redraw()


func _draw() -> void:
	var it := Gear.worn("weapon")
	if it.is_empty():
		return
	var kind := String(it["kind"])
	var metal := Color(String(METAL[clampi(int(it["tier"]), 0, METAL.size() - 1)]))
	var el := String(it.get("elem", "none"))
	var glow := Battle.elem_col(el)
	var wood := Color("#8C6E3F")
	var edge := Color(0.12, 0.09, 0.14, 0.9)
	match kind:
		"stick":
			draw_line(Vector2(0, 2), Vector2(0, -10), edge, 3.0)
			draw_line(Vector2(0, 2), Vector2(0, -10), metal, 1.6)
		"sword":
			draw_line(Vector2(0, 2), Vector2(0, -12), edge, 3.2)
			draw_line(Vector2(0, -1), Vector2(0, -12), metal, 1.8)
			draw_line(Vector2(0, 2), Vector2(0, -1), wood, 1.8)
			draw_line(Vector2(-3, -1), Vector2(3, -1), metal.darkened(0.2), 1.5)
		"staff":
			draw_line(Vector2(0, 3), Vector2(0, -11), edge, 3.0)
			draw_line(Vector2(0, 3), Vector2(0, -11), wood.lightened(0.2), 1.6)
			draw_circle(Vector2(0, -13), 3.0, edge)
			draw_circle(Vector2(0, -13), 2.2, metal if el == "none" else glow)
		"bow":
			draw_arc(Vector2(-3, -4), 7.0, -1.2, 1.2, 10, edge, 3.0)
			draw_arc(Vector2(-3, -4), 7.0, -1.2, 1.2, 10, metal, 1.6)
			draw_line(Vector2(-3, -4) + Vector2.from_angle(-1.2) * 7.0,
				Vector2(-3, -4) + Vector2.from_angle(1.2) * 7.0, Color(1, 1, 1, 0.8), 0.8)
		"dagger":
			draw_line(Vector2(0, 2), Vector2(0, -7), edge, 3.0)
			draw_line(Vector2(0, 0), Vector2(0, -7), metal, 1.6)
			draw_line(Vector2(0, 2), Vector2(0, 0), wood, 1.6)
	# 속성이 있으면 끝이 그 빛깔로 반짝인다.
	if el != "none" and kind != "staff":
		var tip := Vector2(0, -12) if kind in ["sword", "stick"] else Vector2(0, -7)
		if kind == "bow":
			tip = Vector2(4, -4)
		var g := glow
		g.a = 0.55 + 0.35 * sin(Time.get_ticks_msec() / 150.0)
		draw_circle(tip, 1.8, g)
	# 휘두를 때 궤적
	if _swing > 0.0:
		var c := glow if el != "none" else Color(1, 1, 1)
		c.a = _swing * 0.6
		draw_arc(Vector2.ZERO, 11.0, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 10, c, 2.0)

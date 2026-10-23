class_name LaneField
extends Node2D
## 싸움터 바닥: 원근이 있는 한 줄 길, 위 쿼카 성, 아래 벌레 둥지. 그림 파일 없이 그린다.
## 쿼카가 화면 아래(카메라 쪽)로 걸어와 얼굴이 보이게 우리 성을 위에 둔다 - 위가 먼 쪽(작고 좁다).
## 길 위치(0~LEN)를 화면 좌표로 바꾸는 것도 여기서 한다 - 그림과 판정이 같은 식을 쓴다.

var size := Vector2(720, 1280)
var y_front := 250.0           ## 쿼카 성 바로 앞 (길의 0, 화면 위쪽)
var y_far := 880.0             ## 둥지 앞 (길의 끝, 화면 아래쪽)
## 성은 먼 쪽이라 작게 그린다.
const FORT_SCALE := 0.7
var theme_col := Color("#9CC76A")
var lane_col := Color("#D9B98A")
var our_ratio := 1.0
var nest_ratio := 1.0
var our_text := ""
var _font: Font
var shake_our := 0.0
var shake_nest := 0.0
var _t := 0.0


func t_of(pos: float) -> float:
	return clampf(pos / LaneData.LEN, 0.0, 1.0)


## 길 위치 0(우리 성, 멂)~1(둥지, 가까움) → 화면 위~아래 비율. 먼 위쪽을 조금 눌러 깊이가 느껴지게.
func ease_depth(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * 1.35 / (1.0 + 0.35 * u)


func to_screen(pos: float, lateral: float) -> Vector2:
	var t := t_of(pos)
	var y := lerpf(y_front, y_far, ease_depth(t))
	return Vector2(size.x * 0.5 + lateral * scale_at(pos), y)


## 원근: 먼 위쪽(우리 성)이 작고, 가까운 아래쪽(둥지)이 크다.
func scale_at(pos: float) -> float:
	return lerpf(0.62, 1.0, t_of(pos))


func half_width(t: float) -> float:
	return lerpf(size.x * 0.12, size.x * 0.34, ease_depth(t))


## 우리 성 망루 발치 (효과·대포가 나가는 곳).
func fort_pos() -> Vector2:
	return Vector2(size.x * 0.5, y_front - 10.0)


## 둥지 가운데 (흙더미 밑동).
func nest_pos() -> Vector2:
	return Vector2(size.x * 0.5, y_far + 60.0)


func _process(dt: float) -> void:
	_t += dt
	shake_our = maxf(0.0, shake_our - dt * 30.0)
	shake_nest = maxf(0.0, shake_nest - dt * 30.0)
	queue_redraw()


func _draw() -> void:
	# 길 (사다리꼴) - 가장자리 띠 + 바퀴 자국 + 돌멩이
	var cx := size.x * 0.5
	var n := 24
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var y := lerpf(y_front - 40.0, y_far + 70.0, ease_depth(t))
		var hw := half_width(t) * (1.0 + 0.04 * sin(t * 9.0 + 1.0))
		left.append(Vector2(cx - hw, y))
		right.append(Vector2(cx + hw, y))
	var poly := PackedVector2Array()
	poly.append_array(left)
	var rr := right.duplicate()
	rr.reverse()
	poly.append_array(rr)
	draw_colored_polygon(poly, lane_col)
	for side in [left, right]:
		draw_polyline(side, lane_col.darkened(0.25), 6.0, true)
	for i in 16:
		var t := fposmod(float(i) / 16.0, 1.0)
		var p := to_screen(t * LaneData.LEN, (sin(i * 7.3) * 0.6) * half_width(t) / scale_at(t * LaneData.LEN))
		draw_circle(p, 3.0 * scale_at(t * LaneData.LEN) + 1.0, lane_col.darkened(0.18))
	_draw_fort()
	_draw_nest()


func _draw_nest() -> void:
	var c := nest_pos() + Vector2(randf_range(-1, 1) * shake_nest, 0.0)
	var r := 92.0
	# 흙더미
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		var rad := r * (1.0 + 0.08 * sin(i * 2.7))
		pts.append(c + Vector2(cos(a) * rad * 1.25, sin(a) * rad * 0.9))
	draw_colored_polygon(pts, Color("#6B4A33"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -20), c + Vector2(-30, -70), c + Vector2(10, -78),
		c + Vector2(50, -60), c + Vector2(80, -18)]), Color("#82593C"))
	# 구멍과 빛나는 눈들
	for k in 3:
		var h := c + Vector2(-50 + k * 50, -26 - (k % 2) * 22)
		draw_set_transform(h, 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 14.0, Color("#2A1A14"))
		draw_set_transform(Vector2.ZERO)
		var blink := sin(_t * 1.7 + k * 2.1) > -0.85
		if blink:
			draw_circle(h + Vector2(-4, -1), 2.2, Color("#FF5A5A"))
			draw_circle(h + Vector2(4, -1), 2.2, Color("#FF5A5A"))
	# 체력 띠 (흙더미 밑, 아래 판 바로 위)
	var bw := 180.0
	var bp := c + Vector2(-bw * 0.5, 8)
	draw_rect(Rect2(bp - Vector2(3, 3), Vector2(bw + 6, 16)), Color(0.1, 0.06, 0.1, 0.8))
	draw_rect(Rect2(bp, Vector2(bw * nest_ratio, 10)), Color("#FF5A6A"))


func _draw_fort() -> void:
	# 먼 쪽이라 작게: 망루 발치(울타리 밑)를 원점으로 두고 줄여 그린다
	draw_set_transform(fort_pos() + Vector2(randf_range(-1, 1) * shake_our, 0.0), 0.0, Vector2(FORT_SCALE, FORT_SCALE))
	var c := Vector2.ZERO
	# 나무 울타리
	for i in 13:
		var x := c.x - 210.0 + i * 35.0
		var hgt := 54.0 + (i % 2) * 8.0
		draw_rect(Rect2(x - 13, c.y - hgt, 26, hgt + 20), Color("#A9754A"))
		draw_rect(Rect2(x - 13, c.y - hgt, 6, hgt + 20), Color("#C99466"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 13, c.y - hgt), Vector2(x, c.y - hgt - 14),
			Vector2(x + 13, c.y - hgt)]), Color("#8E5E38"))
	draw_rect(Rect2(c.x - 220, c.y - 22, 440, 10), Color("#6E4628"))
	# 가운데 망루 + 쿼카 깃발
	draw_rect(Rect2(c.x - 46, c.y - 128, 92, 120), Color("#C48A58"))
	draw_rect(Rect2(c.x - 46, c.y - 128, 18, 120), Color("#DDA676"))
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 62, c.y - 128), Vector2(c.x, c.y - 178),
		Vector2(c.x + 62, c.y - 128)]), Color("#D9543F"))
	draw_rect(Rect2(c.x - 16, c.y - 92, 32, 40), Color("#5A3A26"))
	draw_circle(Vector2(c.x, c.y - 92), 16.0, Color("#5A3A26"))
	draw_line(Vector2(c.x, c.y - 178), Vector2(c.x, c.y - 226), Color("#5A3A26"), 4.0)
	var wave := sin(_t * 4.0) * 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(c.x + 2, c.y - 226), Vector2(c.x + 46, c.y - 214 + wave),
		Vector2(c.x + 2, c.y - 200)]), Color("#FFD15A"))
	draw_circle(Vector2(c.x + 18, c.y - 213 + wave * 0.5), 5.0, Color("#B8784F"))
	draw_set_transform(Vector2.ZERO)

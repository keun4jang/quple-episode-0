class_name LaneWheel
extends Control
## 행운 룰렛 그림. 한 칸 = 친구 한 명, 칸 크기 = 나올 확률 (`LaneState.wheel_slices`).
## 위쪽 바늘이 가리키는 칸이 뽑힌 친구다. spin_to(id) 로 돌리고, 멈추면 `stopped`.
## 그림 파일 없이 그린다 - 칸 색은 등급 색, 얼굴은 친구 그림의 첫 칸.

signal stopped

var slices: Array = []        ## [{id, rarity, share}]
var rot := 0.0                ## 바퀴가 돈 각 (라디안, 시계 방향)
var idle_spin := 0.0          ## 가만히 있을 때 천천히 도는 빠르기 (라디안/초)
var _faces := {}              ## id → [Texture2D, Rect2]
var _tw: Tween
var _last_tick := -1
var _spinning := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slices.is_empty():
		slices = LaneState.wheel_slices()
	for s in slices:
		var id := String(s["id"])
		var tex := load(LaneData.sheet_path(id, maxi(1, LaneState.level_of(id)))) as Texture2D
		if tex != null:
			var w := tex.get_width() / 4.0
			var h := tex.get_height() / 3.0
			var pad := maxf(0.0, h - w)
			_faces[id] = [tex, Rect2(0, pad, w, h - pad)]


func _process(dt: float) -> void:
	if not _spinning and idle_spin != 0.0:
		rot = fmod(rot + idle_spin * dt, TAU)
	if _spinning:
		# 바늘이 칸 경계를 넘을 때마다 딸깍 (너무 잦으면 건너뛴다)
		var k := _slice_at_pointer()
		if k != _last_tick:
			_last_tick = k
			AudioManager.ui_click()
	queue_redraw()


## 칸 시작 각(바퀴 기준, 12시에서 시계 방향).
func _starts() -> Array:
	var out: Array = []
	var a := 0.0
	for s in slices:
		out.append(a)
		a += float(s["share"]) * TAU
	return out


func _slice_at_pointer() -> int:
	# 바늘은 12시에 고정, 바퀴가 rot 만큼 돌았으니 바퀴 기준 각은 -rot
	var a := fposmod(-rot, TAU)
	var st := _starts()
	for k in range(slices.size() - 1, -1, -1):
		if a >= float(st[k]):
			return k
	return 0


## id 칸에 바늘이 서도록 돌린다. 칸 안 어디에 설지는 rng 로 (가운데만 고르면 뻔하다).
func spin_to(id: String, rng: RandomNumberGenerator, dur := 2.4) -> void:
	var st := _starts()
	var k := 0
	for i in slices.size():
		if String(slices[i]["id"]) == id:
			k = i
	var w := float(slices[k]["share"]) * TAU
	var inside := float(st[k]) + w * rng.randf_range(0.18, 0.82)
	# 바퀴 기준 inside 가 12시에 오려면 rot = -inside (+ 여러 바퀴)
	var target := -inside
	while target < rot + TAU * 4.0:
		target += TAU
	_spinning = true
	_last_tick = _slice_at_pointer()
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "rot", target, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func() -> void:
		_spinning = false
		stopped.emit())


## 남은 회전을 건너뛰고 바로 멈춘다.
func finish_now() -> void:
	if _tw != null and _tw.is_running():
		_tw.custom_step(99.0)


func is_spinning() -> bool:
	return _spinning


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 18.0
	if r <= 10.0 or slices.is_empty():
		return
	var ink := Color("#3B2350")
	draw_circle(c, r + 14.0, ink)
	draw_circle(c, r + 8.0, Color("#FFF4FA"))
	var st := _starts()
	for k in slices.size():
		var s: Dictionary = slices[k]
		var a0 := float(st[k])
		var a1 := a0 + float(s["share"]) * TAU
		var col: Color = LaneData.RARITY_COL[String(s["rarity"])]
		if k % 2 == 1:
			col = col.lightened(0.18)
		var pts := PackedVector2Array([c])
		var n := maxi(2, int((a1 - a0) / 0.05))
		for i in n + 1:
			pts.append(c + _dir(a0 + (a1 - a0) * float(i) / float(n)) * r)
		draw_colored_polygon(pts, col)
		draw_line(c, c + _dir(a0) * r, ink, 2.0, true)
		# 얼굴 - 칸이 좁으면 작게, 아주 좁으면(전설) 테두리 밖에 별만
		var mid := (a0 + a1) * 0.5
		var span := (a1 - a0) * r * 0.62
		var fs := clampf(span, 0.0, r * 0.3)
		var id := String(s["id"])
		if fs >= 26.0 and _faces.has(id):
			var f: Array = _faces[id]
			var p := c + _dir(mid) * r * 0.68
			var mod := Color.WHITE if LaneState.has_unit(id) else Color(0.25, 0.16, 0.35, 0.85)
			draw_texture_rect_region(f[0], Rect2(p - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), f[1], mod)
		if String(s["rarity"]) == "legend":
			_star(c + _dir(mid) * (r + 1.0), 9.0, Color("#FFFFFF"), ink)
	draw_arc(c, r, 0.0, TAU, 96, ink, 3.0, true)
	draw_circle(c, r * 0.16, ink)
	draw_circle(c, r * 0.16 - 5.0, Color("#FFB6C8"))
	# 바늘 (12시, 아래를 가리킨다)
	var top := c + Vector2(0, -r - 20.0)
	var needle := PackedVector2Array([top + Vector2(-22, -8), top + Vector2(22, -8), top + Vector2(0, 40)])
	var outline := PackedVector2Array([top + Vector2(-28, -13), top + Vector2(28, -13), top + Vector2(0, 48)])
	draw_colored_polygon(outline, ink)
	draw_colored_polygon(needle, Color("#FF6FA8"))


## 바퀴 기준 각 a (12시에서 시계 방향) → 화면 방향. 바퀴가 rot 만큼 돌았다.
func _dir(a: float) -> Vector2:
	return Vector2.from_angle(a + rot - PI * 0.5)


func _star(p: Vector2, rr: float, col: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	var big := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		var q := rr if i % 2 == 0 else rr * 0.45
		pts.append(p + Vector2.from_angle(a) * q)
		big.append(p + Vector2.from_angle(a) * (q + 3.0))
	draw_colored_polygon(big, ink)
	draw_colored_polygon(pts, col)

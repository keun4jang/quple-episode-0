class_name IdleFx
extends Node2D
## 전투 효과 - 파편·베기·충격파·화살·별똥별·빛기둥·튀어오르는 숫자. 그림 파일 없이 전부 그린다.
## 모든 효과는 `delay` 초 뒤에 시작할 수 있다 (별똥별이 떨어진 뒤에 숫자가 뜨게).

var font: Font
var _parts: Array = []
var _slashes: Array = []
var _rings: Array = []
var _texts: Array = []
var _bolts: Array = []
var _pillars: Array = []


func _ready() -> void:
	var th := load("res://assets/themes/quple_bold.tres") as Theme
	font = th.default_font if th != null and th.default_font != null else ThemeDB.fallback_font


## 사방(up 이면 위쪽)으로 튀는 조각들. to 를 주면 잠깐 튄 뒤 그쪽으로 빨려 간다 (꿈조각).
func burst(p: Vector2, col: Color, n := 14, speed := 340.0, sz := 8.0, life := 0.55, g := 900.0,
		shape := "sq", delay := 0.0, up := false, to := Vector2.INF) -> void:
	for i in n:
		var a := randf() * TAU
		if up:
			a = -PI * 0.5 + randf_range(-0.9, 0.9)
		var s := speed * randf_range(0.4, 1.0)
		_parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * s, "life": 0.0,
			"max": life * randf_range(0.7, 1.25), "size": sz * randf_range(0.6, 1.25), "col": col,
			"shape": shape, "g": g, "delay": delay + (randf() * 0.05 if to != Vector2.INF else 0.0),
			"rot": randf() * TAU, "to": to})


## 초승달 모양 베기. ang 은 베는 방향(라디안).
func slash(p: Vector2, ang: float, r: float, col: Color, w := 16.0, life := 0.22, delay := 0.0) -> void:
	_slashes.append({"p": p, "ang": ang, "r": r, "col": col, "w": w, "life": 0.0, "max": life, "delay": delay})


func ring(p: Vector2, r0: float, r1: float, col: Color, w := 10.0, life := 0.38, delay := 0.0) -> void:
	_rings.append({"p": p, "r0": r0, "r1": r1, "col": col, "w": w, "life": 0.0, "max": life, "delay": delay})


func text(p: Vector2, t: String, col: Color, fs := 40, life := 0.9, delay := 0.0, rise := 70.0) -> void:
	_texts.append({"p": p, "t": t, "col": col, "fs": fs, "life": 0.0, "max": life, "delay": delay, "rise": rise})


func arrow(a: Vector2, b: Vector2, col: Color, life := 0.14, delay := 0.0) -> void:
	_bolts.append({"a": a, "b": b, "col": col, "life": 0.0, "max": life, "delay": delay, "kind": "arrow"})


## 하늘에서 별똥별이 떨어진다. 떨어지는 순간 터진다.
func meteor(a: Vector2, b: Vector2, col: Color, life := 0.32) -> void:
	_bolts.append({"a": a, "b": b, "col": col, "life": 0.0, "max": life, "delay": 0.0, "kind": "meteor"})
	ring(b, 20.0, 230.0, col, 14.0, 0.45, life)
	ring(b, 10.0, 140.0, Color.WHITE, 8.0, 0.3, life)
	burst(b, col, 26, 520.0, 11.0, 0.7, 700.0, "star", life)
	burst(b, Color.WHITE, 14, 380.0, 7.0, 0.5, 600.0, "sq", life)


func pillar(p: Vector2, col: Color, life := 1.0) -> void:
	_pillars.append({"p": p, "col": col, "life": 0.0, "max": life, "delay": 0.0})


func _process(dt: float) -> void:
	for arr in [_parts, _slashes, _rings, _texts, _bolts, _pillars]:
		var keep: Array = []
		for e in arr:
			if float(e["delay"]) > 0.0:
				e["delay"] = float(e["delay"]) - dt
				keep.append(e)
				continue
			e["life"] = float(e["life"]) + dt
			if e.has("v"):
				var to: Vector2 = e["to"]
				if to != Vector2.INF and float(e["life"]) > 0.22:
					e["p"] = (e["p"] as Vector2).lerp(to, 1.0 - exp(-9.0 * dt))
					if (e["p"] as Vector2).distance_to(to) < 18.0:
						continue
				else:
					var v: Vector2 = e["v"]
					v.y += float(e["g"]) * dt
					v *= 1.0 - minf(0.9, 2.2 * dt)
					e["v"] = v
					e["p"] = (e["p"] as Vector2) + v * dt
					e["rot"] = float(e["rot"]) + dt * 8.0
				if to != Vector2.INF:
					keep.append(e)
					continue
			if float(e["life"]) < float(e["max"]):
				keep.append(e)
		arr.clear()
		arr.append_array(keep)
	queue_redraw()


func _k(e: Dictionary) -> float:
	return clampf(float(e["life"]) / float(e["max"]), 0.0, 1.0)


func _draw() -> void:
	for e in _pillars:
		if float(e["delay"]) > 0.0:
			continue
		var k := _k(e)
		var p: Vector2 = e["p"]
		var col: Color = e["col"]
		var a := sin(k * PI)
		var wid := 90.0 * (1.0 - k * 0.5)
		draw_rect(Rect2(p.x - wid * 0.5, p.y - 900, wid, 900), Color(col, 0.30 * a))
		draw_rect(Rect2(p.x - wid * 0.18, p.y - 900, wid * 0.36, 900), Color(1, 1, 1, 0.45 * a))
	for e in _rings:
		if float(e["delay"]) > 0.0:
			continue
		var k := _k(e)
		var r := lerpf(float(e["r0"]), float(e["r1"]), 1.0 - pow(1.0 - k, 3.0))
		draw_arc(e["p"], r, 0.0, TAU, 48, Color(e["col"], 1.0 - k), maxf(1.0, float(e["w"]) * (1.0 - k)), true)
	for e in _slashes:
		if float(e["delay"]) > 0.0:
			continue
		var k := _k(e)
		var arc := 2.2
		var start := float(e["ang"]) - arc * 0.5
		var sweep := arc * minf(1.0, k * 3.0)
		var col: Color = e["col"]
		var wd := float(e["w"]) * (1.0 - k)
		if wd > 0.5:
			draw_arc(e["p"], float(e["r"]), start, start + sweep, 24, Color(col, 1.0 - k * k), wd, true)
			draw_arc(e["p"], float(e["r"]) - wd * 0.3, start, start + sweep, 24, Color(1, 1, 1, 1.0 - k), wd * 0.35, true)
	for e in _bolts:
		if float(e["delay"]) > 0.0:
			continue
		var k := _k(e)
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var col: Color = e["col"]
		if String(e["kind"]) == "arrow":
			var p := a.lerp(b, k)
			var d := (b - a).normalized()
			draw_line(p - d * 60.0, p, Color(col, 0.35), 6.0)
			draw_line(p - d * 40.0, p, col, 4.0)
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([p + d * 12.0, p + n * 7.0, p - n * 7.0]), col)
		else:
			var kk := k * k
			var head := a.lerp(b, kk)
			for i in 8:
				var tp := a.lerp(b, maxf(0.0, kk - i * 0.035))
				draw_circle(tp, 18.0 - i * 2.0, Color(col, 0.5 - i * 0.06))
			draw_circle(head, 26.0, Color(col, 0.35))
			draw_circle(head, 14.0, Color.WHITE)
	for e in _parts:
		if float(e["delay"]) > 0.0:
			continue
		var k := _k(e) if e["to"] == Vector2.INF else 0.0
		var p: Vector2 = e["p"]
		var col: Color = e["col"]
		var s := float(e["size"]) * (1.0 - k * 0.6)
		var c := Color(col, 1.0 - k * k)
		match String(e["shape"]):
			"sq":
				draw_set_transform(p, float(e["rot"]), Vector2.ONE)
				draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), c)
				draw_set_transform(Vector2.ZERO)
			"star":
				draw_set_transform(p, float(e["rot"]), Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.28, -s * 0.28), Vector2(s, 0),
					Vector2(s * 0.28, s * 0.28), Vector2(0, s), Vector2(-s * 0.28, s * 0.28), Vector2(-s, 0),
					Vector2(-s * 0.28, -s * 0.28)]), c)
				draw_set_transform(Vector2.ZERO)
			"coin":
				draw_circle(p, s, Color("#C98A1E"))
				draw_circle(p, s * 0.72, Color("#FFD45A"))
				draw_circle(p + Vector2(-s * 0.25, -s * 0.25), s * 0.22, Color(1, 1, 1, 0.8))
			_:
				draw_circle(p, s, c)
	for e in _texts:
		if float(e["delay"]) > 0.0:
			continue
		var k := _k(e)
		var pop := 1.0 + 0.7 * maxf(0.0, 1.0 - k * 7.0)
		var fs := int(float(e["fs"]) * pop)
		var t := String(e["t"])
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := float(e["rise"]) * (1.0 - pow(1.0 - minf(1.0, k * 1.6), 2.0))
		var p: Vector2 = (e["p"] as Vector2) + Vector2(-tw * 0.5, -y)
		var a := 1.0 - clampf((k - 0.65) / 0.35, 0.0, 1.0)
		draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(6, fs / 5), Color(0.18, 0.13, 0.2, a))
		draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(e["col"], a))

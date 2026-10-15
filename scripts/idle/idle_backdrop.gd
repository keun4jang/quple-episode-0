class_name IdleBackdrop
extends Control
## 전투 뒤 풍경. 그림 파일 없이 구역마다 다른 하늘·먼 산·가운데 풍경·땅·떠다니는 것을 그린다.
## `scroll` 이 늘면(쿼카가 다음 몬스터로 걸어가면) 겹마다 다른 빠르기로 흘러 깊이가 생긴다.

## 땅이 시작하는 높이 (화면 높이 비율).
const GROUND := 0.74

## 구역별 풍경 - mid: 가운데 풍경 종류, amb: 떠다니는 것.
const THEMES := [
	{"mid": "sea", "ground": "#E8D3A2", "lip": "#F7EAC6", "far": "#86BCD0", "amb": "sparkle",
		"sun": "#FFF7DC", "accent": "#5DB3CC"},
	{"mid": "trees", "ground": "#9CC76A", "lip": "#C2E28C", "far": "#E5B77E", "amb": "mote",
		"sun": "#FFEDB0", "accent": "#6BA357"},
	{"mid": "rocks", "ground": "#BBA07A", "lip": "#D8C49F", "far": "#A08C73", "amb": "dust",
		"sun": "#FFF2D8", "accent": "#8C7660"},
	{"mid": "island", "ground": "#E4D3A3", "lip": "#A9D07A", "far": "#78AED0", "amb": "wind",
		"sun": "#FFFFFF", "accent": "#4FA6C8"},
	{"mid": "river", "ground": "#8CBE78", "lip": "#B5DA93", "far": "#76A6B4", "amb": "leaf",
		"sun": "#FFFBEA", "accent": "#7CC3D8"},
	{"mid": "pond", "ground": "#9BBE8A", "lip": "#C2DCA8", "far": "#A08CC6", "amb": "bubble",
		"sun": "#FFF4FF", "accent": "#8FB8D8"},
	{"mid": "reeds", "ground": "#C8B96B", "lip": "#E4D995", "far": "#B3A86C", "amb": "fluff",
		"sun": "#FFF8DA", "accent": "#D9C27A"},
	{"mid": "pines", "ground": "#6C996A", "lip": "#8EB985", "far": "#62887A", "amb": "leaf",
		"sun": "#F2FFF0", "accent": "#3F6E52"},
	{"mid": "blossom", "ground": "#A7CE89", "lip": "#CBE7A7", "far": "#E19DB2", "amb": "petal",
		"sun": "#FFF0F4", "accent": "#F2A7BF"},
	{"mid": "city", "ground": "#4A4661", "lip": "#635E80", "far": "#3B3754", "amb": "ember",
		"sun": "#F4F0FF", "accent": "#2E2A44", "night": true},
]

var zone := 0
var scroll := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


static func _h(n: float) -> float:
	return fposmod(sin(n * 12.9898 + 78.233) * 43758.5453, 1.0)


func _th() -> Dictionary:
	return THEMES[clampi(zone, 0, THEMES.size() - 1)]


func _draw() -> void:
	var w := size.x
	var h := size.y
	var th := _th()
	var sky: Array = IdleData.ZONES[clampi(zone, 0, IdleData.ZONES.size() - 1)]["sky"]
	var top := Color(sky[0])
	var bot := Color(sky[1])
	var gy := h * GROUND
	var night := bool(th.get("night", false))
	if night:
		top = Color("#1E1B33")
		bot = Color("#5B4E7A")
	_grad(Rect2(0, 0, w, gy + 2), top, bot)
	if night:
		_stars(w, gy)
	_sun(th, w, h, night)
	_clouds(w, h, night)
	var far := Color(th["far"])
	_hills(gy - h * 0.20, h * 0.11, far.lerp(bot, 0.55), 0.06, 0.8, 3.0, gy)
	_hills(gy - h * 0.12, h * 0.09, far.lerp(bot, 0.25), 0.14, 1.4, 11.0, gy)
	_mid(th, w, h, gy)
	_ground(th, w, h, gy)
	_ambient(th, w, h, gy)


func _grad(r: Rect2, a: Color, b: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]), PackedColorArray([a, a, b, b]))


func _stars(w: float, gy: float) -> void:
	for i in 70:
		var x := _h(i * 3.1) * w
		var y := _h(i * 7.7) * gy * 0.7
		var tw := 0.5 + 0.5 * sin(_t * (1.5 + _h(i) * 2.0) + i)
		draw_circle(Vector2(x, y), 1.2 + _h(i * 1.3) * 1.6, Color(1, 1, 0.9, 0.35 + tw * 0.6))


func _sun(th: Dictionary, w: float, h: float, night: bool) -> void:
	var c := Vector2(w * 0.80, h * 0.20)
	var col := Color(th["sun"])
	for i in 5:
		draw_circle(c, 60.0 + i * 26.0 + sin(_t * 0.8) * 4.0, Color(col, 0.10 - i * 0.017))
	draw_circle(c, 46.0, col)
	if night:
		# 초승달 - 하늘색으로 한쪽을 가린다
		draw_circle(c + Vector2(18, -12), 40.0, Color("#262241"))


func _clouds(w: float, h: float, night: bool) -> void:
	var col := Color(1, 1, 1, 0.75) if not night else Color(0.75, 0.72, 0.9, 0.18)
	for i in 6:
		var spd := 6.0 + _h(i * 2.2) * 10.0
		var span := w + 400.0
		var x := fposmod(_h(i * 5.3) * span - _t * spd - scroll * 0.03, span) - 200.0
		var y := h * (0.08 + _h(i * 9.1) * 0.28)
		var s := 0.7 + _h(i * 4.4) * 0.8
		for j in 5:
			var ox := (j - 2) * 34.0 * s
			var r := (30.0 - absf(j - 2) * 7.0) * s
			draw_circle(Vector2(x + ox, y - (r * 0.4)), r, col)
		draw_set_transform(Vector2(x, y + 4 * s), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 72 * s, col)
		draw_set_transform(Vector2.ZERO)


## 사인 몇 겹을 더한 능선.
func _hills(base: float, amp: float, col: Color, par: float, freq: float, seed_v: float, gy: float) -> void:
	var w := size.x
	var pts := PackedVector2Array()
	var off := scroll * par
	var x := 0.0
	while x <= w + 16.0:
		var u := (x + off) * 0.004 * freq
		var n := sin(u + seed_v) * 0.55 + sin(u * 2.3 + seed_v * 2.0) * 0.3 + sin(u * 5.1 + seed_v) * 0.15
		pts.append(Vector2(x, base - amp * (0.5 + 0.5 * n)))
		x += 16.0
	pts.append(Vector2(w + 16.0, gy + 4))
	pts.append(Vector2(0, gy + 4))
	draw_colored_polygon(pts, col)


## 반복해서 놓이는 것들의 자리. 각 자리마다 `f(x, id)` 를 부른다.
func _each(spacing: float, par: float, f: Callable) -> void:
	var off := scroll * par
	var first := floori(off / spacing) - 1
	var n := int(size.x / spacing) + 3
	for i in n:
		var id := first + i
		var x := id * spacing - off
		f.call(x + (_h(id * 1.7) - 0.5) * spacing * 0.5, id)


func _mid(th: Dictionary, w: float, h: float, gy: float) -> void:
	var acc := Color(th["accent"])
	match String(th["mid"]):
		"sea", "island":
			var sy := gy - h * 0.085
			_grad(Rect2(0, sy, w, gy - sy + 2), acc.lightened(0.15), acc.lightened(0.45))
			for i in 26:
				var x := fposmod(_h(i * 2.9) * w - scroll * 0.25 + sin(_t + i) * 8.0, w)
				var y := sy + 6 + _h(i * 6.1) * (gy - sy - 12)
				var a := 0.4 + 0.5 * sin(_t * 3.0 + i * 1.7)
				draw_line(Vector2(x - 10, y), Vector2(x + 10, y), Color(1, 1, 1, maxf(0.0, a)), 2.0)
			if String(th["mid"]) == "sea":
				_each(1300.0, 0.22, func(x: float, _id: int) -> void:
					var b := Vector2(x, sy + 4)
					draw_rect(Rect2(b.x - 9, b.y - 70, 18, 70), Color("#FFFFFF"))
					draw_rect(Rect2(b.x - 9, b.y - 52, 18, 10), Color("#E26A6A"))
					draw_rect(Rect2(b.x - 9, b.y - 28, 18, 10), Color("#E26A6A"))
					draw_rect(Rect2(b.x - 12, b.y - 80, 24, 10), Color("#4D5A6A"))
					draw_circle(b + Vector2(0, -86), 7.0, Color(1, 0.95, 0.6, 0.6 + 0.4 * sin(_t * 2.0))))
			else:
				_each(520.0, 0.25, func(x: float, id: int) -> void:
					var r := 60.0 + _h(id) * 50.0
					draw_circle(Vector2(x, sy + r * 0.55), r, Color(th["lip"]).darkened(0.15))
					var tx := x + (_h(id * 3.0) - 0.5) * r
					var ty := sy + r * 0.55 - r * 0.85
					draw_line(Vector2(tx, ty + 30), Vector2(tx + 6, ty - 30), Color("#8A6A4A"), 6.0)
					for k in 4:
						var a := -PI * 0.9 + k * 0.6
						draw_line(Vector2(tx + 6, ty - 30), Vector2(tx + 6, ty - 30) + Vector2(cos(a), sin(a) + 0.4) * 38.0,
							Color("#4E9A57"), 7.0))
		"trees", "blossom":
			var crown := Color(th["accent"])
			_each(170.0, 0.35, func(x: float, id: int) -> void:
				var s := 0.7 + _h(id * 2.3) * 0.6
				var base := Vector2(x, gy + 2)
				draw_rect(Rect2(base.x - 7 * s, base.y - 70 * s, 14 * s, 70 * s), Color("#7A5A44"))
				var c := crown.darkened(0.08 + _h(id) * 0.12)
				draw_circle(base + Vector2(0, -95 * s), 44 * s, c)
				draw_circle(base + Vector2(-30 * s, -72 * s), 32 * s, c)
				draw_circle(base + Vector2(30 * s, -74 * s), 34 * s, c)
				draw_circle(base + Vector2(-10 * s, -108 * s), 24 * s, c.lightened(0.18)))
		"rocks":
			_each(230.0, 0.35, func(x: float, id: int) -> void:
				var s := 0.6 + _h(id * 4.1) * 0.9
				var c := Color(th["accent"]).lightened(_h(id) * 0.2)
				var b := Vector2(x, gy + 2)
				draw_colored_polygon(PackedVector2Array([b + Vector2(-70, 0) * s, b + Vector2(-50, -60) * s,
					b + Vector2(-5, -95) * s, b + Vector2(45, -55) * s, b + Vector2(75, 0) * s]), c)
				draw_colored_polygon(PackedVector2Array([b + Vector2(-5, -95) * s, b + Vector2(45, -55) * s,
					b + Vector2(20, -40) * s]), c.lightened(0.2)))
		"river":
			var ry := gy - h * 0.06
			_grad(Rect2(0, ry, w, gy - ry + 2), acc, acc.lightened(0.35))
			for i in 14:
				var x := fposmod(_h(i * 3.3) * w + _t * 40.0 - scroll * 0.3, w + 80) - 40
				var y := ry + 5 + _h(i * 8.8) * (gy - ry - 10)
				draw_line(Vector2(x, y), Vector2(x + 30, y), Color(1, 1, 1, 0.55), 2.0)
			_reeds(Color("#7EA25C"), 0.45, gy, 90.0)
		"pond":
			var py := gy - h * 0.07
			_grad(Rect2(0, py, w, gy - py + 2), acc, acc.lightened(0.3))
			_each(150.0, 0.3, func(x: float, id: int) -> void:
				var y := py + 10 + _h(id * 5.0) * (gy - py - 18)
				draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.4))
				draw_circle(Vector2.ZERO, 22.0, Color("#6FA968"))
				draw_set_transform(Vector2.ZERO)
				if _h(id * 2.0) > 0.45:
					draw_circle(Vector2(x + 4, y - 8), 8.0, Color("#F4A6C6"))
					draw_circle(Vector2(x + 4, y - 10), 4.0, Color("#FFE3EE")))
		"reeds":
			_reeds(Color("#C2A24F"), 0.4, gy, 34.0)
		"pines":
			for layer in 2:
				var par := 0.25 + layer * 0.15
				var dark := Color(th["accent"]).lightened(0.25 - layer * 0.2)
				_each(110.0 - layer * 20.0, par, func(x: float, id: int) -> void:
					var s := 0.7 + _h(id * 6.6 + layer) * 0.6 + layer * 0.15
					var b := Vector2(x, gy + 2)
					draw_rect(Rect2(b.x - 5 * s, b.y - 26 * s, 10 * s, 26 * s), Color("#6B4E3A"))
					for k in 3:
						var y0 := b.y - 20 * s - k * 34 * s
						var hw := (46.0 - k * 11.0) * s
						draw_colored_polygon(PackedVector2Array([Vector2(b.x - hw, y0), Vector2(b.x + hw, y0),
							Vector2(b.x, y0 - 54 * s)]), dark))
		"city":
			_each(120.0, 0.3, func(x: float, id: int) -> void:
				var bw := 70.0 + _h(id) * 50.0
				var bh := 120.0 + _h(id * 3.3) * 160.0
				var r := Rect2(x - bw * 0.5, gy - bh, bw, bh)
				draw_rect(r, Color("#2E2A47"))
				var cols := int(bw / 20.0)
				var rows := int(bh / 26.0)
				for cx in cols:
					for cy in rows:
						var lit := _h(id * 31.0 + cx * 7.0 + cy * 13.0) > 0.62
						if lit:
							draw_rect(Rect2(r.position.x + 8 + cx * 20, r.position.y + 10 + cy * 26, 10, 12),
								Color(1.0, 0.86, 0.5, 0.85)))


func _reeds(col: Color, par: float, gy: float, spacing: float) -> void:
	_each(spacing, par, func(x: float, id: int) -> void:
		var hgt := 60.0 + _h(id * 2.7) * 60.0
		var sway := sin(_t * 1.6 + id * 0.7) * 8.0
		var top := Vector2(x + sway, gy - hgt)
		draw_line(Vector2(x, gy + 2), top, col.darkened(0.15), 3.0)
		draw_set_transform(top, 0.3, Vector2(0.45, 1.0))
		draw_circle(Vector2.ZERO, 11.0, col.lightened(0.25))
		draw_set_transform(Vector2.ZERO))


func _ground(th: Dictionary, w: float, h: float, gy: float) -> void:
	var g := Color(th["ground"])
	_grad(Rect2(0, gy, w, h - gy), g, g.darkened(0.18))
	draw_rect(Rect2(0, gy, w, 10), Color(th["lip"]))
	# 길: 가운데 띠
	draw_rect(Rect2(0, gy + 34, w, 46), Color(g.lightened(0.12), 0.7))
	_each(64.0, 1.0, func(x: float, id: int) -> void:
		var r := _h(id * 9.3)
		if r < 0.35:
			draw_circle(Vector2(x, gy + 26 + _h(id) * 70), 3.0 + _h(id * 2.0) * 3.0, g.darkened(0.22))
		elif r < 0.7:
			var b := Vector2(x, gy + 14 + _h(id * 4.0) * 80)
			for k in 3:
				draw_line(b, b + Vector2((k - 1) * 5, -10 - k % 2 * 4), Color(th["lip"]).darkened(0.1), 2.0)
		else:
			var b := Vector2(x, gy + 30 + _h(id * 5.0) * 70)
			draw_circle(b, 4.0, Color("#FFF3F0"))
			draw_circle(b, 2.0, Color("#F6C84A")))
	# 앞쪽 큰 풀 (가장 빠르게 흐른다)
	_each(260.0, 1.4, func(x: float, id: int) -> void:
		var b := Vector2(x, h + 6)
		var c := g.darkened(0.3)
		for k in 5:
			var a := -PI * 0.5 + (k - 2) * 0.28 + sin(_t * 1.3 + id) * 0.05
			draw_line(b, b + Vector2(cos(a), sin(a)) * (40.0 + _h(id + k) * 30.0), c, 6.0))


func _ambient(th: Dictionary, w: float, h: float, gy: float) -> void:
	var kind := String(th["amb"])
	for i in 26:
		var a := _h(i * 1.31)
		var b := _h(i * 2.77)
		var sp := 0.5 + _h(i * 4.1)
		var p := Vector2.ZERO
		var col := Color(1, 1, 1, 0.8)
		match kind:
			"sparkle", "mote":
				p = Vector2(fposmod(a * w - scroll * 0.4 + sin(_t * 0.6 + i) * 20.0, w),
					fposmod(b * h - _t * 14.0 * sp, h * 0.8))
				var tw := 0.5 + 0.5 * sin(_t * 3.0 + i)
				col = Color(1, 1, 0.85, tw) if kind == "sparkle" else Color(1.0, 0.92, 0.6, 0.35 + tw * 0.4)
				_star(p, 3.0 + tw * 3.0, col)
				continue
			"wind":
				p = Vector2(fposmod(a * (w + 300) - _t * 420.0 * sp - scroll, w + 300) - 150, b * gy)
				draw_line(p, p + Vector2(70 * sp, 0), Color(1, 1, 1, 0.45), 2.0)
				continue
			"leaf", "petal":
				p = Vector2(fposmod(a * w - _t * 30.0 * sp - scroll * 0.6 + sin(_t * 1.5 + i) * 30.0, w),
					fposmod(b * h + _t * 40.0 * sp, h))
				col = Color("#F7B6C8") if kind == "petal" else Color(th["accent"]).lightened(0.2)
				draw_set_transform(p, _t * 2.0 + i, Vector2(1.0, 0.55))
				draw_circle(Vector2.ZERO, 5.0, col)
				draw_set_transform(Vector2.ZERO)
				continue
			"bubble":
				p = Vector2(fposmod(a * w - scroll * 0.4, w), h - fposmod(b * h + _t * 30.0 * sp, h))
				draw_arc(p, 4.0 + sp * 4.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.5)
				continue
			"fluff", "dust":
				p = Vector2(fposmod(a * w - _t * 24.0 * sp - scroll * 0.5, w), fposmod(b * h + sin(_t + i) * 12.0, h))
				col = Color(1, 1, 1, 0.7) if kind == "fluff" else Color("#8C7660")
				draw_circle(p, 2.5 + sp * 2.0, Color(col, 0.6))
				continue
			"ember":
				p = Vector2(fposmod(a * w + sin(_t + i) * 15.0 - scroll * 0.4, w), h - fposmod(b * h + _t * 35.0 * sp, h))
				var tw2 := 0.5 + 0.5 * sin(_t * 4.0 + i)
				draw_circle(p, 6.0, Color(1.0, 0.7, 0.3, 0.12 * tw2))
				draw_circle(p, 2.5, Color(1.0, 0.85, 0.5, 0.5 + 0.5 * tw2))
				continue


func _star(p: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.3), p + Vector2(r, 0),
		p + Vector2(r * 0.3, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.3, r * 0.3), p + Vector2(-r, 0),
		p + Vector2(-r * 0.3, -r * 0.3)]), col)

class_name FieldFx
extends RefCounted
## 마을 한가운데 싸움의 반짝이는 것들 - 휘두름, 터짐, 떠오르는 숫자.
##
## 전부 **지도 좌표**에 그린다 (카메라가 따라가도 그 자리에 남는다).
## 그림 파일 없이 도형만 쓴다 - 폰트에 없는 글자(★ 등)도 안 쓴다.
## 스킬마다 빛깔이 다르다 ("형형색색", 0.1.168 턴제 화면에서 옮겨 왔다).

const SKILL_FX := {
	"smile": {"cols": ["#FFE066", "#FFB347", "#FF8FB1", "#FFFFFF"], "n": 12, "rays": 6},
	"breathe": {"cols": ["#8FF5D2", "#7FDBFF", "#C8FFF0", "#FFFFFF"], "n": 14, "rays": 6},
	"remember": {"cols": ["#FF9AA2", "#FFDAC1", "#E2F0CB", "#B5EAD7", "#C7CEEA", "#F8B5FF"],
		"n": 22, "rays": 10},
	"cheer": {"cols": ["#FFD700", "#FF7B54", "#FFB26B", "#FFF3B0"], "n": 18, "rays": 10},
	"steady": {"cols": ["#7AA2FF", "#B28DFF", "#E0C3FC", "#FFFFFF"], "n": 18, "rays": 8},
	"walk_on": {"cols": ["#FF5A5A", "#FFA94D", "#FFE066", "#69DB7C", "#4DABF7",
		"#9775FA", "#F783AC"], "n": 34, "rays": 14},
	"hurt": {"cols": ["#FF6B6B", "#FFFFFF", "#C92A2A"], "n": 8, "rays": 0},
	"gone": {"cols": ["#5C5470", "#8E7DBE", "#DCD6F7", "#FFFFFF"], "n": 20, "rays": 0},
}

## 위에 뜨는 것들은 이름표(40)보다 위에 그린다.
const Z := 60


static func cols_of(id: String) -> Array:
	return SKILL_FX.get(id, SKILL_FX["smile"])["cols"]


## 떠오르다 사라지는 글자 (피해 숫자·"+경험"·상태 이름).
static func number(parent: Node, at: Vector2, text: String, col: Color,
		size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = Z + 2
	l.size = Vector2(120, size + 6)
	# 여러 개가 겹쳐 뜨면 못 읽는다 - 좌우로 조금씩 흩는다.
	l.position = at + Vector2(-60.0 + randf_range(-5.0, 5.0), -size - 4.0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.5, 0.5)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.10)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - 18.0, 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	return l


## 이펙트 모양 표. 스킬마다 **모양부터 다르다** - 빛깔만 바꾸면 멀리서는
## 다 같은 "펑" 으로 보인다 ("더 크고 화려하게", 0.1.170).
##   r      크기(px, 지도 좌표 - 카메라가 두 배쯤 키운다)
##   secs   얼마나 가나
##   core   가운데 번쩍임 · rings 퍼지는 고리 수 · rays 빛살 수
##   sparks 튀는 불똥 수 · stars 네 갈래 별 수 · orbs 떠오르는 방울 수
##   ground 발밑에 퍼지는 납작한 고리 · pillar 빛기둥 · shield 육각 방패
const STYLE := {
	"smile": {"r": 34.0, "secs": 0.5, "core": 10.0, "rings": 2, "rays": 8,
		"sparks": 18, "stars": 5, "orbs": 0},
	"remember": {"r": 56.0, "secs": 0.8, "core": 16.0, "rings": 4, "rays": 12,
		"sparks": 28, "stars": 10, "orbs": 12},
	"walk_on": {"r": 84.0, "secs": 1.0, "core": 24.0, "rings": 7, "rays": 18,
		"sparks": 60, "stars": 16, "orbs": 10, "ground": true},
	"breathe": {"r": 40.0, "secs": 1.0, "core": 0.0, "rings": 1, "rays": 0,
		"sparks": 8, "stars": 8, "orbs": 22, "ground": true, "glow": 26.0},
	"cheer": {"r": 44.0, "secs": 1.0, "core": 0.0, "rings": 1, "rays": 10,
		"sparks": 14, "stars": 14, "orbs": 0, "ground": true, "pillar": true},
	"steady": {"r": 40.0, "secs": 1.0, "core": 0.0, "rings": 1, "rays": 0,
		"sparks": 16, "stars": 6, "orbs": 0, "ground": true, "shield": true},
	"hurt": {"r": 22.0, "secs": 0.35, "core": 8.0, "rings": 1, "rays": 0,
		"sparks": 12, "stars": 0, "orbs": 0},
	"gone": {"r": 44.0, "secs": 0.9, "core": 12.0, "rings": 3, "rays": 0,
		"sparks": 26, "stars": 6, "orbs": 14},
}


## **밤에도 빛나게.** 마을은 `CanvasModulate` 로 하늘빛을 곱하는데, 이펙트까지
## 곱해지면 밤 싸움이 남색 얼룩이 된다. 이름표가 쓰는 수법처럼 미리 역수로 밝힌다.
static func _glow(parent: Node, n: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	n.material = mat
	if parent.has_method("sky_tint"):
		var tint: Color = parent.sky_tint(JourneyState.minutes)
		n.modulate = Color(1.0 / maxf(tint.r, 0.05), 1.0 / maxf(tint.g, 0.05),
			1.0 / maxf(tint.b, 0.05))


static func _animate(n: Node2D, secs: float) -> void:
	n.set_meta("t", 0.0)
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		n.set_meta("t", v)
		n.queue_redraw(), 0.0, 1.0, secs)
	tw.tween_callback(n.queue_free)


## 네 갈래 별 - 폰트의 ★ 대신 도형으로.
static func _star(n: Node2D, p: Vector2, r: float, rot: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + TAU * float(i) / 8.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.32))
	n.draw_colored_polygon(pts, c)


## 손을 휘두른 자국 - 보는 쪽으로 반달 모양 빛이 세 겹으로 스친다.
static func swing(parent: Node, from: Vector2, dir: Vector2, id: String) -> void:
	var cols := cols_of(id)
	var n := Node2D.new()
	n.z_index = Z
	n.position = from + Vector2(0, -8)
	var ang := dir.angle() if dir.length_squared() > 0.001 else PI * 0.5
	var r := 22.0 if id != "walk_on" else Field.WIDE * 0.9
	n.draw.connect(func() -> void:
		var t: float = n.get_meta("t")
		var a := 1.0 - t
		var span := PI * 1.1
		var start := ang - span * 0.5
		var sweep := span * minf(1.0, t * 2.2)
		for i in 3:
			var c := Color(String(cols[i % cols.size()]))
			c.a = a
			n.draw_arc(Vector2.ZERO, r - float(i) * 3.0, start, start + sweep, 18, c,
				4.0 - float(i))
		# 칼끝에 반짝임
		var tip := Vector2.from_angle(start + sweep) * r
		_star(n, tip, 6.0 * a + 2.0, t * 6.0, Color(1, 1, 1, a)))
	_glow(parent, n)
	parent.add_child(n)
	_animate(n, 0.22)


## 터진다. 스킬마다 `STYLE` 의 모양으로. `strong`(약점)이면 한 배 반.
static func burst(parent: Node, at: Vector2, id: String, strong := false) -> void:
	var st: Dictionary = STYLE.get(id, STYLE["smile"])
	var cols: Array = SKILL_FX.get(id, SKILL_FX["smile"])["cols"]
	var k := 1.5 if strong else 1.0
	var R := float(st["r"]) * k
	var secs := float(st["secs"]) * (1.15 if strong else 1.0)
	var rise := String(id) in ["breathe", "cheer", "steady", "gone"]
	# 불똥: [방향 속도, 빛깔, 굵기]
	var sparks: Array = []
	for i in int(int(st["sparks"]) * k):
		var a := randf() * TAU
		if rise:
			a = -PI * 0.5 + randf_range(-1.1, 1.1)
		sparks.append([Vector2.from_angle(a) * randf_range(0.5, 1.0) * R * 1.2,
			Color(String(cols[i % cols.size()])), randf_range(1.2, 2.6)])
	var stars: Array = []
	for i in int(int(st["stars"]) * k):
		stars.append([Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * R,
			Color(String(cols[(i + 1) % cols.size()])), randf_range(3.0, 6.0) * k,
			randf() * TAU, randf_range(-6.0, 6.0)])
	var orbs: Array = []
	for i in int(st["orbs"]):
		orbs.append([randf_range(-R * 0.6, R * 0.6), randf_range(0.0, 0.4),
			randf_range(2.0, 4.5), Color(String(cols[i % cols.size()])), randf() * TAU])
	var spin := randf() * TAU
	var n := Node2D.new()
	n.z_index = Z
	n.position = at
	n.draw.connect(func() -> void:
		var t: float = n.get_meta("t")
		var a := 1.0 - t
		var e3 := 1.0 - pow(1.0 - t, 3.0)
		# 발밑에 납작하게 퍼지는 고리 (서 있는 땅이 울린다)
		if bool(st.get("ground", false)):
			n.draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.38))
			for g in 2:
				var gc := Color(String(cols[g % cols.size()]))
				gc.a = a * 0.9
				n.draw_arc(Vector2.ZERO, R * (0.3 + e3 * (1.0 + 0.3 * g)), 0.0, TAU,
					40, gc, 3.0)
			var fill := Color(String(cols[0]))
			fill.a = a * 0.18
			n.draw_circle(Vector2.ZERO, R * (0.3 + e3), fill)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 빛기둥 (응원) - 위로 솟았다 가늘어진다
		if bool(st.get("pillar", false)):
			var h := R * 2.6 * minf(1.0, t * 3.0)
			for j in 6:
				var w := R * 0.55 * (1.0 - float(j) / 6.0) * (1.0 - t * 0.6)
				var pc := Color(String(cols[j % cols.size()]))
				pc.a = a * 0.22
				n.draw_rect(Rect2(-w * 0.5, 8.0 - h, w, h), pc)
		# 은은한 빛무리 (심호흡)
		if float(st.get("glow", 0.0)) > 0.0:
			for j in 4:
				var gl := Color(String(cols[j % cols.size()]))
				gl.a = a * 0.12
				n.draw_circle(Vector2(0, -6), float(st["glow"]) * (0.6 + 0.25 * j) * (0.7 + e3 * 0.5), gl)
		# 육각 방패 (마음 단단히) - 돌면서 두 겹으로 감싼다
		if bool(st.get("shield", false)):
			for j in 2:
				var sr := R * (0.55 + 0.2 * j) * (0.6 + 0.4 * e3)
				var pts := PackedVector2Array()
				for q in 7:
					pts.append(Vector2(0, -8) + Vector2.from_angle(
						t * (2.0 - 4.0 * j) + TAU * float(q) / 6.0) * sr)
				var sc := Color(String(cols[j % cols.size()]))
				sc.a = a
				n.draw_polyline(pts, sc, 2.5 - j)
				var sf := sc
				sf.a = a * 0.12
				n.draw_colored_polygon(pts.slice(0, 6), sf)
		# 가운데 번쩍 - 하얗게 부풀었다 스러진다
		var core := float(st["core"]) * k
		if core > 0.0:
			# 더하기 섞기라 하얀 원이 크면 그늘까지 통째로 하얗게 덮는다 -
			# 하얀 심은 작게, 둘레는 스킬 빛깔로 옅게.
			var cc := Color(String(cols[0]))
			cc.a = a * 0.3
			n.draw_circle(Vector2.ZERO, core * (1.0 + e3 * 1.3), cc)
			n.draw_circle(Vector2.ZERO, core * 0.5 * (1.0 - t), Color(1, 1, 1, a * 0.6))
		# 퍼지는 고리 - 빛깔마다 조금씩 늦게, 조금씩 크게
		for j in int(st["rings"]):
			var lag := float(j) * 0.08
			var tt := clampf((t - lag) / maxf(0.05, 1.0 - lag), 0.0, 1.0)
			if tt <= 0.0:
				continue
			var rc := Color(String(cols[j % cols.size()]))
			rc.a = (1.0 - tt) * 0.95
			n.draw_arc(Vector2.ZERO, R * (0.2 + 0.9 * (1.0 - pow(1.0 - tt, 2.0))),
				0.0, TAU, 36, rc, 3.0 * k * (1.0 - tt) + 1.0)
		# 빛살 - 가운데가 굵고 끝이 뾰족한 삼각형
		var rays := int(st["rays"])
		for j in rays:
			var d := Vector2.from_angle(spin + t * 1.5 + TAU * float(j) / float(rays))
			var rl := R * (0.4 + e3 * (0.9 if j % 2 == 0 else 0.6))
			var side := d.orthogonal() * 2.4 * k * a
			var yc := Color(String(cols[j % cols.size()]))
			yc.a = a
			n.draw_colored_polygon(PackedVector2Array([d * 4.0 + side, d * rl,
				d * 4.0 - side]), yc)
		# 불똥 - 꼬리를 끌며 날아간다
		for b in sparks:
			var v: Vector2 = b[0]
			var p: Vector2 = v * e3
			if not rise:
				p.y += 30.0 * t * t          # 살짝 떨어진다
			var c3: Color = b[1]
			c3.a = a
			n.draw_line(p, p - v * 0.12 * a, c3, b[2])
			# 머리만 조금 밝게 - 하얗게 칠하면 불똥이 수십 개라 한데 뭉쳐
			# 하얀 덩어리가 되고 그 밑의 그늘이 안 보였다.
			n.draw_circle(p, float(b[2]) * 0.7, c3.lightened(0.35))
		# 별 - 돌면서 반짝인다
		for s2 in stars:
			var sp: Vector2 = s2[0] * e3
			var sc2: Color = s2[1]
			sc2.a = a * (0.6 + 0.4 * sin(t * 30.0 + float(s2[3])))
			_star(n, sp, float(s2[2]) * (0.5 + a), float(s2[3]) + float(s2[4]) * t, sc2)
		# 떠오르는 방울 - 흔들리며 올라간다
		for o in orbs:
			var ot := clampf((t - float(o[1])) / 0.6, 0.0, 1.0)
			if ot <= 0.0 or ot >= 1.0:
				continue
			var op := Vector2(float(o[0]) + sin(ot * 8.0 + float(o[4])) * 5.0,
				-ot * R * 1.6)
			var oc: Color = o[3]
			oc.a = 1.0 - ot
			n.draw_arc(op, float(o[2]), 0.0, TAU, 12, oc, 1.4)
			n.draw_circle(op + Vector2(-1, -1), float(o[2]) * 0.3, Color(1, 1, 1, oc.a)))
	_glow(parent, n)
	parent.add_child(n)
	_animate(n, secs)


## 스킬 이름이 머리 위에 그 빛깔로 크게 떴다 사라진다 - 무엇을 썼는지 한눈에.
static func cast_name(parent: Node, at: Vector2, id: String) -> void:
	var cols := cols_of(id)
	var l := number(parent, at + Vector2(0, -44), String(Battle.SKILLS.get(id, {})
		.get("name", "")), Color(String(cols[0])), 18)
	l.add_theme_constant_override("outline_size", 6)
	var tw := l.create_tween().set_loops(3)
	for c in cols:
		tw.tween_property(l, "theme_override_colors/font_color", Color(String(c)), 0.06)


## 화면이 흔들린다. 카메라의 `offset` 만 흔든다 - 위치는 그대로.
static func shake(cam: Camera2D, power: float, secs: float) -> void:
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := maxi(2, int(secs / 0.03))
	for i in steps:
		var f := power * (1.0 - float(i) / float(steps))
		tw.tween_property(cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)

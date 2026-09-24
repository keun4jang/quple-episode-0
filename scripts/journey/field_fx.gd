class_name FieldFx
extends RefCounted
## 싸움의 반짝이는 것들 - 휘두름, 날아가는 빛, 터짐, 떠오르는 숫자,
## 튀는 꿈조각, 장비 빛기둥.
##
## 전부 **지도 좌표**에 그린다 (카메라가 따라가도 그 자리에 남는다).
## 그림 파일 없이 도형만 쓴다 - 폰트에 없는 글자(★ 등)도 안 쓴다.
## **속성마다 모양부터 다르다** (`docs/elements.md`): 물은 물방울이 튀어
## 떨어지고, 불은 불꽃이 솟고, 나무는 잎이 돌며 흩날리고, 땅은 돌조각이
## 떨어지고, 바람은 소용돌이가 감긴다.

## 이펙트 이름 → 빛깔. 속성 다섯·무·어둠, 그리고 스킬이 아닌 것들.
const PALETTE := {
	"none": ["#FFE066", "#FFB347", "#FF8FB1", "#FFFFFF"],
	"water": ["#4DABF7", "#A5D8FF", "#1C7ED6", "#E7F5FF"],
	"fire": ["#FF7043", "#FFD43B", "#FA5252", "#FFE8CC"],
	"wood": ["#51CF66", "#94D82D", "#2B8A3E", "#D8F5A2"],
	"earth": ["#C9955C", "#E8C39E", "#8D6E4F", "#FFF3BF"],
	"wind": ["#9BE7F5", "#E3FAFC", "#66D9E8", "#FFFFFF"],
	"dark": ["#B197FC", "#7048E8", "#E5DBFF", "#FFFFFF"],
	"rainbow": ["#FF5A5A", "#FFA94D", "#FFE066", "#69DB7C", "#4DABF7", "#9775FA", "#F783AC"],
	"heal": ["#8FF5D2", "#7FDBFF", "#C8FFF0", "#FFFFFF"],
	"guard": ["#7AA2FF", "#B28DFF", "#E0C3FC", "#FFFFFF"],
	"keen": ["#FFD700", "#FF7B54", "#FFB26B", "#FFF3B0"],
	"levelup": ["#FFE066", "#FFFFFF", "#FFD43B", "#FFF3BF", "#69DB7C"],
	"hurt": ["#FF6B6B", "#FFFFFF", "#C92A2A"],
	"gone": ["#8E7DBE", "#5C5470", "#DCD6F7", "#B197FC"],
}

## 이펙트 모양. 크기(px, 지도 좌표 - 카메라가 두 배쯤 키운다), 시간, 가운데
## 번쩍임, 퍼지는 고리, 빛살, 조각 수와 **조각 모양**(`bit`), 떠오르는 방울,
## 발밑 충격파, 빛기둥, 육각 방패, 위로 솟는가(`rise`).
##   bit: spark 불똥 · drop 물방울 · flame 불꽃 · leaf 잎 · rock 돌조각 · swirl 회오리
const STYLE := {
	"none": {"r": 34.0, "secs": 0.5, "core": 10.0, "rings": 2, "rays": 8,
		"n": 18, "stars": 5, "bit": "spark"},
	"water": {"r": 38.0, "secs": 0.6, "core": 10.0, "rings": 3, "rays": 0,
		"n": 22, "stars": 3, "bit": "drop", "orbs": 6},
	"fire": {"r": 36.0, "secs": 0.65, "core": 12.0, "rings": 2, "rays": 10,
		"n": 22, "stars": 2, "bit": "flame", "rise": true},
	"wood": {"r": 40.0, "secs": 0.7, "core": 8.0, "rings": 2, "rays": 0,
		"n": 18, "stars": 3, "bit": "leaf"},
	"earth": {"r": 36.0, "secs": 0.6, "core": 10.0, "rings": 2, "rays": 6,
		"n": 16, "stars": 0, "bit": "rock", "ground": true},
	"wind": {"r": 42.0, "secs": 0.6, "core": 6.0, "rings": 1, "rays": 0,
		"n": 14, "stars": 4, "bit": "swirl", "swirl": 3},
	"dark": {"r": 40.0, "secs": 0.7, "core": 12.0, "rings": 3, "rays": 8,
		"n": 20, "stars": 4, "bit": "spark"},
	"rainbow": {"r": 84.0, "secs": 1.0, "core": 24.0, "rings": 7, "rays": 18,
		"n": 60, "stars": 16, "bit": "spark", "orbs": 10, "ground": true},
	"heal": {"r": 40.0, "secs": 1.0, "core": 0.0, "rings": 1, "rays": 0,
		"n": 8, "stars": 8, "bit": "spark", "orbs": 22, "ground": true, "glow": 26.0,
		"rise": true},
	"keen": {"r": 44.0, "secs": 1.0, "core": 0.0, "rings": 1, "rays": 10,
		"n": 14, "stars": 14, "bit": "spark", "ground": true, "pillar": true, "rise": true},
	"guard": {"r": 40.0, "secs": 1.0, "core": 0.0, "rings": 1, "rays": 0,
		"n": 16, "stars": 6, "bit": "spark", "ground": true, "shield": true, "rise": true},
	"levelup": {"r": 50.0, "secs": 1.2, "core": 0.0, "rings": 3, "rays": 12,
		"n": 30, "stars": 20, "bit": "spark", "ground": true, "pillar": true, "rise": true},
	"hurt": {"r": 22.0, "secs": 0.35, "core": 8.0, "rings": 1, "rays": 0,
		"n": 12, "stars": 0, "bit": "spark"},
	"gone": {"r": 44.0, "secs": 0.9, "core": 5.0, "rings": 3, "rays": 0,
		"n": 26, "stars": 6, "bit": "spark", "orbs": 14, "rise": true},
}

## 위에 뜨는 것들은 이름표(40)보다 위에 그린다.
const Z := 60


static func cols_of(key: String) -> Array:
	return PALETTE.get(key, PALETTE["none"])


## 떠오르다 사라지는 글자 (피해 숫자·"+경험"·상태 이름).
static func number(parent: Node, at: Vector2, text: String, col: Color,
		size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
	l.add_theme_constant_override("outline_size", 4 if size < 18 else 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = Z + 2
	l.size = Vector2(140, size + 6)
	# 여러 개가 겹쳐 뜨면 못 읽는다 - 좌우로 조금씩 흩는다.
	l.position = at + Vector2(-70.0 + randf_range(-5.0, 5.0), -size - 4.0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.5, 0.5)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.2, 1.2), 0.10)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - 18.0, 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	return l


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


## 조각 하나를 모양대로 그린다.
static func _bit(n: Node2D, shape: String, p: Vector2, v: Vector2, s: float, rot: float,
		c: Color, a: float) -> void:
	match shape:
		"drop":
			# 떨어지는 쪽이 둥글고 위가 뾰족한 물방울
			var d := v.normalized() if v.length_squared() > 0.01 else Vector2.DOWN
			n.draw_circle(p, s * 1.1, c)
			n.draw_colored_polygon(PackedVector2Array([p + d.orthogonal() * s,
				p - d * s * 2.6, p - d.orthogonal() * s]), c)
			n.draw_circle(p + Vector2(-s * 0.4, -s * 0.4), s * 0.35, Color(1, 1, 1, a))
		"flame":
			# 위로 솟는 혀 - 바깥 빛깔 + 노란 속
			var h := s * 3.2
			n.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 1.2, 0),
				p + Vector2(0, -h), p + Vector2(s * 1.2, 0), p + Vector2(0, s * 0.8)]), c)
			n.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.5, 0),
				p + Vector2(0, -h * 0.55), p + Vector2(s * 0.5, 0)]), Color(1, 0.95, 0.6, a))
		"leaf":
			# 돌면서 날리는 잎 - 마름모꼴 + 잎맥
			var d2 := Vector2.from_angle(rot)
			var o := d2.orthogonal() * s * 0.9
			n.draw_colored_polygon(PackedVector2Array([p - d2 * s * 2.0, p + o,
				p + d2 * s * 2.0, p - o]), c)
			n.draw_line(p - d2 * s * 1.8, p + d2 * s * 1.8, c.darkened(0.35), 0.8)
		"rock":
			# 모난 돌조각
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(p + Vector2.from_angle(rot + TAU * i / 5.0) * s * (1.2 if i % 2 else 1.7))
			n.draw_colored_polygon(pts, c)
		"swirl":
			n.draw_arc(p, s * 2.2, rot, rot + PI * 1.3, 8, c, 1.4)
		_:
			n.draw_line(p, p - v * 0.12 * a, c, s)
			n.draw_circle(p, s * 0.7, c.lightened(0.35))


## 손을 휘두른 자국 - 보는 쪽으로 반달 모양 빛이 세 겹으로 스친다.
static func swing(parent: Node, from: Vector2, dir: Vector2, key: String) -> void:
	var cols := cols_of(key)
	var n := Node2D.new()
	n.z_index = Z
	n.position = from + Vector2(0, -8)
	var ang := dir.angle() if dir.length_squared() > 0.001 else PI * 0.5
	var r := 22.0
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
		var tip := Vector2.from_angle(start + sweep) * r
		_star(n, tip, 6.0 * a + 2.0, t * 6.0, Color(1, 1, 1, a)))
	_glow(parent, n)
	parent.add_child(n)
	_animate(n, 0.22)


## 멀리 쏜 것 - 빛 덩어리가 꼬리를 끌며 날아가 맞는다 (물총·불꽃·화살·표창).
static func shot(parent: Node, from: Vector2, to: Vector2, key: String) -> void:
	var cols := cols_of(key)
	var shape := String(STYLE.get(key, STYLE["none"])["bit"])
	var n := Node2D.new()
	n.z_index = Z
	n.draw.connect(func() -> void:
		var t: float = n.get_meta("t")
		var head := from.lerp(to, minf(1.0, t * 1.4))
		var tail := from.lerp(to, maxf(0.0, t * 1.4 - 0.35))
		var c0 := Color(String(cols[0]))
		c0.a = 1.0 - maxf(0.0, t - 0.7) / 0.3
		n.draw_line(tail, head, c0, 3.0)
		var c1 := Color(String(cols[1 % cols.size()]))
		c1.a = c0.a
		n.draw_line(tail.lerp(head, 0.5), head, c1, 5.0)
		_bit(n, shape, head, to - from, 3.0, t * 12.0, Color(String(cols[0])), c0.a))
	_glow(parent, n)
	parent.add_child(n)
	_animate(n, 0.25)


## 터진다. `key` 는 속성(water…) 또는 이펙트 이름(heal·gone…). `strong` 이면
## (잘 드는 속성·치명타) 한 배 반.
static func burst(parent: Node, at: Vector2, key: String, strong := false) -> void:
	var st: Dictionary = STYLE.get(key, STYLE["none"])
	var cols := cols_of(key)
	var k := 1.5 if strong else 1.0
	var R := float(st["r"]) * k
	var secs := float(st["secs"]) * (1.15 if strong else 1.0)
	var rise := bool(st.get("rise", false))
	var shape := String(st.get("bit", "spark"))
	var fall := shape in ["drop", "rock"]
	var bits: Array = []
	for i in int(float(st["n"]) * k):
		var a := randf() * TAU
		if rise:
			a = -PI * 0.5 + randf_range(-1.1, 1.1)
		elif fall:
			a = -PI * 0.5 + randf_range(-1.6, 1.6)
		bits.append([Vector2.from_angle(a) * randf_range(0.5, 1.0) * R * 1.2,
			Color(String(cols[i % cols.size()])), randf_range(1.2, 2.6),
			randf() * TAU, randf_range(-8.0, 8.0)])
	var stars: Array = []
	for i in int(float(st["stars"]) * k):
		stars.append([Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * R,
			Color(String(cols[(i + 1) % cols.size()])), randf_range(3.0, 6.0) * k,
			randf() * TAU, randf_range(-6.0, 6.0)])
	var orbs: Array = []
	for i in int(st.get("orbs", 0)):
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
		# 빛기둥 - 위로 솟았다 가늘어진다
		if bool(st.get("pillar", false)):
			var h := R * 2.6 * minf(1.0, t * 3.0)
			for j in 6:
				var w := R * 0.55 * (1.0 - float(j) / 6.0) * (1.0 - t * 0.6)
				var pc := Color(String(cols[j % cols.size()]))
				pc.a = a * 0.22
				n.draw_rect(Rect2(-w * 0.5, 8.0 - h, w, h), pc)
		# 은은한 빛무리
		if float(st.get("glow", 0.0)) > 0.0:
			for j in 4:
				var gl := Color(String(cols[j % cols.size()]))
				gl.a = a * 0.12
				n.draw_circle(Vector2(0, -6),
					float(st["glow"]) * (0.6 + 0.25 * j) * (0.7 + e3 * 0.5), gl)
		# 육각 방패 - 돌면서 두 겹으로 감싼다
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
		# 회오리 - 감기면서 커진다
		for j in int(st.get("swirl", 0)):
			var sc2 := Color(String(cols[j % cols.size()]))
			sc2.a = a
			var base := spin + t * 9.0 + TAU * j / 3.0
			n.draw_arc(Vector2.ZERO, R * (0.25 + e3 * 0.7) * (1.0 - 0.15 * j),
				base, base + PI * 1.2, 16, sc2, 2.2)
		# 가운데 번쩍. 더하기 섞기라 하얀 원이 크면 몬스터까지 통째로
		# 하얗게 덮는다 - 하얀 심은 작게, 둘레는 속성 빛깔로 옅게.
		var core := float(st["core"]) * k
		if core > 0.0:
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
		# 조각 - 속성마다 모양이 다르다. 물·돌은 떨어지고, 불은 솟는다.
		for b in bits:
			var v: Vector2 = b[0]
			var p: Vector2 = v * e3
			if fall:
				p.y += 60.0 * t * t
			elif not rise:
				p.y += 20.0 * t * t
			var c3: Color = b[1]
			c3.a = a
			_bit(n, shape, p, v, float(b[2]), float(b[3]) + float(b[4]) * t, c3, a)
		# 별 - 돌면서 반짝인다
		for s2 in stars:
			var sp: Vector2 = s2[0] * e3
			var sc3: Color = s2[1]
			sc3.a = a * (0.6 + 0.4 * sin(t * 30.0 + float(s2[3])))
			_star(n, sp, float(s2[2]) * (0.5 + a), float(s2[3]) + float(s2[4]) * t, sc3)
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


## 스킬 이름이 머리 위에 그 속성 빛깔로 크게 떴다 사라진다.
static func cast_name(parent: Node, at: Vector2, id: String) -> void:
	var key := Battle.skill_elem(id)
	var cols := cols_of(key)
	var l := number(parent, at + Vector2(0, -44), String(Battle.SKILLS.get(id, {})
		.get("name", "")), Color(String(cols[0])), 18)
	l.add_theme_constant_override("outline_size", 6)
	var tw := l.create_tween().set_loops(3)
	for c in cols:
		tw.tween_property(l, "theme_override_colors/font_color", Color(String(c)), 0.06)


## 꿈조각이 튀어 올랐다가 쿼카에게 빨려 든다.
static func coins(parent: Node, at: Vector2, to: Node2D, count: int) -> void:
	for i in count:
		var n := Node2D.new()
		n.z_index = Z
		n.position = at + Vector2(0, -6)
		var up := Vector2(randf_range(-22.0, 22.0), randf_range(-26.0, -14.0))
		n.draw.connect(func() -> void:
			var t: float = n.get_meta("t")
			var spin := absf(cos(t * 20.0 + i))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.25, spin), 1.0))
			n.draw_circle(Vector2.ZERO, 3.0, Color("#FFD43B"))
			n.draw_circle(Vector2.ZERO, 1.6, Color("#FFF3BF"))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
		parent.add_child(n)
		n.set_meta("t", 0.0)
		var start := n.position
		var tw := n.create_tween()
		tw.tween_method(func(v: float) -> void:
			n.set_meta("t", v)
			if v < 0.5:
				var k := v / 0.5
				n.position = start + Vector2(up.x * k, up.y * sin(k * PI) * 1.4 + 10.0 * k)
			elif is_instance_valid(to):
				var k2 := (v - 0.5) / 0.5
				n.position = n.position.lerp(to.global_position + Vector2(0, -10), k2 * k2)
			n.queue_redraw(), 0.0, 1.0, 0.9 + randf() * 0.2)
		tw.tween_callback(n.queue_free)


## 장비가 떨어진 자리에 **등급 빛깔의 빛기둥**이 선다 - 무엇이 나왔는지
## 이름을 읽기 전에 색으로 먼저 안다. 등급이 높을수록 높고 오래 선다.
static func beam(parent: Node, at: Vector2, col: Color, rar: int) -> void:
	var n := Node2D.new()
	n.z_index = Z - 1
	n.position = at
	var h := 40.0 + 22.0 * rar
	n.draw.connect(func() -> void:
		var t: float = n.get_meta("t")
		var a := (1.0 - t) if t > 0.3 else 1.0
		var grow := minf(1.0, t * 5.0)
		for j in 5:
			var w := (10.0 - j * 1.8) * (1.0 + 0.15 * sin(t * 20.0))
			var c := col
			c.a = a * (0.12 + 0.1 * j)
			n.draw_rect(Rect2(-w * 0.5, -h * grow, w, h * grow), c)
		# 바닥의 상자 - 반짝이는 작은 네모
		n.draw_rect(Rect2(-4, -5, 8, 6), col.lightened(0.2))
		n.draw_rect(Rect2(-4, -5, 8, 2), Color(1, 1, 1, a))
		if rar >= 3:
			_star(n, Vector2(0, -h * grow - 4.0), 5.0, t * 8.0, Color(1, 1, 1, a)))
	_glow(parent, n)
	parent.add_child(n)
	_animate(n, 1.6 + 0.5 * rar)


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

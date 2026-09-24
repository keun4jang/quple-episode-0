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


## 손을 휘두른 자국 - 보는 쪽으로 반달 모양 빛이 스친다.
static func swing(parent: Node, from: Vector2, dir: Vector2, id: String) -> void:
	var cols := cols_of(id)
	var n := Node2D.new()
	n.z_index = Z
	n.position = from + Vector2(0, -8)
	var ang := dir.angle() if dir.length_squared() > 0.001 else PI * 0.5
	var r := 13.0 if id != "walk_on" else Field.WIDE * 0.6
	n.set_meta("t", 0.0)
	n.draw.connect(func() -> void:
		var t: float = n.get_meta("t")
		var a := 1.0 - t
		var span := PI * 0.9
		var start := ang - span * 0.5 + span * t * 0.3
		for i in cols.size():
			var c := Color(String(cols[i]))
			c.a = a * 0.9
			n.draw_arc(Vector2.ZERO, r - float(i) * 1.6, start, start + span * (0.4 + t * 0.6),
				12, c, 2.0))
	parent.add_child(n)
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		n.set_meta("t", v)
		n.queue_redraw(), 0.0, 1.0, 0.18)
	tw.tween_callback(n.queue_free)


## 맞은 자리에서 터진다. 고리 둘 · 빛살 · 여러 빛깔 조각.
static func burst(parent: Node, at: Vector2, id: String, strong := false) -> void:
	var fx: Dictionary = SKILL_FX.get(id, SKILL_FX["smile"])
	var cols: Array = fx["cols"]
	var count := int(fx["n"]) + (10 if strong else 0)
	var rays := int(fx["rays"])
	var size := 1.6 if strong else 1.0
	var bits: Array = []
	for i in count:
		var a := randf() * TAU
		bits.append([Vector2.from_angle(a) * randf_range(10.0, 26.0) * size,
			Color(String(cols[i % cols.size()])), randf_range(1.0, 2.2),
			randf() < 0.35])
	var n := Node2D.new()
	n.z_index = Z
	n.position = at
	n.set_meta("t", 0.0)
	var spin := randf() * TAU
	n.draw.connect(func() -> void:
		var t: float = n.get_meta("t")
		var a := 1.0 - t
		# 고리 둘 - 빛깔을 달리해 겹쳐 퍼진다
		for k in 2:
			var c := Color(String(cols[k % cols.size()]))
			c.a = a * 0.8
			n.draw_arc(Vector2.ZERO, (4.0 + 18.0 * t) * size * (1.0 + 0.35 * k),
				0.0, TAU, 20, c, 1.4)
		# 빛살
		for i in rays:
			var d := Vector2.from_angle(spin + TAU * float(i) / float(rays))
			var c2 := Color(String(cols[i % cols.size()]))
			c2.a = a
			n.draw_line(d * 3.0 * size, d * (8.0 + 16.0 * t) * size, c2, 1.2)
		# 조각 - 넷에 하나는 별(십자) 모양
		for b in bits:
			var p: Vector2 = b[0] * (0.2 + t)
			var c3: Color = b[1]
			c3.a = a
			var s: float = b[2]
			if b[3]:
				n.draw_line(p + Vector2(-s * 1.6, 0), p + Vector2(s * 1.6, 0), c3, 1.0)
				n.draw_line(p + Vector2(0, -s * 1.6), p + Vector2(0, s * 1.6), c3, 1.0)
			else:
				n.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), c3))
	parent.add_child(n)
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		n.set_meta("t", v)
		n.queue_redraw(), 0.0, 1.0, 0.55 if strong else 0.42)
	tw.tween_callback(n.queue_free)


## 스킬 이름이 머리 위에 그 빛깔로 떴다 사라진다 - 무엇을 썼는지 한눈에.
static func cast_name(parent: Node, at: Vector2, id: String) -> void:
	var cols := cols_of(id)
	var l := number(parent, at + Vector2(0, -40), String(Battle.SKILLS.get(id, {})
		.get("name", "")), Color(String(cols[0])), 15)
	var tw := l.create_tween()
	for c in cols:
		tw.tween_property(l, "theme_override_colors/font_color", Color(String(c)), 0.08)

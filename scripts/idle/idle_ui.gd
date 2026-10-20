class_name IdleUi
extends RefCounted
## 진짜 행복 UI 한 벌 (2026-10 전체 개편). 색·상자·버튼·그림 아이콘을 **여기 한 곳**에서 만든다 -
## 전투 화면(`idle_game.gd`)과 메인 화면(`main_menu_3d.gd`)이 같은 것을 쓴다.
##
## 방향 (2026-10-20): **라벤더 + 노랑** 이 핵심 색. 밝은 라벤더 판 · 라벤더 테두리와 버튼 · 노란 주 버튼 ·
## 진한 자두색 글씨. 예전 짙은 보라 판은 너무 진하다는 의견으로 바꿨다.
## 밝은 글씨(노랑·초록·흰색)는 밝은 바탕에 묻히므로 `label()` 이 자동으로 자두색 테두리를 두른다.
## 폰트에 없는 기호(✕ ⚙ ▶ 같은)는 쓰지 않고 아이콘은 전부 직접 그린다 (`draw_icon`).

const LAV := Color("#BF94E4")          ## 라벤더 (핵심 색)
const LAV_DK := Color("#9A6CC8")       ## 라벤더 그늘
const LAV_LT := Color("#EADCF7")       ## 연한 라벤더
const INK := Color("#F6EFFC")          ## 판 바탕 (밝은 라벤더)
const INK_2 := Color("#FFFFFF")        ## 판 안의 카드
const INK_3 := LAV                     ## 보통 버튼
const LINE := Color("#D4BCEE")         ## 카드 테두리
const GOLD := Color("#FFD23F")         ## 노랑 (핵심 색) - 주 버튼·강조
const GOLD_DK := Color("#C99700")
const CREAM := Color("#3B2559")        ## 본문 글씨 (이름은 옛것 - 지금은 진한 자두색)
const SUB := Color("#7B629B")          ## 보조 글씨
const MUTED := Color("#B4A6C6")        ## 잠긴 것
const RED := Color("#F0506E")
const GREEN := Color("#5CCB7A")
const OUTLINE := Color("#3B2559")      ## 밝은 글씨의 테두리
const SHADOW := Color(0.35, 0.2, 0.5, 0.22)

## 직업 빛깔 (필살기·스킬 버튼 테두리).
const JOB_COL := {"novice": Color("#E8D9B0"), "warrior": Color("#FF9F45"), "mage": Color("#8FB5FF"),
	"archer": Color("#8EE07E"), "thief": Color("#C49BFF")}


static func box(bg: Color, border: Color, radius := 22, bw := 3, margin := 12, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = SHADOW
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 4)
	return s


## 큰 판 (창). 짙은 바탕 + 금빛 테두리 + 안쪽 은은한 빛줄.
static func panel_style() -> StyleBoxFlat:
	var s := box(Color(INK.r, INK.g, INK.b, 0.97), LAV, 28, 5, 22)
	s.shadow_size = 18
	s.shadow_color = Color(0.3, 0.15, 0.45, 0.35)
	return s


## 위쪽 정보 알약.
static func pill_style() -> StyleBoxFlat:
	var s := box(Color(1, 1, 1, 0.92), LAV, 20, 3, 10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	return s


static func card_style(border := LINE) -> StyleBoxFlat:
	return box(INK_2, border, 18, 2, 12, false)


static func label(t: String, fs: int, col := CREAM, outline := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	# 밝은 글씨는 자두색 테두리, 어두운 글씨에 테두리를 달라면 흰 테두리 (풍경 위 스티커처럼)
	var light := col.get_luminance() > 0.5
	if outline:
		l.add_theme_color_override("font_outline_color", OUTLINE if light else Color(1, 1, 1, 0.95))
		l.add_theme_constant_override("outline_size", maxi(6, fs / 5))
	elif light:
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", maxi(4, fs / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 버튼 종류: gold(주 행동) · plum(보통) · ghost(닫기 같은 가벼운 것) · danger(지우기).
static func button(t: String, fs: int, kind := "plum", tint := Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	var bg := INK_3
	var border := LAV_DK
	var fc := Color("#2E1A4A")
	match kind:
		"gold":
			bg = GOLD
			border = GOLD_DK
			fc = Color("#3A2410")
		"ghost":
			bg = Color(1, 1, 1, 0.95)
			border = LAV
			fc = CREAM
		"danger":
			bg = Color("#F07C93")
			border = Color("#C9445F")
			fc = Color("#3A0E1C")
	if tint.a > 0.0:
		bg = Color.WHITE.lerp(tint, 0.35)
		border = tint
	for st in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", MUTED)
	var n := box(bg, border, 22, 3, 8)
	var h := box(bg.lightened(0.08), border, 22, 3, 8)
	var p := box(bg.darkened(0.15), border, 22, 3, 8)
	p.shadow_size = 2
	p.shadow_offset = Vector2(0, 1)
	var d := box(Color("#E9E1F1"), Color("#D8CCE4"), 22, 3, 8, false)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func() -> void: b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	return b


static func bar(col: Color, sz: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = sz
	b.size = sz
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(sz.y * 0.5))
	fill.border_width_top = int(maxf(1.0, sz.y * 0.25))
	fill.border_color = col.lightened(0.35)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.23, 0.15, 0.35, 0.55)
	bg.set_corner_radius_all(int(sz.y * 0.5))
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


# ── 아이콘 (폰트 기호 대신 직접 그린다) ─────────────────────────────

## 아이콘을 그리는 작은 컨트롤. `kind`: hero · chest · sword · bag · map · menu · close · lock · auto · coin · star · home ·
## gear · play · refresh · boss
static func icon(kind: String, sz := 40.0, col := CREAM) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: draw_icon(c, kind, Vector2(sz, sz) * 0.5, sz, col))
	return c


static func draw_icon(ci: CanvasItem, kind: String, o: Vector2, sz: float, col: Color) -> void:
	var u := sz / 40.0
	var w := maxf(2.0, 3.2 * u)
	match kind:
		"sword":
			ci.draw_line(o + Vector2(-11, 11) * u, o + Vector2(12, -12) * u, col, w * 1.6, true)
			ci.draw_line(o + Vector2(-13, 3) * u, o + Vector2(-3, 13) * u, col, w, true)
			ci.draw_line(o + Vector2(-14, 14) * u, o + Vector2(-10, 10) * u, col, w * 1.4, true)
		"bag":
			var r := Rect2(o + Vector2(-13, -6) * u, Vector2(26, 20) * u)
			ci.draw_rect(r, col, false, w)
			ci.draw_arc(o + Vector2(0, -6) * u, 7.0 * u, PI, TAU, 12, col, w, true)
			ci.draw_line(o + Vector2(-13, 2) * u, o + Vector2(13, 2) * u, col, w, true)
			ci.draw_rect(Rect2(o + Vector2(-3, 0) * u, Vector2(6, 5) * u), col)
		"map":
			var pts := PackedVector2Array([o + Vector2(-14, -10) * u, o + Vector2(-5, -13) * u,
				o + Vector2(5, -10) * u, o + Vector2(14, -13) * u, o + Vector2(14, 10) * u,
				o + Vector2(5, 13) * u, o + Vector2(-5, 10) * u, o + Vector2(-14, 13) * u, o + Vector2(-14, -10) * u])
			ci.draw_polyline(pts, col, w, true)
			ci.draw_line(o + Vector2(-5, -13) * u, o + Vector2(-5, 10) * u, col, w * 0.7, true)
			ci.draw_line(o + Vector2(5, -10) * u, o + Vector2(5, 13) * u, col, w * 0.7, true)
		"menu":
			for k in [-8.0, 0.0, 8.0]:
				ci.draw_line(o + Vector2(-11, k) * u, o + Vector2(11, k) * u, col, w * 1.1, true)
		"close":
			ci.draw_line(o + Vector2(-9, -9) * u, o + Vector2(9, 9) * u, col, w * 1.2, true)
			ci.draw_line(o + Vector2(9, -9) * u, o + Vector2(-9, 9) * u, col, w * 1.2, true)
		"lock":
			ci.draw_rect(Rect2(o + Vector2(-9, -2) * u, Vector2(18, 14) * u), col)
			ci.draw_arc(o + Vector2(0, -3) * u, 6.0 * u, PI, TAU, 12, col, w, true)
			ci.draw_line(o + Vector2(-6, -3) * u, o + Vector2(-6, -1) * u, col, w, true)
			ci.draw_line(o + Vector2(6, -3) * u, o + Vector2(6, -1) * u, col, w, true)
		"auto", "refresh":
			ci.draw_arc(o, 11.0 * u, 0.4, TAU - 0.6, 24, col, w, true)
			var tip := o + Vector2(cos(0.4), sin(0.4)) * 11.0 * u
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -2) * u, tip + Vector2(5, -3) * u,
				tip + Vector2(1, 7) * u]), col)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-8, -11) * u, o + Vector2(11, 0) * u,
				o + Vector2(-8, 11) * u]), col)
		"coin", "star":
			var p := PackedVector2Array()
			for i in 8:
				var a := -PI * 0.5 + i * PI / 4.0
				var rr := (12.0 if i % 2 == 0 else 4.5) * u
				p.append(o + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(p, col)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-13, -1) * u, o + Vector2(0, -13) * u,
				o + Vector2(13, -1) * u]), col)
			ci.draw_rect(Rect2(o + Vector2(-9, -2) * u, Vector2(18, 14) * u), col)
		"gear":
			ci.draw_arc(o, 8.0 * u, 0.0, TAU, 20, col, w * 1.4, true)
			for i in 8:
				var a := i * PI / 4.0
				ci.draw_line(o + Vector2(cos(a), sin(a)) * 9.0 * u, o + Vector2(cos(a), sin(a)) * 14.0 * u, col,
					w * 1.5, true)
		"boss":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-13, 8) * u, o + Vector2(-13, -6) * u,
				o + Vector2(-6, 1) * u, o + Vector2(0, -11) * u, o + Vector2(6, 1) * u, o + Vector2(13, -6) * u,
				o + Vector2(13, 8) * u]), col)
		"hero":
			ci.draw_circle(o + Vector2(0, -6) * u, 7.5 * u, col)
			ci.draw_circle(o + Vector2(-6, -12) * u, 3.0 * u, col)
			ci.draw_circle(o + Vector2(6, -12) * u, 3.0 * u, col)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-12, 14) * u, o + Vector2(-9, 3) * u,
				o + Vector2(9, 3) * u, o + Vector2(12, 14) * u]), col)
		"chest":
			ci.draw_rect(Rect2(o + Vector2(-14, -4) * u, Vector2(28, 16) * u), col)
			ci.draw_rect(Rect2(o + Vector2(-14, -12) * u, Vector2(28, 7) * u), col.darkened(0.2))
			ci.draw_rect(Rect2(o + Vector2(-3, -6) * u, Vector2(6, 7) * u), GOLD.lightened(0.3))


## 아이콘 + 글자가 위아래로 쌓인 큰 버튼 (아래 줄 셋).
static func icon_button(t: String, kind: String, fs := 24, style := "plum") -> Button:
	var b := button("", fs, style)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(kind, 34.0, GOLD if style != "gold" else Color("#3A2410"))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := label(t, fs, CREAM if style != "gold" else Color("#3A2410"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.add_child(v)
	return b


## 둥근 아이콘만 있는 버튼 (메뉴·닫기).
static func round_button(kind: String, sz := 64.0, style := "plum") -> Button:
	var b := button("", 10, style)
	b.custom_minimum_size = Vector2(sz, sz)
	b.size = Vector2(sz, sz)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := b.get_theme_stylebox(st) as StyleBoxFlat
		if s != null:
			s.set_corner_radius_all(int(sz * 0.5))
	var ic := icon(kind, sz * 0.6, CREAM if style != "gold" else Color("#3A2410"))
	ic.position = Vector2(sz * 0.2, sz * 0.2)
	b.add_child(ic)
	return b


## 굴림 막대를 가늘게 (기본 막대는 굵고 노래서 판 위에서 튀었다).
static func style_scroll(sc: ScrollContainer) -> void:
	var vb := sc.get_v_scroll_bar()
	if vb == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.06)
	track.set_corner_radius_all(4)
	track.content_margin_left = 4
	track.content_margin_right = 4
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 4
	grab.content_margin_right = 4
	var grab_h := grab.duplicate() as StyleBoxFlat
	grab_h.bg_color = GOLD
	vb.add_theme_stylebox_override("scroll", track)
	vb.add_theme_stylebox_override("grabber", grab)
	vb.add_theme_stylebox_override("grabber_highlight", grab_h)
	vb.add_theme_stylebox_override("grabber_pressed", grab_h)
	vb.custom_minimum_size = Vector2(8, 0)

extends CanvasLayer
## 여행 기록 화면.
##
## 이 게임은 숫자로 성취를 말하지 않는다. 그래서 통계도 "몇 개"보다
## 막대의 길이와 점의 밀도로 먼저 보여주고, 숫자는 작게 곁들이기만 한다.
## 1280x720 가로 화면 기준.

## 막별 색. TravelState.CHAPTERS 순서와 짝을 이룬다.
## (CHAPTERS 자체에는 색이 없어서 여행 허브의 색조와 같은 값을 쓴다)
const CHAPTER_COLORS := {
	"korea":  Color(0.55, 0.78, 0.55),
	"world":  Color(0.72, 0.72, 0.92),
	"space":  Color(0.65, 0.72, 0.95),
	"beyond": Color(1.00, 0.86, 0.62),
}

const CREAM := Color(1.00, 0.95, 0.80)
const GOLD  := Color(1.00, 0.86, 0.55)
const SOFT  := Color(0.86, 0.84, 0.95)
const DIM   := Color(0.55, 0.53, 0.68)

var _stats: Dictionary = {}


func _ready() -> void:
	add_to_group("stats_ui")     # 뒤로가기가 이걸 찾아 닫는다
	layer = 60
	_stats = TripStats.gather()
	_build()


## Esc 또는 B 로 닫는다
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_B:
			get_viewport().set_input_as_handled()
			_close()


func _close() -> void:
	queue_free()


# ── 화면 조립 ───────────────────────────────────────────────────────────

func _build() -> void:
	# 배경: 반투명 어두운 막 (뒤의 허브가 비쳐 보인다)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.11, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 64
	panel.offset_right = -64
	panel.offset_top = 28
	panel.offset_bottom = -28
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	# 글자를 30pt 로 올린 뒤로 내용이 화면 높이를 넘겨서 '닫기' 버튼이 잘려 나갔다.
	# 폰 비율(720)에서만 나던 문제라 태블릿에서는 안 보였다.
	# 넘치면 스크롤되게 하고, 닫기 버튼은 스크롤 밖에 고정해 언제나 눌리게 둔다.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	root.add_child(_make_header())
	root.add_child(_make_overall_bar())

	# 가운데: 왼쪽 막별 진행 / 오른쪽 다녀온 곳 점그림
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	cols.add_child(_make_chapter_column())
	cols.add_child(_make_dots_column())
	root.add_child(cols)

	root.add_child(_make_habits_row())
	# 닫기 버튼은 스크롤 밖. 내용이 아무리 길어도 항상 화면 안에 있어야 한다.
	outer.add_child(_make_footer())


func _make_header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)

	var t := Label.new()
	t.text = "여행 기록"
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", CREAM)
	h.add_child(t)

	var sub := Label.new()
	# 숫자보다 문장이 먼저 읽히도록 요약을 한 줄로 준다
	sub.text = "쿼카 커플이 지금까지 다녀온 길"
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", SOFT)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(sub)

	if bool(_stats.get("ending", false)):
		var e := Label.new()
		e.text = "✨ 다른 차원까지 다녀옴"
		e.add_theme_font_size_override("font_size", 30)
		e.add_theme_color_override("font_color", GOLD)
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(e)
	return h


## 전체 진행률 — 굵은 막대 하나로만 말한다
func _make_overall_bar() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)

	var bar := _bar(float(_stats.get("ratio", 0.0)), GOLD, 18)
	v.add_child(bar)

	var l := Label.new()
	l.text = "다녀온 곳 %d / %d" % [int(_stats.get("visited", 0)), int(_stats.get("total", 0))]
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(l)
	return v


## 왼쪽 열: 막별 가로 막대
func _make_chapter_column() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(430, 0)
	v.size_flags_horizontal = Control.SIZE_FILL
	v.add_theme_constant_override("separation", 10)

	v.add_child(_section_title("막별 진행"))

	for ch in _stats.get("chapters", []):
		var c: Dictionary = ch
		var col: Color = CHAPTER_COLORS.get(str(c.get("id", "")), Color(0.7, 0.72, 0.85))
		var open: bool = bool(c.get("unlocked", true))

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)

		var head := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = ("%s" % c.get("name", "")) if open else ("🔒 %s" % c.get("name", ""))
		name_l.add_theme_font_size_override("font_size", 30)
		name_l.add_theme_color_override("font_color", col if open else DIM)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		var num := Label.new()
		num.text = "%d/%d" % [int(c.get("visited", 0)), int(c.get("total", 0))]
		num.add_theme_font_size_override("font_size", 30)
		num.add_theme_color_override("font_color", DIM)
		head.add_child(num)
		row.add_child(head)

		row.add_child(_bar(float(c.get("ratio", 0.0)), col if open else DIM.darkened(0.2), 13))
		v.add_child(row)

	v.add_child(_make_highlight_card())
	return v


## 왼쪽 아래 요약 카드. 숫자를 늘어놓는 대신 문장 세 줄로 말한다.
func _make_highlight_card() -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)

	var top: Dictionary = _stats.get("top", {})
	var lines: Array[String] = []
	if top.is_empty():
		lines.append("아직 첫 여행을 기다리는 중이에요")
	else:
		lines.append("%s  %s에 %d번 — 제일 자주 간 곳" % [
			str(top.get("emoji", "")), str(top.get("name", "")), int(top.get("count", 0))])
		lines.append("사진과 일기 %d장을 모았어요" % int(_stats.get("records", 0)))
		var q := int(_stats.get("quiet_days", 0))
		if q > 0:
			lines.append("그중 %d번은 아무 일 없던 조용한 하루" % q)
		else:
			lines.append("조용한 하루는 아직 없었어요")
	for s in lines:
		var l := Label.new()
		l.text = s
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	pc.add_child(v)
	return pc


## 오른쪽 열: 여행지 하나가 점 하나. 다녀온 곳만 불이 켜진다.
func _make_dots_column() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	v.add_child(_section_title("다녀온 곳"))

	var dots := _DotGrid.new()
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dots.custom_minimum_size = Vector2(0, 200)
	dots.setup(_stats, CHAPTER_COLORS)
	v.add_child(dots)
	return v


## 열린 습관 — 이름만 칩처럼 늘어놓는다
func _make_habits_row() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(_section_title("함께 익힌 것"))

	var habits: Array = _stats.get("habits", [])
	if habits.is_empty():
		var l := Label.new()
		l.text = "아직 없어요. 여행을 다녀오면 하나씩 생겨요."
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", DIM)
		v.add_child(l)
		return v

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for hb in habits:
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.30, 0.26, 0.46, 0.85)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(1)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", sb)
		var cl := Label.new()
		cl.text = str((hb as Dictionary).get("name", ""))
		cl.tooltip_text = str((hb as Dictionary).get("effect_hint", ""))
		cl.add_theme_font_size_override("font_size", 30)
		cl.add_theme_color_override("font_color", CREAM)
		chip.add_child(cl)
		flow.add_child(chip)
	v.add_child(flow)
	return v


func _make_footer() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := Button.new()
	b.text = "닫기"
	b.custom_minimum_size = Vector2(200, 40)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(_close)
	h.add_child(b)
	return h


# ── 작은 부품 ───────────────────────────────────────────────────────────

func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", GOLD)
	return l


## 가로 막대 하나 (배경 홈 + 채운 부분)
func _bar(ratio: float, col: Color, height: int) -> Control:
	var back := PanelContainer.new()
	back.custom_minimum_size = Vector2(0, height)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(1, 1, 1, 0.08)
	bs.set_corner_radius_all(height / 2)
	back.add_theme_stylebox_override("panel", bs)

	# 채운 부분은 비율만큼만 가로를 차지하게 하고, 나머지는 빈 Control 이 먹는다
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var fill := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(col.r, col.g, col.b, 0.92)
	fs.set_corner_radius_all(height / 2)
	fill.add_theme_stylebox_override("panel", fs)
	var r := clampf(ratio, 0.0, 1.0)
	# 0 이어도 아주 얇게 남겨두면 막대가 어디 있는지 보인다
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = maxf(r, 0.001)
	var rest := Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = maxf(1.0 - r, 0.001)
	rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	row.add_child(rest)
	back.add_child(row)
	return back


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.20, 0.94)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	return sb


## 여행지 점그림. 225곳을 이름으로 늘어놓을 수 없으니 점의 밀도로 보여준다.
## Control 을 직접 그려서(_draw) 노드 수백 개를 만들지 않는다.
class _DotGrid extends Control:
	var _entries: Array = []   # [{color, on}]

	func setup(stats: Dictionary, chapter_colors: Dictionary) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		var state = tree.root.get_node_or_null("TravelState") if tree else null
		if state == null:
			return
		var visits: Dictionary = stats.get("visit_counts", {})
		for d in state.DESTINATIONS:
			var dd: Dictionary = d
			var col: Color = chapter_colors.get(str(dd.get("chapter", "")), Color(0.7, 0.72, 0.85))
			_entries.append({
				"color": col,
				"on": int(visits.get(str(dd.get("id", "")), 0)) > 0,
			})
		queue_redraw()

	func _draw() -> void:
		if _entries.is_empty():
			return
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		# 점이 영역 전체에 고르게 퍼지도록 칸 크기를 넓이·높이로 함께 정한다.
		# (가로만 보고 정하면 아래가 텅 비어 진행이 실제보다 적어 보인다)
		var cell: float = maxf(8.0, sqrt(w * h / float(_entries.size())))
		var cols: int = clampi(int(w / cell), 6, _entries.size())
		var rows: int = int(ceil(float(_entries.size()) / float(cols)))
		var cw := w / float(cols)
		var chh: float = minf(cw, h / float(maxi(rows, 1)))
		var rad: float = maxf(1.5, minf(cw, chh) * 0.32)
		for i in range(_entries.size()):
			var e: Dictionary = _entries[i]
			var cx := (float(i % cols) + 0.5) * cw
			var cy := (float(i / cols) + 0.5) * chh
			if cy > h:
				break
			var c: Color = e["color"]
			if bool(e["on"]):
				draw_circle(Vector2(cx, cy), rad, c)
			else:
				draw_circle(Vector2(cx, cy), rad * 0.62, Color(c.r, c.g, c.b, 0.16))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

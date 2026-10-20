class_name LaneGacha
extends Control
## 꿈 캡슐 여는 연출. 캡슐이 떨어지고 → 등급만큼 흔들리며 색이 바뀌고 → 터지면서 친구가 튀어나온다.
## 강한 효과는 여기와 전설 등장에만 몰아 쓴다 - 평소 싸움이 번쩍거리면 정작 이 순간이 안 산다.
## play(results) 로 시작, 다 보면 `finished`.

signal finished

const COL := {"rare": Color("#7FD0FF"), "super": Color("#C58CFF"), "legend": Color("#FFD15A")}
const SHAKES := {"rare": 1, "super": 2, "legend": 3}
const SHOW_PX := 11.0

var _results: Array = []
var _i := 0
var _phase := "idle"        ## drop · shake · open · show · summary
var _cap_pos := Vector2.ZERO
var _cap_col := Color("#FFF4F0")
var _cap_open := 0.0        ## 0 닫힘 → 1 반쪽이 날아감
var _cap_rot := 0.0
var _cap_alpha := 1.0
var _rays := 0.0            ## 뒤에서 도는 빛 줄기 세기
var _ray_col := Color.WHITE
var _t := 0.0
var _tw: Tween
var _fx: IdleFx
var _vfx: IdleVfx
var _flash: ColorRect
var _card: Control
var _hint: Label
var _tap_ok := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fx = IdleFx.new()
	add_child(_fx)
	_vfx = IdleVfx.new()
	add_child(_vfx)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_hint = IdleUi.label("", 24, IdleUi.LAV_LT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func play(results: Array) -> void:
	_results = results
	_i = 0
	_next()


func _process(dt: float) -> void:
	_t += dt
	_flash.size = size
	_flash.color.a = maxf(0.0, _flash.color.a - dt * 2.5)
	_hint.position = Vector2(0, size.y - 120)
	_hint.size = Vector2(size.x, 40)
	_hint.modulate.a = 0.5 + 0.5 * sin(_t * 4.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.11, 0.27, 0.96))
	var c := size * Vector2(0.5, 0.42)
	if _rays > 0.0:
		# 뒤에서 천천히 도는 빛 줄기
		var n := 14
		for k in n:
			var a0 := _t * 0.5 + TAU * float(k) / float(n)
			var a1 := a0 + TAU / float(n) * 0.45
			var r := size.x * 1.1
			var col := _ray_col
			col.a = 0.16 * _rays
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r]), col)
		var glow := _ray_col
		for i in 5:
			glow.a = 0.07 * _rays
			draw_circle(c, 80.0 + float(i) * 40.0, glow)
	if _phase in ["drop", "shake", "open"]:
		_draw_capsule()


func _draw_capsule() -> void:
	# 달걀 모양 꿈 캡슐 - 위 반쪽에 색, 아래 반쪽은 우윳빛, 이음매는 톱니. 가운데 별 스티커.
	var rx := 84.0
	var ry := 104.0
	var p := _cap_pos
	var top := _cap_col
	top.a = _cap_alpha
	var bot := Color("#FFF8F2")
	bot.a = _cap_alpha
	var ink := Color(0.17, 0.1, 0.18, _cap_alpha)
	var off := _cap_open * 260.0
	draw_set_transform(p + Vector2(-off * 0.3, -off), _cap_rot - _cap_open * 1.2, Vector2.ONE)
	draw_colored_polygon(_half(rx + 6.0, ry * 1.08 + 6.0, true), ink)
	draw_colored_polygon(_half(rx, ry * 1.08, true), top)
	draw_circle(Vector2(-rx * 0.42, -ry * 0.55), rx * 0.16, Color(1, 1, 1, 0.6 * _cap_alpha))
	_star(Vector2(rx * 0.12, -ry * 0.42), 22.0, Color(1, 1, 1, 0.9 * _cap_alpha), ink)
	draw_set_transform(p + Vector2(off * 0.3, off * 0.6), _cap_rot + _cap_open * 0.9, Vector2.ONE)
	draw_colored_polygon(_half(rx + 6.0, ry * 0.92 + 6.0, false), ink)
	draw_colored_polygon(_half(rx, ry * 0.92, false), bot)
	draw_circle(Vector2(-rx * 0.4, ry * 0.3), rx * 0.1, Color(1, 1, 1, 0.8 * _cap_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _star(c: Vector2, r: float, col: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	var big := PackedVector2Array()
	for q in pts:
		big.append(c + (q - c) * 1.25)
	draw_colored_polygon(big, ink)
	draw_colored_polygon(pts, col)


## 달걀 반쪽 - 위(upper) 또는 아래. 자른 면은 톱니 모양.
static func _half(rx: float, ry: float, upper: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI + PI * float(i) / 20.0 if upper else PI * float(i) / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	# 톱니 이음매 (오른쪽 → 왼쪽, 또는 왼쪽 → 오른쪽)
	var n := 8
	for k in range(1, n):
		var t := float(k) / float(n)
		var x := rx - 2.0 * rx * t if upper else -rx + 2.0 * rx * t
		pts.append(Vector2(x, (7.0 if k % 2 == 0 else -7.0) * (1.0 if upper else 1.0)))
	return pts


func _gui_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if not tap:
		return
	accept_event()
	if _phase == "show" and _tap_ok:
		_i += 1
		_next()
	elif _phase in ["drop", "shake"] and _results.size() > 1:
		# 10번 뽑기는 눌러서 빨리 넘긴다 - 바로 열기
		_open()
	elif _phase == "summary" and _tap_ok:
		finished.emit()
		queue_free()


func _next() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
	if _i >= _results.size():
		if _results.size() > 1:
			_summary()
		else:
			finished.emit()
			queue_free()
		return
	var res: Dictionary = _results[_i]
	_phase = "drop"
	_tap_ok = false
	_rays = 0.0
	_cap_open = 0.0
	_cap_alpha = 1.0
	_cap_rot = 0.0
	_cap_col = Color("#FFB6C8")
	_hint.text = "%d / %d" % [_i + 1, _results.size()] if _results.size() > 1 else ""
	var c := size * Vector2(0.5, 0.42)
	_cap_pos = Vector2(c.x, -160.0)
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "_cap_pos", c, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func() -> void:
		AudioManager.ui_click()
		_vfx.burst(c + Vector2(0, 100), Color("#F2E2C2"), 8, 200.0, 0.4, 0.35, true))
	var shakes := int(SHAKES[String(res["rarity"])])
	var steps := [Color("#FFB6C8"), COL["rare"], COL["super"], COL["legend"]]
	for k in shakes:
		_tw.tween_interval(0.25)
		_tw.tween_callback(func() -> void:
			_phase = "shake"
			_cap_col = steps[k + 1]
			_fx.ring(c, 60.0, 220.0 + 60.0 * k, steps[k + 1], 10.0, 0.45)
			_vfx.burst(c, steps[k + 1], 10 + 8 * k, 260.0, 0.5, 0.45)
			AudioManager.battle_weak_hit())
		for j in 4:
			_tw.tween_property(self, "_cap_rot", 0.22 * (1.0 if j % 2 == 0 else -1.0) * (1.0 + 0.4 * k), 0.06)
		_tw.tween_property(self, "_cap_rot", 0.0, 0.06)
	_tw.tween_interval(0.3 if shakes < 3 else 0.6)
	_tw.tween_callback(_open)


func _open() -> void:
	if _phase == "open" or _phase == "show":
		return
	if _tw != null:
		_tw.kill()
	var res: Dictionary = _results[_i]
	var r := String(res["rarity"])
	var col: Color = COL[r]
	var c := size * Vector2(0.5, 0.42)
	_cap_pos = c
	_cap_col = col
	_phase = "open"
	_ray_col = col
	_flash.color = Color(1, 1, 1, 0.9 if r == "legend" else 0.6)
	_fx.rays(c, col, 18 if r == "legend" else 12, 80.0, size.x * 0.8, 0.5)
	_fx.ring(c, 40.0, size.x * 0.7, col, 18.0, 0.6)
	_vfx.burst(c, col, 30 + 20 * int(SHAKES[r]), 520.0, 0.9, 0.6)
	_vfx.burst(c, Color.WHITE, 16, 360.0, 0.6, 0.4)
	if r == "legend":
		_vfx.burst(c, Color("#FF8FD8"), 30, 700.0, 1.2, 0.6, false, 0.15)
		_vfx.burst(c, Color("#9FD8FF"), 30, 700.0, 1.2, 0.6, false, 0.3)
		AudioManager.sky_crack()
	AudioManager.souvenir_get()
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(self, "_cap_open", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "_cap_alpha", 0.0, 0.45)
	_tw.tween_property(self, "_rays", 1.0 if r != "rare" else 0.6, 0.4)
	_show_card(res)


func _show_card(res: Dictionary) -> void:
	var id := String(res["id"])
	var r := String(res["rarity"])
	var col: Color = COL[r]
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = size
	add_child(_card)
	move_child(_card, _flash.get_index())
	var c := size * Vector2(0.5, 0.42)
	var tex := load(LaneData.sheet_path(id, int(res["lv"]))) as Texture2D
	var pic := TextureRect.new()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		var a := AtlasTexture.new()
		a.atlas = tex
		var w := tex.get_width() / 4.0
		var h := tex.get_height() / 3.0
		a.region = Rect2(w, 0, w, h)   # 만세 칸
		pic.texture = a
		pic.size = Vector2(w, h) * SHOW_PX * (0.8 if w > 30 else 1.0)
	pic.position = c - pic.size * 0.5
	pic.pivot_offset = pic.size * 0.5
	pic.scale = Vector2(0.1, 0.1)
	_card.add_child(pic)
	var tw := create_tween()
	tw.tween_property(pic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 숨 쉬듯 살짝 통통
	tw.tween_callback(func() -> void:
		var bob := pic.create_tween().set_loops()
		bob.tween_property(pic, "scale", Vector2(1.04, 0.97), 0.5).set_trans(Tween.TRANS_SINE)
		bob.tween_property(pic, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE))
	var y := c.y + pic.size.y * 0.5 + 20.0
	var stars := IdleUi.label("★".repeat(int(LaneData.RARITY_STARS[r])) + "  " + String(LaneData.RARITY_NAME[r]), 34, col, true)
	_card.add_child(_at(stars, y))
	var name := IdleUi.label(LaneData.unit_name(id, int(res["lv"])), 50, Color.WHITE, true)
	_card.add_child(_at(name, y + 50))
	var sub := IdleUi.label(LaneData.trait_text(id) if LaneData.trait_text(id) != "" else String(LaneData.UNITS[id]["role"]),
		24, IdleUi.LAV_LT)
	_card.add_child(_at(sub, y + 120))
	var tag: Label
	if bool(res["new"]):
		tag = IdleUi.label("NEW! 새 친구가 합류했어요", 32, IdleUi.GREEN, true)
	elif int(res["xp"]) > 0:
		tag = IdleUi.label("이미 최고 레벨 - 꿈조각 +%s" % LaneGacha._num(int(res["xp"])), 28, IdleUi.GOLD, true)
	else:
		tag = IdleUi.label("또 만났어요! 레벨 +1 (Lv %d)" % int(res["lv"]), 28, IdleUi.GOLD, true)
	_card.add_child(_at(tag, y + 166))
	for l in [stars, name, sub, tag]:
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.25).set_delay(0.25)
	if r == "legend":
		var big := IdleUi.label("전설!", 80, COL["legend"], true)
		_card.add_child(_at(big, size.y * 0.1))
		big.pivot_offset = Vector2(size.x * 0.5, 40)
		big.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(big, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 금빛 가루가 계속 내린다
		var rain := create_tween().set_loops(6)
		rain.tween_callback(func() -> void:
			_vfx.burst(Vector2(randf_range(60, size.x - 60), size.y * 0.15), COL["legend"], 8, 120.0, 1.4, 0.4, false))
		rain.tween_interval(0.35)
	_later(0.6, func() -> void:
		_phase = "show"
		_tap_ok = true
		if _results.size() == 1 or _i == _results.size() - 1:
			_hint.text = "눌러서 닫기" if _results.size() == 1 else "눌러서 모아 보기"
		else:
			_hint.text = "눌러서 다음  (%d / %d)" % [_i + 1, _results.size()])


func _summary() -> void:
	_phase = "summary"
	_rays = 0.0
	_tap_ok = false
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = size
	add_child(_card)
	var t := IdleUi.label("이번에 만난 친구들", 40, IdleUi.GOLD, true)
	_card.add_child(_at(t, 120))
	var cols := 3
	var cw := (size.x - 80.0) / float(cols)
	for k in _results.size():
		var res: Dictionary = _results[k]
		var id := String(res["id"])
		var r := String(res["rarity"])
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", IdleUi.card_style(COL[r]))
		cell.position = Vector2(40.0 + float(k % cols) * cw + 6.0, 200.0 + float(k / cols) * 230.0)
		cell.custom_minimum_size = Vector2(cw - 12.0, 218.0)
		cell.size = cell.custom_minimum_size
		_card.add_child(cell)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(v)
		var tex := load(LaneData.sheet_path(id, int(res["lv"]))) as Texture2D
		var pic := TextureRect.new()
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(110, 110)
		if tex != null:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(0, 0, tex.get_width() / 4.0, tex.get_height() / 3.0)
			pic.texture = a
		v.add_child(pic)
		var nm := IdleUi.label(String(LaneData.UNITS[id]["name"]), 20, IdleUi.CREAM)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var tg := IdleUi.label("NEW!" if bool(res["new"]) else "Lv %d" % int(res["lv"]), 20,
			IdleUi.GREEN if bool(res["new"]) else COL[r])
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tg)
		cell.pivot_offset = cell.size * 0.5
		cell.scale = Vector2.ZERO
		create_tween().tween_property(cell, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT).set_delay(0.05 * float(k))
	_hint.text = "눌러서 닫기"
	_later(0.8, func() -> void: _tap_ok = true)


func _at(l: Label, y: float) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(20, y)
	l.size = Vector2(size.x - 40, 60)
	return l


func _later(d: float, f: Callable) -> void:
	create_tween().tween_callback(f).set_delay(d)


static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

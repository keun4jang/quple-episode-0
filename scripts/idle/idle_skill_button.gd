class_name IdleSkillButton
extends Control
## 전투 화면의 스킬 버튼 하나 (둥근 것). 쿨타임은 어두운 부채꼴이 시계 방향으로 걷히며 남은 초를 보여 준다.
## 아직 못 배운 스킬은 **버튼은 보이되 꺼져 있다** - 자물쇠와 "LV 15" 를 그린다 (`docs/redesign-idle.md`).

signal pressed(i: int)

var index := 0
var title := ""
var col := Color.WHITE
var locked := true
var lock_lv := 5
var charge := 0.0          ## 0 막 씀 ~ 1 다 참
var secs_left := 0.0
var _t := 0.0
var _down := false
var _flash := 0.0
var _was_ready := false
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font
	var th := get_theme_default_font()
	if th != null:
		font = th


func set_state(p_title: String, p_col: Color, p_locked: bool, p_lv: int, p_charge: float, p_secs: float) -> void:
	title = p_title
	col = p_col
	locked = p_locked
	lock_lv = p_lv
	charge = p_charge
	secs_left = p_secs
	var ready := not locked and charge >= 1.0
	if ready and not _was_ready:
		_flash = 1.0            # 막 다 찼다 - 한 번 반짝
	_was_ready = ready


func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt * 2.5)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var down: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed)
	var up: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) \
		or (e is InputEventScreenTouch and not e.pressed)
	if down:
		_down = true
		accept_event()
	elif up and _down:
		_down = false
		accept_event()
		pressed.emit(index)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var o := size * 0.5
	var k := 0.93 if _down else 1.0
	var rr := r * k
	var ready := not locked and charge >= 1.0
	# 그림자
	draw_circle(o + Vector2(0, 4), rr, Color(0.06, 0.03, 0.12, 0.45))
	# 바탕
	var base := IdleUi.INK if not locked else Color("#2A2536")
	draw_circle(o, rr, base)
	if not locked:
		draw_circle(o, rr * 0.86, IdleUi.INK_2.lerp(col, 0.28))
	# 쿨타임 부채꼴 (안 찬 만큼 어둡게)
	if not locked and charge < 1.0:
		var pts := PackedVector2Array([o])
		var a0 := -PI * 0.5 + TAU * charge
		var steps := 28
		for i in steps + 1:
			var a := a0 + (TAU * (1.0 - charge)) * float(i) / float(steps)
			pts.append(o + Vector2(cos(a), sin(a)) * rr * 0.86)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.05, 0.03, 0.1, 0.62))
	# 테두리 - 다 차면 숨쉬며 빛난다
	var ring := IdleUi.MUTED if locked else col
	var rw := 4.0
	if ready:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(o, rr + 3.0 + pulse * 3.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.35 + 0.3 * pulse), 4.0, true)
		rw = 5.0
	draw_arc(o, rr - 2.0, 0, TAU, 40, ring, rw, true)
	if not locked and charge < 1.0:
		draw_arc(o, rr - 2.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, col.lightened(0.3), rw, true)
	if _flash > 0.0:
		draw_circle(o, rr * (1.0 + 0.3 * (1.0 - _flash)), Color(1, 1, 1, 0.35 * _flash))
	# 글자
	if locked:
		IdleUi.draw_icon(self, "lock", o + Vector2(0, -rr * 0.22), rr * 0.7, IdleUi.MUTED)
		_text("LV %d" % lock_lv, o + Vector2(0, rr * 0.42), int(rr * 0.36), IdleUi.MUTED)
		return
	var fs := int(rr * (0.42 if title.length() <= 2 else 0.34))
	if charge < 1.0:
		_text(title, o + Vector2(0, -rr * 0.18), fs, Color(1, 1, 1, 0.55))
		_text("%d" % int(ceil(secs_left)), o + Vector2(0, rr * 0.36), int(rr * 0.42), Color.WHITE)
	else:
		_text(title, o + Vector2(0, 0), fs, Color.WHITE)


func _text(t: String, at: Vector2, fs: int, c: Color) -> void:
	if font == null:
		return
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := at + Vector2(-w * 0.5, fs * 0.36)
	draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 5), Color("#1E1630"))
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

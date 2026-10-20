class_name LaneTutorial
extends Control
## 처음 하는 사람을 위한 한 걸음씩 안내. 한 번에 한 문장, "이거 눌러 보세요".
## 누를 곳만 밝게 뚫어 두고 나머지는 어둡게 막는다 - 그 구멍 안의 단추만 눌린다 (`_has_point`).
## 손가락이 그 단추를 콕콕 가리킨다. 단계는 `LaneGame._tut_*` 가 정하고, 여기는 보여 주기만 한다.

signal skipped

var _target: Control
var _rect := Rect2()
var _tap_any := false
var _on_next: Callable
var _t := 0.0
var _bubble: PanelContainer
var _text: Label
var _hint: Label
var _skip: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble = PanelContainer.new()
	var sb := IdleUi.box(Color.WHITE, IdleUi.LAV, 24, 5, 18)
	sb.shadow_size = 12
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_bubble.add_child(v)
	_text = IdleUi.label("", 30, IdleUi.CREAM)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	_hint = IdleUi.label("", 20, IdleUi.LAV_DK)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	_skip = IdleUi.button("건너뛰기", 18, "ghost")
	_skip.custom_minimum_size = Vector2(120, 52)
	_skip.pressed.connect(func() -> void: skipped.emit())
	add_child(_skip)


## 단추 하나를 가리킨다. 그 단추를 누르면 on_next. target 이 없으면 아무 데나 눌러 넘긴다.
func point(target: Control, text: String, on_next: Callable) -> void:
	_target = target
	_tap_any = target == null
	_on_next = on_next
	_text.text = text
	_hint.text = "화면을 눌러 넘겨요" if _tap_any else "반짝이는 곳을 눌러 보세요"
	visible = true
	if target is BaseButton:
		var b := target as BaseButton
		var cb := func() -> void:
			if visible and _target == b:
				_advance()
		b.pressed.connect(cb, CONNECT_ONE_SHOT)
	_bubble.modulate.a = 0.0
	create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.2)
	AudioManager.ui_click()


func _advance() -> void:
	var f := _on_next
	_target = null
	visible = false
	if f.is_valid():
		f.call()


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	size = get_parent_area_size() if get_parent() is Control else size
	if _target != null and is_instance_valid(_target) and _target.is_visible_in_tree():
		_rect = Rect2(_target.global_position - global_position, _target.size * _target.get_global_transform().get_scale())
		_rect = _rect.grow(10)
	else:
		_rect = Rect2()
	# 말풍선: 구멍 위나 아래 (자리가 넓은 쪽)
	var w := minf(size.x - 40.0, 620.0)
	_bubble.custom_minimum_size = Vector2(w, 0)
	_bubble.reset_size()
	var bh := _bubble.size.y
	var by := size.y * 0.4 - bh * 0.5
	if _rect.size.x > 0.0:
		if _rect.position.y > size.y * 0.5:
			by = _rect.position.y - bh - 120.0
		else:
			by = _rect.end.y + 120.0
	_bubble.position = Vector2((size.x - w) * 0.5, clampf(by, 90.0, size.y - bh - 20.0))
	_skip.position = Vector2(size.x - 140.0, 16.0)
	queue_redraw()


## 구멍 안은 아래 단추가 받는다 (false = 이 판은 안 받는다).
func _has_point(p: Vector2) -> bool:
	if _tap_any:
		return true
	if _skip.get_global_rect().has_point(p + global_position):
		return false
	return not _rect.has_point(p)


func _gui_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if tap:
		accept_event()
		if _tap_any:
			_advance()


func _draw() -> void:
	var dim := Color(0.13, 0.07, 0.2, 0.62)
	if _rect.size.x <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return
	var r := _rect
	draw_rect(Rect2(0, 0, size.x, r.position.y), dim)
	draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), dim)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), dim)
	# 반짝이는 테두리
	var k := 0.5 + 0.5 * sin(_t * 6.0)
	draw_rect(r, Color(1.0, 0.86, 0.25, 0.6 + 0.4 * k), false, 6.0)
	draw_rect(r.grow(6.0 + 6.0 * k), Color(1.0, 0.95, 0.6, 0.35 * (1.0 - k)), false, 4.0)
	# 손가락 (도트) - 구멍 위나 아래에서 콕콕
	var below := r.position.y < size.y * 0.5
	var tip := Vector2(r.get_center().x, (r.end.y + 8.0) if below else (r.position.y - 8.0))
	var bob := absf(sin(_t * 5.0)) * 22.0
	_draw_hand(tip + Vector2(0, bob if below else -bob), below)


## 도트 손가락 - 3점 픽셀로 그린다 (화면의 도트 크기와 같게).
func _draw_hand(tip: Vector2, from_below: bool) -> void:
	var px := 6.0
	# 0 빈칸 · 1 살 · 2 테두리 · 3 손톱 (위를 가리키는 손)
	var rows := [
		"00222000",
		"02113200",
		"02111200",
		"02111222",
		"02111121",
		"22111111",
		"21111111",
		"21111111",
		"02111112",
		"00222220",
	]
	var cols := {"1": Color("#FFE0C2"), "2": Color("#3B2559"), "3": Color("#FFFFFF")}
	var h := float(rows.size()) * px
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if ch == "0":
				continue
			var yy := float(y) if from_below else float(rows.size() - 1 - y)
			var p := tip + Vector2((float(x) - 3.0) * px, (yy * px) if from_below else (yy * px - h))
			draw_rect(Rect2(p, Vector2(px, px)), cols[ch])

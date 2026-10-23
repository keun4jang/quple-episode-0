class_name DragScroll
extends Node
## 스크롤 상자 안 어디를 잡고 끌어도 위아래로 넘어가게 한다 (손가락·마우스 모두).
##
## Godot 4.3 의 ScrollContainer 는 끌기를 자기 몸에서만 받는다. 안에 든 카드·단추가 누르는 순간
## 입력을 가져가 버려서, 빈 틈을 잡고 끌면 넘어가고 카드 위를 잡고 끌면 안 넘어갔다 ("됐다 안 됐다").
## 여기서는 화면 입력을 먼저(`_input`) 보고, 누른 채 SLOP 점 넘게 움직이면 끌기로 본다:
## 누르고 있던 단추에는 '밖에서 뗐다' 를 보내 눌림을 취소하고(단추가 안 눌린다), 그 뒤 움직임은 스크롤에 쓴다.
## 손을 떼면 그 속도로 조금 더 미끄러진다.
##
## 쓰는 법: `DragScroll.attach(scroll_container)`

const SLOP := 14.0          ## 이만큼 움직여야 끌기 (그 전엔 그냥 누르기)
const FRICTION := 5.0       ## 미끄러짐이 줄어드는 빠르기

var sc: ScrollContainer
var _down := false
var _active := false
var _start := Vector2.ZERO
var _start_scroll := 0.0
var _last_y := 0.0
var _last_t := 0
var _vel := 0.0
var _pos := 0.0
var _synth := false


static func attach(s: ScrollContainer) -> DragScroll:
	var d := DragScroll.new()
	d.name = "DragScroll"
	s.add_child(d)
	return d


func _ready() -> void:
	sc = get_parent() as ScrollContainer


## 위에 덮는 창(팝업·안내·설정)은 이 그룹에 넣는다 - 떠 있는 동안 그 뒤 목록은 끌리지 않는다.
const MODAL_GROUPS := ["modal", "settings_ui"]


func _owns(p: Vector2) -> bool:
	if sc == null or not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(p):
		return false
	for g in MODAL_GROUPS:
		for m in get_tree().get_nodes_in_group(g):
			if m == sc or m.is_ancestor_of(sc):
				continue
			var shown := (m as CanvasItem).is_visible_in_tree() if m is CanvasItem else \
				(bool((m as CanvasLayer).visible) if m is CanvasLayer else false)
			if shown:
				return false
	return true


func _input(ev: InputEvent) -> void:
	if _synth or sc == null:
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			_down = _owns(mb.position)
			_active = false
			_vel = 0.0
			_start = mb.position
			_start_scroll = float(sc.scroll_vertical)
			_pos = _start_scroll
			_last_y = mb.position.y
			_last_t = Time.get_ticks_msec()
		else:
			if _active:
				get_viewport().set_input_as_handled()
			_down = false
			_active = false
	elif ev is InputEventMouseMotion and _down:
		var mm := ev as InputEventMouseMotion
		var dy := mm.position.y - _start.y
		if not _active and absf(dy) > SLOP:
			_active = true
			_cancel_press()
		if _active:
			_pos = clampf(_start_scroll - dy, 0.0, _max_scroll())
			sc.scroll_vertical = int(_pos)
			var now := Time.get_ticks_msec()
			var dt := maxf(0.001, float(now - _last_t) / 1000.0)
			_vel = lerpf(_vel, -(mm.position.y - _last_y) / dt, 0.5)
			_last_y = mm.position.y
			_last_t = now
			get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag and _active:
		# 손가락 끌기는 위에서 처리했다 - 스크롤 상자가 한 번 더 움직이지 않게
		get_viewport().set_input_as_handled()


## 누르고 있던 단추에 '손가락이 밖으로 나갔다가 밖에서 뗐다' 를 보낸다 - 눌림이 풀리고 pressed 는 안 나간다.
## (단추는 뗄 때 위치를 다시 보지 않고 마지막 움직임 때 '안에 있었나' 만 본다 - 그래서 움직임을 먼저 보낸다.)
func _cancel_press() -> void:
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-10000, -10000)
	away.global_position = away.position
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	_synth = true
	get_viewport().push_input(away)
	_synth = false
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-10000, -10000)
	up.global_position = up.position
	_synth = true
	get_viewport().push_input(up)
	_synth = false


func _max_scroll() -> float:
	var bar := sc.get_v_scroll_bar()
	return maxf(0.0, float(bar.max_value) - float(bar.page)) if bar != null else 1e9


func _process(dt: float) -> void:
	if _down or absf(_vel) < 20.0 or sc == null:
		return
	_pos = clampf(float(sc.scroll_vertical) + _vel * dt, 0.0, _max_scroll())
	sc.scroll_vertical = int(_pos)
	_vel *= exp(-FRICTION * dt)
	if _pos <= 0.0 or _pos >= _max_scroll():
		_vel = 0.0

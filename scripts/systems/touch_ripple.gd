extends Node
## 손가락이 닿은 자리에 물결 하나.
##
## 폰 게임은 마우스 커서가 없다. 눌렀는데 아무 표시가 없으면 "눌린 건가?"
## 부터 의심하게 된다 — 특히 이 게임은 화면 아무 데나 눌러 걷고, 대화를
## 넘기고, 창을 닫는다. 닿은 자리마다 작은 물결이 퍼지면 그 의심이 없다.
##
## SceneTransition 씬에 얹혀 산다. 오토로드 목록은 APK 를 새로 깔아야
## 바뀌지만, 이 씬의 자식은 팩 갱신만으로 폰에 전달된다 (back_handler 와
## 같은 이유). 그래서 메인화면·여행·설정 어디서나 같이 산다.

const LIFE := 0.32            # 물결 하나가 사는 시간
const R0 := 6.0               # 시작 반지름
const R1 := 26.0              # 끝 반지름

var _canvas: CanvasLayer
var _draw_node: Control
## [자리, 남은 시간] 들. 거의 늘 0~2개다.
var _ripples: Array = []


func _ready() -> void:
	# 무엇보다 위에 그린다. 설정(5)·대화(10)·여행판(12)·잠 페이드(20)
	# 어디를 눌러도 보여야 한다. 60(뒤로가기 안내)보다도 위.
	_canvas = CanvasLayer.new()
	_canvas.layer = 90
	add_child(_canvas)
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_ripples)
	_canvas.add_child(_draw_node)
	set_process(false)


func _input(e: InputEvent) -> void:
	# `_input` 이라 누가 이벤트를 먹어도 물결은 뜬다. 손가락마다 하나 —
	# 두 손가락 확대면 물결도 둘이다. 흉내낸 마우스(device -1)는 거른다.
	# 진짜 마우스는 개발용 PC 뿐이라 같이 받아도 해가 없다.
	if e is InputEventScreenTouch and e.pressed:
		_add((e as InputEventScreenTouch).position)
	elif e is InputEventMouseButton and e.pressed and e.device != -1 \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_add((e as InputEventMouseButton).position)


func _add(at: Vector2) -> void:
	_ripples.append([at, LIFE])
	set_process(true)


func _process(delta: float) -> void:
	var i := _ripples.size() - 1
	while i >= 0:
		_ripples[i][1] -= delta
		if _ripples[i][1] <= 0.0:
			_ripples.remove_at(i)
		i -= 1
	_draw_node.queue_redraw()
	if _ripples.is_empty():
		set_process(false)


func _draw_ripples() -> void:
	for r in _ripples:
		var k: float = 1.0 - (r[1] as float) / LIFE      # 0 → 1
		var rad := R0 + (R1 - R0) * k
		var a := (1.0 - k) * 0.55
		# 크림빛 고리. 게임 팔레트의 종이색이라 어느 화면에도 얹힌다.
		_draw_node.draw_arc(r[0], rad, 0.0, TAU, 24,
			Color(1.0, 0.98, 0.90, a), 2.5, true)
		_draw_node.draw_circle(r[0], rad * 0.35,
			Color(1.0, 0.98, 0.90, a * 0.35))

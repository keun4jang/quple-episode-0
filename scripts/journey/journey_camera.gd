class_name JourneyCamera
extends Camera2D
## 따라다니는 카메라 + 두 손가락 확대·축소.
##
## 픽셀 그림에서 줌은 조심해야 한다. **정수 배율만 쓴다.**
##
## 기획 문서에는 0.5 단위로 적어 두었는데, 실제로 붙여 보니 2.5배에서
## 원본 한 픽셀이 화면 2.5픽셀이 되어 어떤 픽셀은 두 칸, 어떤 픽셀은 세
## 칸을 차지한다. 격자가 울퉁불퉁해지고 걸어 다니면 지글거린다.
## 그래서 **2 / 3 / 4** 세 단계로 바꿨다. 세 단계면 충분하다 —
## 넓게 보기 · 기본 · 얼굴 보기.
##
## 오므리는 동안에는 부드럽게 따라오고, 손을 떼면 가까운 눈금에 붙는다.

const STEPS := [2.0, 3.0, 4.0]
const DEFAULT_STEP := 1          # 3배
const SNAP_TIME := 0.18
const FOLLOW := 6.0              # 클수록 딱 붙는다

@export var target_path: NodePath
## 세로로 들면 화면이 좁아 한 단계 넓게 보여 준다.
@export var portrait_relief := true

var target: Node2D

var _pinching := false
var _snap: Tween
var _touch: Dictionary = {}      # finger id → 화면 좌표
var _base_dist := 0.0
var _base_zoom := 1.0
var _step := DEFAULT_STEP


func _ready() -> void:
	position_smoothing_enabled = false     # 우리가 직접 따라간다
	ignore_rotation = true
	if target_path != NodePath():
		target = get_node_or_null(target_path)
	zoom = Vector2.ONE * _wanted()
	set_process_unhandled_input(true)


func _wanted() -> float:
	var z: float = STEPS[clampi(_step, 0, STEPS.size() - 1)]
	if portrait_relief:
		var vp := get_viewport_rect().size
		if vp.y > vp.x:                    # 세로로 들었다
			z = maxf(STEPS[0], z - 1.0)
	return z


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# 목표를 픽셀 격자에 맞춰 따라간다. 소수점 위치로 따라가면 배경이
	# 정수 배율이어도 캐릭터만 반 픽셀씩 떨린다.
	var want := target.global_position
	var k := clampf(delta * FOLLOW, 0.0, 1.0)
	global_position = global_position.lerp(want, k).round()


# ── 두 손가락 ─────────────────────────────────────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touch[e.index] = e.position
		else:
			_touch.erase(e.index)
			if _pinching and _touch.size() < 2:
				_pinching = false
				_snap_to_step()
		if _touch.size() == 2 and not _pinching:
			_begin_pinch()
	elif e is InputEventScreenDrag:
		if not _touch.has(e.index):
			return
		_touch[e.index] = e.position
		if _pinching:
			_update_pinch()

	# 마우스 휠은 개발용. 폰에는 없다.
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(-1)


func _fingers() -> Array:
	return _touch.values()


func _begin_pinch() -> void:
	var p: Array = _fingers()
	_base_dist = maxf(1.0, (p[0] as Vector2).distance_to(p[1] as Vector2))
	_base_zoom = zoom.x
	_pinching = true
	if _snap != null and _snap.is_valid():
		_snap.kill()


func _update_pinch() -> void:
	var p: Array = _fingers()
	if p.size() < 2:
		return
	var d := maxf(1.0, (p[0] as Vector2).distance_to(p[1] as Vector2))
	var z := clampf(_base_zoom * (d / _base_dist), STEPS[0] * 0.8,
		STEPS[STEPS.size() - 1] * 1.2)

	# 확대 중심은 **두 손가락 사이**다. 화면 한가운데를 기준으로 잡으면
	# 보려던 것이 화면 밖으로 밀려난다 — 지도 앱이 다 이렇게 한다.
	var mid: Vector2 = ((p[0] as Vector2) + (p[1] as Vector2)) * 0.5
	var before := _screen_to_world(mid)
	zoom = Vector2.ONE * z
	var after := _screen_to_world(mid)
	global_position += before - after


func _screen_to_world(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return global_position + (p - vp * 0.5) / zoom


## 손을 떼면 가까운 눈금에 붙는다.
func _snap_to_step() -> void:
	var best := 0
	var gap := INF
	for i in STEPS.size():
		var d: float = absf(zoom.x - float(STEPS[i]))
		if d < gap:
			gap = d
			best = i
	_step = best
	_tween_zoom(_wanted())


func _nudge(dir: int) -> void:
	_step = clampi(_step + dir, 0, STEPS.size() - 1)
	_tween_zoom(_wanted())


func _tween_zoom(z: float) -> void:
	if _snap != null and _snap.is_valid():
		_snap.kill()
	_snap = create_tween()
	_snap.tween_property(self, "zoom", Vector2.ONE * z, SNAP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## 지도 크기에 맞춰 카메라가 밖으로 안 나가게 막는다.
func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


## 지금 배율 (테스트용)
func step_index() -> int:
	return _step

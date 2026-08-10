class_name JourneyTouch
extends Control
## 한 손가락은 걷기, 두 손가락은 확대.
##
## 화면에 고정된 조이스틱을 안 그린다. **누른 자리가 곧 중심**이다.
## 엄지 위치가 사람마다 다르고, 세로로 들 때와 가로로 들 때가 또 다르다.
##
## 두 번째 손가락이 닿는 순간 걷기를 놓는다 — 확대하려다 쿼카가
## 엉뚱한 데로 걸어가면 안 된다.

const RADIUS := 46.0       # 여기까지 밀면 최고 속도
const DEAD := 0.16         # 이 안은 안 움직인다
## **진짜 미는 손가락인지 가르는 기준**, `_press_pos` 로부터의 거리다.
##
## 이게 없으면 조이스틱 기능만 됐다 — 목적지를 톡 찍으면 `Place` 가
## 그 자리로 `walk_to()` 를 시작하는데, 화면을 누르고 떼는 그 짧은
## 순간에도 손끝은 몇 픽셀씩 흔들린다. `DEAD`(약 7px)는 그 흔들림보다도
## 작아서, 탭할 때마다 이 조이스틱이 "밀었다" 고 오해하고 `_dir` 을
## 채워 `Place._process()` 가 막 시작한 `walk_to()` 를 매 프레임
## `stop_walk_to()` 로 끊어 버렸다. 폰에서는 늘 조이스틱만 도는 것처럼
## 보였던 이유다. 확실히 밀 때까지는 방향을 0 으로 묶어 둔다.
const DRAG_CONFIRM := 20.0

var _finger := -1
var _origin := Vector2.ZERO
var _now := Vector2.ZERO
var _dir := Vector2.ZERO
## 손가락을 처음 댄 자리. `_origin` 과 달리 손가락이 반경을 넘어가도
## 다시 옮기지 않는다 — "진짜 밀었나" 는 늘 처음 댄 자리에서 잰다.
var _press_pos := Vector2.ZERO
var _drag_confirmed := false
## 지금 화면에 닿아 있는 손가락. index → 위치.
var _down: Dictionary = {}
## 두 손가락이 닿은 뒤로는 다 뗄 때까지 걷지 않는다.
var _pinch_lock := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("journey_touch")


## 지금 가리키는 방향 (-1..1). 걷기를 안 하면 0.
func direction() -> Vector2:
	return _dir


## 두 손가락 이상이 닿아 있나. 확대하려던 손가락이 대화를 열면 안 된다.
func is_multi() -> bool:
	return _pinch_lock or _down.size() >= 2


## 손가락 수를 세는 대신 **누가 닿아 있는지**를 들고 있는다.
##
## 예전엔 `_extra` 라는 숫자만 셌는데, 두 손가락 중 **먼저 댄 쪽을 떼면**
## 그 숫자가 0 으로 돌아갔다. 남은 손가락은 아직 화면에 있는데 걷기가
## 다시 열려서, 화면을 오므리는 중에 쿼카가 걸어갔다.
## 그래서 두 손가락이 닿은 순간 잠그고, **다 뗄 때까지** 안 푼다.
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			# HUD 버튼(배낭·사진)이 먼저다. 터치→마우스 흉내는 첫 손가락
			# 하나에만 걸리는데 그 손가락을 걷기가 쓰고 있어서, 걸으면서
			# 셔터를 누르면 아무 일도 안 일어났다. 직접 눌러 준다.
			# 미니맵은 `Place` 가 본다. 여기서도 보면 **두 번 눌린 셈**이 되어
			# 켰다가 바로 꺼진다 — 폰에서 아무 일도 안 나 보였던 이유다.
			var hud := get_tree().get_first_node_in_group("journey_hud")
			if hud != null and hud.has_method("try_touch") and hud.try_touch(e.position):
				get_viewport().set_input_as_handled()
				return
			_down[e.index] = e.position
			if _down.size() >= 2:
				_pinch_lock = true
				_release()
			elif not _pinch_lock:
				_finger = e.index
				_origin = e.position
				_now = e.position
				_press_pos = e.position
				_drag_confirmed = false
		else:
			_down.erase(e.index)
			if e.index == _finger:
				_release()
			if _down.is_empty():
				_pinch_lock = false
	elif e is InputEventScreenDrag:
		if _down.has(e.index):
			_down[e.index] = e.position
		if e.index == _finger and not _pinch_lock:
			_now = e.position
			_recalc()


func _release() -> void:
	_finger = -1
	_dir = Vector2.ZERO
	_drag_confirmed = false


func _recalc() -> void:
	# 확실히 밀었다고 볼 만큼 손끝이 처음 댄 자리에서 멀어지기 전에는
	# 조이스틱이 끼어들지 않는다. 탭 한 번으로 목적지까지 걸어가는 길을
	# 여기서 지켜 준다.
	if not _drag_confirmed:
		if (_now - _press_pos).length() < DRAG_CONFIRM:
			_dir = Vector2.ZERO
			return
		_drag_confirmed = true
	var v := (_now - _origin) / RADIUS
	var len := v.length()
	if len < DEAD:
		_dir = Vector2.ZERO
		return
	# 죽은 구간을 뺀 나머지를 0~1 로 다시 편다. 안 그러면 손가락을 조금
	# 움직인 순간 갑자기 중간 속도로 튄다.
	var k := clampf((len - DEAD) / (1.0 - DEAD), 0.0, 1.0)
	_dir = v.normalized() * k

	# 손가락이 반경을 넘어가면 원점을 끌고 간다. 안 그러면 화면 끝까지
	# 밀었다가 되돌아올 때 한참을 움직여야 방향이 바뀐다.
	if len > 1.0:
		_origin = _now - v.normalized() * RADIUS


## 키보드도 받는다 (개발·PC용). 터치가 없을 때만.
func direction_with_keys() -> Vector2:
	if _dir.length_squared() > 0.0:
		return _dir
	var k := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	return k if k.length_squared() <= 1.0 else k.normalized()

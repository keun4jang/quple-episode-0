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

var _finger := -1
var _origin := Vector2.ZERO
var _now := Vector2.ZERO
var _dir := Vector2.ZERO
var _extra := 0            # 두 번째 이상의 손가락 수


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("journey_touch")


## 지금 가리키는 방향 (-1..1). 걷기를 안 하면 0.
func direction() -> Vector2:
	return _dir


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if _finger == -1 and _extra == 0:
				_finger = e.index
				_origin = e.position
				_now = e.position
			else:
				_extra += 1
				_release()          # 두 손가락 = 확대. 걷기는 놓는다
		else:
			if e.index == _finger:
				_release()
			elif _extra > 0:
				_extra -= 1
	elif e is InputEventScreenDrag and e.index == _finger:
		_now = e.position
		_recalc()


func _release() -> void:
	_finger = -1
	_dir = Vector2.ZERO


func _recalc() -> void:
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

class_name QuoSprite
extends Sprite2D
## 걷기 시트 한 장을 읽어 방향과 걸음을 다룬다.
##
## 시트는 `tools/pixel/import-journey-art.py` 가 만든다.
## 가로 4프레임 x 세로 3방향 — 아래(정면) / 옆 / 위(뒷모습).
## 오른쪽은 옆을 뒤집어 쓴다. 그래서 시트에 오른쪽 줄이 없다.
##
## 발끝이 원점이다. 탑다운에서 캐릭터의 "있는 자리"는 머리가 아니라 발이고,
## Y 정렬도 발 높이로 해야 앞뒤가 맞다.

const FRAMES := 4
const ROW_DOWN := 0
const ROW_SIDE := 1
const ROW_UP := 2

## 한 걸음에 걸리는 시간. 걷는 속도와 안 맞으면 발이 미끄러진다.
@export var step_time := 0.16

var _cell := Vector2i.ZERO
var _row := ROW_DOWN
var _frame := 0
var _t := 0.0
var _walking := false


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture != null:
		_measure()


func load_sheet(path: String) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("걷기 시트를 못 읽었다: %s" % path)
		return
	texture = tex
	_measure()


func _measure() -> void:
	_cell = Vector2i(texture.get_width() / FRAMES, texture.get_height() / 3)
	region_enabled = true
	_apply()


## 발끝이 원점에 오도록 그린다.
func _apply() -> void:
	if _cell == Vector2i.ZERO:
		return
	region_rect = Rect2(_frame * _cell.x, _row * _cell.y, _cell.x, _cell.y)
	offset = Vector2(-_cell.x / 2.0, -_cell.y)


## 어느 쪽을 보고 얼마나 빨리 가는지 알려 주면 알아서 걷는다.
func drive(dir: Vector2, delta: float) -> void:
	var moving := dir.length_squared() > 0.001
	if moving:
		# 가로가 세로보다 크면 옆모습. 대각선에서도 옆모습이 낫다 —
		# 정면으로 두면 옆으로 미끄러지는 것처럼 보인다.
		if absf(dir.x) >= absf(dir.y):
			_row = ROW_SIDE
			flip_h = dir.x > 0.0        # 시트는 왼쪽을 보고 있다
		else:
			_row = ROW_UP if dir.y < 0.0 else ROW_DOWN
			flip_h = false

	if moving != _walking:
		_walking = moving
		_t = 0.0
		if not moving:
			_frame = 0                  # 멈추면 서 있는 자세로
			_apply()
			return

	if not moving:
		return
	_t += delta
	while _t >= step_time:
		_t -= step_time
		_frame = (_frame + 1) % FRAMES
	_apply()


## 방향만 바꾼다 (말 걸 때 마주 보게)
func face(dir: Vector2) -> void:
	drive(dir, 0.0)
	_walking = false
	_frame = 0
	_apply()


func size() -> Vector2i:
	return _cell

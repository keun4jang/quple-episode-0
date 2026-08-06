extends Node
## 보고 싶은 곳을 본다. 하늘도, 뒤도, 옆도.
##
## 지금까지 카메라는 맵 스크립트가 매 프레임 정해진 자리로 밀어넣기만 했다.
## 3D 인데 정해진 각도 하나만 보이는 건 아깝다. 힐링 게임이라면 더 그렇다.
## 멈춰 서서 하늘을 올려다보는 것 자체가 이 게임에서 할 일이어야 한다.
##
## 조작
##   오른쪽 화면 드래그 → 둘러보기 (좌우 360°, 하늘부터 내려다보기까지)
##   두 손가락 오므리기 → 거리 조절
##   ⟲ 버튼 → 원래 각도로
##   PC 는 마우스 드래그 / 휠
##
## 맵 스크립트가 카메라를 매 프레임 덮어쓰기 때문에, 이 노드는 process_priority 를
## 높게 잡아 **가장 마지막에** 카메라를 잡는다. 맵 코드를 고치지 않아도 된다.

# pitch 는 카메라가 캐릭터보다 얼마나 **높이** 있는가다.
# 그래서 하늘을 보려면 카메라가 낮게 내려앉아야 한다(음수).
const PITCH_MIN := -42.0        # 낮게 앉아 하늘 올려다보기
const PITCH_MAX := 74.0         # 위에서 내려다보기. 90 까지 가면 뒤집힌다
const DIST_MIN := 2.6
const DIST_MAX := 14.0
const DRAG_TO_DEG := 0.26       # 손가락 1px 당 회전량
const SMOOTH := 12.0
const RECENTER_DELAY := 3.0     # 손 뗀 뒤 이만큼 지나야 슬슬 돌아온다
const RECENTER_SPEED := 0.55

@export var enabled := true

var yaw := 0.0                  # 목표 각도 (도)
var pitch := 0.0
var dist := 8.0

var _yaw := 0.0                 # 실제 각도 (부드럽게 따라간다)
var _pitch := 0.0
var _dist := 8.0
var _pivot_y := 1.5             # 플레이어 발밑에서 이만큼 위를 본다

var _cam: Camera3D
var _player: Node3D
var _home := Vector3.ZERO       # 처음 각도 (⟲ 로 돌아올 자리)
var _touch := -1                # 둘러보기 중인 손가락
var _last := Vector2.ZERO
var _pinch := {}                # 두 손가락 거리 재기
var _pinch_base := 0.0
var _idle := 0.0                # 마지막 조작 이후 흐른 시간
var _ready_done := false


func _ready() -> void:
	add_to_group("free_look")
	process_priority = 100      # 맵 스크립트보다 뒤에 돌아야 카메라를 가져올 수 있다
	set_process_input(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_grab()


func _grab() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_cam = _find(scene, "Camera3D") as Camera3D
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _cam == null or _player == null:
		return
	# 맵이 잡아 둔 "구도" 를 그대로 출발점으로 삼는다.
	#
	# 카메라 위치만 보고 플레이어를 보도록 각도를 다시 만들면 안 된다.
	# 맵마다 카메라가 겨냥하는 곳이 다르다 — 사무실은 플레이어가 아니라 방을 잡고
	# 있어서, 플레이어를 보게 강제했더니 시점이 위로 꺾이며 앞벽이 화면을 덮었다.
	#
	# 그래서 카메라가 실제로 보고 있는 방향에서 회전 중심을 역산한다.
	# 그 시선 위에서 플레이어와 가장 가까운 점이 곧 맵이 잡은 중심이다.
	var cpos := _cam.global_position
	var fwd := -_cam.global_transform.basis.z
	var to_player := _player.global_position - cpos
	var along := maxf(to_player.dot(fwd), 1.0)
	var pivot := cpos + fwd * along

	_pivot_y = clampf(pivot.y - _player.global_position.y, -1.0, 4.0)
	var off := cpos - pivot
	dist = clampf(off.length(), DIST_MIN, DIST_MAX)
	yaw = rad_to_deg(atan2(off.x, off.z))
	pitch = rad_to_deg(asin(clampf(off.y / maxf(off.length(), 0.001), -1.0, 1.0)))
	_yaw = yaw
	_pitch = pitch
	_dist = dist
	_home = Vector3(yaw, pitch, dist)
	_ready_done = true


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


# ── 입력 ───────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not enabled or not _ready_done:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_look_area(event.position):
				if _touch == -1:
					_touch = event.index
					_last = event.position
				_pinch[event.index] = event.position
		else:
			if event.index == _touch:
				_touch = -1
			_pinch.erase(event.index)
			_pinch_base = 0.0
	elif event is InputEventScreenDrag:
		if _pinch.has(event.index):
			_pinch[event.index] = event.position
		if _pinch.size() >= 2:
			_do_pinch()
		elif event.index == _touch:
			_turn(event.position - _last)
			_last = event.position
	# PC 에서도 확인할 수 있어야 한다. 마우스 드래그와 휠.
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _is_look_area(event.position):
			_turn(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.6)


## 오른쪽 절반이 둘러보기 영역. 단 버튼 위는 아니다.
## 왼쪽은 이동 조이스틱 자리라 건드리면 안 된다.
func _is_look_area(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	if pos.x < vp.x * 0.5:
		return false
	var tc := get_tree().get_first_node_in_group("touch_controls")
	if tc != null and tc.has_method("blocks_look"):
		return not tc.blocks_look(pos)
	return true


func _turn(delta: Vector2) -> void:
	yaw -= delta.x * DRAG_TO_DEG
	pitch = clampf(pitch + delta.y * DRAG_TO_DEG, PITCH_MIN, PITCH_MAX)
	_idle = 0.0


func _do_pinch() -> void:
	var pts := _pinch.values()
	var d: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
	if _pinch_base <= 0.0:
		_pinch_base = d
		return
	_zoom((_pinch_base - d) * 0.02)
	_pinch_base = d


func _zoom(amount: float) -> void:
	dist = clampf(dist + amount, DIST_MIN, DIST_MAX)
	_idle = 0.0


## 처음 각도로 돌아간다 (⟲ 버튼)
func recenter() -> void:
	yaw = _home.x
	pitch = _home.y
	dist = _home.z
	_idle = 0.0


# ── 카메라 ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not enabled or not _ready_done:
		return
	if _cam == null or _player == null or not is_instance_valid(_cam) \
			or not is_instance_valid(_player):
		_grab()
		return

	_idle += delta
	_auto_recenter(delta)

	# 각도는 부드럽게 따라간다. 손가락을 홱 움직여도 화면이 튀지 않게.
	var t := clampf(delta * SMOOTH, 0.0, 1.0)
	# 각도는 lerp_angle 로 섞는다. 359° 에서 1° 로 갈 때 358° 를 되감지 않게.
	_yaw = rad_to_deg(lerp_angle(deg_to_rad(_yaw), deg_to_rad(yaw), t))
	_pitch = lerpf(_pitch, pitch, t)
	_dist = lerpf(_dist, dist, t)

	var pivot: Vector3 = _player.global_position + Vector3(0, _pivot_y, 0)
	var want := pivot + _dir() * _dist

	# 벽을 뚫고 나가지 않게 앞으로 당긴다
	want = _avoid_walls(pivot, want)

	_cam.global_position = want
	_cam.look_at(pivot, Vector3.UP)


func _dir() -> Vector3:
	var y := deg_to_rad(_yaw)
	var p := deg_to_rad(_pitch)
	return Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)).normalized()


## 걷는 동안에는 슬슬 원래 각도로 돌아온다. 서 있을 때는 절대 돌리지 않는다 —
## 멈춰서 하늘을 보고 있는데 카메라가 제멋대로 내려오면 그게 제일 짜증난다.
func _auto_recenter(delta: float) -> void:
	if _idle < RECENTER_DELAY:
		return
	if not ("velocity" in _player):
		return
	var v: Vector3 = _player.velocity
	if Vector2(v.x, v.z).length() < 0.4:
		return
	var step := RECENTER_SPEED * delta * 60.0
	yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), deg_to_rad(_home.x), clampf(step * 0.01, 0.0, 1.0)))
	pitch = move_toward(pitch, _home.y, step * 0.35)


func _avoid_walls(pivot: Vector3, want: Vector3) -> Vector3:
	var space := _cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pivot, want)
	q.collide_with_areas = false
	if _player is CollisionObject3D:
		q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return want
	# 벽에 살짝 못 미치는 지점으로
	return pivot + (want - pivot).normalized() * maxf(pivot.distance_to(hit.position) - 0.35, DIST_MIN * 0.4)

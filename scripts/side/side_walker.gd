extends CharacterBody2D
class_name SideWalker
## 옆에서 본 쿼카. 걷고, 뛰고, 사다리를 타고, 계단을 오르고, 엘리베이터를 탄다.
##
## 이 파일에서 가장 공들인 것은 점프 높이나 걷는 속도 같은 숫자가 아니라
## **손이 기대한 것과 화면이 하는 일 사이의 어긋남을 줄이는 장치들**이다.
## 발판에서 막 벗어난 순간에도 점프를 받아 주고(코요테), 착지 직전에 누른
## 점프를 기억했다가 닿는 순간 써 주고(버퍼), 꼭대기에서 중력을 줄여 잠깐
## 머물게 한다(체공). 셋 다 없어도 게임은 돌아가지만, 없으면 "왜 안 뛰지"
## 라는 말이 나온다.

## ─── 걷기 ───
## 최고 속도. 쿼카는 짧은 다리로 종종거리는 편이 어울린다.
@export var speed: float = 430.0
## 멈춤 → 최고 속도까지 걸리는 시간(초). 0 이면 즉시 — 그러면 미끄러지듯
## 딱딱해진다. 짧게 두어 발을 떼는 느낌만 남긴다.
@export var accel_time: float = 0.10
## 손을 뗀 뒤 멈추기까지. 가속보다 짧아야 조작이 무겁지 않다.
@export var brake_time: float = 0.07

## ─── 점프 ───
## 점프 높이(픽셀). 시간과 높이로 정하면 중력이 따라 나온다 —
## 중력 가속도를 직접 정하는 것보다 조율하기 훨씬 쉽다.
@export var jump_height: float = 250.0
## 꼭대기까지 걸리는 시간(초).
@export var jump_rise_time: float = 0.36
## 내려올 때 중력 배수. 1.0 이면 붕 떠 있고, 올려야 발이 땅을 찾는다.
@export var fall_multiplier: float = 1.9
## 점프 버튼을 일찍 떼면 이 배수로 위로 가던 속도를 깎는다. 살짝 눌러
## 낮게, 꾹 눌러 높게 — 같은 버튼으로 두 가지를 하게 해 준다.
@export var short_hop_cut: float = 0.45
## 꼭대기 근처에서 중력을 이만큼으로 줄인다. 잠깐 머무는 이 구간이
## 메이플 특유의 두둥실한 맛을 만든다.
@export var apex_gravity_scale: float = 0.55
## 체공으로 칠 세로 속도 범위(±).
@export var apex_threshold: float = 130.0
## 발판을 벗어난 뒤에도 점프를 받아 주는 시간(초).
@export var coyote_time: float = 0.11
## 공중에서 미리 누른 점프를 기억하는 시간(초).
@export var jump_buffer: float = 0.13

## ─── 사다리 ───
@export var climb_speed: float = 260.0

## ─── 보기 ───
## 캐릭터 키(픽셀).
@export var body_height: float = 190.0
@export var art_prefix: String = "res://assets/mascots/sheet/leader"

signal landed(strength: float)
signal entered_ladder()
signal left_ladder()

enum State { GROUND, AIR, LADDER, RIDING }

var state: int = State.AIR
var facing: int = 1
## 지금 겹쳐 있는 사다리들. 겹칠 수 있으니 목록으로 둔다.
var _ladders: Array[Area2D] = []
var _ladder: Area2D = null
## 지금 타고 있는 엘리베이터. 타는 동안에는 발판이 움직여도 같이 간다.
var _lift: Node = null

var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := false
var _fall_speed_last := 0.0
var _walk_phase := 0.0
var _squash := Vector2.ONE

@onready var art: Sprite2D = $Art
@onready var shape: CollisionShape2D = $Shape

var _tex_side: Texture2D
var _tex_front: Texture2D
var _tex_back: Texture2D


## 높이와 시간으로부터 중력을 얻는다.  h = ½·g·t²  →  g = 2h/t²
func _gravity() -> float:
	return 2.0 * jump_height / (jump_rise_time * jump_rise_time)


## 그 중력에서 목표 높이에 닿는 처음 속도.  v = g·t
func _jump_velocity() -> float:
	return -_gravity() * jump_rise_time


func _ready() -> void:
	add_to_group("side_walker")
	_tex_side = _load("side")
	_tex_front = _load("front")
	_tex_back = _load("back")
	_fit_art()
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	# 계단을 오르내릴 때 발이 붙어 있게 한다. 없으면 내리막마다 통통 튄다.
	floor_snap_length = 22.0
	floor_max_angle = deg_to_rad(52.0)
	floor_constant_speed = true


func _load(which: String) -> Texture2D:
	var p := "%s-%s.png" % [art_prefix, which]
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## 그림 높이를 body_height 에 맞추고, 발바닥을 원점에 둔다.
func _fit_art() -> void:
	if art == null or _tex_side == null:
		return
	art.texture = _tex_side
	var s := body_height / float(_tex_side.get_height())
	art.scale = Vector2(s, s)
	art.offset = Vector2(0, -_tex_side.get_height() * 0.5)
	if shape != null and shape.shape is CapsuleShape2D:
		var cap := shape.shape as CapsuleShape2D
		cap.height = body_height * 0.86
		cap.radius = body_height * 0.22
		shape.position = Vector2(0, -body_height * 0.43)


func _physics_process(delta: float) -> void:
	match state:
		State.LADDER:
			_climb(delta)
		_:
			_walk(delta)
	_animate(delta)


# ─────────────────────────────── 걷기 · 점프 ───────────────────────────────

func _walk(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()

	# 코요테 — 발판 끝에서 한 발 벗어난 순간의 점프를 살려 준다.
	_coyote = coyote_time if on_floor else maxf(_coyote - delta, 0.0)
	# 버퍼 — 아직 공중일 때 누른 점프를 잠깐 들고 있는다.
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	# 사다리에 올라타기. 위나 아래를 누르고 있어야 한다 —
	# 그냥 지나가기만 해도 붙으면 사다리 앞을 못 지나간다.
	if _ladder_here() != null:
		var want_up := Input.is_action_pressed("move_up")
		var want_down := Input.is_action_pressed("move_down") and not on_floor
		if want_up or want_down:
			_enter_ladder()
			return

	# 가로 속도. 즉시 바꾸지 않고 시간을 들여 붙이고 뗀다.
	var target := dir * speed
	var t := accel_time if absf(target) > 0.01 else brake_time
	velocity.x = move_toward(velocity.x, target, speed / maxf(t, 0.001) * delta)
	if absf(dir) > 0.01:
		facing = 1 if dir > 0.0 else -1

	# 중력. 올라갈 때 · 꼭대기 · 내려갈 때가 각각 다르다.
	var g := _gravity()
	if not on_floor:
		if absf(velocity.y) < apex_threshold:
			g *= apex_gravity_scale        # 꼭대기에서 잠깐 머문다
		elif velocity.y > 0.0:
			g *= fall_multiplier           # 내려올 땐 빨리 떨어진다
		velocity.y += g * delta

	# 점프
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = _jump_velocity()
		_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.86, 1.18)      # 튀어 오르며 길쭉해진다
		_lift = null
	# 버튼을 일찍 뗐으면 위로 가던 힘을 깎는다
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= short_hop_cut

	# 아래 + 점프 = 발판 아래로 내려서기
	if on_floor and Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump"):
		_drop_through()
		return

	_fall_speed_last = velocity.y
	move_and_slide()
	_after_move(on_floor)


## 착지한 순간을 잡아 낸다. 세게 떨어졌을수록 크게 눌린다.
func _after_move(was_on_floor_before: bool) -> void:
	var now := is_on_floor()
	if now and not was_on_floor_before and _fall_speed_last > 60.0:
		var k := clampf(_fall_speed_last / 900.0, 0.0, 1.0)
		_squash = Vector2(1.0 + 0.30 * k, 1.0 - 0.26 * k)
		landed.emit(k)
	state = State.GROUND if now else State.AIR
	_was_on_floor = now


## 한 방향 발판을 통과해 아래로 내려선다.
func _drop_through() -> void:
	position.y += 4.0
	velocity.y = 40.0
	state = State.AIR
	_coyote = 0.0


# ───────────────────────────────── 사다리 ─────────────────────────────────

func _ladder_here() -> Area2D:
	for a in _ladders:
		if is_instance_valid(a):
			return a
	return null


func _enter_ladder() -> void:
	_ladder = _ladder_here()
	if _ladder == null:
		return
	state = State.LADDER
	velocity = Vector2.ZERO
	# 사다리 한가운데로 붙인다. 비스듬히 매달려 있으면 지저분하다.
	position.x = _ladder.global_position.x
	entered_ladder.emit()


func _exit_ladder() -> void:
	state = State.AIR
	_ladder = null
	left_ladder.emit()


func _climb(delta: float) -> void:
	if _ladder_here() == null:
		_exit_ladder()
		return
	var v := Input.get_axis("move_up", "move_down")
	velocity = Vector2(0, v * climb_speed)
	# 사다리에서 점프하면 잡은 손을 놓고 옆으로 뛴다.
	if Input.is_action_just_pressed("jump"):
		velocity = Vector2(Input.get_axis("move_left", "move_right") * speed * 0.8, _jump_velocity() * 0.8)
		_exit_ladder()
		move_and_slide()
		return
	move_and_slide()
	# 사다리 위쪽 끝에서 바닥을 밟으면 자연히 내려선다.
	if is_on_floor() and v > 0.0:
		_exit_ladder()
	_walk_phase += absf(v) * delta * 6.0


# ──────────────────────────────── 엘리베이터 ────────────────────────────────

## 엘리베이터가 자기를 태우고 갈 때 부른다.
func ride(lift: Node) -> void:
	_lift = lift
	state = State.RIDING


func stop_riding() -> void:
	_lift = null
	state = State.GROUND


# ────────────────────────────────── 보기 ──────────────────────────────────

func _animate(delta: float) -> void:
	if art == null:
		return
	# 눌린 몸이 천천히 제자리로 돌아온다.
	_squash = _squash.lerp(Vector2.ONE, clampf(delta * 11.0, 0.0, 1.0))

	var base := body_height / float(_tex_side.get_height()) if _tex_side != null else 1.0
	var bob := 0.0
	var tilt := 0.0

	if state == State.LADDER:
		# 사다리에서는 뒷모습. 등을 보이고 오르는 편이 자연스럽다.
		if _tex_back != null:
			art.texture = _tex_back
		art.flip_h = false
		bob = sin(_walk_phase * 2.0) * 3.0
	else:
		if _tex_side != null:
			art.texture = _tex_side
		art.flip_h = facing < 0
		if state == State.GROUND and absf(velocity.x) > 30.0:
			# 걷는 느낌. 다리를 못 움직이니 몸통이 대신 일한다 —
			# 위아래로 통통 튀면서 앞으로 살짝 기운다.
			_walk_phase += delta * (6.0 + absf(velocity.x) / speed * 5.0)
			bob = -absf(sin(_walk_phase)) * 9.0
			tilt = sin(_walk_phase * 2.0) * 0.035 + facing * 0.05
		else:
			_walk_phase = 0.0
			if state == State.GROUND:
				bob = sin(Time.get_ticks_msec() * 0.0022) * 2.0   # 숨쉬기
			else:
				# 공중에서는 올라갈 때 길쭉, 내려올 때 살짝 웅크린다.
				var k := clampf(velocity.y / 900.0, -1.0, 1.0)
				_squash = _squash.lerp(Vector2(1.0 - 0.12 * -k, 1.0 + 0.14 * -k), 0.35)

	art.position.y = bob
	art.rotation = tilt
	art.scale = Vector2(base * _squash.x, base * _squash.y)


# ─────────────────────────── 사다리 겹침 알림 ───────────────────────────

func ladder_entered(a: Area2D) -> void:
	if not _ladders.has(a):
		_ladders.append(a)


func ladder_exited(a: Area2D) -> void:
	_ladders.erase(a)
	if _ladder == a and state == State.LADDER:
		_exit_ladder()

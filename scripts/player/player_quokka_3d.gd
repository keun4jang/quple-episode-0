extends CharacterBody3D

const MAX_SPEED: float = 3.2
## 쿼카는 급할 때 네 발로 통통 튀며 달린다. 스틱을 끝까지 밀면 그 걸음이 나온다.
const RUN_SPEED: float = 5.6
const RUN_INPUT: float = 0.86      # 스틱을 이만큼 넘게 밀면 달리기
const QUAD_BLEND: float = 3.2      # 두 발 ↔ 네 발 전환 속도
const ACCELERATION: float = 14.0
const DECELERATION: float = 18.0
const TURN_LERP: float = 8.0

var _walk_time: float = 0.0
var _idle_time: float = 0.0
var _blink_timer: float = 0.0
var _blink_duration: float = 0.0
var _is_walking: bool = false
var _speed: float = 0.0
var _step_accum: float = 0.0
var _input_power: float = 0.0      # 스틱을 얼마나 밀었나 (0~1)
var _quad: float = 0.0             # 0 = 두 발, 1 = 네 발
var _bound_time: float = 0.0       # 네 발 뜀박질 위상

var dialogue_box = null
var choice_box = null

var _left_eye_white: MeshInstance3D
var _right_eye_white: MeshInstance3D
var _left_eye_hl: MeshInstance3D
var _right_eye_hl: MeshInstance3D
var _tail_mesh: MeshInstance3D

@onready var body_pivot: Node3D = $BodyPivot
@onready var head_pivot: Node3D = $BodyPivot/HeadPivot
@onready var left_arm: Node3D = $BodyPivot/LeftArmPivot
@onready var right_arm: Node3D = $BodyPivot/RightArmPivot
@onready var left_leg: Node3D = $BodyPivot/LeftLegPivot
@onready var right_leg: Node3D = $BodyPivot/RightLegPivot
@onready var left_ear: Node3D = $BodyPivot/HeadPivot/LeftEarPivot
@onready var right_ear: Node3D = $BodyPivot/HeadPivot/RightEarPivot
@onready var backpack: Node3D = $BodyPivot/BackpackPivot
@onready var left_eye_mesh: MeshInstance3D = $BodyPivot/HeadPivot/LeftEyeMesh
@onready var right_eye_mesh: MeshInstance3D = $BodyPivot/HeadPivot/RightEyeMesh
@onready var interaction_area: Area3D = $InteractionArea

var nearby_interactables: Array = []

func _ready() -> void:
	_build_meshes()
	# 인물 전용 부드러운 조명 (항상 캐릭터가 잘 보이게)
	var keylight = OmniLight3D.new()
	keylight.light_color = Color("#FFE9C8")
	keylight.light_energy = 1.1
	keylight.omni_range = 3.2
	keylight.position = Vector3(0, 1.6, 0.6)
	keylight.shadow_enabled = false
	add_child(keylight)
	# 발밑 그림자 블롭
	var shadow = MeshInstance3D.new()
	var sc = CylinderMesh.new(); sc.top_radius = 0.32; sc.bottom_radius = 0.32; sc.height = 0.01
	shadow.mesh = sc
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.35)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = smat
	shadow.position = Vector3(0, 0.03, 0)
	add_child(shadow)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	_blink_timer = randf_range(3.0, 5.0)

func _physics_process(delta: float) -> void:
	_cache_ui()
	if _is_locked():
		velocity = velocity.move_toward(Vector3.ZERO, DECELERATION * delta)
		move_and_slide()
		return

	var dir := _get_input_dir()
	_is_walking = dir.length_squared() > 0.01

	if _is_walking:
		var top: float = RUN_SPEED if is_running() else MAX_SPEED
		_speed = move_toward(_speed, top, ACCELERATION * delta)
		velocity = velocity.move_toward(dir * top, ACCELERATION * delta)
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_LERP * delta)
	else:
		_speed = move_toward(_speed, 0.0, DECELERATION * delta)
		velocity = velocity.move_toward(Vector3.ZERO, DECELERATION * delta)

	move_and_slide()

func _process(delta: float) -> void:
	_animate(delta)

func _animate(delta: float) -> void:
	# 두 발 ↔ 네 발은 즉시 바뀌지 않는다. 뚝 끊기면 사람이 아니라 인형처럼 보인다.
	_quad = move_toward(_quad, 1.0 if is_running() else 0.0, delta * QUAD_BLEND)

	if _is_walking:
		_walk_time += delta * _speed * 2.2
		_bound_time += delta * _speed * 2.0

		# ── 두 발로 걷는 자세 ──
		var bob := sin(_walk_time * 3.0) * 0.07
		var tilt := sin(_walk_time * 3.0) * deg_to_rad(3.0)
		var lean := 0.0
		var arm_l := sin(_walk_time * 3.0) * deg_to_rad(12.0)
		var arm_r := -sin(_walk_time * 3.0) * deg_to_rad(12.0)
		var leg_l := -sin(_walk_time * 3.0) * deg_to_rad(8.0)
		var leg_r := sin(_walk_time * 3.0) * deg_to_rad(8.0)
		var head_z := sin(_walk_time * 3.0 - 0.2) * deg_to_rad(1.5)
		var head_x := 0.0

		if _quad > 0.001:
			# ── 네 발로 뛰는 자세 ──
			# 쿼카는 성큼성큼 걷는 게 아니라 앞발과 뒷발을 각각 모아 통통 튄다.
			# 그래서 좌우를 엇갈리게 하지 않고 앞/뒤로 묶는다.
			var b := _bound_time * 2.6
			var hop := maxf(sin(b), 0.0)                     # 땅을 차고 뜨는 구간만
			var front := sin(b) * deg_to_rad(38.0)
			var back := sin(b + 0.9) * deg_to_rad(34.0)
			var q := _quad

			# 몸을 앞으로 숙여 앞발이 땅에 닿게 한다
			# 52° 까지 숙였더니 통통 튀는 게 아니라 바닥에 엎드린 것처럼 보였다.
			# 이 체형은 짧고 통통해서 30° 근처가 "네 발로 뛴다" 로 읽힌다.
			lean = lerpf(lean, deg_to_rad(30.0), q)
			bob = lerpf(bob, hop * 0.24 - 0.02, q)
			tilt = lerpf(tilt, 0.0, q)
			# 팔이 앞발이 된다. 아래로 내려 땅을 짚는 각도.
			# 앞발은 아래로만 뻗는 게 아니라 앞으로 뻗었다가 당겨진다
			arm_l = lerpf(arm_l, deg_to_rad(-44.0) + front, q)
			arm_r = lerpf(arm_r, deg_to_rad(-44.0) + front, q)
			leg_l = lerpf(leg_l, back, q)
			leg_r = lerpf(leg_r, back, q)
			# 몸을 숙인 만큼 고개는 들어야 앞을 본다
			# 숙인 몸을 상쇄하고도 조금 더 들어야 앞을 보는 얼굴이 된다
			head_x = lerpf(0.0, deg_to_rad(-34.0), q)
			head_z = lerpf(head_z, 0.0, q)

		body_pivot.position.y = bob
		body_pivot.rotation.x = lerp(body_pivot.rotation.x, lean, delta * 8.0)
		body_pivot.rotation.z = tilt
		head_pivot.rotation.x = lerp(head_pivot.rotation.x, head_x, delta * 8.0)
		head_pivot.rotation.z = head_z
		left_arm.rotation.x = arm_l
		right_arm.rotation.x = arm_r
		left_leg.rotation.x = leg_l
		right_leg.rotation.x = leg_r
		left_ear.rotation.z = sin(_walk_time * 2.5) * deg_to_rad(2.0)
		right_ear.rotation.z = -sin(_walk_time * 2.5) * deg_to_rad(2.0)
		backpack.rotation.x = sin(_walk_time * 3.0 - 0.3) * deg_to_rad(4.0)

		# 네 발일 때는 발이 네 개니까 발소리도 촘촘해진다
		_step_accum += delta * _speed * lerpf(1.0, 1.7, _quad)
		if _step_accum >= 0.5:
			_step_accum = 0.0
			var _am := get_node_or_null("/root/AudioManager")
			if _am and _am.has_method("footstep"): _am.footstep()
		_idle_time = 0.0
	else:
		_idle_time += delta
		var breathe = sin(_idle_time * (TAU / 1.8)) * 0.025
		body_pivot.position.y = breathe
		body_pivot.rotation.z = lerp(body_pivot.rotation.z, 0.0, delta * 4.0)
		# 멈추면 네 발 자세를 풀고 일어선다
		body_pivot.rotation.x = lerp(body_pivot.rotation.x, 0.0, delta * 6.0)
		head_pivot.rotation.x = lerp(head_pivot.rotation.x, 0.0, delta * 6.0)
		head_pivot.rotation.z = sin(_idle_time * (TAU / 2.5)) * deg_to_rad(1.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, delta * 5.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 5.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 5.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 5.0)
		left_ear.rotation.z = sin(_idle_time * 1.3) * deg_to_rad(1.5)
		right_ear.rotation.z = -sin(_idle_time * 1.3) * deg_to_rad(1.5)
		backpack.rotation.x = lerp(backpack.rotation.x, 0.0, delta * 4.0)
	_animate_blink(delta)
	if _tail_mesh:
		if _is_walking:
			_tail_mesh.rotation.z = sin(_walk_time * 4.0) * deg_to_rad(20.0)
		else:
			_tail_mesh.rotation.z = sin(_idle_time * 1.5) * deg_to_rad(8.0)

func _animate_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_duration > 0.0:
		_blink_duration -= delta
		var scale_y = 0.05 if _blink_duration > 0.0 else 1.0
		left_eye_mesh.scale.y = scale_y
		right_eye_mesh.scale.y = scale_y
	elif _blink_timer <= 0.0:
		_blink_duration = 0.1
		_blink_timer = randf_range(3.0, 5.0)

func _get_input_dir() -> Vector3:
	var v := Vector3.ZERO
	v.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	v.z = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	# 방향은 정규화해서 쓰지만, "얼마나 밀었나" 는 따로 남겨 둔다.
	# 이게 없으면 살살 밀어도 달리기가 나온다.
	_input_power = clampf(v.length(), 0.0, 1.0)
	return v.normalized()


## 지금 네 발로 달리는 중인가
func is_running() -> bool:
	return _is_walking and _input_power >= RUN_INPUT

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_cache_ui()
		if dialogue_box != null and dialogue_box.is_open():
			dialogue_box.hide_box()
			return
		if choice_box != null and choice_box.visible:
			return
		if nearby_interactables.size() > 0:
			nearby_interactables[0].interact()

func _is_locked() -> bool:
	if dialogue_box != null and dialogue_box.is_open():
		return true
	if choice_box != null and choice_box.visible:
		return true
	return false

func _cache_ui() -> void:
	if dialogue_box == null:
		dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if choice_box == null:
		choice_box = get_tree().get_first_node_in_group("choice_box")

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactables.append(area)

func _on_area_exited(area: Area3D) -> void:
	nearby_interactables.erase(area)

func _build_meshes() -> void:
	_build_quokka(self, {
		# 그림 속 쿼카는 스웨터를 입지 않았다. 온몸이 갈색 털이고 배만 밝다.
		# 예전엔 몸통 전체가 크림이라 기저귀를 찬 것처럼 보였고, 소매가 몸통과
		# 같은 색이라 팔이 실루엣에서 통째로 사라졌다.
		# 색은 도안(docs/refs/leader-turnaround.jpg)에서 뽑았다.
		# 예전 #B8784F 는 너무 주황이라 화면에서 당근처럼 보였다.
		"body": "#AC7E63",   # 갈색 털(몸통)
		"fur": "#AC7E63",    # 갈색 털(머리/귀)
		"belly": "#DCC5A8",  # 크림 배
		"sleeve": "#9C6E55", # 팔(한 단계 어둡게 — 옆 실루엣이 산다)
		"foot": "#8A6047",   # 발(제일 어둡게)
		"pack": "#4A7DAD",   # 배낭
		"mat": "#6FB8C8",    # 돌돌 만 매트
	})
	# 애니메이션이 참조하는 눈/꼬리 노드 보관
	_tail_mesh = get_node_or_null("BodyPivot/_Tail")

func _build_quokka(_unused, c: Dictionary) -> void:
	var fur = c.fur
	# ── 몸통(스웨터) : 둥근 달걀형 ──
	_set_sphere($BodyPivot/BodyMesh, 0.36, 0.56, c.body)
	$BodyPivot/BodyMesh.position = Vector3(0, -0.02, 0)
	$BodyPivot/BodyMesh.scale = Vector3(1.0, 1.0, 0.95)
	# 크림색 배. 예전엔 몸통과 색차가 0.05 뿐이라 없는 것과 같았다.
	_set_sphere($BodyPivot/BellyMesh, 0.275, 0.275, c.belly)
	$BodyPivot/BellyMesh.position = Vector3(0, 0.03, 0.235)
	$BodyPivot/BellyMesh.scale = Vector3(0.80, 1.05, 0.55)

	# ── 머리 ──
	#
	# 삼면도를 재 보니 그림은 **머리폭 / 몸통폭 = 0.81** 인데 여기는 1.06 이었다.
	# 머리가 몸보다 커서 눈사람으로 읽힌 것이다. 머리 안쪽(눈·귀·주둥이·모자)은
	# 서로 맞물려 있으므로 하나하나 줄이지 않고 피벗을 통째로 줄인다.
	# 그림의 목 잘록한 지점(위에서 48%)이 생기도록 위치도 함께 올린다.
	$BodyPivot/HeadPivot.position = Vector3(0, 0.50, 0)
	$BodyPivot/HeadPivot.scale = Vector3(0.80, 0.80, 0.80)
	_set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.35, 0.36, fur)
	$BodyPivot/HeadPivot/HeadMesh.scale = Vector3(1.05, 0.98, 1.0)

	# 머리 상단 털 뭉치 비활성 (메뉴에서 안테나처럼 보이는 문제 방지)

	# ── 귀 : 머리 위쪽 옆에 붙임 + 분홍 안쪽 ──
	# 귀를 바깥으로 눕힌다. 똑바로 세우면 머리 실루엣이 하트가 된다.
	# 도안 실측: 귀는 머리 **옆**이 아니라 위에 얹혀 있다. 중심이 머리 반경의
	# 절반쯤 바깥이고, 머리 꼭대기보다 더 올라온다. 앞뒤로 눌린 원반 모양이다.
	$BodyPivot/HeadPivot/LeftEarPivot.position = Vector3(-0.168, 0.275, -0.01)
	$BodyPivot/HeadPivot/RightEarPivot.position = Vector3(0.168, 0.275, -0.01)
	$BodyPivot/HeadPivot/LeftEarPivot.rotation_degrees = Vector3(0, 0, 9)
	$BodyPivot/HeadPivot/RightEarPivot.rotation_degrees = Vector3(0, 0, -9)
	_set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.145, 0.16, fur)
	_set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.145, 0.16, fur)
	$BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh.scale = Vector3(0.95, 1.05, 0.55)
	$BodyPivot/HeadPivot/RightEarPivot/RightEarMesh.scale = Vector3(0.95, 1.05, 0.55)
	# 분홍 안쪽은 살짝만 보이게. z 로 앞에 내밀면 눈처럼 읽힌다.
	_child_sphere($BodyPivot/HeadPivot/LeftEarPivot, 0.072, 0.080, "#C99A86", Vector3(0, 0.005, 0.032), Vector3(0.78, 0.90, 0.5))
	_child_sphere($BodyPivot/HeadPivot/RightEarPivot, 0.072, 0.080, "#C99A86", Vector3(0, 0.005, 0.032), Vector3(0.78, 0.90, 0.5))
	# 귀 털 뭉치

	# ── 주둥이(밝은 털) : 얼굴 아래쪽 둥근 입주변 ──
	var muzzle = MeshInstance3D.new()
	_set_sphere_mi(muzzle, 0.155, 0.148, _shade(c.belly, -0.06))
	muzzle.position = Vector3(0, -0.065, 0.245)
	muzzle.scale = Vector3(1.20, 0.88, 0.62)
	$BodyPivot/HeadPivot.add_child(muzzle)

	# ── 눈 : 검은 눈 하나 + 하이라이트 둘 ──
	#
	# 예전엔 흰자·홍채·동공 구 세 개를 5mm 간격으로 겹쳐 놨다. 동공(0.065)이
	# 흰자(0.068)와 거의 같은 크기라 흰자가 위쪽 초승달로만 남았고, 그래서
	# 눈이 반쯤 감긴 채 아래를 보는 표정이 됐다. 화면에서 눈은 6px 이다 —
	# 그 크기에 구 세 개는 절대 안 읽히고 오차만 만든다.
	# 그림이 쓰는 구성 그대로 간다: 큰 검은 눈 + 하이라이트 두 점.
	_set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.078, 0.094, "#2A211C")
	_set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.078, 0.094, "#2A211C")
	$BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.14, 0.07, 0.285)
	$BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.14, 0.07, 0.285)
	# 큰 하이라이트(위 바깥) + 작은 하이라이트(아래 안쪽)
	_left_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.026, 0.030, "#FFFFFF", Vector3(-0.165, 0.105, 0.335), Vector3.ONE)
	_right_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.026, 0.030, "#FFFFFF", Vector3(0.115, 0.105, 0.335), Vector3.ONE)
	_child_sphere($BodyPivot/HeadPivot, 0.013, 0.015, "#FFFFFF", Vector3(-0.108, 0.030, 0.330), Vector3.ONE)
	_child_sphere($BodyPivot/HeadPivot, 0.013, 0.015, "#FFFFFF", Vector3(0.172, 0.030, 0.330), Vector3.ONE)

	# ── 코 ──
	_set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.048, 0.056, "#6B4A38")
	$BodyPivot/HeadPivot/NoseMesh.position = Vector3(0, -0.01, 0.315)
	$BodyPivot/HeadPivot/NoseMesh.scale = Vector3(1.15, 0.95, 1.0)



	# 볼터치는 뺐다 — 도안에 없다. 분홍 점 두 개가 붙으면 쿼카가 아니라
	# 곰인형으로 보인다.
	$BodyPivot/HeadPivot/LeftCheekMesh.visible = false
	$BodyPivot/HeadPivot/RightCheekMesh.visible = false

	_build_face_lines(c)

	# ── 팔 : 어깨에서 몸 옆으로 내려옴(스웨터 소매) + 손 ──
	$BodyPivot/LeftArmPivot.position = Vector3(-0.32, 0.08, 0.04)
	$BodyPivot/RightArmPivot.position = Vector3(0.32, 0.08, 0.04)
	_set_capsule($BodyPivot/LeftArmPivot/LeftArmMesh, 0.08, 0.26, c.sleeve)
	_set_capsule($BodyPivot/RightArmPivot/RightArmMesh, 0.08, 0.26, c.sleeve)
	$BodyPivot/LeftArmPivot/LeftArmMesh.position = Vector3(0, -0.11, 0)
	$BodyPivot/RightArmPivot/RightArmMesh.position = Vector3(0, -0.11, 0)
	$BodyPivot/LeftArmPivot.rotation_degrees = Vector3(0, 0, 12)
	$BodyPivot/RightArmPivot.rotation_degrees = Vector3(0, 0, -12)
	_child_sphere($BodyPivot/LeftArmPivot, 0.075, 0.08, fur, Vector3(0, -0.24, 0.01), Vector3.ONE)   # 손
	_child_sphere($BodyPivot/RightArmPivot, 0.075, 0.08, fur, Vector3(0, -0.24, 0.01), Vector3.ONE)

	# ── 다리 : 몸 아래 짧게(틈 없이) + 발 ──
	$BodyPivot/LeftLegPivot.position = Vector3(-0.14, -0.24, 0.03)
	$BodyPivot/RightLegPivot.position = Vector3(0.14, -0.24, 0.03)
	_set_capsule($BodyPivot/LeftLegPivot/LeftLegMesh, 0.085, 0.18, fur)
	_set_capsule($BodyPivot/RightLegPivot/RightLegMesh, 0.085, 0.18, fur)
	$BodyPivot/LeftLegPivot/LeftLegMesh.position = Vector3(0, -0.06, 0)
	$BodyPivot/RightLegPivot/RightLegMesh.position = Vector3(0, -0.06, 0)
	_child_sphere($BodyPivot/LeftLegPivot, 0.09, 0.07, _shade(fur, -0.1), Vector3(0, -0.16, 0.05), Vector3(1.0, 0.7, 1.3))  # 발
	_child_sphere($BodyPivot/RightLegPivot, 0.09, 0.07, _shade(fur, -0.1), Vector3(0, -0.16, 0.05), Vector3(1.0, 0.7, 1.3))

	# ── 꼬리 ──
	var tail = _child_sphere($BodyPivot, 0.1, 0.12, _shade(fur, 0.18), Vector3(0, -0.05, -0.32), Vector3(0.8, 0.8, 1.0))
	tail.name = "_Tail"

	# ── 몸통 앞면 털 뭉치 (앞쪽 반구, z > 0 위치만) ──
	# 털 뭉치는 뺐다.
	#
	# 결을 내려던 것인데 화면에서는 혹으로 보였다. 크기를 키워도 줄여도
	# 마찬가지였다 — 캐릭터가 100px 인데 뭉치는 3~5px 이라 결이 될 수가 없다.
	# 그리고 삼면도를 보면 목표 화풍은 **완전히 매끈한 클레이**다.
	# 없는 것이 그림에 더 가깝다.

	_build_gear()

	# ── 배낭 + 돌돌 만 매트 (등 뒤) ──
	if $BodyPivot.has_node("BackpackPivot"):
		$BodyPivot/BackpackPivot.position = Vector3(0, 0.08, -0.30)
		_set_box($BodyPivot/BackpackPivot/BackpackMesh, Vector3(0.34, 0.4, 0.18), c.pack)
		var matroll = MeshInstance3D.new()
		var rm = CapsuleMesh.new(); rm.radius = 0.07; rm.height = 0.34; matroll.mesh = rm
		var rmat = StandardMaterial3D.new(); rmat.albedo_color = Color(c.mat); rmat.roughness = 0.9
		matroll.material_override = rmat
		matroll.position = Vector3(0, 0.26, 0)
		matroll.rotation_degrees = Vector3(0, 0, 90)
		$BodyPivot/BackpackPivot.add_child(matroll)

## 눈썹·입·발.
##
## 도안에는 있고 모델에는 없던 것들이다. 눈썹이 없으면 표정이 안 생기고
## (`set_emotion` 이 눈 크기만 바꾸던 이유가 이것이다), 입이 점 하나면
## 웃는지 알 수 없고, 발이 없으면 몸이 바닥에서 잘린 것처럼 보인다.
##
## 곡선은 작은 구를 호를 따라 늘어놓아 만든다. 이 크기(화면 100px)에서는
## 메시를 깎는 것보다 정확하고, 표정마다 호의 방향만 바꾸면 된다.
func _build_face_lines(c: Dictionary) -> void:
	var head := $BodyPivot/HeadPivot

	# 눈썹 — 눈 위 짧은 호, 바깥이 살짝 처진다
	for sx in [-1.0, 1.0]:
		for i in range(5):
			var t := float(i) / 4.0 - 0.5           # -0.5 .. 0.5
			var bx: float = sx * (0.14 + t * sx * 0.085)
			var by: float = 0.175 - absf(t) * 0.022
			var d := _child_sphere(head, 0.023, 0.026, "#5E4030",
				Vector3(bx, by, 0.275), Vector3(1.0, 0.75, 0.6))
			d.name = "Brow%s%d" % ["L" if sx < 0.0 else "R", i]

	# 입 — 코 아래 웃는 호
	for i in range(7):
		var u := float(i) / 6.0 - 0.5
		var mx := u * 0.135
		var my := -0.088 - (0.25 - u * u) * 0.10
		var m := _child_sphere(head, 0.019, 0.022, "#5E3A2C",
			Vector3(mx, my, 0.285), Vector3(1.0, 0.85, 0.6))
		m.name = "Mouth%d" % i

	# 발 — 도안은 몸 아래로 둥근 발이 살짝 나온다
	for sx in [-1.0, 1.0]:
		var f := _child_sphere($BodyPivot, 0.105, 0.09, c.get("foot", c.fur),
			Vector3(sx * 0.145, -0.335, 0.075), Vector3(1.0, 0.62, 1.25))
		f.name = "Foot%s" % ["L" if sx < 0.0 else "R"]


## 리더를 리더로 알아보게 하는 것들 — 초록 모자와 목에 건 카메라.
##
## 그림 속 리더는 행성 배지가 달린 초록 캡을 쓰고 카메라를 목에 걸고 있다.
## 3D 에는 등 뒤 배낭 하나뿐이었는데, 게임 카메라는 캐릭터를 뒤 위에서
## 내려다보므로 배낭은 몸에 가려 어느 캡처에도 안 보였다.
## 화면에서 캐릭터는 높이 100px 남짓이라, 알아보는 건 색이 아니라 **윤곽**이다.
## 모자는 윤곽 위쪽을, 카메라는 가슴 쪽을 튀어나오게 만든다.
func _build_gear() -> void:
	var head := $BodyPivot/HeadPivot

	# 모자 — 머리통(크라운) + 앞 챙
	var crown := MeshInstance3D.new()
	var cm := SphereMesh.new(); cm.radius = 0.255; cm.height = 0.30
	crown.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color("#7E9670"); cmat.roughness = 0.85
	crown.material_override = cmat
	crown.position = Vector3(0, 0.255, -0.015)
	crown.scale = Vector3(1.0, 0.66, 1.0)
	head.add_child(crown)

	# 챙은 크라운에 파묻혀 앞으로만 나오게 한다. 따로 떨어뜨리면
	# 초록 원반 두 장이 겹친 것처럼 보인다.
	var brim := MeshInstance3D.new()
	var bm := SphereMesh.new(); bm.radius = 0.135; bm.height = 0.14
	brim.mesh = bm
	brim.material_override = cmat
	brim.position = Vector3(0, 0.185, 0.20)
	brim.scale = Vector3(0.82, 0.24, 1.55)
	head.add_child(brim)

	# 행성 배지
	var badge := _child_sphere(head, 0.045, 0.050, "#8FC4E8", Vector3(0, 0.285, 0.165), Vector3.ONE)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.062; tm.outer_radius = 0.086
	ring.mesh = tm
	var rmat2 := StandardMaterial3D.new()
	rmat2.albedo_color = Color("#E8C87A"); rmat2.roughness = 0.7
	ring.material_override = rmat2
	ring.position = badge.position
	ring.rotation_degrees = Vector3(72, 0, 18)
	head.add_child(ring)

	# 카메라 — 몸통 + 렌즈 + 어깨끈
	var body_p := $BodyPivot
	var cam_body := MeshInstance3D.new()
	var cbm := BoxMesh.new(); cbm.size = Vector3(0.165, 0.115, 0.065)
	cam_body.mesh = cbm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#C8C4BE"); dark.roughness = 0.45
	cam_body.material_override = dark
	cam_body.position = Vector3(0, 0.115, 0.30)
	body_p.add_child(cam_body)

	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.042; lm.bottom_radius = 0.046; lm.height = 0.05
	lens.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color("#4A423C"); lmat.roughness = 0.30
	lens.material_override = lmat
	lens.position = Vector3(0, 0.115, 0.345)
	lens.rotation_degrees = Vector3(90, 0, 0)
	body_p.add_child(lens)

	var strap_mat := StandardMaterial3D.new()
	strap_mat.albedo_color = Color("#8A5A3A"); strap_mat.roughness = 0.9
	for sx in [-1.0, 1.0]:
		var strap := MeshInstance3D.new()
		var sm2 := BoxMesh.new(); sm2.size = Vector3(0.026, 0.17, 0.018)
		strap.mesh = sm2
		strap.material_override = strap_mat
		strap.position = Vector3(sx * 0.085, 0.205, 0.248)
		strap.rotation_degrees = Vector3(0, 0, sx * 26.0)
		body_p.add_child(strap)


# 구 표면에 털 뭉치 스피어를 구면 피보나치로 균일하게 배치
func _add_fur_tufts(parent: Node3D, surface_r: float, fur_hex: String, count: int, center_offset: Vector3) -> void:
	var base_col = Color(fur_hex)
	# 황금각(구면 피보나치 분포)
	var golden_angle = PI * (3.0 - sqrt(5.0))
	for i in range(count):
		# 구면 피보나치 분포로 균일한 방향 생성
		var y = 1.0 - (float(i) / float(count - 1)) * 2.0
		var radius_at_y = sqrt(max(0.0, 1.0 - y * y))
		var theta = golden_angle * float(i)
		var dir = Vector3(cos(theta) * radius_at_y, y, sin(theta) * radius_at_y)
		# 표면 위치 (살짝 돌출)
		var tuft_r = 0.026 + fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 0.012
		var pos = center_offset + dir * (surface_r + tuft_r * 0.5)
		# 색상 무작위 밝기 변화 ±0.12
		var shade_amt = fmod(sin(float(i) * 78.233) * 43758.5453, 1.0) * 0.10 - 0.05
		var tuft_col: Color
		if shade_amt >= 0.0:
			tuft_col = base_col.lightened(shade_amt)
		else:
			tuft_col = base_col.darkened(-shade_amt)
		# 스피어 메시 생성
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = tuft_r
		sm.height = tuft_r * 2.0
		mi.mesh = sm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tuft_col
		mat.roughness = 0.95
		mi.material_override = mat
		mi.position = pos
		parent.add_child(mi)

# 몸통 앞쪽 반구(z > 0)에만 털 뭉치 배치
func _add_fur_tufts_body(parent: Node3D, surface_r: float, fur_hex: String, count: int) -> void:
	var base_col = Color(fur_hex)
	var golden_angle = PI * (3.0 - sqrt(5.0))
	# 앞쪽 반구만 필터해서 count개 배치
	var placed = 0
	var attempt = 0
	while placed < count and attempt < count * 8:
		attempt += 1
		var y = 1.0 - (float(attempt) / float(count * 8 - 1)) * 2.0
		var radius_at_y = sqrt(max(0.0, 1.0 - y * y))
		var theta = golden_angle * float(attempt)
		var dir = Vector3(cos(theta) * radius_at_y, y, sin(theta) * radius_at_y)
		# 앞쪽 반구 (z > 0.1) 이고 위쪽 절반 (y > -0.2)만
		if dir.z < 0.1 or dir.y < -0.2:
			continue
		var tuft_r = 0.026 + fmod(sin(float(attempt) * 12.9898) * 43758.5453, 1.0) * 0.012
		var pos = dir * (surface_r + tuft_r * 0.5)
		var shade_amt = fmod(sin(float(attempt) * 78.233) * 43758.5453, 1.0) * 0.10 - 0.05
		var tuft_col: Color
		if shade_amt >= 0.0:
			tuft_col = base_col.lightened(shade_amt)
		else:
			tuft_col = base_col.darkened(-shade_amt)
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = tuft_r
		sm.height = tuft_r * 2.0
		mi.mesh = sm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tuft_col
		mat.roughness = 0.95
		mi.material_override = mat
		mi.position = pos
		parent.add_child(mi)
		placed += 1

func _shade(hex: String, amt: float) -> Color:
	var c = Color(hex)
	return c.lightened(amt) if amt >= 0.0 else c.darkened(-amt)

func _child_sphere(parent: Node3D, radius: float, height: float, col, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = (col if col is Color else Color(col)); mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos; mi.scale = scl
	parent.add_child(mi)
	return mi

func _to_col(c) -> Color:
	return c if c is Color else Color(c)

func _set_sphere_mi(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
	var m = SphereMesh.new()
	m.radius = radius
	m.height = height
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = _to_col(hex)
	mat.roughness = 0.85
	mi.material_override = mat

func _set_sphere(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
	var m = SphereMesh.new()
	m.radius = radius
	m.height = height
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = _to_col(hex)
	mat.roughness = 0.85
	mi.material_override = mat

func _set_capsule(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
	var m = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = _to_col(hex)
	mat.roughness = 0.85
	mi.material_override = mat

func _set_box(mi: MeshInstance3D, size: Vector3, hex) -> void:
	var m = BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = _to_col(hex)
	mat.roughness = 0.85
	mi.material_override = mat

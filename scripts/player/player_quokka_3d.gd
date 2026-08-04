extends CharacterBody3D

const MAX_SPEED: float = 3.2
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
		_speed = move_toward(_speed, MAX_SPEED, ACCELERATION * delta)
		velocity = velocity.move_toward(dir * MAX_SPEED, ACCELERATION * delta)
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_LERP * delta)
	else:
		_speed = move_toward(_speed, 0.0, DECELERATION * delta)
		velocity = velocity.move_toward(Vector3.ZERO, DECELERATION * delta)

	move_and_slide()

func _process(delta: float) -> void:
	_animate(delta)

func _animate(delta: float) -> void:
	if _is_walking:
		_walk_time += delta * _speed * 2.2
		var bob = sin(_walk_time * 3.0) * 0.07
		var tilt = sin(_walk_time * 3.0) * deg_to_rad(3.0)
		body_pivot.position.y = 0.0 + bob
		body_pivot.rotation.z = tilt
		head_pivot.rotation.z = sin(_walk_time * 3.0 - 0.2) * deg_to_rad(1.5)
		left_arm.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(12.0)
		right_arm.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(12.0)
		left_leg.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(8.0)
		right_leg.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(8.0)
		left_ear.rotation.z = sin(_walk_time * 2.5) * deg_to_rad(2.0)
		right_ear.rotation.z = -sin(_walk_time * 2.5) * deg_to_rad(2.0)
		backpack.rotation.x = sin(_walk_time * 3.0 - 0.3) * deg_to_rad(4.0)
		_step_accum += delta * _speed
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
	return v.normalized()

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
		"body": "#F2E4C6",   # 크림 니트 스웨터(몸통)
		"fur": "#B8784F",    # 갈색 털(머리/팔다리/귀)
		"sleeve": "#F2E4C6", # 스웨터 소매
		"pack": "#4A7DAD",   # 배낭
		"mat": "#6FB8C8",    # 돌돌 만 매트
	})
	# 애니메이션이 참조하는 눈/꼬리 노드 보관
	_tail_mesh = get_node_or_null("BodyPivot/_Tail")

func _build_quokka(_unused, c: Dictionary) -> void:
	var fur = c.fur
	# ── 몸통(스웨터) : 둥근 달걀형 ──
	_set_sphere($BodyPivot/BodyMesh, 0.33, 0.52, c.body)
	$BodyPivot/BodyMesh.position = Vector3(0, -0.02, 0)
	$BodyPivot/BodyMesh.scale = Vector3(1.0, 1.0, 0.95)
	# 스웨터 짜임 칼라(목)
	var collar = MeshInstance3D.new()
	_set_sphere_mi(collar, 0.22, 0.16, _shade(c.body, -0.07))
	collar.position = Vector3(0, 0.22, 0.02)
	collar.scale = Vector3(1.0, 0.5, 1.0)
	$BodyPivot.add_child(collar)
	# 가슴 하이라이트(밝은 배)
	_set_sphere($BodyPivot/BellyMesh, 0.2, 0.2, _shade(c.body, 0.05))
	$BodyPivot/BellyMesh.position = Vector3(0, 0.02, 0.17)
	$BodyPivot/BellyMesh.scale = Vector3(0.85, 0.95, 0.5)

	# ── 머리 : 크고 둥글게, 몸에 자연스럽게 얹힘(목 없음) ──
	$BodyPivot/HeadPivot.position = Vector3(0, 0.42, 0)
	_set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.35, 0.36, fur)
	$BodyPivot/HeadPivot/HeadMesh.scale = Vector3(1.05, 0.98, 1.0)

	# 머리 상단 털 뭉치 비활성 (메뉴에서 안테나처럼 보이는 문제 방지)

	# ── 귀 : 머리 위쪽 옆에 붙임 + 분홍 안쪽 ──
	$BodyPivot/HeadPivot/LeftEarPivot.position = Vector3(-0.19, 0.22, 0.06)
	$BodyPivot/HeadPivot/RightEarPivot.position = Vector3(0.19, 0.22, 0.06)
	_set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.12, 0.13, fur)
	_set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.12, 0.13, fur)
	$BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh.scale = Vector3(0.9, 1.0, 0.7)
	$BodyPivot/HeadPivot/RightEarPivot/RightEarMesh.scale = Vector3(0.9, 1.0, 0.7)
	_child_sphere($BodyPivot/HeadPivot/LeftEarPivot, 0.07, 0.08, "#F2A6AE", Vector3(0, 0.01, 0.05), Vector3(0.8, 1.0, 0.6))
	_child_sphere($BodyPivot/HeadPivot/RightEarPivot, 0.07, 0.08, "#F2A6AE", Vector3(0, 0.01, 0.05), Vector3(0.8, 1.0, 0.6))
	# 귀 털 뭉치
	_add_fur_tufts($BodyPivot/HeadPivot/LeftEarPivot, 0.11, fur, 8, Vector3.ZERO)
	_add_fur_tufts($BodyPivot/HeadPivot/RightEarPivot, 0.11, fur, 8, Vector3.ZERO)

	# ── 주둥이(밝은 털) : 얼굴 아래쪽 둥근 입주변 ──
	var muzzle = MeshInstance3D.new()
	_set_sphere_mi(muzzle, 0.16, 0.15, _shade(fur, 0.22))
	muzzle.position = Vector3(0, -0.07, 0.26)
	muzzle.scale = Vector3(1.25, 0.85, 0.8)
	$BodyPivot/HeadPivot.add_child(muzzle)

	# ── 눈 : 흰자 + 홍채(갈색 링) + 동공 + 하이라이트 ──
	# 흰자
	var left_white = MeshInstance3D.new()
	_set_sphere_mi(left_white, 0.068, 0.082, "#FAFAFA")
	left_white.position = Vector3(-0.14, 0.07, 0.290)
	$BodyPivot/HeadPivot.add_child(left_white)
	var right_white = MeshInstance3D.new()
	_set_sphere_mi(right_white, 0.068, 0.082, "#FAFAFA")
	right_white.position = Vector3(0.14, 0.07, 0.290)
	$BodyPivot/HeadPivot.add_child(right_white)
	# 홍채(갈색 링 - 흰자와 동공 사이)
	var left_iris = MeshInstance3D.new()
	_set_sphere_mi(left_iris, 0.057, 0.068, "#6B3A2A")
	left_iris.position = Vector3(-0.14, 0.07, 0.296)
	$BodyPivot/HeadPivot.add_child(left_iris)
	var right_iris = MeshInstance3D.new()
	_set_sphere_mi(right_iris, 0.057, 0.068, "#6B3A2A")
	right_iris.position = Vector3(0.14, 0.07, 0.296)
	$BodyPivot/HeadPivot.add_child(right_iris)
	# 동공 (기존 LeftEyeMesh/RightEyeMesh 재사용, 반경 약간 키움)
	_set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.065, 0.078, "#2A211C")
	_set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.065, 0.078, "#2A211C")
	$BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.14, 0.07, 0.295)
	$BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.14, 0.07, 0.295)
	# 하이라이트
	_left_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.02, 0.024, "#FFFFFF", Vector3(-0.155, 0.095, 0.33), Vector3.ONE)
	_right_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.02, 0.024, "#FFFFFF", Vector3(0.125, 0.095, 0.33), Vector3.ONE)

	# ── 코 ──
	_set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.034, 0.04, "#3A2418")
	$BodyPivot/HeadPivot/NoseMesh.position = Vector3(0, 0.0, 0.34)
	$BodyPivot/HeadPivot/NoseMesh.scale = Vector3(1.2, 0.9, 0.9)

	# ── 미소(입) : 코 아래 작은 어두운 곡선 ──
	var mouth = MeshInstance3D.new()
	_set_sphere_mi(mouth, 0.05, 0.05, "#5A3A28")
	mouth.position = Vector3(0, -0.09, 0.33)
	mouth.scale = Vector3(1.4, 0.45, 0.4)
	$BodyPivot/HeadPivot.add_child(mouth)

	# ── 볼터치 : 눈 아래 옆쪽 ──
	_set_sphere($BodyPivot/HeadPivot/LeftCheekMesh, 0.06, 0.06, "#FFB3BA")
	_set_sphere($BodyPivot/HeadPivot/RightCheekMesh, 0.06, 0.06, "#FFB3BA")
	$BodyPivot/HeadPivot/LeftCheekMesh.position = Vector3(-0.22, -0.03, 0.23)
	$BodyPivot/HeadPivot/RightCheekMesh.position = Vector3(0.22, -0.03, 0.23)
	$BodyPivot/HeadPivot/LeftCheekMesh.scale = Vector3(1.0, 0.7, 0.5)
	$BodyPivot/HeadPivot/RightCheekMesh.scale = Vector3(1.0, 0.7, 0.5)

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
	_add_fur_tufts_body($BodyPivot, 0.33, fur, 14)

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
		var tuft_r = randf_range(0.011, 0.020)
		var pos = center_offset + dir * (surface_r + tuft_r * 0.5)
		# 색상 무작위 밝기 변화 ±0.12
		var shade_amt = randf_range(-0.12, 0.12)
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
		var tuft_r = randf_range(0.011, 0.020)
		var pos = dir * (surface_r + tuft_r * 0.5)
		var shade_amt = randf_range(-0.12, 0.12)
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

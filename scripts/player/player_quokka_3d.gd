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
			if AudioManager: AudioManager.footstep()
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
	v.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	v.z = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return v.normalized()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
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
	_set_sphere($BodyPivot/BodyMesh, 0.30, 0.34, "#B8784F")
	_set_sphere($BodyPivot/BellyMesh, 0.22, 0.26, "#F3D5AD")
	_set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.33, 0.35, "#B8784F")
	_set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.1, 0.115, "#B8784F")
	_set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.1, 0.115, "#B8784F")
	_set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.06, 0.066, "#1A1412")
	_set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.06, 0.066, "#1A1412")
	_set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.03, 0.034, "#3A2418")
	_set_sphere($BodyPivot/HeadPivot/LeftCheekMesh, 0.065, 0.072, "#FFB3BA")
	_set_sphere($BodyPivot/HeadPivot/RightCheekMesh, 0.065, 0.072, "#FFB3BA")

	# 큰 머리에 맞춰 얼굴 요소 앞으로 재배치 (귀여운 비율)
	$BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.12, 0.06, 0.27)
	$BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.12, 0.06, 0.27)
	$BodyPivot/HeadPivot/NoseMesh.position = Vector3(0, -0.03, 0.32)
	$BodyPivot/HeadPivot/LeftCheekMesh.position = Vector3(-0.17, -0.05, 0.25)
	$BodyPivot/HeadPivot/RightCheekMesh.position = Vector3(0.17, -0.05, 0.25)
	_set_capsule($BodyPivot/LeftArmPivot/LeftArmMesh, 0.07, 0.22, "#B8784F")
	_set_capsule($BodyPivot/RightArmPivot/RightArmMesh, 0.07, 0.22, "#B8784F")
	_set_capsule($BodyPivot/LeftLegPivot/LeftLegMesh, 0.07, 0.24, "#B8784F")
	_set_capsule($BodyPivot/RightLegPivot/RightLegMesh, 0.07, 0.24, "#B8784F")
	_set_box($BodyPivot/BackpackPivot/BackpackMesh, Vector3(0.18, 0.2, 0.1), "#4A7DAD")

	# White sclera (behind pupils)
	_left_eye_white = MeshInstance3D.new()
	_set_sphere_mi(_left_eye_white, 0.072, 0.085, "#F5F5F5")
	_left_eye_white.position = $BodyPivot/HeadPivot/LeftEyeMesh.position + Vector3(0, 0, -0.01)
	$BodyPivot/HeadPivot.add_child(_left_eye_white)

	_right_eye_white = MeshInstance3D.new()
	_set_sphere_mi(_right_eye_white, 0.072, 0.085, "#F5F5F5")
	_right_eye_white.position = $BodyPivot/HeadPivot/RightEyeMesh.position + Vector3(0, 0, -0.01)
	$BodyPivot/HeadPivot.add_child(_right_eye_white)

	# Eye highlight dots (on top of pupils)
	_left_eye_hl = MeshInstance3D.new()
	_set_sphere_mi(_left_eye_hl, 0.024, 0.030, "#FFFFFF")
	_left_eye_hl.position = $BodyPivot/HeadPivot/LeftEyeMesh.position + Vector3(-0.02, 0.022, 0.035)
	$BodyPivot/HeadPivot.add_child(_left_eye_hl)

	_right_eye_hl = MeshInstance3D.new()
	_set_sphere_mi(_right_eye_hl, 0.024, 0.030, "#FFFFFF")
	_right_eye_hl.position = $BodyPivot/HeadPivot/RightEyeMesh.position + Vector3(0.02, 0.022, 0.035)
	$BodyPivot/HeadPivot.add_child(_right_eye_hl)

	# Tail
	_tail_mesh = MeshInstance3D.new()
	_set_sphere_mi(_tail_mesh, 0.1, 0.12, "#F3D5AD")
	_tail_mesh.position = Vector3(0, 0.1, -0.3)
	$BodyPivot.add_child(_tail_mesh)

	# Foot tips
	var lfoot = MeshInstance3D.new()
	_set_sphere_mi(lfoot, 0.07, 0.08, "#8A5A38")
	lfoot.position = Vector3(0, -0.2, 0.04)
	$BodyPivot/LeftLegPivot.add_child(lfoot)

	var rfoot = MeshInstance3D.new()
	_set_sphere_mi(rfoot, 0.07, 0.08, "#8A5A38")
	rfoot.position = Vector3(0, -0.2, 0.04)
	$BodyPivot/RightLegPivot.add_child(rfoot)

	# === 추가: 니트 스웨터 ===
	var sweater = MeshInstance3D.new()
	_set_sphere_mi(sweater, 0.315, 0.30, "#F2E4C6")
	sweater.position = Vector3(0, -0.02, 0)
	sweater.scale = Vector3(1.0, 0.85, 1.0)
	$BodyPivot.add_child(sweater)
	# 스웨터 목 칼라
	var collar = MeshInstance3D.new()
	_set_sphere_mi(collar, 0.16, 0.12, "#E5D2A8")
	collar.position = Vector3(0, 0.2, 0.02)
	$BodyPivot.add_child(collar)

	# === 추가: 둥근 주둥이 ===
	var muzzle = MeshInstance3D.new()
	_set_sphere_mi(muzzle, 0.14, 0.13, "#D8A878")
	muzzle.position = Vector3(0, -0.05, 0.26)
	muzzle.scale = Vector3(1.1, 0.85, 0.8)
	$BodyPivot/HeadPivot.add_child(muzzle)

	# === 추가: 미소 ===
	for sgn in [-1.0, 1.0]:
		var m = MeshInstance3D.new()
		var cm = CapsuleMesh.new(); cm.radius = 0.012; cm.height = 0.09; m.mesh = cm
		var mat = StandardMaterial3D.new(); mat.albedo_color = Color("#5A3A28"); mat.roughness = 0.8
		m.material_override = mat
		m.position = Vector3(sgn * 0.05, -0.12, 0.34)
		m.rotation_degrees = Vector3(0, 0, 90 + sgn * 25)
		$BodyPivot/HeadPivot.add_child(m)

	# === 추가: 배낭 위 돌돌 만 매트 ===
	var mat_roll = MeshInstance3D.new()
	var rm = CapsuleMesh.new(); rm.radius = 0.06; rm.height = 0.26; mat_roll.mesh = rm
	var rmat = StandardMaterial3D.new(); rmat.albedo_color = Color("#6FB8C8"); rmat.roughness = 0.9
	mat_roll.material_override = rmat
	mat_roll.position = Vector3(0, 0.13, -0.02)
	mat_roll.rotation_degrees = Vector3(0, 0, 90)
	$BodyPivot/BackpackPivot.add_child(mat_roll)

func _set_sphere_mi(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
	var m = SphereMesh.new()
	m.radius = radius
	m.height = height
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.85
	mi.material_override = mat

func _set_sphere(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
	var m = SphereMesh.new()
	m.radius = radius
	m.height = height
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.85
	mi.material_override = mat

func _set_capsule(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
	var m = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.85
	mi.material_override = mat

func _set_box(mi: MeshInstance3D, size: Vector3, hex: String) -> void:
	var m = BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.85
	mi.material_override = mat

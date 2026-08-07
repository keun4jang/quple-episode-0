extends Node3D

const FOLLOW_SPEED: float = 2.8
const FOLLOW_START_DIST: float = 2.0
const FOLLOW_STOP_DIST: float = 1.2
const TELEPORT_DIST: float = 5.0

var _is_following: bool = false
var _idle_time: float = 0.0
var _walk_time: float = 0.0
var _is_walking: bool = false
var _joined: bool = false
var _holding: bool = false

var _tail_mesh: MeshInstance3D = null
var _left_eye_hl: MeshInstance3D = null
var _right_eye_hl: MeshInstance3D = null
var _emotion: String = "neutral"
var _emotion_time: float = 0.0
var _left_ear: Node3D = null
var _right_ear: Node3D = null

@onready var body_pivot: Node3D = $BodyPivot
@onready var head_pivot: Node3D = $BodyPivot/HeadPivot
@onready var left_arm: Node3D = $BodyPivot/LeftArmPivot
@onready var right_arm: Node3D = $BodyPivot/RightArmPivot
@onready var left_leg: Node3D = $BodyPivot/LeftLegPivot
@onready var right_leg: Node3D = $BodyPivot/RightLegPivot
@onready var left_ear: Node3D = $BodyPivot/HeadPivot/LeftEarPivot
@onready var right_ear: Node3D = $BodyPivot/HeadPivot/RightEarPivot

func _ready() -> void:
	_build_meshes()

	var shadow = MeshInstance3D.new()
	var sc = CylinderMesh.new(); sc.top_radius = 0.3; sc.bottom_radius = 0.3; sc.height = 0.01
	shadow.mesh = sc
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.32)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = smat
	shadow.position = Vector3(0, 0.03, 0)
	add_child(shadow)

func join_player() -> void:
	if _joined:
		return
	_joined = true
	set_emotion("happy")
	# 합류 순간: 살짝 통통 튀어오르며 자세를 편다
	var tw := create_tween()
	tw.tween_property(body_pivot, "position:y", 0.14, 0.18).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body_pivot, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE)

func is_joined() -> bool:
	return _joined

func set_emotion(emotion: String) -> void:
	_emotion = emotion
	_emotion_time = 0.0

func _physics_process(delta: float) -> void:
	if not _joined:
		_holding = false
		_animate_idle(delta)
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		_holding = false
		_animate_idle(delta)
		return
	var dist = global_position.distance_to(player.global_position)
	_holding = _joined and dist <= 1.5
	if dist > TELEPORT_DIST:
		global_position = player.global_position + Vector3(0.8, 0, 0.8)
	if dist > FOLLOW_START_DIST:
		var dir = (player.global_position - global_position).normalized()
		dir.y = 0
		global_position += dir * FOLLOW_SPEED * delta
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
		_is_walking = true
	else:
		_is_walking = false
	if _is_walking:
		_animate_walk(delta)
	else:
		_animate_idle(delta)

func _animate_idle(delta: float) -> void:
	_idle_time += delta
	# 합류 전에는 느리고 작게(지친 숨), 합류 후에는 조금 더 크고 경쾌하게
	var intensity := 0.015 if _joined else 0.008
	var breath_period := 1.8 if _joined else 2.6
	body_pivot.position.y = sin(_idle_time * (TAU / breath_period)) * intensity
	head_pivot.rotation.z = sin(_idle_time * (TAU / 2.5)) * deg_to_rad(0.8)

	# 자세: 합류 전엔 어깨와 고개가 앞으로 처지고, 합류 후엔 곧게 펴진다
	var slouch := 0.0 if _joined else deg_to_rad(11.0)
	var head_drop := 0.0 if _joined else deg_to_rad(8.0)
	body_pivot.rotation.x = lerp_angle(body_pivot.rotation.x, slouch, delta * 3.0)
	head_pivot.rotation.x = lerp_angle(head_pivot.rotation.x, head_drop, delta * 3.0)
	# 지쳤을 땐 귀도 살짝 내려간다
	var ear_droop := 0.0 if _joined else deg_to_rad(14.0)
	if _left_ear:
		_left_ear.rotation.x = lerp_angle(_left_ear.rotation.x, ear_droop, delta * 3.0)
	if _right_ear:
		_right_ear.rotation.x = lerp_angle(_right_ear.rotation.x, ear_droop, delta * 3.0)

	_emotion_time += delta
	if _emotion_time > 4.0:
		_emotion = "neutral"

	match _emotion:
		"happy":
			# 빠른 귀 흔들기, 꼬리 흔들기
			if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 4.0) * deg_to_rad(25.0)
			left_ear.rotation.z = sin(_idle_time * 3.0) * deg_to_rad(5.0)
			right_ear.rotation.z = -sin(_idle_time * 3.0) * deg_to_rad(5.0)
		"nervous":
			# 귀 처짐, 몸 떨림
			left_ear.rotation.z = lerp(left_ear.rotation.z, deg_to_rad(-8.0), delta * 3.0)
			right_ear.rotation.z = lerp(right_ear.rotation.z, deg_to_rad(8.0), delta * 3.0)
			body_pivot.rotation.z = sin(_idle_time * 8.0) * deg_to_rad(1.5)
		"excited":
			# 팔 살짝 올림
			left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
			right_arm.rotation.x = lerp(right_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
			if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 6.0) * deg_to_rad(30.0)
		_:
			if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 1.5) * deg_to_rad(8.0)

	if _holding:
		left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-25.0), delta * 6.0)
		left_arm.rotation.z = lerp(left_arm.rotation.z, deg_to_rad(-30.0), delta * 6.0)

func _animate_walk(delta: float) -> void:
	_walk_time += delta * FOLLOW_SPEED * 2.5
	body_pivot.position.y = sin(_walk_time * 3.0) * 0.06
	left_arm.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(10.0)
	right_arm.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(10.0)
	left_leg.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(7.0)
	right_leg.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(7.0)

	_emotion_time += delta
	if _emotion_time > 4.0:
		_emotion = "neutral"

	match _emotion:
		"happy":
			# 빠른 귀 흔들기, 꼬리 흔들기
			if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 4.0) * deg_to_rad(25.0)
			left_ear.rotation.z = sin(_idle_time * 3.0) * deg_to_rad(5.0)
			right_ear.rotation.z = -sin(_idle_time * 3.0) * deg_to_rad(5.0)
		"nervous":
			# 귀 처짐, 몸 떨림
			left_ear.rotation.z = lerp(left_ear.rotation.z, deg_to_rad(-8.0), delta * 3.0)
			right_ear.rotation.z = lerp(right_ear.rotation.z, deg_to_rad(8.0), delta * 3.0)
			body_pivot.rotation.z = sin(_idle_time * 8.0) * deg_to_rad(1.5)
		"excited":
			# 팔 살짝 올림
			left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
			right_arm.rotation.x = lerp(right_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
			if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 6.0) * deg_to_rad(30.0)
		_:
			if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 1.5) * deg_to_rad(8.0)

	if _holding:
		left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-25.0), delta * 6.0)
		left_arm.rotation.z = lerp(left_arm.rotation.z, deg_to_rad(-30.0), delta * 6.0)

func _build_meshes() -> void:
	# 그림 속 파트너도 스웨터를 입지 않았다. 온몸이 갈색 털이고,
	# 알아보게 하는 것은 몸 색이 아니라 **분홍 니트 목도리**다.
	# 색은 도안(docs/refs/partner-turnaround.jpg)에서 뽑았다.
	# 파트너는 리더(#AC7E63)보다 한 톤 밝다 — 둘을 나란히 놓으면 구분된다.
	var fur = "#C0906C"
	var body_col = "#C0906C"
	var belly_col = "#DCC5A8"
	# ── 몸통(스웨터) ──
	_set_sphere($BodyPivot/BodyMesh, 0.345, 0.545, body_col)
	$BodyPivot/BodyMesh.position = Vector3(0, -0.02, 0)
	$BodyPivot/BodyMesh.scale = Vector3(1.0, 1.0, 0.95)
	_set_sphere($BodyPivot/BellyMesh, 0.265, 0.265, belly_col)
	$BodyPivot/BellyMesh.position = Vector3(0, 0.03, 0.225); $BodyPivot/BellyMesh.scale = Vector3(0.80, 1.05, 0.55)

	# ── 머리 ──
	# 삼면도 실측: 머리폭/몸통폭 = 0.81. 리더와 같은 이유로 피벗째 줄인다.
	$BodyPivot/HeadPivot.position = Vector3(0, 0.48, 0)
	$BodyPivot/HeadPivot.scale = Vector3(0.80, 0.80, 0.80)
	_set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.33, 0.34, fur)
	$BodyPivot/HeadPivot/HeadMesh.scale = Vector3(1.05, 0.98, 1.0)
	# 머리 털 뭉치
	# 머리 상단 털 뭉치 비활성 (안테나 방지)

	# ── 귀 + 분홍 안쪽 ──
	# 도안 실측: 귀는 머리 옆이 아니라 위에 얹혀 있고, 앞뒤로 눌린 원반이다.
	$BodyPivot/HeadPivot/LeftEarPivot.position = Vector3(-0.160, 0.262, -0.01)
	$BodyPivot/HeadPivot/RightEarPivot.position = Vector3(0.160, 0.262, -0.01)
	$BodyPivot/HeadPivot/LeftEarPivot.rotation_degrees = Vector3(0, 0, 9)
	$BodyPivot/HeadPivot/RightEarPivot.rotation_degrees = Vector3(0, 0, -9)
	_set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.138, 0.152, fur)
	_set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.138, 0.152, fur)
	$BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh.scale = Vector3(0.95, 1.05, 0.55)
	$BodyPivot/HeadPivot/RightEarPivot/RightEarMesh.scale = Vector3(0.95, 1.05, 0.55)
	# 분홍 안쪽을 앞으로 내밀면 눈처럼 읽혀 얼굴이 개구리가 된다.
	_child_sphere($BodyPivot/HeadPivot/LeftEarPivot, 0.068, 0.076, "#D2A38E", Vector3(0, 0.005, 0.030), Vector3(0.78, 0.90, 0.5))
	_child_sphere($BodyPivot/HeadPivot/RightEarPivot, 0.068, 0.076, "#D2A38E", Vector3(0, 0.005, 0.030), Vector3(0.78, 0.90, 0.5))
	# 귀 털 뭉치

	# ── 주둥이 ──
	var muzzle = MeshInstance3D.new()
	_set_sphere_mi(muzzle, 0.148, 0.142, _shade(belly_col, -0.06))
	muzzle.position = Vector3(0, -0.062, 0.235); muzzle.scale = Vector3(1.20, 0.88, 0.62)
	$BodyPivot/HeadPivot.add_child(muzzle)

	# ── 눈 : 검은 눈 하나 + 하이라이트 둘 ──
	# 흰자·홍채·동공을 5mm 간격으로 겹치면 화면 6px 에서 흰자가 위쪽
	# 초승달로만 남아 반쯤 감은 표정이 된다. 그림의 구성으로 단순화한다.
	_set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.075, 0.090, "#2A211C")
	_set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.075, 0.090, "#2A211C")
	$BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.13, 0.07, 0.268)
	$BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.13, 0.07, 0.268)
	_left_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.025, 0.029, "#FFFFFF", Vector3(-0.152, 0.100, 0.315), Vector3.ONE)
	_right_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.025, 0.029, "#FFFFFF", Vector3(0.108, 0.100, 0.315), Vector3.ONE)
	# 작은 두 번째 하이라이트(아래 반대편). 눈이 초롱초롱해진다.
	_child_sphere($BodyPivot/HeadPivot, 0.012, 0.014, "#FFFFFF", Vector3(-0.100, 0.032, 0.310), Vector3.ONE)
	_child_sphere($BodyPivot/HeadPivot, 0.012, 0.014, "#FFFFFF", Vector3(0.160, 0.032, 0.310), Vector3.ONE)

	# ── 코 ──
	_set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.046, 0.054, "#6B4A38")
	$BodyPivot/HeadPivot/NoseMesh.position = Vector3(0, -0.01, 0.305); $BodyPivot/HeadPivot/NoseMesh.scale = Vector3(1.15, 0.95, 1.0)

	# 볼터치는 뺐다 — 도안에 없다.
	$BodyPivot/HeadPivot/LeftCheekMesh.visible = false
	$BodyPivot/HeadPivot/RightCheekMesh.visible = false

	_build_face_lines(belly_col)
	# ── 팔(소매) + 손 ──
	$BodyPivot/LeftArmPivot.position = Vector3(-0.3, 0.08, 0.04)
	$BodyPivot/RightArmPivot.position = Vector3(0.3, 0.08, 0.04)
	# 팔을 몸통보다 한 단계 어둡게. 같은 색이면 옆 실루엣에서 사라진다.
	_set_capsule($BodyPivot/LeftArmPivot/LeftArmMesh, 0.075, 0.24, _shade(body_col, -0.10))
	_set_capsule($BodyPivot/RightArmPivot/RightArmMesh, 0.075, 0.24, _shade(body_col, -0.10))
	$BodyPivot/LeftArmPivot/LeftArmMesh.position = Vector3(0, -0.1, 0)
	$BodyPivot/RightArmPivot/RightArmMesh.position = Vector3(0, -0.1, 0)
	$BodyPivot/LeftArmPivot.rotation_degrees = Vector3(0, 0, 12)
	$BodyPivot/RightArmPivot.rotation_degrees = Vector3(0, 0, -12)
	_child_sphere($BodyPivot/LeftArmPivot, 0.07, 0.075, fur, Vector3(0, -0.22, 0.01), Vector3.ONE)
	_child_sphere($BodyPivot/RightArmPivot, 0.07, 0.075, fur, Vector3(0, -0.22, 0.01), Vector3.ONE)

	# ── 다리 + 발 ──
	$BodyPivot/LeftLegPivot.position = Vector3(-0.13, -0.24, 0.03)
	$BodyPivot/RightLegPivot.position = Vector3(0.13, -0.24, 0.03)
	_set_capsule($BodyPivot/LeftLegPivot/LeftLegMesh, 0.08, 0.16, fur)
	_set_capsule($BodyPivot/RightLegPivot/RightLegMesh, 0.08, 0.16, fur)
	$BodyPivot/LeftLegPivot/LeftLegMesh.position = Vector3(0, -0.05, 0)
	$BodyPivot/RightLegPivot/RightLegMesh.position = Vector3(0, -0.05, 0)
	_child_sphere($BodyPivot/LeftLegPivot, 0.085, 0.065, _shade(fur, -0.1), Vector3(0, -0.14, 0.05), Vector3(1.0, 0.7, 1.3))
	_child_sphere($BodyPivot/RightLegPivot, 0.085, 0.065, _shade(fur, -0.1), Vector3(0, -0.14, 0.05), Vector3(1.0, 0.7, 1.3))

	# ── 사원증(가슴) ──
	_set_box($BodyPivot/BadgeMesh, Vector3(0.09, 0.11, 0.02), "#EDEDED")
	$BodyPivot/BadgeMesh.position = Vector3(0.1, 0.04, 0.27)

	# ── 꼬리 ──
	var tail = _child_sphere($BodyPivot, 0.09, 0.11, _shade(fur, 0.18), Vector3(0, -0.05, -0.3), Vector3(0.8, 0.8, 1.0))
	_tail_mesh = tail

	# ── 몸통 앞면 털 뭉치 ──
	# 털 뭉치는 뺐다.
	#
	# 결을 내려던 것인데 화면에서는 혹으로 보였다. 크기를 키워도 줄여도
	# 마찬가지였다 — 캐릭터가 100px 인데 뭉치는 3~5px 이라 결이 될 수가 없다.
	# 그리고 삼면도를 보면 목표 화풍은 **완전히 매끈한 클레이**다.
	# 없는 것이 그림에 더 가깝다.

	_build_gear()

	# ── 배낭 + 매트(등 뒤) ──
	var pack = MeshInstance3D.new()
	_set_sphere_mi(pack, 0.17, 0.34, "#C97A5A")
	pack.position = Vector3(0, 0.05, -0.3); pack.scale = Vector3(1.0, 1.0, 0.6)
	$BodyPivot.add_child(pack)
	var matroll = MeshInstance3D.new()
	var rm = CapsuleMesh.new(); rm.radius = 0.065; rm.height = 0.32; matroll.mesh = rm
	var rmat = StandardMaterial3D.new(); rmat.albedo_color = Color("#F2A0B0"); rmat.roughness = 0.9
	matroll.material_override = rmat
	matroll.position = Vector3(0, 0.24, -0.3); matroll.rotation_degrees = Vector3(0, 0, 90)
	$BodyPivot.add_child(matroll)

## 눈썹·입·발. 도안에는 있고 모델에는 없던 것들이다.
## 작은 구를 호를 따라 늘어놓아 곡선을 만든다 — 이 크기에서는 메시를 깎는
## 것보다 정확하고, 표정을 바꿀 때 호의 방향만 손보면 된다.
func _build_face_lines(_belly: String) -> void:
	var head := $BodyPivot/HeadPivot
	for sx in [-1.0, 1.0]:
		for i in range(5):
			var t := float(i) / 4.0 - 0.5
			var bx: float = sx * (0.132 + t * sx * 0.080)
			var by: float = 0.168 - absf(t) * 0.021
			_child_sphere(head, 0.022, 0.025, "#6E4A38",
				Vector3(bx, by, 0.265), Vector3(1.0, 0.75, 0.6))
	for i in range(7):
		var u := float(i) / 6.0 - 0.5
		_child_sphere(head, 0.018, 0.021, "#6E453A",
			Vector3(u * 0.128, -0.082 - (0.25 - u * u) * 0.095, 0.275),
			Vector3(1.0, 0.85, 0.6))
	for sx2 in [-1.0, 1.0]:
		_child_sphere($BodyPivot, 0.10, 0.086, "#9C7050",
			Vector3(sx2 * 0.138, -0.325, 0.07), Vector3(1.0, 0.62, 1.25))


## 파트너를 파트너로 알아보게 하는 것 — 분홍 니트 목도리와 옆구리 가방.
##
## 예전에는 코랄색 스웨터로 구분했는데, 몸 색은 조명이 바뀌면 같이 바뀐다.
## 실제로 리더와 나란히 세운 캡처에서 둘의 차이가 몸 색조 하나뿐이라
## 조명이 다르면 같은 캐릭터로 보였다. 목도리는 목선을 굵게 만들어
## **윤곽만으로도** 둘을 갈라 준다.
func _build_gear() -> void:
	var body_p := $BodyPivot
	var knit := StandardMaterial3D.new()
	knit.albedo_color = Color("#E8AFAF")
	knit.roughness = 0.98

	# 목을 감은 두께
	var wrap := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16; tm.outer_radius = 0.255
	tm.rings = 24; tm.ring_segments = 10
	wrap.mesh = tm
	wrap.material_override = knit
	wrap.position = Vector3(0, 0.235, 0.01)
	wrap.scale = Vector3(1.0, 1.0, 0.92)
	body_p.add_child(wrap)

	# 앞으로 늘어뜨린 자락 두 가닥
	for sx in [-1.0, 1.0]:
		var tail_end := MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.radius = 0.055; cm.height = 0.26
		tail_end.mesh = cm
		tail_end.material_override = knit
		tail_end.position = Vector3(sx * 0.085, 0.10, 0.20)
		tail_end.rotation_degrees = Vector3(12, 0, sx * 8.0)
		body_p.add_child(tail_end)

	# 옆구리 가방 + 어깨끈. 등 뒤에 있으면 게임 카메라에서 몸에 가린다.
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("#7A4A32"); leather.roughness = 0.9
	var bag := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.17, 0.15, 0.09)
	bag.mesh = bm
	bag.material_override = leather
	bag.position = Vector3(0.29, -0.08, 0.07)
	bag.rotation_degrees = Vector3(0, -12, 0)
	body_p.add_child(bag)

	var strap := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.032, 0.34, 0.02)
	strap.mesh = sm
	strap.material_override = leather
	strap.position = Vector3(0.10, 0.10, 0.22)
	strap.rotation_degrees = Vector3(0, 0, -34.0)
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

func _to_col(c) -> Color:
	return c if c is Color else Color(c)

func _child_sphere(parent: Node3D, radius: float, height: float, col, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
	var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(col); mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos; mi.scale = scl
	parent.add_child(mi)
	return mi

func _set_sphere(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
	var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
	var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
	mi.material_override = mat

func _set_sphere_mi(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
	var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
	var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
	mi.material_override = mat

func _set_capsule(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
	var m = CapsuleMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
	var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
	mi.material_override = mat

func _set_box(mi: MeshInstance3D, size: Vector3, hex) -> void:
	var m = BoxMesh.new(); m.size = size; mi.mesh = m
	var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
	mi.material_override = mat

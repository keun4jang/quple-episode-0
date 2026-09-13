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

# 착용 장비를 붙이는 자리 — { 슬롯: [Node3D, ...] }
# 손/발처럼 좌우 두 곳에 붙는 슬롯이 있어서 슬롯마다 배열로 들고 있는다.
var _equip_roots: Dictionary = {}

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
	_setup_equipment_roots()
	PlayerStats.equipment_changed.connect(_refresh_equipment)
	_refresh_equipment()

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

	# ── 귀 : 머리 위쪽 옆에 붙임 + 분홍 안쪽 ──
	$BodyPivot/HeadPivot/LeftEarPivot.position = Vector3(-0.19, 0.22, 0.06)
	$BodyPivot/HeadPivot/RightEarPivot.position = Vector3(0.19, 0.22, 0.06)
	_set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.12, 0.13, fur)
	_set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.12, 0.13, fur)
	$BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh.scale = Vector3(0.9, 1.0, 0.7)
	$BodyPivot/HeadPivot/RightEarPivot/RightEarMesh.scale = Vector3(0.9, 1.0, 0.7)
	_child_sphere($BodyPivot/HeadPivot/LeftEarPivot, 0.07, 0.08, "#F2A6AE", Vector3(0, 0.01, 0.05), Vector3(0.8, 1.0, 0.6))
	_child_sphere($BodyPivot/HeadPivot/RightEarPivot, 0.07, 0.08, "#F2A6AE", Vector3(0, 0.01, 0.05), Vector3(0.8, 1.0, 0.6))

	# ── 주둥이(밝은 털) : 얼굴 아래쪽 둥근 입주변 ──
	var muzzle = MeshInstance3D.new()
	_set_sphere_mi(muzzle, 0.16, 0.15, _shade(fur, 0.22))
	muzzle.position = Vector3(0, -0.07, 0.26)
	muzzle.scale = Vector3(1.25, 0.85, 0.8)
	$BodyPivot/HeadPivot.add_child(muzzle)

	# ── 눈 : 작은 검은 눈 + 작은 하이라이트(흰자 없음) ──
	_set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.058, 0.07, "#2A211C")
	_set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.058, 0.07, "#2A211C")
	$BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.14, 0.07, 0.295)
	$BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.14, 0.07, 0.295)
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

# ── 장비 착용 표시 ────────────────────────────────────
## 슬롯마다 장비 메시를 붙일 빈 자리를 만든다. 위치는 쿼카 몸 비율에 맞춰 고정.
## 손·발은 좌우 두 곳이라 자리도 두 개씩 만든다.
func _setup_equipment_roots() -> void:
	_equip_roots = {
		"scarf": [_make_equip_root($BodyPivot, Vector3(0, 0.24, 0))],
		"hat": [_make_equip_root($BodyPivot/HeadPivot, Vector3(0, 0.13, 0))],
		"gloves": [
			_make_equip_root($BodyPivot/LeftArmPivot, Vector3(0, -0.24, 0.01)),
			_make_equip_root($BodyPivot/RightArmPivot, Vector3(0, -0.24, 0.01)),
		],
		"shoes": [
			_make_equip_root($BodyPivot/LeftLegPivot, Vector3(0, -0.16, 0.05)),
			_make_equip_root($BodyPivot/RightLegPivot, Vector3(0, -0.16, 0.05)),
		],
	}
	# 꼬리는 메시 자체가 흔들리므로 그 자식으로 붙여야 장식도 같이 흔들린다.
	# (_Tail 은 _build_meshes() 가 만든다 — 타입이 Node 로 굳지 않게 var 로 받는다)
	var tail_node = get_node_or_null("BodyPivot/_Tail")
	if tail_node != null:
		var tail_root := _make_equip_root(tail_node, Vector3(0, 0.01, 0.05))
		# 꼬리 메시가 (0.8, 0.8, 1.0)으로 눌려 있어 그만큼 되돌려준다
		tail_root.scale = Vector3(1.25, 1.25, 1.0)
		_equip_roots["tail"] = [tail_root]

func _make_equip_root(parent: Node3D, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

## PlayerStats.equipment 를 보고 실제 메시를 다시 만든다 (장비 변경 시마다 호출)
func _refresh_equipment() -> void:
	if _equip_roots.is_empty():
		return
	for slot in _equip_roots:
		var item_id = String(PlayerStats.equipment.get(slot, ""))
		for root in _equip_roots[slot]:
			for c in root.get_children():
				root.remove_child(c)
				c.queue_free()
			_build_worn(root, item_id)

func _build_worn(root: Node3D, item_id: String) -> void:
	if item_id == "":
		return
	var item = ItemDB.get_item(item_id)
	if item.is_empty():
		return
	var wear = item.get("wear", {})
	var col = Color(String(wear.get("color", "#E0645A")))
	var accent = Color(String(wear.get("accent", "#FFF6E4")))
	var style = String(wear.get("style", ""))
	match String(item.get("slot", "")):
		"scarf":
			_build_worn_scarf(root, col, accent, style)
		"hat":
			_build_worn_hat(root, col, accent, style)
		"gloves":
			_build_worn_gloves(root, col, accent, style)
		"shoes":
			_build_worn_shoes(root, col, accent, style)
		"tail":
			_build_worn_tail(root, col, accent, style)

func _build_worn_scarf(root: Node3D, col: Color, accent: Color, style: String) -> void:
	# 목에 두르는 링
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.23
	ring.mesh = tm
	ring.material_override = _wear_mat(col)
	root.add_child(ring)
	# 앞으로 늘어뜨린 자락
	var tail = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.11, 0.26, 0.06)
	tail.mesh = bm
	tail.material_override = _wear_mat(col)
	tail.position = Vector3(0.07, -0.14, 0.25)
	tail.rotation_degrees = Vector3(10, 0, -6)
	root.add_child(tail)
	if style == "muffler":
		# 양쪽으로 길게 늘어뜨린 자락 (같이 두르는 목도리)
		for i in range(2):
			var side_tail = MeshInstance3D.new()
			var stm = BoxMesh.new()
			stm.size = Vector3(0.10, 0.34, 0.06)
			side_tail.mesh = stm
			side_tail.material_override = _wear_mat(col)
			var sx = 0.16 if i == 0 else -0.16
			side_tail.position = Vector3(sx, -0.18, 0.18)
			side_tail.rotation_degrees = Vector3(8, 0, -6.0 if i == 0 else 6.0)
			root.add_child(side_tail)
			# 자락 끝 술
			var fringe = MeshInstance3D.new()
			var fm = BoxMesh.new()
			fm.size = Vector3(0.11, 0.05, 0.07)
			fringe.mesh = fm
			fringe.material_override = _wear_mat(accent)
			fringe.position = Vector3(sx, -0.34, 0.19)
			root.add_child(fringe)
	elif style == "star":
		# 링 위에 박힌 작은 별빛
		for i in range(4):
			var star = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.03
			sm.height = 0.06
			star.mesh = sm
			star.material_override = _wear_mat(accent)
			var a = TAU * float(i) / 4.0 + 0.4
			star.position = Vector3(cos(a) * 0.19, 0.02, sin(a) * 0.19)
			root.add_child(star)
	else:
		# 자락에 들어간 줄무늬
		for i in range(2):
			var stripe = MeshInstance3D.new()
			var sbm = BoxMesh.new()
			sbm.size = Vector3(0.12, 0.04, 0.05)
			stripe.mesh = sbm
			stripe.material_override = _wear_mat(accent)
			stripe.position = Vector3(0.07, -0.09 - float(i) * 0.1, 0.27)
			root.add_child(stripe)

func _build_worn_hat(root: Node3D, col: Color, accent: Color, style: String) -> void:
	var crown = MeshInstance3D.new()
	var cm = SphereMesh.new()
	cm.radius = 0.27
	cm.height = 0.26
	crown.mesh = cm
	crown.material_override = _wear_mat(col)
	crown.scale = Vector3(1.0, 0.85, 1.0)
	root.add_child(crown)
	# 아래 테두리
	var band = MeshInstance3D.new()
	var bandm = CylinderMesh.new()
	bandm.top_radius = 0.30
	bandm.bottom_radius = 0.33
	bandm.height = 0.07
	band.mesh = bandm
	band.material_override = _wear_mat(accent)
	band.position = Vector3(0, -0.06, 0)
	root.add_child(band)
	if style == "straw":
		# 사방으로 넓게 퍼진 챙 (밀짚모자)
		var wide = MeshInstance3D.new()
		var wm = CylinderMesh.new()
		wm.top_radius = 0.30
		wm.bottom_radius = 0.46
		wm.height = 0.035
		wide.mesh = wm
		wide.material_override = _wear_mat(col)
		wide.position = Vector3(0, -0.07, 0)
		root.add_child(wide)
		# 챙에 두른 띠
		var ribbon = MeshInstance3D.new()
		var rm = TorusMesh.new()
		rm.inner_radius = 0.28
		rm.outer_radius = 0.33
		ribbon.mesh = rm
		ribbon.material_override = _wear_mat(accent)
		ribbon.position = Vector3(0, -0.04, 0)
		root.add_child(ribbon)
	elif style == "cap":
		# 앞으로 뻗은 챙
		var brim = MeshInstance3D.new()
		var brimm = BoxMesh.new()
		brimm.size = Vector3(0.30, 0.03, 0.20)
		brim.mesh = brimm
		brim.material_override = _wear_mat(accent)
		brim.position = Vector3(0, -0.06, 0.30)
		brim.rotation_degrees = Vector3(-6, 0, 0)
		root.add_child(brim)
	else:
		# 방울
		var pom = MeshInstance3D.new()
		var pm = SphereMesh.new()
		pm.radius = 0.07
		pm.height = 0.14
		pom.mesh = pm
		pom.material_override = _wear_mat(accent)
		pom.position = Vector3(0, 0.16, 0)
		root.add_child(pom)

func _build_worn_gloves(root: Node3D, col: Color, accent: Color, style: String) -> void:
	# 손을 감싸는 덩어리 (원래 손보다 한 겹 크게)
	var mitt = MeshInstance3D.new()
	var mm = SphereMesh.new()
	mm.radius = 0.092
	mm.height = 0.184
	mitt.mesh = mm
	mitt.material_override = _wear_mat(col)
	if style == "glove" or style == "hold":
		# 장갑은 손 모양이 살아 있게 조금 갸름하게
		mitt.scale = Vector3(0.92, 1.05, 1.0)
	root.add_child(mitt)
	if style == "hold":
		# 손등에 올라간 작은 장식
		var stud = MeshInstance3D.new()
		var stm = SphereMesh.new()
		stm.radius = 0.035
		stm.height = 0.06
		stud.mesh = stm
		stud.material_override = _wear_mat(accent)
		stud.position = Vector3(0, 0.02, 0.075)
		root.add_child(stud)
	# 손목 테두리
	var cuff = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.088
	cm.bottom_radius = 0.098
	cm.height = 0.055
	cuff.mesh = cm
	cuff.material_override = _wear_mat(accent)
	cuff.position = Vector3(0, 0.085, 0)
	root.add_child(cuff)

func _build_worn_shoes(root: Node3D, col: Color, accent: Color, style: String) -> void:
	if style == "sandal":
		# 샌들은 발을 덮지 않는다 — 얇은 밑창 + 발등을 가로지르는 끈 두 개
		var plate = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(0.19, 0.03, 0.26)
		plate.mesh = pm
		plate.material_override = _wear_mat(col)
		plate.position = Vector3(0, -0.05, 0.02)
		root.add_child(plate)
		for i in range(2):
			var strap = MeshInstance3D.new()
			var stm = BoxMesh.new()
			stm.size = Vector3(0.2, 0.03, 0.045)
			strap.mesh = stm
			strap.material_override = _wear_mat(accent)
			strap.position = Vector3(0, 0.005 - float(i) * 0.02, -0.02 + float(i) * 0.12)
			strap.rotation_degrees = Vector3(12.0 * float(i), 0, 0)
			root.add_child(strap)
		return
	# 발등 (원래 발보다 한 겹 크게, 앞으로 길게)
	var shoe = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.098
	sm.height = 0.15
	shoe.mesh = sm
	shoe.material_override = _wear_mat(col)
	shoe.scale = Vector3(1.05, 0.8, 1.4)
	root.add_child(shoe)
	# 밑창
	var sole = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.2, 0.035, 0.27)
	sole.mesh = bm
	sole.material_override = _wear_mat(accent if style == "slipper" else Color("#3A3630"))
	sole.position = Vector3(0, -0.055, 0.02)
	root.add_child(sole)
	if style == "sneaker":
		# 발등 끈
		var lace = MeshInstance3D.new()
		var lm = BoxMesh.new()
		lm.size = Vector3(0.13, 0.02, 0.06)
		lace.mesh = lm
		lace.material_override = _wear_mat(accent)
		lace.position = Vector3(0, 0.052, 0.05)
		root.add_child(lace)

func _build_worn_tail(root: Node3D, col: Color, accent: Color, style: String) -> void:
	# 꼬리를 감싸는 띠 (토러스 구멍이 꼬리 방향(Z)을 향하도록 눕힌다)
	var band = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.055
	tm.outer_radius = 0.095
	band.mesh = tm
	band.material_override = _wear_mat(col)
	band.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(band)
	if style == "knot":
		# 매듭 — 겹쳐 묶은 두 덩이와 아래로 뻗은 짧은 끈
		for i in range(2):
			var lump = MeshInstance3D.new()
			var km = SphereMesh.new()
			km.radius = 0.05
			km.height = 0.085
			lump.mesh = km
			lump.material_override = _wear_mat(accent)
			var kx = 0.045 if i == 0 else -0.045
			lump.position = Vector3(kx, -0.02, -0.03)
			lump.scale = Vector3(1.0, 1.0, 0.8)
			root.add_child(lump)
		var cord = MeshInstance3D.new()
		var cm2 = BoxMesh.new()
		cm2.size = Vector3(0.03, 0.12, 0.03)
		cord.mesh = cm2
		cord.material_override = _wear_mat(accent)
		cord.position = Vector3(0, -0.1, -0.03)
		root.add_child(cord)
	elif style == "charm":
		# 별 장식 — 작은 구 하나에 십자 막대를 얹어 반짝임을 만든다
		var core = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		core.mesh = sm
		core.material_override = _wear_mat(accent)
		core.position = Vector3(0, -0.12, -0.02)
		root.add_child(core)
		for i in range(2):
			var spike = MeshInstance3D.new()
			var sbm = BoxMesh.new()
			sbm.size = Vector3(0.14, 0.025, 0.025)
			spike.mesh = sbm
			spike.material_override = _wear_mat(accent)
			spike.position = Vector3(0, -0.12, -0.02)
			spike.rotation_degrees = Vector3(0, 0, 45.0 + 90.0 * float(i))
			root.add_child(spike)
	else:
		# 리본 — 양옆으로 뻗은 고리 두 개와 가운데 매듭
		for i in range(2):
			var loop = MeshInstance3D.new()
			var lm = SphereMesh.new()
			lm.radius = 0.055
			lm.height = 0.09
			loop.mesh = lm
			loop.material_override = _wear_mat(accent)
			var side = 0.09 if i == 0 else -0.09
			loop.position = Vector3(side, 0.02, -0.02)
			loop.scale = Vector3(1.3, 0.7, 0.6)
			root.add_child(loop)
		var knot = MeshInstance3D.new()
		var km = SphereMesh.new()
		km.radius = 0.038
		km.height = 0.07
		knot.mesh = km
		knot.material_override = _wear_mat(accent)
		knot.position = Vector3(0, 0.02, -0.02)
		root.add_child(knot)

func _wear_mat(col: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	return mat

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

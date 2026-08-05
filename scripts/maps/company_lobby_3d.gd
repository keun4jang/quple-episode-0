extends Node3D
## 쿼카전자 로비. 조용하고 차갑지만 무섭지는 않게.

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 6.4, 8.6)
const CAM_LOOK_OFFSET = Vector3(0, 1.6, -2.2)
const CAM_LERP = 5.0

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	AudioManager.play_bgm("episode0")
	$ToOfficeInteract.interacted.connect(_go_office)
	$ToFrontInteract.interacted.connect(_go_front)
	$BadgeBoxInteract.interacted.connect(_return_badge)
	PartnerSpawner.ensure(self, player)
	if Episode0State.current_state == Episode0State.State.ENTER_COMPANY:
		Episode0State.advance_to(Episode0State.State.FIND_PARTNER)
		await get_tree().create_timer(0.5).timeout
		dialogue_box.show_text("조용한 로비. 위층에만 불이 켜져 있어요.")

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)

func _go_office() -> void:
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn")

func _go_front() -> void:
	SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

func _return_badge() -> void:
	if Episode0State.current_state < Episode0State.State.RETURN_BADGE:
		dialogue_box.show_text("사원증 반납함이에요. 아직은 반납할 때가 아니에요.")
		return
	if Episode0State.badge_returned:
		dialogue_box.show_text("사원증은 이미 반납했어요.")
		return
	Episode0State.badge_returned = true
	dialogue_box.show_text("사원증을 반납했어요. 이제 정말 나가는 거예요.")
	Episode0State.partner_joined = true
	Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
	PartnerSpawner.ensure(self, player)

func _build_scene() -> void:
	# 바닥 / 벽 / 천장
	_box(self, Vector3(0, -0.05, 0), Vector3(20, 0.1, 20), "#3F4550", "Floor")
	_box(self, Vector3(0, 0.005, 0), Vector3(11, 0.02, 12), "#59616E", "FloorInner")
	_box(self, Vector3(0, 2.6, -7.0), Vector3(20, 5.4, 0.3), "#2D3A4A", "BackWall")
	_box(self, Vector3(-7.5, 2.6, 0), Vector3(0.3, 5.4, 14), "#2D3A4A", "LeftWall")
	_box(self, Vector3(7.5, 2.6, 0), Vector3(0.3, 5.4, 14), "#2D3A4A", "RightWall")

	# 안내 데스크
	_box(self, Vector3(-2.6, 0.55, -3.4), Vector3(3.4, 1.1, 0.9), "#43566A", "Desk")
	_box(self, Vector3(-2.6, 1.14, -3.4), Vector3(3.6, 0.08, 1.05), "#7F8790", "DeskTop")
	# 데스크 작은 램프 (따뜻한 점광)
	_cylinder(self, Vector3(-1.5, 1.28, -3.3), 0.05, 0.2, "#8A9099", "LampStem")
	var shade := _cylinder(self, Vector3(-1.5, 1.46, -3.3), 0.13, 0.16, "#FFD76D", "LampShade")
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#FFD76D")
	lm.emission_enabled = true
	lm.emission = Color("#FFE7A8")
	lm.emission_energy_multiplier = 2.0
	shade.material_override = lm
	var lamp_light := OmniLight3D.new()
	lamp_light.light_color = Color("#FFD76D")
	lamp_light.light_energy = 1.1
	lamp_light.omni_range = 4.0
	lamp_light.position = Vector3(-1.5, 1.5, -3.3)
	add_child(lamp_light)

	# 출입 게이트 2개
	for gx in [-1.1, 1.1]:
		_box(self, Vector3(gx, 0.5, -1.0), Vector3(0.35, 1.0, 1.5), "#43566A", "Gate")
		_box(self, Vector3(gx, 1.02, -1.0), Vector3(0.4, 0.06, 1.6), "#7F8790", "GateTop")

	# 엘리베이터 문 (사무실로 가는 길)
	_box(self, Vector3(2.8, 1.5, -6.75), Vector3(2.2, 3.0, 0.14), "#1E2733", "ElevFrame")
	_box(self, Vector3(2.24, 1.45, -6.66), Vector3(1.0, 2.8, 0.06), "#43566A", "ElevDoorL")
	_box(self, Vector3(3.36, 1.45, -6.66), Vector3(1.0, 2.8, 0.06), "#43566A", "ElevDoorR")
	_box(self, Vector3(2.8, 3.15, -6.66), Vector3(0.5, 0.16, 0.05), "#FFD76D", "ElevSign")

	# 정문 (밖으로) — 왼쪽 벽에 두어 카메라 시야를 막지 않게 한다
	_box(self, Vector3(-7.35, 1.3, 3.2), Vector3(0.16, 2.6, 2.4), "#182533", "FrontDoor")
	_box(self, Vector3(-7.24, 1.3, 3.2), Vector3(0.05, 2.3, 2.1), "#3E6278", "FrontGlass")
	_box(self, Vector3(-7.24, 2.85, 3.2), Vector3(0.05, 0.22, 1.0), "#FFD76D", "ExitSign")

	# 사원증 반납함
	_box(self, Vector3(4.9, 0.55, -2.2), Vector3(0.7, 1.1, 0.5), "#43566A", "BadgeBoxBody")
	_box(self, Vector3(4.9, 1.13, -2.2), Vector3(0.75, 0.07, 0.55), "#7F8790", "BadgeBoxTop")
	_box(self, Vector3(4.9, 0.95, -1.96), Vector3(0.42, 0.05, 0.03), "#17283A", "BadgeSlot")

	# 벽시계 (22:47 느낌)
	_cylinder(self, Vector3(0, 3.6, -6.8), 0.42, 0.08, "#F2EEE2", "ClockFace")
	_box(self, Vector3(-0.10, 3.68, -6.72), Vector3(0.22, 0.035, 0.02), "#2D3A4A", "ClockHourHand")
	_box(self, Vector3(0.03, 3.50, -6.72), Vector3(0.035, 0.30, 0.02), "#2D3A4A", "ClockMinHand")

	# 화분 / 안내 표지판
	for px in [-6.2, 6.2]:
		_cylinder(self, Vector3(px, 0.28, -5.2), 0.32, 0.55, "#6D7D8F", "PlanterPot")
		_sphere(self, Vector3(px, 0.85, -5.2), 0.45, "#6FA98A", "PlanterLeaf")
	_cylinder(self, Vector3(-5.4, 0.8, 1.2), 0.04, 1.6, "#8A9099", "SignPole")
	_box(self, Vector3(-5.4, 1.68, 1.2), Vector3(0.6, 0.4, 0.05), "#43566A", "SignBoard")

	# 은은한 천장 조명
	for lz in [-4.0, 0.0, 4.0]:
		var cl := OmniLight3D.new()
		cl.light_color = Color("#B9A7E8")
		cl.light_energy = 0.55
		cl.omni_range = 9.0
		cl.position = Vector3(0, 4.2, lz)
		add_child(cl)

# ── 헬퍼 ──
func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, label: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new(); m.top_radius = radius; m.bottom_radius = radius; m.height = height
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, hex: String, label: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radius = radius; m.height = radius * 2.0
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

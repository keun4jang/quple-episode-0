extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var warm_window_light: OmniLight3D = $WarmWindowLight
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 6.0, 12.8)   # 건물과 플레이어가 함께 보이는 디오라마 거리
const CAM_LERP = 5.0
const CAM_LOOK_OFFSET = Vector3(0, 4.0, -3.6)  # 시선을 건물 쪽 위로

var _light_time: float = 0.0
var _lit_window: MeshInstance3D = null

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	$EntranceInteract.interacted.connect(_enter_company)
	if Episode0State.current_state == Episode0State.State.START:
		_show_opening()
	elif Episode0State.current_state == Episode0State.State.PARTNER_JOINED:
		Episode0State.advance_to(Episode0State.State.FIRST_PHOTO)

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)
	# 켜진 창문: 2.5초 주기로 아주 약하게 숨 쉬듯
	_light_time += delta
	var breathe := sin(_light_time * TAU / 2.5)
	warm_window_light.light_energy = 1.0 + breathe * 0.06
	if _lit_window and _lit_window.material_override:
		_lit_window.material_override.emission_energy_multiplier = 2.2 + breathe * 0.25

func _show_opening() -> void:
	await get_tree().create_timer(0.8).timeout
	dialogue_box.show_text("늦은 밤, 쿼카전자에는 딱 하나의 불빛만 남아 있어요.")
	Episode0State.advance_to(Episode0State.State.ENTER_COMPANY)

func _build_scene() -> void:
	# 도로, 인도, 횡단보도
	# 바닥 베이스(가장자리 잘림 방지)
	_box(self, Vector3(0, -0.12, 0), Vector3(60, 0.1, 60), "#2F3242", "GroundBase")
	_box(self, Vector3(0, -0.04, 6), Vector3(60, 0.08, 16), "#3B3E46", "Road")
	_box(self, Vector3(0, 0, -1), Vector3(60, 0.1, 6), "#7F8790", "Sidewalk")
	for i in range(-2, 3):
		_box(self, Vector3(i * 0.9, 0.01, 3.5), Vector3(0.45, 0.01, 2.5), "#F2EEE2", "Crosswalk%d" % i)
	# 건물 본체 및 창문
	_box(self, Vector3(0, 9, -6), Vector3(10, 18, 2), "#2D3A4A", "Building")
	_box(self, Vector3(-5.1, 9, -6), Vector3(0.2, 18, 2.5), "#1E2733", "BuildingLeft")
	_box(self, Vector3(5.1, 9, -6), Vector3(0.2, 18, 2.5), "#1E2733", "BuildingRight")
	# 창문 6칸 x 11줄. 단 하나만 따뜻하게 켜져 있다 (중간보다 위쪽)
	for row in range(11):
		for col in range(6):
			var wx = -4.25 + col * 1.7
			var wy = 2.2 + row * 1.4
			var is_lit = (row == 6 and col == 3)
			var color = "#FFD76D" if is_lit else "#17283A"
			var win = _box(self, Vector3(wx, wy, -4.95), Vector3(0.95, 0.75, 0.05), color, "Win_%d_%d" % [row, col])
			if is_lit:
				var lm = StandardMaterial3D.new()
				lm.albedo_color = Color("#FFE7A8")
				lm.emission_enabled = true
				lm.emission = Color("#FFD76D")
				lm.emission_energy_multiplier = 2.2
				win.material_override = lm
				_lit_window = win
				# 켜진 창문 바로 앞에 따뜻한 빛
				warm_window_light.position = Vector3(wx, wy, -4.3)
	# 간판, 출입문
	_box(self, Vector3(0, 18.5, -5.1), Vector3(5, 0.6, 0.3), "#FFD76D", "SignBG")
	_box(self, Vector3(0, 1.2, -5.0), Vector3(2.2, 2.4, 0.15), "#182533", "EntranceDoor")
	_box(self, Vector3(0, 1.2, -4.84), Vector3(2.0, 2.2, 0.05), "#3E6278", "DoorGlass")
	# 가로등, 볼라드, 벤치, 화분, 나무
	_lamppost(self, Vector3(-6, 0, -2))
	_lamppost(self, Vector3(6, 0, -2))
	for bx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_box(self, Vector3(bx, 0.2, 0.8), Vector3(0.18, 0.4, 0.18), "#6D7D8F", "Bollard")
	_bench(self, Vector3(-7, 0, -0.5))
	_planter(self, Vector3(3.5, 0, -2))
	_planter(self, Vector3(-3.5, 0, -2))
	_tree(self, Vector3(-8, 0, 0))
	_tree(self, Vector3(8, 0, 0))
	# 거리 소품 추가
	_add_street_details()

func _add_street_details() -> void:
	# 쓰레기통 2개 (원기둥 형태)
	_cylinder(self, Vector3(-2.5, 0.28, 0.5), 0.18, 0.55, "#4A4A52", "Trashcan1")
	_cylinder(self, Vector3(3.2, 0.28, -0.8), 0.18, 0.55, "#4A4A52", "Trashcan2")

	# 자전거 거치대 (가로 바 + 세로 기둥 2개)
	_box(self, Vector3(-4.0, 0.35, 0.2), Vector3(1.2, 0.08, 0.12), "#888890", "BikeRackBar")
	_box(self, Vector3(-4.0 - 0.55, 0.35, 0.2), Vector3(0.08, 0.7, 0.08), "#888890", "BikeRackPostL")
	_box(self, Vector3(-4.0 + 0.55, 0.35, 0.2), Vector3(0.08, 0.7, 0.08), "#888890", "BikeRackPostR")

	# 버스 정류장 표지판 (폴 + 표지판)
	_cylinder(self, Vector3(5.0, 0.9, 0.2), 0.04, 1.8, "#C8C8D0", "BusStopPole")
	_box(self, Vector3(5.0, 1.95, 0.2), Vector3(0.4, 0.3, 0.06), "#4A7ACC", "BusStopSign")

	# 바닥 물웅덩이 반사 (얇은 원반, 반투명)
	var puddle_data = [
		[Vector3(-1.5, 0.002, 2.5), 0.6],
		[Vector3(2.8, 0.002, 3.2), 0.45],
		[Vector3(-3.5, 0.002, 3.8), 0.75],
		[Vector3(1.0, 0.002, 1.8), 0.4],
	]
	for i in range(puddle_data.size()):
		var pd = puddle_data[i]
		var mi = _cylinder(self, pd[0], pd[1], 0.005, "#7AB8D0", "Puddle%d" % i)
		# 물 반사 느낌: 낮은 roughness, 약간의 metallic
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.478, 0.722, 0.816, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mat.metallic = 0.2
		mi.material_override = mat

	# 신호등 (기둥 + 함체 + 빨강/노랑/초록)
	_cylinder(self, Vector3(-6.8, 1.3, 1.4), 0.05, 2.6, "#4A5058", "TrafficPole")
	_box(self, Vector3(-6.8, 2.75, 1.4), Vector3(0.28, 0.72, 0.22), "#2C3138", "TrafficBox")
	var tl_colors = ["#E8544A", "#FFD76D", "#6FCF7F"]
	for ti in range(3):
		var lamp = _sphere_mi(self, Vector3(-6.8, 3.0 - ti * 0.22, 1.29), 0.07, tl_colors[ti], "TrafficLamp%d" % ti)
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color(tl_colors[ti])
		tm.emission_enabled = true
		tm.emission = Color(tl_colors[ti])
		tm.emission_energy_multiplier = 1.6 if ti == 2 else 0.25
		lamp.material_override = tm

	# CCTV 처럼 보이는 작은 박스 (건물 입구 위)
	_box(self, Vector3(-1.6, 3.05, -4.8), Vector3(0.1, 0.1, 0.26), "#3A4048", "CctvBody")
	_box(self, Vector3(-1.6, 3.22, -4.72), Vector3(0.06, 0.16, 0.06), "#3A4048", "CctvMount")

	# 안내 표지판 (기둥 + 판)
	_cylinder(self, Vector3(2.2, 0.7, 0.9), 0.04, 1.4, "#8A9099", "InfoPole")
	_box(self, Vector3(2.2, 1.5, 0.9), Vector3(0.62, 0.42, 0.05), "#43566A", "InfoSign")
	_box(self, Vector3(2.2, 1.58, 0.86), Vector3(0.46, 0.06, 0.02), "#F2EEE2", "InfoLine1")
	_box(self, Vector3(2.2, 1.44, 0.86), Vector3(0.34, 0.05, 0.02), "#F2EEE2", "InfoLine2")

	# 네온사인 "QUOKKA CORP" (건물 파사드 상단에 발광 박스)
	var neon_mi = MeshInstance3D.new()
	neon_mi.name = "NeonSign"
	var neon_mesh = BoxMesh.new()
	neon_mesh.size = Vector3(2.2, 0.35, 0.08)
	neon_mi.mesh = neon_mesh
	var neon_mat = StandardMaterial3D.new()
	neon_mat.albedo_color = Color("#88DDFF")
	neon_mat.emission_enabled = true
	neon_mat.emission = Color("#88DDFF")
	neon_mat.emission_energy_multiplier = 2.5
	neon_mat.roughness = 0.3
	neon_mi.material_override = neon_mat
	neon_mi.position = Vector3(0, 3.5, -4.9)
	self.add_child(neon_mi)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, label: String = "") -> MeshInstance3D:
	# 원기둥 메시 헬퍼
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func _lamppost(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 2.5, 0), Vector3(0.12, 5.0, 0.12), "#4A5568", "Post")
	_box(parent, pos + Vector3(0, 5.1, 0), Vector3(0.5, 0.12, 0.12), "#4A5568", "Arm")
	var light = OmniLight3D.new()
	light.position = pos + Vector3(0, 5.2, 0)
	light.light_color = Color("#FFE7A8")
	light.light_energy = 0.8
	light.omni_range = 4.0
	parent.add_child(light)

func _bench(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.2, 0), Vector3(1.4, 0.1, 0.4), "#7F8790", "BenchSeat")
	_box(parent, pos + Vector3(-0.6, 0.1, 0), Vector3(0.08, 0.2, 0.4), "#6D7D8F", "BenchLegL")
	_box(parent, pos + Vector3(0.6, 0.1, 0), Vector3(0.08, 0.2, 0.4), "#6D7D8F", "BenchLegR")

func _planter(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), "#6D7D8F", "PlanterBox")
	_sphere_mi(parent, pos + Vector3(0, 0.55, 0), 0.22, "#72B48D", "Plant")

func _tree(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.6, 0), Vector3(0.2, 1.2, 0.2), "#5B3A29", "Trunk")
	_sphere_mi(parent, pos + Vector3(0, 1.5, 0), 0.7, "#72B48D", "Canopy")

func _sphere_mi(parent: Node3D, pos: Vector3, radius: float, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 2; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func _enter_company() -> void:
	SceneTransition.go_to("res://scenes/maps/CompanyLobby3D.tscn")

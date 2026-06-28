extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var quokka_pivot: Node3D = $QuokkaPivot
var _t := 0.0
var _globe: Node3D = null
var _floaters: Array = []       # [ {node, radius, speed, phase, y} ]
var _star_meshes: Array = []    # 밝은 별 목록 (반짝임 애니메이션용)
var _star_phases: Array = []    # 각 별의 위상 값

const GLOBE_CENTER := Vector3(0, -1.4, 0)
const GLOBE_R := 2.0

func _ready() -> void:
	_build_scene()
	var cont = $UILayer/Control/VBox/ContinueBtn
	cont.disabled = not FileAccess.file_exists("user://save.cfg")
	$UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
	cont.pressed.connect(_on_continue)
	$UILayer/Control/VBox/QuitBtn.pressed.connect(_on_quit)
	$UILayer/Control/VBox/SettingsBtn.pressed.connect(func(): var s = get_tree().get_first_node_in_group("settings_ui"); if s: s.open())
	if AudioManager:
		AudioManager.play_bgm("menu")

func _process(delta: float) -> void:
	_t += delta
	# 지구본 천천히 자전
	if _globe:
		_globe.rotate_y(delta * 0.25)
	# 커플은 지구본 위에서 살짝 둥실
	quokka_pivot.position.y = (GLOBE_CENTER.y + GLOBE_R + 0.05) + sin(_t * 1.4) * 0.06
	# 떠다니는 행성/로켓/달/혜성 공전
	for f in _floaters:
		var a = f.phase + _t * f.speed
		f.node.position = Vector3(cos(a) * f.radius, f.y + sin(a * 0.7) * 0.3, -3.0 + sin(a) * f.radius * 0.4)
		f.node.rotate_y(delta * 0.4)
	# 밝은 별 반짝임 애니메이션
	for i in range(_star_meshes.size()):
		var star_mi: MeshInstance3D = _star_meshes[i]
		var phase: float = _star_phases[i]
		if star_mi and is_instance_valid(star_mi):
			var mat = star_mi.material_override as StandardMaterial3D
			if mat:
				# 각 별마다 다른 주파수로 반짝임
				var freq = 1.5 + fmod(phase, 2.0)
				mat.emission_energy_multiplier = 3.0 + sin(_t * freq + phase) * 1.5

# ─────────────────────────────────────────────
func _on_start() -> void:
	Episode0State.current_state = Episode0State.State.START
	Episode0State.has_camera = false
	Episode0State.has_notebook = false
	Episode0State.has_travel_bag = false
	Episode0State.badge_returned = false
	Episode0State.partner_joined = false
	Episode0State.first_photo_taken = false
	Episode0State.album_created = false
	Episode0State.episode0_cleared = false
	Episode0State.memos_found = []
	SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn", "hopeful")

func _on_continue() -> void:
	SaveManager.load_game()
	var cfg = ConfigFile.new()
	cfg.load("user://save.cfg")
	var scene = cfg.get_value("game", "current_scene", "res://scenes/maps/CompanyFront3D.tscn")
	SceneTransition.go_to(scene, "normal")

func _on_quit() -> void:
	get_tree().quit()

# ─────────────────────────────────────────────
func _build_scene() -> void:
	# A) 은하 배경 별 (120개 이상, 세 그룹)
	_build_galaxy_stars()

	# B) 성운 구름 (반투명 대형 구체)
	_build_nebula_clouds()

	# ── 지구본 ──
	_globe = Node3D.new()
	_globe.position = GLOBE_CENTER
	add_child(_globe)

	# C) 바다 (지구 본체, 약간 반짝임)
	var ocean = MeshInstance3D.new()
	var om = SphereMesh.new(); om.radius = GLOBE_R; om.height = GLOBE_R * 2
	ocean.mesh = om
	var ocean_mat = StandardMaterial3D.new()
	ocean_mat.albedo_color = Color("#5ABCEE")
	ocean_mat.roughness = 0.4
	ocean_mat.metallic = 0.1
	ocean.material_override = ocean_mat
	_globe.add_child(ocean)

	# 대기권 고리 (토러스)
	var atmo = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 2.15
	tm.outer_radius = 2.5
	atmo.mesh = tm
	var atmo_mat = StandardMaterial3D.new()
	atmo_mat.albedo_color = Color(0.533, 0.8, 1.0, 0.25)
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo.material_override = atmo_mat
	atmo.rotation_degrees = Vector3(90, 0, 0)
	_globe.add_child(atmo)

	# 북극 빙하
	var ice = MeshInstance3D.new()
	var ism = SphereMesh.new(); ism.radius = 0.55; ism.height = 0.4
	ice.mesh = ism
	ice.material_override = _mat("#EEF4FF", 0.3)
	ice.position = Vector3(0, GLOBE_R - 0.1, 0)
	ice.scale = Vector3(1.0, 0.3, 1.0)
	_globe.add_child(ice)

	# 대륙 (납작한 초록 덩어리들)
	var land_spots := [
		Vector3(0.2, 0.95, 0.15), Vector3(-0.7, 0.5, 0.5),
		Vector3(0.7, 0.4, 0.5), Vector3(0.0, 0.2, -0.95),
		Vector3(-0.5, -0.3, 0.7), Vector3(0.5, -0.5, 0.6),
	]
	for s in land_spots:
		var land = MeshInstance3D.new()
		var lm = SphereMesh.new(); lm.radius = 0.7; lm.height = 0.5
		land.mesh = lm
		land.material_override = _mat("#8BD17C", 0.9)
		land.position = s.normalized() * (GLOBE_R - 0.05)
		land.look_at_from_position(land.position, Vector3.ZERO, Vector3.UP)
		land.scale = Vector3(1.0, 0.35, 1.0)
		_globe.add_child(land)

	# 랜드마크들 (지구본 윗면 둘레에 배치) — 자전과 함께 돈다
	_eiffel(_surf(Vector3(-0.9, 0.8, 0.2)))
	_tower(_surf(Vector3(0.95, 0.7, 0.1)))      # 남산타워 느낌
	_hanok(_surf(Vector3(0.4, 0.7, -0.7)))
	_pyramid(_surf(Vector3(-0.6, 0.55, -0.7)))
	_pisa(_surf(Vector3(-0.2, 0.6, 0.95)))
	_statue(_surf(Vector3(0.7, 0.55, 0.6)))

	# D) 떠다니는 행성/로켓/달/혜성
	_add_floater(_planet("#E8A766", true), 5.5, 0.18, 0.0, 2.5)    # 토성
	_add_floater(_planet("#B59CE0", false), 6.5, 0.13, 2.2, -1.5)  # 보라 행성
	_add_floater(_planet("#9FC6E8", false), 6.0, 0.16, 4.0, 1.0)   # 파랑 행성
	_add_floater(_rocket(), 4.8, 0.30, 1.0, 3.0)                   # 로켓
	# 추가: 작은 달
	_add_floater(_small_moon(), 7.2, 0.10, 3.5, 0.5)
	# 추가: 혜성
	_add_floater(_comet(), 5.0, 0.22, 5.0, 2.0)

	# 고정 달 (쿼카가 앉은 작은 달)
	var moon = _planet("#D8D8E2", false)
	moon.position = Vector3(3.6, 3.2, -4.0)
	moon.scale = Vector3(0.7, 0.7, 0.7)
	add_child(moon)

# A) 은하 배경 별 생성
func _build_galaxy_stars() -> void:
	var golden_angle = PI * (3.0 - sqrt(5.0))

	# 밝은 흰 별 (40개, 크고 밝음)
	for i in range(40):
		var ang = float(i) * golden_angle
		var t = float(i) / 39.0
		var spread = 7.0 + t * 4.0
		var pos = Vector3(
			cos(ang) * spread * (0.8 + fmod(float(i) * 0.13, 0.4)),
			-2.0 + fmod(float(i) * 0.31, 6.0),
			-5.0 - fmod(float(i) * 0.17, 7.0)
		)
		var r = randf_range(0.06, 0.10)
		var star_mi = _emit_sphere(self, pos, r, "#FFFFFF", 4.0)
		_star_meshes.append(star_mi)
		_star_phases.append(float(i) * 0.73)

	# 중간 파스텔 별 (50개)
	var pastel_colors = ["#FFD6E8", "#D6E8FF", "#E8D6FF", "#FFE8D6", "#D6FFE8"]
	for i in range(50):
		var ang = float(i) * golden_angle * 1.3
		var spread = 6.0 + fmod(float(i) * 0.23, 5.0)
		var pos = Vector3(
			cos(ang) * spread,
			-3.0 + fmod(float(i) * 0.47, 8.0),
			-6.0 - fmod(float(i) * 0.19, 6.0)
		)
		var r = randf_range(0.03, 0.055)
		var col = pastel_colors[i % pastel_colors.size()]
		_emit_sphere(self, pos, r, col, 2.5)

	# 멀리 있는 작은 별 (40개)
	for i in range(40):
		var ang = float(i) * golden_angle * 0.7
		var spread = 8.0 + fmod(float(i) * 0.37, 4.0)
		var pos = Vector3(
			cos(ang) * spread,
			-4.0 + fmod(float(i) * 0.53, 10.0),
			-9.0 - fmod(float(i) * 0.29, 3.0)
		)
		var r = randf_range(0.015, 0.025)
		_emit_sphere(self, pos, r, "#FFFFFF", 2.0)

# B) 성운 구름 (반투명 대형 구체)
func _build_nebula_clouds() -> void:
	var nebula_data = [
		{"pos": Vector3(-6.0, 1.0, -8.0), "r": 2.8, "col": Color(0.502, 0.376, 0.784, 0.10)},
		{"pos": Vector3(7.0, -1.0, -7.0), "r": 2.5, "col": Color(0.251, 0.502, 0.816, 0.12)},
		{"pos": Vector3(0.0, 3.0, -9.0),  "r": 3.0, "col": Color(0.753, 0.376, 0.502, 0.08)},
		{"pos": Vector3(-4.0, -2.0, -7.5), "r": 1.8, "col": Color(0.502, 0.376, 0.784, 0.13)},
		{"pos": Vector3(5.0, 2.5, -8.5),  "r": 2.2, "col": Color(0.376, 0.627, 0.878, 0.09)},
		{"pos": Vector3(-2.0, -3.0, -6.0), "r": 1.5, "col": Color(0.816, 0.502, 0.659, 0.15)},
	]
	for d in nebula_data:
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = d.r
		sm.height = d.r * 2.0
		mi.mesh = sm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = d.col
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.position = d.pos
		add_child(mi)

# 지구본 표면 위 위치(자전 노드 기준 로컬좌표) 반환
func _surf(dir: Vector3) -> Vector3:
	return dir.normalized() * (GLOBE_R - 0.02)

# ── 랜드마크 빌더 (지구본 자식 → 함께 회전) ──
func _place(node: Node3D, local_pos: Vector3) -> void:
	node.position = local_pos
	# 표면 바깥 방향으로 세우기
	var up = local_pos.normalized()
	var basis = Basis()
	var fwd = up.cross(Vector3.RIGHT)
	if fwd.length() < 0.01:
		fwd = up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	var right = up.cross(fwd).normalized()
	node.basis = Basis(right, up, fwd)
	_globe.add_child(node)

func _eiffel(pos: Vector3) -> void:
	var n = Node3D.new()
	_cone_to(n, Vector3(0, 0.18, 0), 0.20, 0.06, 0.55, "#C8A06A")
	_cone_to(n, Vector3(0, 0.56, 0), 0.07, 0.02, 0.38, "#C8A06A")
	_place(n, pos)

func _tower(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.28, 0), 0.045, 0.55, "#DCdce4")
	_ball(n, Vector3(0, 0.57, 0), 0.13, "#9FE0E0")
	_cyl(n, Vector3(0, 0.76, 0), 0.017, 0.27, "#DCDCE4")
	_place(n, pos)

func _hanok(pos: Vector3) -> void:
	var n = Node3D.new()
	_boxn(n, Vector3(0, 0.14, 0), Vector3(0.55, 0.27, 0.38), "#E6D2B5")
	_cone4(n, Vector3(0, 0.36, 0), 0.50, 0.0, 0.25, "#3A4654")  # 기와지붕
	_place(n, pos)

func _pyramid(pos: Vector3) -> void:
	var n = Node3D.new()
	_cone4(n, Vector3(0, 0.25, 0), 0.45, 0.0, 0.50, "#E0C27A")
	_place(n, pos)

func _pisa(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.30, 0), 0.11, 0.60, "#F0EAD8")
	n.rotation_degrees.z = 12
	_place(n, pos)

func _statue(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.14, 0), 0.09, 0.27, "#7FB89E")  # 받침/몸
	_ball(n, Vector3(0, 0.34, 0), 0.08, "#7FB89E")        # 머리
	_cone(n, Vector3(0, 0.48, 0), 0.11, 0.0, 0.16, "#7FB89E")  # 왕관 스파이크
	_place(n, pos)

# ── 떠다니는 오브젝트 ──
func _add_floater(node: Node3D, radius: float, speed: float, phase: float, y: float) -> void:
	add_child(node)
	_floaters.append({"node": node, "radius": radius, "speed": speed, "phase": phase, "y": y})

func _planet(hex: String, ring: bool) -> Node3D:
	var n = Node3D.new()
	_ball(n, Vector3.ZERO, 0.6, hex)
	if ring:
		var r = MeshInstance3D.new()
		var tm = TorusMesh.new(); tm.inner_radius = 0.8; tm.outer_radius = 1.1
		r.mesh = tm
		r.material_override = _mat("#F0D8A8", 0.7)
		r.rotation_degrees = Vector3(80, 0, 18)
		n.add_child(r)
	return n

func _small_moon() -> Node3D:
	# 작은 달 (분화구 있음)
	var n = Node3D.new()
	_ball(n, Vector3.ZERO, 0.38, "#C8C8D2")
	_ball(n, Vector3(0.18, 0.15, 0.28), 0.06, "#AAAABC")  # 분화구
	_ball(n, Vector3(-0.12, 0.22, 0.28), 0.04, "#AAAABC") # 분화구2
	return n

func _comet() -> Node3D:
	# 혜성 (핵 + 꼬리)
	var n = Node3D.new()
	_ball(n, Vector3.ZERO, 0.22, "#E8E4FF")
	# 꼬리 (납작한 원뿔형)
	var tail_mi = MeshInstance3D.new()
	var tail_cm = CylinderMesh.new()
	tail_cm.top_radius = 0.0
	tail_cm.bottom_radius = 0.18
	tail_cm.height = 0.8
	tail_mi.mesh = tail_cm
	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.8, 0.85, 1.0, 0.4)
	tail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail_mi.material_override = tail_mat
	tail_mi.position = Vector3(0, -0.5, 0)
	tail_mi.rotation_degrees = Vector3(0, 0, 0)
	n.add_child(tail_mi)
	return n

func _rocket() -> Node3D:
	var n = Node3D.new()
	_cyl(n, Vector3.ZERO, 0.12, 0.5, "#F4F4F8")
	_cone(n, Vector3(0, 0.32, 0), 0.12, 0.0, 0.22, "#FF8A7A")
	_cone(n, Vector3(0, -0.3, 0), 0.16, 0.05, 0.18, "#FFC36A")  # 화염
	n.rotation_degrees.z = 90
	return n

# G) 발광 구체를 만들어 parent에 추가하고 MeshInstance3D 반환
func _emit_sphere(parent: Node3D, pos: Vector3, r: float, hex: String, energy: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.emission_enabled = true
	mat.emission = Color(hex)
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

# ── 메시 헬퍼 ──
func _mat(hex: String, rough: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new(); m.albedo_color = Color(hex); m.roughness = rough
	return m

func _emit_mat(hex: String, energy: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new(); m.albedo_color = Color(hex)
	m.emission_enabled = true; m.emission = Color(hex); m.emission_energy_multiplier = energy
	return m

func _ball(parent: Node3D, pos: Vector3, r: float, hex: String) -> void:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = r; sm.height = r * 2; mi.mesh = sm
	mi.material_override = _mat(hex, 0.8); mi.position = pos; parent.add_child(mi)

func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, hex: String) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; mi.mesh = cm
	mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

func _cone(parent: Node3D, pos: Vector3, br: float, tr: float, h: float, hex: String) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new(); cm.top_radius = tr; cm.bottom_radius = br; cm.height = h; mi.mesh = cm
	mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

func _cone4(parent: Node3D, pos: Vector3, br: float, tr: float, h: float, hex: String) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new(); cm.top_radius = tr; cm.bottom_radius = br; cm.height = h
	cm.radial_segments = 4; mi.mesh = cm
	mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

func _cone_to(parent: Node3D, pos: Vector3, br: float, tr: float, h: float, hex: String) -> void:
	_cone(parent, pos, br, tr, h, hex)

func _boxn(parent: Node3D, pos: Vector3, size: Vector3, hex: String) -> void:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

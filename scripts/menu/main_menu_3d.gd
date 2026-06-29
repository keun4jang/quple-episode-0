extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var quokka_pivot: Node3D = $QuokkaPivot
var _t := 0.0
var _globe: Node3D = null
var _floaters: Array = []       # [ {node, radius, speed, phase, y} ]
var _star_meshes: Array = []    # 밝은 별 목록 (반짝임 애니메이션용)
var _star_phases: Array = []    # 각 별의 위상 값
var _logo_pulse_t: float = 0.0

const GLOBE_CENTER := Vector3(0, -1.2, 0)
const GLOBE_R := 2.2

func _ready() -> void:
	_build_scene()
	var cont = $UILayer/Control/VBox/ContinueBtn
	cont.disabled = not FileAccess.file_exists("user://save.cfg")
	$UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
	cont.pressed.connect(_on_continue)
	$UILayer/Control/SmallBtnRow/QuitBtn.pressed.connect(_on_quit)
	$UILayer/Control/SmallBtnRow/SettingsBtn.pressed.connect(func(): var sv = get_tree().get_first_node_in_group("settings_ui"); if sv: sv.open())
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_bgm("menu")

func _process(delta: float) -> void:
	_t += delta
	_logo_pulse_t += delta

	# 지구본 천천히 자전
	if _globe:
		_globe.rotate_y(delta * 0.22)

	# 커플은 지구본 위에서 살짝 둥실
	quokka_pivot.position.y = (GLOBE_CENTER.y + GLOBE_R + 0.05) + sin(_t * 1.4) * 0.07

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
				mat.emission_energy_multiplier = 3.5 + sin(_t * _star_phases[i] + i) * 2.0

	# 로고 펄스 (알파 0.95~1.0)
	var logo = get_node_or_null("UILayer/Control/Logo")
	if logo:
		var alpha = 0.975 + sin(_logo_pulse_t * 1.8) * 0.025
		logo.modulate.a = alpha

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
	SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

func _on_continue() -> void:
	SaveManager.load_game()
	var cfg = ConfigFile.new()
	cfg.load("user://save.cfg")
	var scene = cfg.get_value("game", "current_scene", "res://scenes/maps/CompanyFront3D.tscn")
	SceneTransition.go_to(scene)

func _on_quit() -> void:
	get_tree().quit()

# ─────────────────────────────────────────────
func _build_scene() -> void:
	_build_stars()
	_build_nebula()
	_build_globe()
	_build_landmarks()
	_build_floaters()

	# 고정 달 (쿼카가 앉은 작은 달)
	var moon = _planet("#D8D8E2", false)
	moon.position = Vector3(3.6, 3.2, -4.0)
	moon.scale = Vector3(0.7, 0.7, 0.7)
	add_child(moon)

# ── A) 은하 배경 별 생성 (150개, 3티어) ──
func _build_stars() -> void:
	var golden_angle = 2.399963  # golden angle in radians

	# Tier 1: 밝은 흰 별 (50개)
	for i in range(50):
		var ang = float(i) * golden_angle
		var spread = 7.0 + fmod(float(i) * 0.23, 5.0)
		var pos = Vector3(
			cos(ang) * spread * (0.8 + fmod(float(i) * 0.13, 0.4)),
			-4.0 + fmod(float(i) * 0.31, 8.0),
			-5.0 - fmod(float(i) * 0.17, 9.0)
		)
		var r = 0.07 + fmod(float(i) * 0.004, 0.05)
		var energy = 5.0 + fmod(float(i) * 0.06, 3.0)
		var star_mi = _emit_sphere(self, pos, r, "#FFFFFF", energy)
		_star_meshes.append(star_mi)
		_star_phases.append(1.2 + fmod(float(i) * 0.73, 2.3))

	# Tier 2: 중간 파스텔 별 (60개)
	var pastel_colors = ["#FFD6E8", "#C8D6FF", "#E8D6FF", "#FFE8C8", "#D6FFE8"]
	for i in range(60):
		var ang = float(i) * golden_angle * 1.3
		var spread = 6.0 + fmod(float(i) * 0.23, 5.0)
		var pos = Vector3(
			cos(ang) * spread,
			-3.0 + fmod(float(i) * 0.47, 8.0),
			-6.0 - fmod(float(i) * 0.19, 8.0)
		)
		var r = 0.03 + fmod(float(i) * 0.0005, 0.03)
		var col = pastel_colors[i % pastel_colors.size()]
		var energy = 2.5 + fmod(float(i) * 0.033, 2.0)
		var star_mi = _emit_sphere(self, pos, r, col, energy)
		_star_meshes.append(star_mi)
		_star_phases.append(0.8 + fmod(float(i) * 0.61, 2.7))

	# Tier 3: 멀리 있는 작은 별 (40개)
	for i in range(40):
		var ang = float(i) * golden_angle * 0.7
		var spread = 8.0 + fmod(float(i) * 0.37, 4.0)
		var pos = Vector3(
			cos(ang) * spread,
			-4.0 + fmod(float(i) * 0.53, 10.0),
			-14.0 - fmod(float(i) * 0.29, 6.0)
		)
		var r = 0.015 + fmod(float(i) * 0.00025, 0.01)
		_emit_sphere(self, pos, r, "#FFFFFF", 2.0 + fmod(float(i) * 0.025, 1.0))

# ── B) 성운 구름 ──
func _build_nebula() -> void:
	var nebula_data = [
		{"pos": Vector3(-6.0, 1.0, -8.0),  "r": 3.0, "col": Color(0.45, 0.28, 0.78, 0.07)},
		{"pos": Vector3(7.0, -1.0, -7.0),  "r": 2.8, "col": Color(0.22, 0.45, 0.88, 0.06)},
		{"pos": Vector3(0.0, 3.0, -10.0),  "r": 3.5, "col": Color(0.78, 0.35, 0.55, 0.065)},
		{"pos": Vector3(-4.0, -2.0, -9.0), "r": 2.5, "col": Color(0.15, 0.25, 0.65, 0.05)},
		{"pos": Vector3(5.0, 2.5, -11.0),  "r": 3.0, "col": Color(0.25, 0.65, 0.78, 0.055)},
		{"pos": Vector3(-2.0, -3.0, -7.0), "r": 2.0, "col": Color(0.88, 0.55, 0.25, 0.04)},
		{"pos": Vector3(3.0, 4.0, -12.0),  "r": 3.5, "col": Color(0.45, 0.28, 0.78, 0.05)},
		{"pos": Vector3(-8.0, 0.5, -9.0),  "r": 2.2, "col": Color(0.22, 0.45, 0.88, 0.045)},
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
		mat.no_depth_test = true
		mi.material_override = mat
		mi.position = d.pos
		add_child(mi)

# ── C) 지구본 ──
func _build_globe() -> void:
	_globe = Node3D.new()
	_globe.position = GLOBE_CENTER
	add_child(_globe)

	# 바다 (지구 본체)
	var ocean = MeshInstance3D.new()
	var om = SphereMesh.new(); om.radius = GLOBE_R; om.height = GLOBE_R * 2
	ocean.mesh = om
	var ocean_mat = StandardMaterial3D.new()
	ocean_mat.albedo_color = Color("#4ABDE8")
	ocean_mat.roughness = 0.35
	ocean_mat.metallic = 0.12
	ocean.material_override = ocean_mat
	_globe.add_child(ocean)

	# 대기권 고리 (토러스)
	var atmo = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 2.28
	tm.outer_radius = 2.55
	atmo.mesh = tm
	var atmo_mat = StandardMaterial3D.new()
	atmo_mat.albedo_color = Color(0.627, 0.847, 1.0, 0.22)
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo.material_override = atmo_mat
	atmo.rotation_degrees = Vector3(90, 0, 0)
	_globe.add_child(atmo)

	# 북극 빙하
	var ice = MeshInstance3D.new()
	var ism = SphereMesh.new(); ism.radius = 0.55; ism.height = 0.4
	ice.mesh = ism
	ice.material_override = _mat("#E8F4FF", 0.3)
	ice.position = Vector3(0, GLOBE_R - 0.1, 0)
	ice.scale = Vector3(1.0, 0.3, 1.0)
	_globe.add_child(ice)

	# 대륙 (7개, 더 많아짐)
	var land_spots := [
		Vector3(0.2, 0.95, 0.15), Vector3(-0.7, 0.5, 0.5),
		Vector3(0.7, 0.4, 0.5), Vector3(0.0, 0.2, -0.95),
		Vector3(-0.5, -0.3, 0.7), Vector3(0.5, -0.5, 0.6),
		Vector3(-0.3, 0.7, 0.6),
	]
	for sp in land_spots:
		var land = MeshInstance3D.new()
		var lm = SphereMesh.new(); lm.radius = 0.7; lm.height = 0.5
		land.mesh = lm
		land.material_override = _mat("#72C85A", 0.88)
		land.position = sp.normalized() * (GLOBE_R - 0.05)
		land.look_at_from_position(land.position, Vector3.ZERO, Vector3.UP)
		land.scale = Vector3(1.0, 0.35, 1.0)
		_globe.add_child(land)

	# 구름 (5개, 바다 위)
	var cloud_positions = [
		Vector3(0.6, 0.7, 0.4), Vector3(-0.5, 0.6, 0.6),
		Vector3(0.2, 0.5, -0.8), Vector3(-0.7, 0.3, -0.5),
		Vector3(0.8, -0.2, 0.5),
	]
	for cp in cloud_positions:
		var cloud = MeshInstance3D.new()
		var csm = SphereMesh.new(); csm.radius = 0.4; csm.height = 0.18
		cloud.mesh = csm
		var cmat = StandardMaterial3D.new()
		cmat.albedo_color = Color(1, 1, 1, 0.7)
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud.material_override = cmat
		cloud.position = cp.normalized() * (GLOBE_R + 0.08)
		cloud.scale = Vector3(1.0, 0.35, 1.0)
		_globe.add_child(cloud)

# ── D) 랜드마크 (30% 더 크게) ──
func _build_landmarks() -> void:
	_eiffel(_surf(Vector3(-0.9, 0.8, 0.2)))
	_tower(_surf(Vector3(0.95, 0.7, 0.1)))
	_hanok(_surf(Vector3(0.4, 0.7, -0.7)))
	_pyramid(_surf(Vector3(-0.6, 0.55, -0.7)))
	_pisa(_surf(Vector3(-0.2, 0.6, 0.95)))
	_statue(_surf(Vector3(0.7, 0.55, 0.6)))
	_windmill(_surf(Vector3(0.15, 0.8, 0.55)))

# ── E) 떠다니는 행성/로켓/달/혜성 ──
func _build_floaters() -> void:
	_add_floater(_planet("#E8A766", true), 5.5, 0.18, 0.0, 2.5)    # 토성 (링 더 크게)
	_add_floater(_planet("#B59CE0", false), 6.5, 0.13, 2.2, -1.5)  # 보라 행성
	_add_floater(_planet("#9FC6E8", false), 6.0, 0.16, 4.0, 1.0)   # 파랑 행성
	_add_floater(_rocket(), 4.8, 0.30, 1.0, 3.0)                   # 로켓
	_add_floater(_small_moon(), 7.2, 0.10, 3.5, 0.5)               # 작은 달
	_add_floater(_comet(), 5.0, 0.22, 5.0, 2.0)                    # 혜성

# 지구본 표면 위 위치(자전 노드 기준 로컬좌표) 반환
func _surf(dir: Vector3) -> Vector3:
	return dir.normalized() * (GLOBE_R - 0.02)

# ── 랜드마크 배치 헬퍼 ──
func _place(node: Node3D, local_pos: Vector3) -> void:
	node.position = local_pos
	var up = local_pos.normalized()
	var fwd = up.cross(Vector3.RIGHT)
	if fwd.length() < 0.01:
		fwd = up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	var right = up.cross(fwd).normalized()
	node.basis = Basis(right, up, fwd)
	_globe.add_child(node)

func _eiffel(pos: Vector3) -> void:
	var n = Node3D.new()
	_cone_to(n, Vector3(0, 0.23, 0), 0.26, 0.078, 0.715, "#C8A06A")
	_cone_to(n, Vector3(0, 0.73, 0), 0.091, 0.026, 0.494, "#C8A06A")
	_place(n, pos)

func _tower(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.364, 0), 0.0585, 0.715, "#DCdce4")
	_ball(n, Vector3(0, 0.741, 0), 0.169, "#9FE0E0")
	_cyl(n, Vector3(0, 0.988, 0), 0.0221, 0.351, "#DCDCE4")
	_place(n, pos)

func _hanok(pos: Vector3) -> void:
	var n = Node3D.new()
	_boxn(n, Vector3(0, 0.182, 0), Vector3(0.715, 0.351, 0.494), "#E6D2B5")
	_cone4(n, Vector3(0, 0.468, 0), 0.65, 0.0, 0.325, "#3A4654")
	_place(n, pos)

func _pyramid(pos: Vector3) -> void:
	var n = Node3D.new()
	_cone4(n, Vector3(0, 0.325, 0), 0.585, 0.0, 0.65, "#E0C27A")
	_place(n, pos)

func _pisa(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.39, 0), 0.143, 0.78, "#F0EAD8")
	n.rotation_degrees.z = 12
	_place(n, pos)

func _statue(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.182, 0), 0.117, 0.351, "#7FB89E")
	_ball(n, Vector3(0, 0.442, 0), 0.104, "#7FB89E")
	_cone(n, Vector3(0, 0.624, 0), 0.143, 0.0, 0.208, "#7FB89E")
	_place(n, pos)

func _windmill(pos: Vector3) -> void:
	var n = Node3D.new()
	# 기둥
	_cyl(n, Vector3(0, 0.3, 0), 0.06, 0.6, "#E8DCC8")
	# 몸통
	_cone(n, Vector3(0, 0.65, 0), 0.18, 0.1, 0.3, "#D4C8B0")
	# 날개 4개
	for i in range(4):
		var blade = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = Vector3(0.06, 0.32, 0.04)
		blade.mesh = bm
		blade.material_override = _mat("#FFFFFF", 0.7)
		var angle = float(i) * PI * 0.5
		blade.position = Vector3(sin(angle) * 0.22, 0.72 + cos(angle) * 0.22, 0.05)
		n.add_child(blade)
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
		var tm = TorusMesh.new(); tm.inner_radius = 0.85; tm.outer_radius = 1.3
		r.mesh = tm
		r.material_override = _mat("#F0D8A8", 0.7)
		r.rotation_degrees = Vector3(80, 0, 18)
		n.add_child(r)
	return n

func _small_moon() -> Node3D:
	var n = Node3D.new()
	_ball(n, Vector3.ZERO, 0.4, "#D8D5E8")
	_ball(n, Vector3(0.18, 0.15, 0.28), 0.06, "#AAAABC")
	_ball(n, Vector3(-0.12, 0.22, 0.28), 0.04, "#AAAABC")
	return n

func _comet() -> Node3D:
	var n = Node3D.new()
	# 핵 (캡슐 대신 구체)
	_ball(n, Vector3.ZERO, 0.15, "#E8EAF0")
	# 꼬리 파티클 3개 (뒤로 갈수록 작아짐)
	var trail_positions = [Vector3(-0.25, 0, 0), Vector3(-0.45, 0, 0), Vector3(-0.65, 0, 0)]
	var trail_radii = [0.1, 0.07, 0.04]
	for i in range(3):
		var tp = MeshInstance3D.new()
		var tsm = SphereMesh.new(); tsm.radius = trail_radii[i]; tsm.height = trail_radii[i] * 2
		tp.mesh = tsm
		var tmat = StandardMaterial3D.new()
		tmat.albedo_color = Color(0.8, 0.85, 1.0, 0.5 - float(i) * 0.15)
		tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tp.material_override = tmat
		tp.position = trail_positions[i]
		n.add_child(tp)
	return n

func _rocket() -> Node3D:
	var n = Node3D.new()
	_cyl(n, Vector3.ZERO, 0.12, 0.5, "#F4F4F8")
	_cone(n, Vector3(0, 0.32, 0), 0.12, 0.0, 0.22, "#FF8A7A")
	_cone(n, Vector3(0, -0.3, 0), 0.16, 0.05, 0.18, "#FFC36A")
	n.rotation_degrees.z = 90
	return n

# ── 발광 구체 헬퍼 ──
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

extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var quokka_pivot: Node3D = $QuokkaPivot
var _t := 0.0
var _globe: Node3D = null
var _floaters: Array = []
var _star_meshes: Array = []
var _star_phases: Array = []

# 지구를 작게 + 낮게 배치 → 캐릭터가 화면 중앙에 크게 보임
const GLOBE_CENTER := Vector3(0, -2.4, 0)
const GLOBE_R := 1.5

func _ready() -> void:
	_build_scene()
	# 캐릭터를 지구 표면 위 정확히 배치
	quokka_pivot.position = Vector3(0, GLOBE_CENTER.y + GLOBE_R + 0.1, 0)

	# 캐릭터 강조 키라이트 (따뜻한 앞조명)
	var key = OmniLight3D.new()
	key.light_color = Color("#FFDDC8")
	key.light_energy = 2.5
	key.omni_range = 5.0
	key.position = Vector3(0, 0.5, 2.2)
	key.shadow_enabled = false
	add_child(key)
	# 보조 림라이트 (좌측)
	var fill = OmniLight3D.new()
	fill.light_color = Color("#C8D8FF")
	fill.light_energy = 1.0
	fill.omni_range = 4.0
	fill.position = Vector3(-2.0, 1.2, 1.5)
	fill.shadow_enabled = false
	add_child(fill)

	var cont = $UILayer/Control/VBox/ContinueBtn
	cont.disabled = not FileAccess.file_exists("user://save.cfg")
	$UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
	cont.pressed.connect(_on_continue)
	$UILayer/Control/SmallBtnRow/QuitBtn.pressed.connect(_on_quit)
	$UILayer/Control/SmallBtnRow/SettingsBtn.pressed.connect(
		func(): var sv = get_tree().get_first_node_in_group("settings_ui"); if sv: sv.open())
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_bgm("menu")

	# UI 장식 요소를 코드로 추가
	_build_ui_decorations()

func _process(delta: float) -> void:
	_t += delta
	if _globe:
		_globe.rotate_y(delta * 0.2)
	# 캐릭터 부드럽게 둥실
	quokka_pivot.position.y = (GLOBE_CENTER.y + GLOBE_R + 0.1) + sin(_t * 1.4) * 0.07
	# 떠다니는 오브젝트 공전
	for f in _floaters:
		var a = f.phase + _t * f.speed
		f.node.position = Vector3(cos(a) * f.radius, f.y + sin(a * 0.7) * 0.3, -3.0 + sin(a) * f.radius * 0.4)
		f.node.rotate_y(delta * 0.4)
	# 별 반짝임
	for i in range(_star_meshes.size()):
		var sm: MeshInstance3D = _star_meshes[i]
		if sm and is_instance_valid(sm):
			var mat = sm.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 3.5 + sin(_t * _star_phases[i] + i) * 2.2
	# 로고 펄스
	var logo = get_node_or_null("UILayer/Control/Logo")
	if logo:
		logo.modulate.a = 0.97 + sin(_t * 1.8) * 0.03

# ─── 스토리 전환 ───────────────────────────────────
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

# ─── 씬 빌드 ───────────────────────────────────────
func _build_scene() -> void:
	_build_stars()
	_build_nebula()
	_build_globe()
	_build_landmarks()
	_build_floaters()
	# 배경 고정 달
	var moon = _planet("#D8D5E8", false)
	moon.position = Vector3(3.8, 3.5, -4.5)
	moon.scale = Vector3(0.6, 0.6, 0.6)
	add_child(moon)

# ── UI 장식 (오브 + 따뜻한 글로우 + 반짝이) ──
func _build_ui_decorations() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return

	# 중앙 따뜻한 글로우 오버레이 (캐릭터 주변 따뜻한 빛 느낌)
	var glow = ColorRect.new()
	glow.color = Color(0.88, 0.48, 0.38, 0.11)
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.size = Vector2(900, 750)
	glow.position = Vector2(-450, -200)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(glow)
	ctrl.move_child(glow, 4)   # 프레임 뒤에 배치

	# 상단 보라빛 글로우 (로고 배경 강조)
	var top_glow = ColorRect.new()
	top_glow.color = Color(0.45, 0.22, 0.75, 0.13)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.size.y = 500
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(top_glow)
	ctrl.move_child(top_glow, 4)

	# 미니 행성 오브 6개
	var orbs = [
		{"pos": Vector2(65, 420), "size": 88.0, "color": Color("#E8A8D0"), "alpha": 0.82},
		{"pos": Vector2(940, 480), "size": 68.0, "color": Color("#A8C8E8"), "alpha": 0.78},
		{"pos": Vector2(40, 850), "size": 108.0, "color": Color("#C8A8E8"), "alpha": 0.70},
		{"pos": Vector2(920, 900), "size": 78.0, "color": Color("#E8C8A0"), "alpha": 0.75},
		{"pos": Vector2(110, 1150), "size": 52.0, "color": Color("#A8E8C8"), "alpha": 0.65},
		{"pos": Vector2(960, 1100), "size": 62.0, "color": Color("#E8D8A0"), "alpha": 0.68},
	]
	for od in orbs:
		var orb = Panel.new()
		var st = StyleBoxFlat.new()
		var c: Color = od.color
		c.a = od.alpha
		st.bg_color = c
		var r = int(od.size * 0.5)
		st.corner_radius_top_left = r
		st.corner_radius_top_right = r
		st.corner_radius_bottom_left = r
		st.corner_radius_bottom_right = r
		# 하이라이트 테두리
		st.border_width_top = 2
		st.border_width_right = 2
		st.border_width_bottom = 2
		st.border_width_left = 2
		st.border_color = Color(1, 1, 1, 0.35)
		orb.add_theme_stylebox_override("panel", st)
		orb.set_anchors_preset(Control.PRESET_TOP_LEFT)
		orb.position = od.pos
		orb.size = Vector2(od.size, od.size)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(orb)
		ctrl.move_child(orb, 5)

	# 추가 반짝이 레이블 8개 (로고 주변 + 중간 영역)
	var sparks = [
		{"pos": Vector2(180, 420), "size": 28, "txt": "✦"},
		{"pos": Vector2(870, 440), "size": 24, "txt": "✦"},
		{"pos": Vector2(140, 680), "size": 20, "txt": "★"},
		{"pos": Vector2(920, 720), "size": 18, "txt": "★"},
		{"pos": Vector2(220, 960), "size": 22, "txt": "✦"},
		{"pos": Vector2(840, 980), "size": 20, "txt": "✦"},
		{"pos": Vector2(320, 1200), "size": 16, "txt": "✩"},
		{"pos": Vector2(730, 1220), "size": 16, "txt": "✩"},
	]
	for sd in sparks:
		var lbl = Label.new()
		lbl.text = sd.txt
		lbl.add_theme_font_size_override("font_size", sd.size)
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.72, 0.82))
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.position = sd.pos
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(lbl)

# ── A) 별 (상단에 집중 배치 + 150개) ──
func _build_stars() -> void:
	var gold = 2.399963
	# Tier 1: 밝고 큰 흰 별 (55개, 위쪽 집중)
	for i in range(55):
		var ang = float(i) * gold
		var t = float(i) / 55.0
		var pos = Vector3(
			cos(ang) * (6.0 + t * 6.0),
			1.0 + t * 9.0,           # y: 1~10 (화면 위쪽)
			-8.0 - t * 8.0
		)
		var r = 0.08 + fmod(float(i) * 0.005, 0.05)
		var energy = 5.0 + fmod(float(i) * 0.07, 3.5)
		var sm = _emit_sphere(self, pos, r, "#FFFFFF", energy)
		_star_meshes.append(sm)
		_star_phases.append(1.2 + fmod(float(i) * 0.73, 2.5))

	# Tier 2: 파스텔 별 (65개, 전체 분포)
	var pcols = ["#FFD6E8", "#C8D6FF", "#E8D6FF", "#FFE8C8", "#D6FFE8", "#FFE8F8"]
	for i in range(65):
		var ang = float(i) * gold * 1.3
		var t = float(i) / 65.0
		var pos = Vector3(
			cos(ang) * (5.0 + t * 7.0),
			-2.0 + t * 11.0,
			-7.0 - t * 8.0
		)
		var r = 0.028 + fmod(float(i) * 0.0006, 0.032)
		var col = pcols[i % pcols.size()]
		var sm = _emit_sphere(self, pos, r, col, 2.8 + fmod(float(i) * 0.033, 2.2))
		_star_meshes.append(sm)
		_star_phases.append(0.8 + fmod(float(i) * 0.61, 3.0))

	# Tier 3: 작은 원거리 별 (45개)
	for i in range(45):
		var ang = float(i) * gold * 0.8
		var t = float(i) / 45.0
		var pos = Vector3(
			cos(ang) * (7.0 + t * 5.0),
			-1.0 + t * 12.0,
			-16.0 - t * 5.0
		)
		var r = 0.014 + fmod(float(i) * 0.0003, 0.012)
		_emit_sphere(self, pos, r, "#FFFFFF", 2.0 + fmod(float(i) * 0.025, 1.2))

# ── B) 성운 (따뜻한 색 포함) ──
func _build_nebula() -> void:
	var nd = [
		{"p": Vector3(-7.0, 2.0, -9.0),  "r": 3.2, "c": Color(0.48, 0.28, 0.80, 0.08)},
		{"p": Vector3(7.5, 0.0, -8.0),   "r": 2.8, "c": Color(0.22, 0.45, 0.90, 0.07)},
		{"p": Vector3(0.0, 5.0, -11.0),  "r": 4.0, "c": Color(0.80, 0.35, 0.58, 0.07)},
		{"p": Vector3(-4.0, -1.0, -10.0),"r": 2.5, "c": Color(0.15, 0.28, 0.68, 0.06)},
		{"p": Vector3(5.0, 3.5, -12.0),  "r": 3.5, "c": Color(0.25, 0.65, 0.80, 0.065)},
		{"p": Vector3(-2.0, -2.0, -8.0), "r": 2.2, "c": Color(0.90, 0.55, 0.28, 0.055)},
		{"p": Vector3(3.0, 6.0, -13.0),  "r": 3.8, "c": Color(0.72, 0.38, 0.80, 0.06)},
		{"p": Vector3(-9.0, 1.0, -10.0), "r": 2.6, "c": Color(0.88, 0.45, 0.45, 0.05)},
	]
	for d in nd:
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = d.r; sm.height = d.r * 2.0; mi.mesh = sm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = d.c
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mi.material_override = mat
		mi.position = d.p
		add_child(mi)

# ── C) 지구본 (작고 컬러풀하게) ──
func _build_globe() -> void:
	_globe = Node3D.new()
	_globe.position = GLOBE_CENTER
	add_child(_globe)

	# 바다 (선명한 청록)
	var ocean = MeshInstance3D.new()
	var om = SphereMesh.new(); om.radius = GLOBE_R; om.height = GLOBE_R * 2
	ocean.mesh = om
	var omat = StandardMaterial3D.new()
	omat.albedo_color = Color("#3ABCE8")
	omat.roughness = 0.3
	omat.metallic = 0.15
	ocean.material_override = omat
	_globe.add_child(ocean)

	# 대기권 토러스
	var atmo = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = GLOBE_R + 0.08
	tm.outer_radius = GLOBE_R + 0.38
	atmo.mesh = tm
	var amat = StandardMaterial3D.new()
	amat.albedo_color = Color(0.62, 0.84, 1.0, 0.20)
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo.material_override = amat
	atmo.rotation_degrees = Vector3(90, 0, 0)
	_globe.add_child(atmo)

	# 북극 빙하
	var ice = MeshInstance3D.new()
	var ism = SphereMesh.new(); ism.radius = 0.45; ism.height = 0.32
	ice.mesh = ism
	ice.material_override = _mat("#E8F4FF", 0.28)
	ice.position = Vector3(0, GLOBE_R - 0.08, 0)
	ice.scale = Vector3(1.0, 0.25, 1.0)
	_globe.add_child(ice)

	# 대륙 (7개, 더 밝은 초록)
	var lands := [
		Vector3(0.2, 0.95, 0.15), Vector3(-0.7, 0.5, 0.5),
		Vector3(0.7, 0.4, 0.5),  Vector3(0.0, 0.2, -0.95),
		Vector3(-0.5, -0.3, 0.7), Vector3(0.5, -0.5, 0.6),
		Vector3(-0.3, 0.7, 0.6),
	]
	for sp in lands:
		var land = MeshInstance3D.new()
		var lm = SphereMesh.new(); lm.radius = 0.62; lm.height = 0.44
		land.mesh = lm
		land.material_override = _mat("#6DC84A", 0.85)
		land.position = sp.normalized() * (GLOBE_R - 0.04)
		land.look_at_from_position(land.position, Vector3.ZERO, Vector3.UP)
		land.scale = Vector3(1.0, 0.33, 1.0)
		_globe.add_child(land)

	# 구름 (5개)
	var cpos = [
		Vector3(0.6, 0.7, 0.4), Vector3(-0.5, 0.6, 0.6),
		Vector3(0.2, 0.5, -0.8), Vector3(-0.7, 0.3, -0.5),
		Vector3(0.8, -0.2, 0.5),
	]
	for cp in cpos:
		var cloud = MeshInstance3D.new()
		var csm = SphereMesh.new(); csm.radius = 0.36; csm.height = 0.16
		cloud.mesh = csm
		var cmat = StandardMaterial3D.new()
		cmat.albedo_color = Color(1, 1, 1, 0.72)
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud.material_override = cmat
		cloud.position = cp.normalized() * (GLOBE_R + 0.07)
		cloud.scale = Vector3(1.0, 0.32, 1.0)
		_globe.add_child(cloud)

# ── D) 랜드마크 ──
func _build_landmarks() -> void:
	_eiffel(_surf(Vector3(-0.9, 0.8, 0.2)))
	_tower(_surf(Vector3(0.95, 0.7, 0.1)))
	_hanok(_surf(Vector3(0.4, 0.7, -0.7)))
	_pyramid(_surf(Vector3(-0.6, 0.55, -0.7)))
	_pisa(_surf(Vector3(-0.2, 0.6, 0.95)))
	_statue(_surf(Vector3(0.7, 0.55, 0.6)))
	_windmill(_surf(Vector3(0.15, 0.8, 0.55)))

# ── E) 떠다니는 오브젝트 ──
func _build_floaters() -> void:
	_add_floater(_planet("#E8A766", true), 5.5, 0.18, 0.0, 2.5)
	_add_floater(_planet("#B59CE0", false), 6.5, 0.13, 2.2, -1.5)
	_add_floater(_planet("#9FC6E8", false), 6.0, 0.16, 4.0, 1.0)
	_add_floater(_rocket(), 4.8, 0.30, 1.0, 3.0)
	_add_floater(_small_moon(), 7.2, 0.10, 3.5, 0.5)
	_add_floater(_comet(), 5.0, 0.22, 5.0, 2.0)

func _surf(dir: Vector3) -> Vector3:
	return dir.normalized() * (GLOBE_R - 0.02)

func _place(node: Node3D, local_pos: Vector3) -> void:
	node.position = local_pos
	var up = local_pos.normalized()
	var fwd = up.cross(Vector3.RIGHT)
	if fwd.length() < 0.01:
		fwd = up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	node.basis = Basis(up.cross(fwd).normalized(), up, fwd)
	_globe.add_child(node)

func _eiffel(pos: Vector3) -> void:
	var n = Node3D.new()
	_cone_to(n, Vector3(0, 0.23, 0), 0.26, 0.078, 0.715, "#C8A06A")
	_cone_to(n, Vector3(0, 0.73, 0), 0.091, 0.026, 0.494, "#C8A06A")
	_place(n, pos)

func _tower(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.364, 0), 0.058, 0.715, "#DCDCE4")
	_ball(n, Vector3(0, 0.741, 0), 0.169, "#9FE0E0")
	_cyl(n, Vector3(0, 0.988, 0), 0.022, 0.351, "#DCDCE4")
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
	_cyl(n, Vector3(0, 0.3, 0), 0.06, 0.6, "#E8DCC8")
	_cone(n, Vector3(0, 0.65, 0), 0.18, 0.1, 0.3, "#D4C8B0")
	for i in range(4):
		var blade = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = Vector3(0.06, 0.32, 0.04)
		blade.mesh = bm
		blade.material_override = _mat("#FFFFFF", 0.7)
		var ang = float(i) * PI * 0.5
		blade.position = Vector3(sin(ang) * 0.22, 0.72 + cos(ang) * 0.22, 0.05)
		n.add_child(blade)
	_place(n, pos)

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
	_ball(n, Vector3.ZERO, 0.15, "#E8EAF0")
	var tpos = [Vector3(-0.25, 0, 0), Vector3(-0.45, 0, 0), Vector3(-0.65, 0, 0)]
	var trad = [0.10, 0.07, 0.04]
	for i in range(3):
		var tp = MeshInstance3D.new()
		var tsm = SphereMesh.new(); tsm.radius = trad[i]; tsm.height = trad[i] * 2
		tp.mesh = tsm
		var tmat = StandardMaterial3D.new()
		tmat.albedo_color = Color(0.8, 0.85, 1.0, 0.5 - float(i) * 0.15)
		tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tp.material_override = tmat
		tp.position = tpos[i]
		n.add_child(tp)
	return n

func _rocket() -> Node3D:
	var n = Node3D.new()
	_cyl(n, Vector3.ZERO, 0.12, 0.5, "#F4F4F8")
	_cone(n, Vector3(0, 0.32, 0), 0.12, 0.0, 0.22, "#FF8A7A")
	_cone(n, Vector3(0, -0.3, 0), 0.16, 0.05, 0.18, "#FFC36A")
	n.rotation_degrees.z = 90
	return n

func _emit_sphere(parent: Node3D, pos: Vector3, r: float, hex: String, energy: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; mi.mesh = sm
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

func _mat(hex: String, rough: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new(); m.albedo_color = Color(hex); m.roughness = rough; return m

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

extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var quokka_pivot: Node3D = $QuokkaPivot
var _t := 0.0
var _globe: Node3D = null
var _floaters: Array = []
var _star_meshes: Array = []
var _star_phases: Array = []

# 지구를 작게 + 앞쪽에 → 미니 디오라마 느낌
const GLOBE_CENTER := Vector3(0, -1.4, 0)
const GLOBE_R := 0.75

func _ready() -> void:
	_build_scene()
	quokka_pivot.position = Vector3(0, GLOBE_CENTER.y + GLOBE_R + 0.1, 0)

	# 캐릭터 키라이트
	var key = OmniLight3D.new()
	key.light_color = Color("#FFDDC8"); key.light_energy = 2.8
	key.omni_range = 5.0; key.position = Vector3(0, 0.5, 2.2)
	key.shadow_enabled = false; add_child(key)
	# 글로브 위쪽 조명
	var globe_light = OmniLight3D.new()
	globe_light.light_color = Color("#C8F0FF"); globe_light.light_energy = 1.5
	globe_light.omni_range = 4.0; globe_light.position = Vector3(1.0, 0.5, 2.5)
	globe_light.shadow_enabled = false; add_child(globe_light)

	var cont = $UILayer/Control/VBox/ContinueBtn
	cont.disabled = not FileAccess.file_exists("user://save.cfg")
	$UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
	cont.pressed.connect(_on_continue)
	$UILayer/Control/SmallBtnRow/QuitBtn.pressed.connect(_on_quit)
	$UILayer/Control/SmallBtnRow/SettingsBtn.pressed.connect(
		func(): var sv = get_tree().get_first_node_in_group("settings_ui"); if sv: sv.open())
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_bgm("menu")

	_build_ui_decorations()

func _process(delta: float) -> void:
	_t += delta
	if _globe:
		_globe.rotate_y(delta * 0.18)
	# 캐릭터 둥실
	quokka_pivot.position.y = (GLOBE_CENTER.y + GLOBE_R + 0.1) + sin(_t * 1.4) * 0.06
	# 떠다니는 오브젝트
	for f in _floaters:
		var a = f.phase + _t * f.speed
		f.node.position = Vector3(cos(a) * f.radius, f.y + sin(a * 0.7) * 0.28, -3.0 + sin(a) * f.radius * 0.4)
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

# ─── 스토리 전환 ───
func _on_start() -> void:
	Episode0State.current_state = Episode0State.State.START
	Episode0State.has_camera = false; Episode0State.has_notebook = false
	Episode0State.has_travel_bag = false; Episode0State.badge_returned = false
	Episode0State.partner_joined = false; Episode0State.first_photo_taken = false
	Episode0State.album_created = false; Episode0State.episode0_cleared = false
	Episode0State.memos_found = []
	SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

func _on_continue() -> void:
	SaveManager.load_game()
	var cfg = ConfigFile.new(); cfg.load("user://save.cfg")
	var scene = cfg.get_value("game", "current_scene", "res://scenes/maps/CompanyFront3D.tscn")
	SceneTransition.go_to(scene)

func _on_quit() -> void:
	get_tree().quit()

# ─── 씬 빌드 ───
func _build_scene() -> void:
	_build_stars()
	_build_nebula()
	_build_globe()
	_build_landmarks()
	_build_floaters()
	# 달
	var moon = _planet("#D8D5E8", false)
	moon.position = Vector3(3.8, 3.5, -4.5)
	moon.scale = Vector3(0.55, 0.55, 0.55)
	add_child(moon)

# ── UI 장식 (사각형 오버레이 절대 금지 — 원형 오브만) ──
func _build_ui_decorations() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return

	# 미니 행성 오브 6개 (사각형 아닌 원형 패널)
	var orbs = [
		{"pos": Vector2(42, 400), "size": 80.0, "color": Color("#E8A8D0"), "alpha": 0.78},
		{"pos": Vector2(958, 460), "size": 62.0, "color": Color("#A8C8E8"), "alpha": 0.74},
		{"pos": Vector2(28, 820), "size": 96.0, "color": Color("#C8A8E8"), "alpha": 0.65},
		{"pos": Vector2(942, 880), "size": 72.0, "color": Color("#E8C8A0"), "alpha": 0.70},
		{"pos": Vector2(88, 1120), "size": 48.0, "color": Color("#A8E8C8"), "alpha": 0.60},
		{"pos": Vector2(962, 1080), "size": 58.0, "color": Color("#E8D8A0"), "alpha": 0.64},
	]
	for od in orbs:
		var orb = Panel.new()
		var st = StyleBoxFlat.new()
		var c: Color = od.color; c.a = od.alpha
		st.bg_color = c
		var r = int(od.size * 0.5)
		st.corner_radius_top_left = r; st.corner_radius_top_right = r
		st.corner_radius_bottom_left = r; st.corner_radius_bottom_right = r
		st.border_width_top = 2; st.border_width_right = 2
		st.border_width_bottom = 2; st.border_width_left = 2
		st.border_color = Color(1, 1, 1, 0.32)
		orb.add_theme_stylebox_override("panel", st)
		orb.set_anchors_preset(Control.PRESET_TOP_LEFT)
		orb.position = od.pos; orb.size = Vector2(od.size, od.size)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(orb); ctrl.move_child(orb, 0)

	# 반짝이 레이블
	var sparks = [
		{"pos": Vector2(165, 410), "size": 26, "txt": "✦"},
		{"pos": Vector2(882, 430), "size": 22, "txt": "✦"},
		{"pos": Vector2(128, 660), "size": 18, "txt": "★"},
		{"pos": Vector2(930, 700), "size": 16, "txt": "★"},
		{"pos": Vector2(205, 940), "size": 20, "txt": "✦"},
		{"pos": Vector2(855, 960), "size": 18, "txt": "✦"},
		{"pos": Vector2(310, 1180), "size": 14, "txt": "✩"},
		{"pos": Vector2(742, 1200), "size": 14, "txt": "✩"},
	]
	for sd in sparks:
		var lbl = Label.new()
		lbl.text = sd.txt
		lbl.add_theme_font_size_override("font_size", sd.size)
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.72, 0.80))
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.position = sd.pos; lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(lbl)

# ── A) 별 ──
func _build_stars() -> void:
	var gold = 2.399963
	for i in range(55):
		var ang = float(i) * gold
		var t = float(i) / 55.0
		var pos = Vector3(cos(ang) * (6.0 + t * 6.0), 1.0 + t * 9.0, -8.0 - t * 8.0)
		var r = 0.08 + fmod(float(i) * 0.005, 0.05)
		var energy = 5.0 + fmod(float(i) * 0.07, 3.5)
		var sm = _emit_sphere(self, pos, r, "#FFFFFF", energy)
		_star_meshes.append(sm); _star_phases.append(1.2 + fmod(float(i) * 0.73, 2.5))
	var pcols = ["#FFD6E8", "#C8D6FF", "#E8D6FF", "#FFE8C8", "#D6FFE8", "#FFE8F8"]
	for i in range(65):
		var ang = float(i) * gold * 1.3; var t = float(i) / 65.0
		var pos = Vector3(cos(ang) * (5.0 + t * 7.0), -2.0 + t * 11.0, -7.0 - t * 8.0)
		var r = 0.028 + fmod(float(i) * 0.0006, 0.032)
		var sm = _emit_sphere(self, pos, r, pcols[i % pcols.size()], 2.8 + fmod(float(i) * 0.033, 2.2))
		_star_meshes.append(sm); _star_phases.append(0.8 + fmod(float(i) * 0.61, 3.0))
	for i in range(45):
		var ang = float(i) * gold * 0.8; var t = float(i) / 45.0
		var pos = Vector3(cos(ang) * (7.0 + t * 5.0), -1.0 + t * 12.0, -16.0 - t * 5.0)
		var r = 0.014 + fmod(float(i) * 0.0003, 0.012)
		_emit_sphere(self, pos, r, "#FFFFFF", 2.0 + fmod(float(i) * 0.025, 1.2))

# ── B) 성운 ──
func _build_nebula() -> void:
	var nd = [
		{"p": Vector3(-7.0, 2.0, -9.0),   "r": 3.2, "c": Color(0.48, 0.28, 0.80, 0.08)},
		{"p": Vector3(7.5, 0.0, -8.0),    "r": 2.8, "c": Color(0.22, 0.45, 0.90, 0.07)},
		{"p": Vector3(0.0, 5.0, -11.0),   "r": 4.0, "c": Color(0.80, 0.35, 0.58, 0.07)},
		{"p": Vector3(-4.0, -1.0, -10.0), "r": 2.5, "c": Color(0.15, 0.28, 0.68, 0.06)},
		{"p": Vector3(5.0, 3.5, -12.0),   "r": 3.5, "c": Color(0.25, 0.65, 0.80, 0.065)},
		{"p": Vector3(-2.0, -2.0, -8.0),  "r": 2.2, "c": Color(0.90, 0.55, 0.28, 0.055)},
		{"p": Vector3(3.0, 6.0, -13.0),   "r": 3.8, "c": Color(0.72, 0.38, 0.80, 0.06)},
		{"p": Vector3(-9.0, 1.0, -10.0),  "r": 2.6, "c": Color(0.88, 0.45, 0.45, 0.05)},
	]
	for d in nd:
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new(); sm.radius = d.r; sm.height = d.r * 2.0; mi.mesh = sm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = d.c; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.no_depth_test = true
		mi.material_override = mat; mi.position = d.p; add_child(mi)

# ── C) 지구본 (미니 여행 월드 디오라마) ──
func _build_globe() -> void:
	_globe = Node3D.new()
	_globe.position = GLOBE_CENTER
	add_child(_globe)

	# 바다 (청록)
	var ocean = MeshInstance3D.new()
	var om = SphereMesh.new(); om.radius = GLOBE_R; om.height = GLOBE_R * 2
	ocean.mesh = om
	var omat = StandardMaterial3D.new()
	omat.albedo_color = Color("#3ABCE8"); omat.roughness = 0.25; omat.metallic = 0.1
	ocean.material_override = omat; _globe.add_child(ocean)

	# 대기권 토러스
	var atmo = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = GLOBE_R + 0.06; tm.outer_radius = GLOBE_R + 0.28
	atmo.mesh = tm
	var amat = StandardMaterial3D.new()
	amat.albedo_color = Color(0.62, 0.84, 1.0, 0.18)
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo.material_override = amat; atmo.rotation_degrees = Vector3(90, 0, 0)
	_globe.add_child(atmo)

	# 하이라이트 (상단 반사광)
	var hl = MeshInstance3D.new()
	var hlm = SphereMesh.new(); hlm.radius = 0.38; hlm.height = 0.2
	hl.mesh = hlm
	var hlmat = StandardMaterial3D.new()
	hlmat.albedo_color = Color(1, 1, 1, 0.22)
	hlmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hlmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hl.material_override = hlmat; hl.position = Vector3(-0.28, GLOBE_R * 0.72, 0.3)
	hl.scale = Vector3(1.0, 0.3, 1.0); _globe.add_child(hl)

	# 북극 빙하
	var ice = MeshInstance3D.new()
	var ism = SphereMesh.new(); ism.radius = 0.38; ism.height = 0.25
	ice.mesh = ism; ice.material_override = _mat("#E8F4FF", 0.28)
	ice.position = Vector3(0, GLOBE_R - 0.06, 0); ice.scale = Vector3(1.0, 0.22, 1.0)
	_globe.add_child(ice)

	# 대륙 (앞쪽에 집중)
	var lands := [
		Vector3(0.15, 0.92, 0.35),   # 앞 중심 상단
		Vector3(-0.65, 0.48, 0.58),  # 앞 왼쪽
		Vector3(0.62, 0.42, 0.62),   # 앞 오른쪽
		Vector3(0.0, 0.18, -0.95),   # 뒤쪽
		Vector3(-0.48, -0.28, 0.72), # 앞 하단 왼쪽
		Vector3(0.48, -0.48, 0.65),  # 앞 하단 오른쪽
		Vector3(-0.28, 0.68, 0.68),  # 앞 상단 왼쪽
	]
	for sp in lands:
		var land = MeshInstance3D.new()
		var lm = SphereMesh.new(); lm.radius = 0.50; lm.height = 0.36
		land.mesh = lm; land.material_override = _mat("#6DC84A", 0.82)
		land.position = sp.normalized() * (GLOBE_R - 0.03)
		land.look_at_from_position(land.position, Vector3.ZERO, Vector3.UP)
		land.scale = Vector3(1.0, 0.30, 1.0); _globe.add_child(land)

	# 구름
	var cpos = [
		Vector3(0.55, 0.68, 0.48), Vector3(-0.48, 0.58, 0.62),
		Vector3(0.18, 0.48, -0.85), Vector3(-0.65, 0.28, -0.55),
		Vector3(0.78, -0.18, 0.58),
	]
	for cp in cpos:
		var cloud = MeshInstance3D.new()
		var csm = SphereMesh.new(); csm.radius = 0.28; csm.height = 0.12
		cloud.mesh = csm
		var cmat = StandardMaterial3D.new()
		cmat.albedo_color = Color(1, 1, 1, 0.70)
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud.material_override = cmat
		cloud.position = cp.normalized() * (GLOBE_R + 0.06)
		cloud.scale = Vector3(1.0, 0.30, 1.0); _globe.add_child(cloud)

	# 미니 나무 숲 (앞 중앙 아래)
	for i in range(6):
		var ang = float(i) / 6.0 * PI * 0.8 - 0.4
		var tree_pos = Vector3(sin(ang) * 0.3, 0.18, GLOBE_R - 0.08)
		var tree = Node3D.new()
		_cyl(tree, Vector3(0, 0.06, 0), 0.025, 0.12, "#7A4C2A")
		_cone(tree, Vector3(0, 0.16, 0), 0.08, 0.0, 0.16, "#2A7C3A")
		_cone(tree, Vector3(0, 0.24, 0), 0.06, 0.0, 0.12, "#38A04A")
		tree.position = tree_pos.normalized() * (GLOBE_R - 0.02)
		tree.look_at_from_position(tree.position, Vector3.ZERO, Vector3.UP)
		tree.scale = Vector3(0.7, 0.7, 0.7)
		_globe.add_child(tree)

# ── D) 랜드마크 (앞쪽 반구에 집중) ──
func _build_landmarks() -> void:
	_eiffel(_surf(Vector3(-0.65, 0.62, 0.52)))
	_tower(_surf(Vector3(0.62, 0.62, 0.52)))
	_hanok(_surf(Vector3(0.08, 0.52, 0.82)))
	_pyramid(_surf(Vector3(-0.75, 0.28, 0.62)))
	_windmill(_surf(Vector3(0.25, 0.78, 0.56)))
	_pisa(_surf(Vector3(0.72, 0.42, 0.52)))

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
	node.scale = Vector3(0.62, 0.62, 0.62)
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

func _windmill(pos: Vector3) -> void:
	var n = Node3D.new()
	_cyl(n, Vector3(0, 0.3, 0), 0.06, 0.6, "#E8DCC8")
	_cone(n, Vector3(0, 0.65, 0), 0.18, 0.1, 0.3, "#D4C8B0")
	for i in range(4):
		var blade = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = Vector3(0.06, 0.32, 0.04)
		blade.mesh = bm; blade.material_override = _mat("#FFFFFF", 0.7)
		var ang = float(i) * PI * 0.5
		blade.position = Vector3(sin(ang) * 0.22, 0.72 + cos(ang) * 0.22, 0.05)
		n.add_child(blade)
	_place(n, pos)

func _add_floater(node: Node3D, radius: float, speed: float, phase: float, y: float) -> void:
	add_child(node)
	_floaters.append({"node": node, "radius": radius, "speed": speed, "phase": phase, "y": y})

func _planet(hex: String, ring: bool) -> Node3D:
	var n = Node3D.new(); _ball(n, Vector3.ZERO, 0.6, hex)
	if ring:
		var r = MeshInstance3D.new()
		var tm = TorusMesh.new(); tm.inner_radius = 0.85; tm.outer_radius = 1.3
		r.mesh = tm; r.material_override = _mat("#F0D8A8", 0.7)
		r.rotation_degrees = Vector3(80, 0, 18); n.add_child(r)
	return n

func _small_moon() -> Node3D:
	var n = Node3D.new()
	_ball(n, Vector3.ZERO, 0.4, "#D8D5E8")
	_ball(n, Vector3(0.18, 0.15, 0.28), 0.06, "#AAAABC")
	_ball(n, Vector3(-0.12, 0.22, 0.28), 0.04, "#AAAABC")
	return n

func _comet() -> Node3D:
	var n = Node3D.new(); _ball(n, Vector3.ZERO, 0.15, "#E8EAF0")
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
		tp.material_override = tmat; tp.position = tpos[i]; n.add_child(tp)
	return n

func _rocket() -> Node3D:
	var n = Node3D.new()
	_cyl(n, Vector3.ZERO, 0.12, 0.5, "#F4F4F8")
	_cone(n, Vector3(0, 0.32, 0), 0.12, 0.0, 0.22, "#FF8A7A")
	_cone(n, Vector3(0, -0.3, 0), 0.16, 0.05, 0.18, "#FFC36A")
	n.rotation_degrees.z = 90; return n

func _emit_sphere(parent: Node3D, pos: Vector3, r: float, hex: String, energy: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; mi.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex); mat.emission_enabled = true
	mat.emission = Color(hex); mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

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

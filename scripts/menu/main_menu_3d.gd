extends Node3D

@onready var camera: Camera3D = $Camera3D
var _t := 0.0
var _star_meshes: Array = []
var _star_phases: Array = []

const POSTER_PATH    := "res://assets/splash/splash-poster-no-text.png"
const COUPLE_3D_PATH := "res://assets/mascots/quica-couple-splash.png"

func _ready() -> void:
	_build_bg_stars()
	_inject_poster_background()
	_inject_mascot_couple()

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

# ─── 포스터 배경 주입 ───
func _inject_poster_background() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return

	var tex: Texture2D = null
	var abs_path = ProjectSettings.globalize_path(POSTER_PATH)
	if FileAccess.file_exists(abs_path):
		var img = Image.load_from_file(abs_path)
		if img:
			tex = ImageTexture.create_from_image(img)

	if tex:
		var bg = TextureRect.new()
		bg.name = "PosterBG"
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(bg)
		ctrl.move_child(bg, 0)
	else:
		# 포스터 없을 때 fallback: 어두운 배경 + 안내 메시지
		var fallback = ColorRect.new()
		fallback.name = "FallbackBG"
		fallback.color = Color(0.06, 0.04, 0.18, 1.0)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(fallback)
		ctrl.move_child(fallback, 0)

		var hint = Label.new()
		hint.text = "assets/splash/splash-poster-no-text.png 를 추가하면\n고퀄리티 포스터가 표시됩니다."
		hint.add_theme_font_size_override("font_size", 28)
		hint.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0, 0.55))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(hint)
		ctrl.move_child(hint, 1)

# ─── 3D 마스코트 커플 주입 ───
func _inject_mascot_couple() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return
	var abs_path = ProjectSettings.globalize_path(COUPLE_3D_PATH)
	if not FileAccess.file_exists(abs_path):
		return
	var img = Image.load_from_file(abs_path)
	if not img:
		return
	var tex = ImageTexture.create_from_image(img)

	# 컨테이너: halo glow + contact shadow + 캐릭터를 함께 배치
	var wrap = Control.new()
	wrap.name = "MascotCoupleWrap"
	wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wrap.set_offset(SIDE_LEFT,  -560)
	wrap.set_offset(SIDE_RIGHT,  560)
	wrap.set_offset(SIDE_TOP,   -820)
	wrap.set_offset(SIDE_BOTTOM, 30)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1) 캐릭터 뒤 은은한 halo (방사형 밝은 원)
	var halo = TextureRect.new()
	halo.name = "Halo"
	halo.texture = _make_radial_glow(256, Color(1.0, 0.95, 0.78, 0.55))
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.set_anchors_preset(Control.PRESET_CENTER)
	halo.set_offset(SIDE_LEFT,  -420)
	halo.set_offset(SIDE_RIGHT,  420)
	halo.set_offset(SIDE_TOP,   -420)
	halo.set_offset(SIDE_BOTTOM, 300)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.modulate.a = 0.85
	wrap.add_child(halo)

	# 2) 행성 접지 그림자 (하단 타원)
	var shadow = TextureRect.new()
	shadow.name = "ContactShadow"
	shadow.texture = _make_radial_glow(128, Color(0.0, 0.0, 0.02, 0.65))
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shadow.set_offset(SIDE_LEFT,  120)
	shadow.set_offset(SIDE_RIGHT, -120)
	shadow.set_offset(SIDE_TOP,   -120)
	shadow.set_offset(SIDE_BOTTOM, 30)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(shadow)

	# 3) 캐릭터 본체
	var rect = TextureRect.new()
	rect.name = "MascotCouple3D"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1.0, 0.99, 0.97, 1.0)
	wrap.add_child(rect)

	ctrl.add_child(wrap)
	# 버튼(VBox)보다 뒤에 배치
	var vbox = ctrl.get_node_or_null("VBox")
	if vbox:
		ctrl.move_child(wrap, vbox.get_index())

# 방사형 그라디언트 텍스처 생성 (halo/그림자용)
func _make_radial_glow(size: int, col: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c = size * 0.5
	for y in range(size):
		for x in range(size):
			var d = Vector2(x - c, y - c).length() / c
			var a = clampf(1.0 - d, 0.0, 1.0)
			a = a * a  # smooth falloff
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)

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

# ─── 배경 별 (3D 앰비언트) ───
func _build_bg_stars() -> void:
	var gold = 2.399963
	for i in range(55):
		var ang = float(i) * gold
		var t = float(i) / 55.0
		var pos = Vector3(cos(ang) * (6.0 + t * 6.0), 1.0 + t * 9.0, -8.0 - t * 8.0)
		var r = 0.08 + fmod(float(i) * 0.005, 0.05)
		var sm = _emit_sphere(self, pos, r, "#FFFFFF", 5.0 + fmod(float(i) * 0.07, 3.5))
		_star_meshes.append(sm); _star_phases.append(1.2 + fmod(float(i) * 0.73, 2.5))
	var pcols = ["#FFD6E8", "#C8D6FF", "#E8D6FF", "#FFE8C8", "#D6FFE8"]
	for i in range(80):
		var ang = float(i) * gold * 1.3; var t = float(i) / 80.0
		var pos = Vector3(cos(ang) * (5.0 + t * 7.0), -2.0 + t * 11.0, -7.0 - t * 8.0)
		var r = 0.028 + fmod(float(i) * 0.0006, 0.032)
		var sm = _emit_sphere(self, pos, r, pcols[i % pcols.size()], 2.8 + fmod(float(i) * 0.033, 2.2))
		_star_meshes.append(sm); _star_phases.append(0.8 + fmod(float(i) * 0.61, 3.0))

# ── UI 장식 (반짝이 레이블) ──
func _build_ui_decorations() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return
	var sparks = [
		{"pos": Vector2(165, 410), "size": 26, "txt": "✦"},
		{"pos": Vector2(882, 430), "size": 22, "txt": "✦"},
		{"pos": Vector2(128, 660), "size": 18, "txt": "★"},
		{"pos": Vector2(930, 700), "size": 16, "txt": "★"},
		{"pos": Vector2(205, 940), "size": 20, "txt": "✦"},
		{"pos": Vector2(855, 960), "size": 18, "txt": "✦"},
	]
	for sd in sparks:
		var lbl = Label.new()
		lbl.text = sd.txt
		lbl.add_theme_font_size_override("font_size", sd.size)
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.72, 0.80))
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.position = sd.pos; lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(lbl)

func _emit_sphere(parent: Node3D, pos: Vector3, r: float, hex: String, energy: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; mi.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex); mat.emission_enabled = true
	mat.emission = Color(hex); mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

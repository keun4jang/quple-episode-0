extends Node3D

@onready var camera: Camera3D = $Camera3D
var _t := 0.0
var _star_meshes: Array = []
var _star_phases: Array = []

# 가로 화면용 배경. 예전 포스터는 1080x1920 **세로**라, 초광각 폰에 채우면
# 세로로 70% 가 잘려 나가면서 쿼카 두 마리의 머리가 통째로 날아갔다.
# 이건 처음부터 가로로 그린 것이고, 오른쪽 절반이 비어 있어 버튼 기둥이 앉는다.
const POSTER_PATH    := "res://assets/splash/menu-bg-wide.png"
const COUPLE_3D_PATH := "res://assets/mascots/quica-hero-diorama.png"

func _ready() -> void:
	_build_bg_stars()
	_inject_poster_background()
	# 캐릭터+디오라마는 no-text 포스터 에셋에 포함(구조: 포스터 우선 + 코드 UI).
	# Blender 히어로 런타임 오버레이는 디버그용으로만 유지.
	if OS.get_environment("QUPLE_DEBUG_HERO") != "":
		_inject_mascot_couple()

	var cont = $UILayer/Control/VBox/ContinueBtn
	cont.disabled = not SaveManager.has_save()
	$UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
	cont.pressed.connect(_on_continue)
	$UILayer/Control/SmallBtnRow/QuitBtn.pressed.connect(_on_quit)
	$UILayer/Control/SmallBtnRow/SettingsBtn.pressed.connect(
		func(): var sv = get_tree().get_first_node_in_group("settings_ui"); if sv: sv.open())
	_fix_subtitle_overlap()
	_add_credits_button()
	AudioManager.play_bgm("arirang")

	if OS.get_environment("QUPLE_SHOT") != "":
		_capture_shot()

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

	# load() 로 읽는다. 예전에는 globalize_path() + FileAccess 로 **OS 파일 경로**를
	# 뒤졌는데, 그건 에디터에서만 통한다. 내보낸 앱에서 res:// 는 APK·팩 안에 있어서
	# 그런 경로가 존재하지 않는다. 그래서 폰에서는 **항상** 실패했고, 포스터 대신
	# 개발자용 안내문("assets/... 를 추가하면")이 화면에 그대로 떴다.
	var tex: Texture2D = null
	if ResourceLoader.exists(POSTER_PATH):
		tex = load(POSTER_PATH) as Texture2D

	if tex != null:
		var bg = TextureRect.new()
		bg.name = "PosterBG"
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(bg)
		ctrl.move_child(bg, 0)
		_fit_poster(bg)
		ctrl.resized.connect(func(): _fit_poster(bg))
		_add_title_scrim(ctrl)
		return

	# 포스터가 없어도 **완성된 화면**이어야 한다.
	# 개발용 안내문을 사용자에게 보여 주는 건 그 자체로 버그다.
	# 밤하늘 그라데이션을 깔아 두면 별·잎사귀 장식과 이어져 의도된 화면이 된다.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.09, 0.22))
	grad.set_color(1, Color(0.04, 0.03, 0.10))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 64

	var fallback = TextureRect.new()
	fallback.name = "FallbackBG"
	fallback.texture = gt
	fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fallback.stretch_mode = TextureRect.STRETCH_SCALE
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(fallback)
	ctrl.move_child(fallback, 0)

## 제목이 얹히는 왼쪽을 살짝 어둡게 깐다.
##
## 포스터 위에 글자를 그냥 얹으면 쿼카 얼굴과 글자가 서로를 잡아먹는다.
## 영화 포스터가 늘 하는 것처럼, 제목 쪽만 부드럽게 눌러 준다.
## 오른쪽은 건드리지 않는다 — 거기는 캐릭터가 주인공이다.
func _add_title_scrim(ctrl: Control) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.14, 0.12, 0.08, 0.50))
	g.set_color(1, Color(0.14, 0.12, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 8

	var scrim := TextureRect.new()
	scrim.name = "TitleScrim"
	scrim.texture = gt
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.anchor_top = 0.0
	scrim.anchor_bottom = 1.0
	scrim.anchor_left = 0.0
	scrim.anchor_right = 0.62
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(scrim)
	ctrl.move_child(scrim, 1)


## 세로 포스터를 가로 화면에 채운다.
##
## KEEP_ASPECT_COVERED 는 **가운데**를 잘라낸다. 우리 포스터는 세로 3:2 이고
## 폰은 가로 2.2:1 이라 세로로 70% 가 잘려 나가는데, 그 가운데 띠에 얼굴이
## 없다 — 쿼카 두 마리의 머리가 통째로 날아갔다.
## 그래서 직접 계산하고, 자르는 위치를 위쪽으로 당긴다.
const POSTER_BIAS := 0.5   # 0=위 정렬, 0.5=가운데

func _fit_poster(bg: TextureRect) -> void:
	var ctrl := bg.get_parent() as Control
	if ctrl == null or bg.texture == null:
		return
	var view := ctrl.size
	var tsz := bg.texture.get_size()
	if tsz.x <= 0.0 or tsz.y <= 0.0 or view.x <= 0.0:
		return
	var s: float = maxf(view.x / tsz.x, view.y / tsz.y)
	var out := tsz * s
	bg.size = out
	bg.position = Vector2((view.x - out.x) * 0.5, (view.y - out.y) * POSTER_BIAS)


# ─── 3D 마스코트 커플 주입 ───
func _inject_mascot_couple() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return
	# 여기도 같은 이유로 load() 를 쓴다 (내보낸 앱에는 OS 파일 경로가 없다)
	if not ResourceLoader.exists(COUPLE_3D_PATH):
		return
	var tex = load(COUPLE_3D_PATH) as Texture2D
	if tex == null:
		return

	# 히어로 디오라마: 캐릭터+행성 통합 에셋을 중앙 히어로로 배치 (y13~70%)
	var wrap = Control.new()
	wrap.name = "MascotCoupleWrap"
	wrap.anchor_left = 0.5; wrap.anchor_right = 0.5
	wrap.anchor_top = 0.105; wrap.anchor_bottom = 0.63
	wrap.set_offset(SIDE_LEFT,  -440)
	wrap.set_offset(SIDE_RIGHT,  440)
	wrap.set_offset(SIDE_TOP,    0)
	wrap.set_offset(SIDE_BOTTOM, 0)
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

	# (접지 그림자는 히어로 디오라마 에셋에 이미 렌더됨)

	# 3) 히어로 본체 (캐릭터+행성 통합)
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

# ─── 스크린샷 캡처 (QUPLE_SHOT 환경변수) ───
func _capture_shot() -> void:
	await get_tree().create_timer(1.4).timeout
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("QUPLE_SHOT")
	img.save_png(path)
	print("SHOT_SAVED: ", path)
	get_tree().quit()

# ─── 스토리 전환 ───
func _on_start() -> void:
	# 0편을 이미 클리어했다면 건너뛸지 물어본다
	if SaveManager.has_cleared_episode0():
		_ask_skip_prologue()
		return
	_start_new(false)

## 프롤로그를 건너뛸지 선택
func _ask_skip_prologue() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if ctrl == null:
		_start_new(false); return
	if ctrl.has_node("SkipAsk"):
		return
	var wrap := PanelContainer.new()
	wrap.name = "SkipAsk"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.20, 0.96)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 0.85, 0.43, 0.5)
	sb.set_content_margin_all(34)
	wrap.add_theme_stylebox_override("panel", sb)
	wrap.set_anchors_preset(Control.PRESET_CENTER)
	wrap.set_offset(SIDE_LEFT, -400); wrap.set_offset(SIDE_RIGHT, 400)
	wrap.set_offset(SIDE_TOP, -220);  wrap.set_offset(SIDE_BOTTOM, 220)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	var t := Label.new()
	t.text = "0편을 이미 보셨어요"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color(1, 0.95, 0.80))
	v.add_child(t)
	var d := Label.new()
	d.text = "프롤로그를 건너뛰고\n바로 여행을 떠날까요?"
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 36)
	d.add_theme_color_override("font_color", Color(0.88, 0.85, 1.0))
	v.add_child(d)

	var skip := Button.new()
	skip.text = "건너뛰고 여행 시작"
	skip.custom_minimum_size = Vector2(0, 104)
	skip.add_theme_font_size_override("font_size", 44)
	skip.pressed.connect(func(): AudioManager.ui_confirm(); _start_new(true))
	v.add_child(skip)

	var play := Button.new()
	play.text = "0편부터 다시 보기"
	play.custom_minimum_size = Vector2(0, 92)
	play.add_theme_font_size_override("font_size", 44)
	play.pressed.connect(func(): AudioManager.ui_click(); _start_new(false))
	v.add_child(play)

	wrap.add_child(v)
	ctrl.add_child(wrap)

func _start_new(skip_prologue: bool) -> void:
	Episode0State.current_state = Episode0State.State.START
	Episode0State.has_camera = false; Episode0State.has_notebook = false
	Episode0State.has_travel_bag = false; Episode0State.badge_returned = false
	Episode0State.partner_joined = false; Episode0State.first_photo_taken = false
	Episode0State.album_created = false; Episode0State.episode0_cleared = false
	Episode0State.memos_found = []
	TravelState.reset()
	if skip_prologue:
		# 프롤로그를 건너뛰면 0편에서 얻는 것들을 미리 갖춘 채 여행을 시작한다
		Episode0State.has_camera = true
		Episode0State.has_notebook = true
		Episode0State.has_travel_bag = true
		Episode0State.badge_returned = true
		Episode0State.partner_joined = true
		Episode0State.advance_to(Episode0State.State.CLEAR)
		SaveManager.autosave("res://scenes/travel/TravelHub.tscn")
		SceneTransition.go_to("res://scenes/travel/TravelHub.tscn", "hopeful")
	else:
		SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

func _on_continue() -> void:
	SaveManager.load_game()
	SceneTransition.go_to(SaveManager.get_current_scene())

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
## 부제가 두 개 겹쳐 찍히고 있었다. 아래로 옮겨도 이번엔 시작 버튼과 부딪힌다.
## 로고 아래는 한 줄이면 충분하다 — 둘 다 같은 말을 하고 있었다.
func _fix_subtitle_overlap() -> void:
	var copy := get_node_or_null("UILayer/Control/CopyLabel")
	if copy != null:
		copy.visible = false


## 만든사람. 게임을 만든 도구와 저작권 표시를 남기는 자리이기도 하다 —
## 폰트와 곡이 전부 자유 라이선스라 출처를 밝혀야 한다.
func _add_credits_button() -> void:
	var row := get_node_or_null("UILayer/Control/SmallBtnRow")
	if row == null:
		return
	var src: Button = row.get_node_or_null("SettingsBtn")
	var b := Button.new()
	b.text = "🎬 만든사람"
	b.focus_mode = Control.FOCUS_NONE
	if src != null:
		b.custom_minimum_size = src.custom_minimum_size
		for st in ["normal", "hover", "pressed"]:
			var sb := src.get_theme_stylebox(st)
			if sb != null:
				b.add_theme_stylebox_override(st, sb)
		b.add_theme_font_size_override("font_size",
			src.get_theme_font_size("font_size"))
		b.add_theme_color_override("font_color", src.get_theme_color("font_color"))
	b.pressed.connect(_show_credits)
	row.add_child(b)
	row.move_child(b, 1)


func _show_credits() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.09, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	dim.add_child(box)

	var lines := [
		["쿼플", 54, Color(1, 0.93, 0.78)],
		["쿼카 커플의 힐링 여행", 30, Color(1, 0.86, 0.62)],
		["", 18, Color.WHITE],
		["기획 · 개발 · 아트", 26, Color(0.82, 0.86, 0.96)],
		["Godot 4.3 · Blender · Python", 24, Color(0.72, 0.78, 0.90)],
		["", 18, Color.WHITE],
		["글꼴  Jua (SIL Open Font License)", 22, Color(0.72, 0.78, 0.90)],
		["음악  한국 동요 편곡 (저작권 만료)", 22, Color(0.72, 0.78, 0.90)],
		["", 18, Color.WHITE],
		["화면을 누르면 닫혀요", 24, Color(1, 0.86, 0.62)],
	]
	for l in lines:
		var lb := Label.new()
		lb.text = str(l[0])
		lb.add_theme_font_size_override("font_size", int(l[1]))
		lb.add_theme_color_override("font_color", l[2])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lb)

	# 아무 데나 눌러 닫는다. 폰에는 Esc 가 없다.
	var close := Button.new()
	close.flat = true
	close.set_anchors_preset(Control.PRESET_FULL_RECT)
	close.pressed.connect(layer.queue_free)
	layer.add_child(close)


func _build_ui_decorations() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return
	# 좌표는 1280×720 기준이다. 예전 값은 세로 화면에서 잡은 것이라
	# 절반이 화면 밖(y 940)에 있었고, 남은 것도 버튼 위에 얹혔다.
	# 오른쪽 버튼 기둥(x 700 이상)은 비워 둔다.
	var sparks = [
		{"pos": Vector2(96, 128), "size": 26, "txt": "✦"},
		{"pos": Vector2(612, 96), "size": 22, "txt": "✦"},
		{"pos": Vector2(74, 430), "size": 20, "txt": "★"},
		{"pos": Vector2(640, 400), "size": 18, "txt": "★"},
		{"pos": Vector2(150, 604), "size": 22, "txt": "✦"},
		{"pos": Vector2(520, 640), "size": 18, "txt": "✦"},
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

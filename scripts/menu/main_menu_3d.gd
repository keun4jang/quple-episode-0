extends Node3D

@onready var camera: Camera3D = $Camera3D
var _t := 0.0

# 가로 화면용 배경. 예전 포스터는 1080x1920 **세로**라, 초광각 폰에 채우면
# 세로로 70% 가 잘려 나가면서 쿼카의 머리가 통째로 날아갔다.
# 이건 처음부터 가로로 그린 것이고, 오른쪽 절반이 비어 있어 버튼 기둥이 앉는다.
const POSTER_PATH    := "res://assets/splash/menu-bg-wide.png"
const HERO_3D_PATH := "res://assets/mascots/quica-hero-diorama.png"

func _ready() -> void:
	_inject_poster_background()
	# 캐릭터+디오라마는 no-text 포스터 에셋에 포함(구조: 포스터 우선 + 코드 UI).
	# Blender 히어로 런타임 오버레이는 디버그용으로만 유지.
	if OS.get_environment("QUPLE_DEBUG_HERO") != "":
		_inject_mascot_hero()

	var cont = $UILayer/Control/VBox/ContinueBtn
	cont.disabled = not SaveManager.has_save()
	$UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
	cont.pressed.connect(_on_continue)
	$UILayer/Control/SmallBtnRow/QuitBtn.pressed.connect(_on_quit)
	$UILayer/Control/SmallBtnRow/SettingsBtn.pressed.connect(
		func(): var sv = get_tree().get_first_node_in_group("settings_ui"); if sv: sv.open())
	_add_credits_button()
	AudioManager.play_bgm("arirang")

	if OS.get_environment("QUPLE_SHOT") != "":
		_capture_shot()

	_build_ui_decorations()
	_add_title()
	_add_subtitle()

func _process(delta: float) -> void:
	_t += delta
	# 제목 숨쉬기. 그림이면 그림, 아니면 글자.
	var title = get_node_or_null("UILayer/Control/LogoImage")
	if title == null or not title.visible:
		title = get_node_or_null("UILayer/Control/TitleText")
	if title:
		var k: float = 1.0 + sin(_t * 1.4) * 0.012
		title.scale = Vector2(k, k)
		title.pivot_offset = title.size * 0.5

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

## 제목이 얹히는 **위쪽**을 살짝 어둡게 깐다.
##
## 원래는 왼쪽을 눌렀다. 그때는 포스터의 왼쪽이 하늘이었기 때문이다.
## 새 포스터는 **왼쪽이 쿼카**다 — 그대로 두니 주인공만 3.13:1 로
## 어두워지고, 정작 제목이 앉는 가운데는 스크림이 이미 투명해진 자리라
## 아무 도움도 못 받고 있었다.
##
## 제목은 위 가운데에 있다. 눌러야 할 곳도 거기다.
func _add_title_scrim(ctrl: Control) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.14, 0.12, 0.08, 0.34))
	g.set_color(1, Color(0.14, 0.12, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 128

	var scrim := TextureRect.new()
	scrim.name = "TitleScrim"
	scrim.texture = gt
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.anchor_left = 0.0
	scrim.anchor_right = 1.0
	scrim.anchor_top = 0.0
	scrim.anchor_bottom = 0.0
	scrim.offset_bottom = 300.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(scrim)
	ctrl.move_child(scrim, 1)


## 세로 포스터를 가로 화면에 채운다.
##
## KEEP_ASPECT_COVERED 는 **가운데**를 잘라낸다. 우리 포스터는 세로 3:2 이고
## 폰은 가로 2.2:1 이라 세로로 70% 가 잘려 나가는데, 그 가운데 띠에 얼굴이
## 없다 — 쿼카의 머리가 통째로 날아갔다.
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


# ─── 3D 마스코트 히어로 주입 (디버그 전용) ───
func _inject_mascot_hero() -> void:
	var ctrl = get_node_or_null("UILayer/Control")
	if not ctrl:
		return
	# 여기도 같은 이유로 load() 를 쓴다 (내보낸 앱에는 OS 파일 경로가 없다)
	if not ResourceLoader.exists(HERO_3D_PATH):
		return
	var tex = load(HERO_3D_PATH) as Texture2D
	if tex == null:
		return

	# 히어로 디오라마: 캐릭터+행성 통합 에셋을 중앙 히어로로 배치 (y13~70%)
	var wrap = Control.new()
	wrap.name = "MascotHeroWrap"
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
	rect.name = "MascotHero3D"
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
	# 프롤로그(쿼카컴퍼니)를 이미 지나온 적이 있으면 건너뛸지 물어본다
	if SaveManager.has_seen_prologue():
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
	t.text = "처음 이야기를 이미 보셨어요"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color(1, 0.95, 0.80))
	v.add_child(t)
	var d := Label.new()
	d.text = "처음 이야기를 건너뛰고\n바로 떠날까요?"
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
	play.text = "처음부터 다시 보기"
	play.custom_minimum_size = Vector2(0, 92)
	play.add_theme_font_size_override("font_size", 44)
	play.pressed.connect(func(): AudioManager.ui_click(); _start_new(false))
	v.add_child(play)

	wrap.add_child(v)
	ctrl.add_child(wrap)

func _start_new(skip_prologue: bool) -> void:
	# 새로 시작하면 쿼카컴퍼니(프롤로그)부터. 건너뛰면 첫 여행지로 간다.
	JourneyState.reset()
	if skip_prologue:
		SaveManager.autosave("res://scenes/journey/Yunseul.tscn")
		SceneTransition.go_to("res://scenes/journey/Yunseul.tscn", "hopeful")
	else:
		SaveManager.autosave(SaveManager.HUB)
		SceneTransition.go_to(SaveManager.HUB)

func _on_continue() -> void:
	SaveManager.load_game()
	SceneTransition.go_to(SaveManager.get_current_scene())

func _on_quit() -> void:
	get_tree().quit()

# ─── 배경 별 (3D 앰비언트) ───
## 제목.
##
## 그림이 있으면 그림을 쓰고, 없으면 게임 폰트로 그린다.
##
## 한동안 글자로만 그렸다. 옛 로고 그림이 "쿼플" 이라는 **글자 모양
## 자체**여서, 이름이 바뀐 뒤로는 쓸 수가 없었기 때문이다. 새 그림이
## 왔으니 그림을 쓰되, 못 읽는 경우를 대비해 글자 쪽을 남겨 둔다 —
## 첫 화면이 비는 것보다 폰트로라도 제목이 있는 편이 낫다.
const TITLE_PATH := "res://assets/splash/logo-title.png"

func _add_title() -> void:
	var logo := get_node_or_null("UILayer/Control/LogoImage") as TextureRect
	if logo == null:
		return
	if logo.texture != null:
		logo.visible = true
		return

	logo.visible = false
	var t := Label.new()
	t.name = "TitleText"
	t.text = "진짜 행복"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 92)
	t.add_theme_color_override("font_color", Color(0.99, 0.97, 0.90))
	t.add_theme_color_override("font_outline_color", Color(0.36, 0.44, 0.30))
	t.add_theme_constant_override("outline_size", 20)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_left = logo.anchor_left
	t.anchor_right = logo.anchor_right
	t.offset_left = logo.offset_left
	t.offset_right = logo.offset_right
	t.offset_top = logo.offset_top
	t.offset_bottom = logo.offset_bottom + 60.0
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.get_parent().add_child(t)


## 제목 아래 한 줄.
##
## 예전엔 이 문구가 **로고 그림에 구워져** 있었다 — "쿼카 커플의 힐링
## 여행". 그림이라 고칠 수가 없어서, 커플을 접은 뒤로도 첫 화면에 그대로
## 떠 있었다. 그림에서 그 줄을 떼어내고 여기서 글자로 그린다.
## (`CLAUDE.md`: 포스터는 글자 없는 그림이어야 하고 문구는 코드로 렌더한다)
func _add_subtitle() -> void:
	var logo := get_node_or_null("UILayer/Control/LogoImage") as Control
	if logo == null:
		return
	var l := Label.new()
	l.name = "Subtitle"
	l.text = "혼자 떠나는 쿼카의 힐링 여행"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(0.42, 0.36, 0.30))
	l.add_theme_color_override("font_outline_color", Color(1, 0.99, 0.95, 0.75))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.anchor_left = logo.anchor_left
	l.anchor_right = logo.anchor_right
	l.offset_left = logo.offset_left - 60.0
	l.offset_right = logo.offset_right + 60.0
	l.offset_top = logo.offset_bottom + 18.0
	l.offset_bottom = l.offset_top + 40.0
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.get_parent().add_child(l)


# 배경 별(3D 발광 구체 135개)은 지웠다.
#
# 포스터가 알파 없는 불투명 그림이고 화면을 덮도록 늘어난다. 그 뒤에
# 있는 별은 **한 번도 보인 적이 없다.** 그런데 `_process` 가 매 프레임
# 135개 머티리얼의 발광 세기를 고쳐 쓰고 있었다 — 안 보이는 것을 위해
# 폰이 계속 더워졌다. 포스터가 없을 때 깔리는 그라데이션도 불투명이라
# 어느 쪽으로도 드러날 자리가 없다.


## 만든사람. 게임을 만든 도구와 저작권 표시를 남기는 자리이기도 하다 —
## 폰트와 곡이 전부 자유 라이선스라 출처를 밝혀야 한다.
func _add_credits_button() -> void:
	var row := get_node_or_null("UILayer/Control/SmallBtnRow")
	if row == null:
		return
	var src: Button = row.get_node_or_null("SettingsBtn")
	var b := Button.new()
	b.text = "만든 사람"
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
		["진짜 행복", 54, Color(1, 0.93, 0.78)],
		["혼자 떠나는 쿼카의 힐링 여행", 30, Color(1, 0.86, 0.62)],
		["", 18, Color.WHITE],
		["1인 개발  김근영", 28, Color(0.96, 0.92, 0.82)],
		["기획 · 개발 · 아트", 26, Color(0.82, 0.86, 0.96)],
		["Godot 4.3 · Blender · Python", 24, Color(0.72, 0.78, 0.90)],
		["", 18, Color.WHITE],
		["글꼴  PoorStory (SIL Open Font License)", 22, Color(0.72, 0.78, 0.90)],
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
		{"pos": Vector2(96, 128), "size": 26, "txt": "*"},
		{"pos": Vector2(612, 96), "size": 22, "txt": "*"},
		{"pos": Vector2(74, 430), "size": 20, "txt": "*"},
		{"pos": Vector2(640, 400), "size": 18, "txt": "*"},
		{"pos": Vector2(150, 604), "size": 22, "txt": "*"},
		{"pos": Vector2(520, 640), "size": 18, "txt": "*"},
	]
	for sd in sparks:
		var lbl = Label.new()
		lbl.text = sd.txt
		lbl.add_theme_font_size_override("font_size", sd.size)
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.72, 0.80))
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.position = sd.pos; lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(lbl)

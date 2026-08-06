extends CanvasLayer
## 돌아온 순간.
##
## 여행이 끝나도 조용히 목록에 한 줄 늘어날 뿐이었다. 다시 켤 이유가 여기서
## 만들어져야 하는데 아무 사건도 일어나지 않았다.
##
## 그래서 도착을 **장면**으로 만든다. 말은 거의 없고, 보는 것으로 끝난다.
##   1) 화면이 그 시각의 하늘빛으로 어두워진다
##   2) 지평선 저 끝에 점 두 개가 생겨 천천히 걸어온다 (발밑에 먼지)
##   3) 문 앞에 짐을 툭 내려놓는다
##   4) 기다린 만큼 쪽지가 한 장씩 내려앉는다 (며칠 만에 켰으면 문 앞이 두툼하다)
##   5) 짧은 한 줄. 그리고 멈춰 있는다
##
## 축포도 점수도 없다. "아, 다녀왔구나" 하고 잠깐 멈추는 것이 전부다.
## 화면을 누르면 건너뛰고(연출 중) / 닫는다(끝난 뒤).

signal finished

const TW := preload("res://scripts/ui/text_wrap.gd")

const D := preload("res://scripts/ui/design.gd")
const MoodPalette := preload("res://scripts/systems/mood_palette.gd")
const COUPLE_TEX := "res://assets/mascots/quica-couple-splash.png"
## 그림 안에서 발이 닿는 높이 (이미지 위쪽부터의 비율).
## 그래야 발이 지평선에 붙는다 — 그림 한가운데를 기준으로 잡으면 공중에 뜬다.
const FOOT_FRAC := 0.78
## 그림 안에서 둘이 실제로 차지하는 세로 비율 (위아래 여백을 뺀 값)
const FIGURE_FRAC := 0.51

## 걸어오는 데 걸리는 시간. 서두르면 사건이 아니라 알림이 된다.
const WALK_SEC := 2.6
## 발소리 간격
const STEP_SEC := 0.42

var _screen: Control
var _backdrop: ColorRect
var _sky: TextureRect
var _ground: ColorRect
var _walker: Control
var _couple: TextureRect
var _bag: Label
var _line: Label
var _sub: Label
var _notes_box: Control
var _hint: Label

var _note_cards: Array[Control] = []
var _tween: Tween = null
var _walking := false
var _step_t := 0.0
var _bob := 0.0
var _done := false
var _closing := false
var _vp := Vector2(1280, 720)

func _ready() -> void:
	layer = 6
	_vp = Vector2(1280, 720)
	var vp := get_viewport()
	if vp:
		_vp = vp.get_visible_rect().size
	_build()
	_play()

# ── 화면 ────────────────────────────────────────────────────────────────

func _build() -> void:
	var m: Dictionary = MoodPalette.now()
	var sky_top: Color = m.get("sky_top", Color(0.22, 0.21, 0.40))
	var sky_low: Color = m.get("sky_horizon", Color(0.72, 0.66, 0.80))
	var soil: Color = m.get("ground_bottom", Color(0.20, 0.20, 0.32))

	_screen = Control.new()
	_screen.name = "Screen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.gui_input.connect(_on_input)
	add_child(_screen)

	# 뒤 화면을 덮는다. 열린 화면 뒤는 어둡게 깔고 조작 UI 는 감춘다.
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(D.INK.r, D.INK.g, D.INK.b, 1.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_backdrop)

	# 그 시각의 하늘. 밤에 돌아오면 밤하늘 아래로 걸어온다.
	_sky = TextureRect.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.texture = _gradient(sky_top.darkened(0.25), sky_low.darkened(0.30))
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_sky)

	# 땅. 지평선이 있어야 "걸어온다" 가 읽힌다.
	_ground = ColorRect.new()
	_ground.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ground.offset_top = -_vp.y * 0.34   # 지평선이 발밑에 오게
	_ground.color = Color(0, 0, 0, 0)
	var soil_tex := TextureRect.new()
	soil_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	soil_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	soil_tex.stretch_mode = TextureRect.STRETCH_SCALE
	soil_tex.texture = _gradient(
		Color(soil.r * 0.78, soil.g * 0.74, soil.b * 0.72),
		Color(soil.r * 0.42, soil.g * 0.40, soil.b * 0.46))
	soil_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.add_child(soil_tex)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_ground)

	# 걸어오는 둘. 위치는 _walker 가, 걸음의 출렁임은 _couple 이 맡는다.
	# (한 노드에 둘 다 걸면 트윈과 흔들림이 서로를 덮어쓴다)
	_walker = Control.new()
	_walker.name = "Walker"
	_walker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_walker)

	_couple = TextureRect.new()
	_couple.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_couple.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 화면에서 둘이 이만큼 커 보이게 (720 높이 기준 약 300px)
	var fig := _vp.y * 0.34
	var rect_h := fig / FIGURE_FRAC
	_couple.size = Vector2(rect_h * 2048.0 / 1536.0, rect_h)
	_couple.position = _couple_home()
	# 커지고 작아지는 기준점은 발밑이다. 가운데를 잡으면 땅을 파고든다.
	_couple.pivot_offset = Vector2(_couple.size.x / 2.0, _couple.size.y * FOOT_FRAC)
	_couple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := load(COUPLE_TEX)
	if tex:
		_couple.texture = tex
	_walker.add_child(_couple)

	# 짐 — 걸음이 끝나면 문 앞에 툭 내려놓는다
	_bag = Label.new()
	_bag.text = "🎒"
	_bag.add_theme_font_size_override("font_size", D.TEXT_XL)
	_bag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_bag.size = Vector2(96, 76)
	_bag.pivot_offset = Vector2(48, 38)
	_bag.modulate = Color(1, 1, 1, 0)
	_bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_bag)

	# 쪽지가 쌓이는 자리 (왼쪽 아래, 엄지에 닿지 않는 쪽)
	_notes_box = Control.new()
	_notes_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_notes_box.position = Vector2(_vp.x - 424.0, _vp.y * 0.28)
	_notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_notes_box)

	# 말은 두 줄까지만.
	_line = _text(TravelState.arrival_line(), D.TEXT_L, D.TEXT)
	_line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_line.offset_top = -_vp.y * 0.26
	_line.offset_bottom = -_vp.y * 0.26 + 60.0
	_screen.add_child(_line)

	_sub = _text("", D.TEXT_S, D.TEXT_DIM)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sub.offset_top = -_vp.y * 0.26 + 56.0
	_sub.offset_bottom = -_vp.y * 0.26 + 108.0
	_screen.add_child(_sub)

	_hint = _text("화면을 누르면 계속", D.TEXT_S, D.TEXT_DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -64.0
	_hint.offset_bottom = -16.0
	_hint.modulate = Color(1, 1, 1, 0)
	_screen.add_child(_hint)

	# 쪽지 카드는 미리 만들어 두고 하나씩 내려앉힌다
	var notes: Array = TravelState.waiting_notes()
	for i in range(notes.size()):
		var card := _make_note(notes[i] as Dictionary, i)
		_notes_box.add_child(card)
		_note_cards.append(card)
	if notes.size() > 0:
		_sub.text = "문 앞에 쪽지가 %d장 놓여 있어요" % notes.size()

## _walker 를 발밑 한가운데로 두기 위한 그림 위치
func _couple_home() -> Vector2:
	return Vector2(-_couple.size.x / 2.0, -_couple.size.y * FOOT_FRAC)

func _text(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", D.OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 문틈에 끼워둔 쪽지 한 장
func _make_note(n: Dictionary, i: int) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.89, 0.96)
	sb.set_corner_radius_all(D.ROUND_S)
	sb.set_content_margin_all(D.GAP_M)
	sb.shadow_color = Color(0.05, 0.03, 0.15, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pc.size = Vector2(360, 0)
	pc.custom_minimum_size = Vector2(360, 0)
	# 손으로 대충 겹쳐 놓은 것처럼 조금씩 어긋나게 (화면 끝으로는 밀지 않는다)
	pc.position = Vector2(-i * 12, i * 92 - 40)
	pc.rotation = deg_to_rad(-3.0 + float(i) * 2.4)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.modulate = Color(1, 1, 1, 0)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", D.GAP_M)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := Label.new()
	e.text = str(n.get("emoji", "📮"))
	e.add_theme_font_size_override("font_size", D.TEXT_L)
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(e)
	var t := Label.new()
	t.text = str(n.get("text", ""))
	t.add_theme_font_size_override("font_size", D.TEXT_S)
	t.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	TW.keep_words(t)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	pc.add_child(h)
	return pc

## 세로 그라데이션 한 장. 화면 크기로 늘려 쓴다.
func _gradient(top: Color, bottom: Color) -> ImageTexture:
	var img := Image.create(4, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		var c := top.lerp(bottom, float(y) / 63.0)
		for x in range(4):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# ── 연출 ────────────────────────────────────────────────────────────────

## 저 멀리 (작게) → 문 앞 (크게). 글자 자리와 쪽지 자리를 비워 둔 배치다.
func _far_pos() -> Vector2:
	return Vector2(_vp.x * 0.52, _vp.y * 0.56)

func _near_pos() -> Vector2:
	return Vector2(_vp.x * 0.40, _vp.y * 0.66)

func _bag_pos() -> Vector2:
	return Vector2(_vp.x * 0.40 + _vp.y * 0.20, _vp.y * 0.66 - 60.0)

func _play() -> void:
	# 여행 한 번에 한 번만. 연출 도중에 앱이 죽어도 다시 재생하지 않는다.
	TravelState.mark_arrival_seen()

	_walker.position = _far_pos()
	_couple.scale = Vector2(0.16, 0.16)
	_couple.modulate = Color(0.30, 0.28, 0.36, 0.0)   # 멀리 있을 땐 실루엣
	_backdrop.modulate = Color(1, 1, 1, 0)
	_sky.modulate = Color(1, 1, 1, 0)
	_ground.modulate = Color(1, 1, 1, 0)
	_line.modulate = Color(1, 1, 1, 0)
	_sub.modulate = Color(1, 1, 1, 0)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_backdrop, "modulate", Color(1, 1, 1, 1), 0.6)
	_tween.tween_property(_sky, "modulate", Color(1, 1, 1, 1), 0.8)
	_tween.tween_property(_ground, "modulate", Color(1, 1, 1, 1), 0.8)
	# 점 두 개가 생겨서 커진다
	_tween.tween_property(_couple, "modulate", Color(0.34, 0.32, 0.40, 1.0), 0.7) \
		.set_delay(0.35)
	_tween.set_parallel(false)
	_tween.tween_interval(0.35)
	_tween.tween_callback(func(): _walking = true)
	_tween.set_parallel(true)
	_tween.tween_property(_walker, "position", _near_pos(), WALK_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_couple, "scale", Vector2.ONE, WALK_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_couple, "modulate", Color(1, 1, 1, 1), WALK_SEC)
	_tween.set_parallel(false)
	_tween.tween_callback(func(): _walking = false)
	# 짐을 내려놓는다
	_tween.tween_callback(_drop_bag)
	_tween.tween_interval(0.55)
	_tween.set_parallel(true)
	_tween.tween_property(_line, "modulate", Color(1, 1, 1, 1), 0.5)
	_tween.tween_property(_sub, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.2)
	_tween.set_parallel(false)
	# 기다린 만큼 쪽지가 내려앉는다
	for i in range(_note_cards.size()):
		_tween.tween_callback(_drop_note.bind(i))
		_tween.tween_interval(0.35)
	_tween.tween_callback(_on_done)

func _drop_bag() -> void:
	var to := _bag_pos()
	_bag.position = to - Vector2(0, _vp.y * 0.12)
	_bag.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_bag, "position", to, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_callback(func():
		AudioManager.footstep()
		_dust(to + Vector2(48, 66), 5))

func _drop_note(i: int) -> void:
	if i >= _note_cards.size():
		return
	var card := _note_cards[i]
	var to := card.position
	card.position = to - Vector2(0, 60)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.35)
	tw.tween_property(card, "position", to, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if i == 0:
		AudioManager.message_arrive()

## 발밑 먼지. CPUParticles 는 크기가 말을 안 들어서 사고가 났던 적이 있다.
## 작은 알갱이 몇 개를 직접 띄우는 편이 눈에 보이는 대로 나온다.
func _dust(at: Vector2, n: int) -> void:
	var soil := Color(0.86, 0.82, 0.74, 0.55)
	for i in range(n):
		var dot := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = soil
		sb.set_corner_radius_all(D.ROUND_PILL)
		dot.add_theme_stylebox_override("panel", sb)
		var r := 6.0 + float(i % 3) * 3.0
		dot.size = Vector2(r, r)
		dot.position = at - Vector2(r, r) / 2.0
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(dot)
		var dir := Vector2(-1.0 + 2.0 * float(i) / maxf(1.0, float(n - 1)), -0.5)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(dot, "position", dot.position + dir * (26.0 + r * 2.0), 0.7) \
			.set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "modulate", Color(1, 1, 1, 0), 0.7)
		tw.chain().tween_callback(dot.queue_free)

func _on_done() -> void:
	_done = true
	_hint.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_hint, "modulate", Color(1, 1, 1, 0.9), 0.6)

func _process(delta: float) -> void:
	if not _walking:
		return
	# 걸음의 출렁임. 가까워질수록 폭이 커진다.
	_bob += delta * 7.0
	var amp: float = 6.0 * _couple.scale.y
	_couple.position.y = _couple_home().y - absf(sin(_bob)) * amp
	_step_t += delta
	if _step_t >= STEP_SEC:
		_step_t = 0.0
		AudioManager.footstep()

# ── 넘기기 / 닫기 ───────────────────────────────────────────────────────

func _on_input(ev: InputEvent) -> void:
	var tapped := false
	if ev is InputEventMouseButton:
		tapped = (ev as InputEventMouseButton).pressed
	elif ev is InputEventScreenTouch:
		tapped = (ev as InputEventScreenTouch).pressed
	if not tapped:
		return
	if not _done:
		skip()
	else:
		close()

## 연출을 끝 상태로 바로 옮긴다 (건너뛰기)
func skip() -> void:
	if _done:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_walking = false
	_backdrop.modulate = Color(1, 1, 1, 1)
	_sky.modulate = Color(1, 1, 1, 1)
	_ground.modulate = Color(1, 1, 1, 1)
	_walker.position = _near_pos()
	_couple.scale = Vector2.ONE
	_couple.modulate = Color(1, 1, 1, 1)
	_couple.position = _couple_home()
	_bag.position = _bag_pos()
	_bag.modulate = Color(1, 1, 1, 1)
	_line.modulate = Color(1, 1, 1, 1)
	_sub.modulate = Color(1, 1, 1, 1)
	for c in _note_cards:
		c.modulate = Color(1, 1, 1, 1)
	_on_done()

func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_screen, "modulate", Color(1, 1, 1, 0), 0.35)
	tw.tween_callback(func():
		finished.emit()
		queue_free())

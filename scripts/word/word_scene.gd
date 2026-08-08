extends Control
## 마법영자문 장면 하나.
##
##   막힌 곳을 만난다 → 무슨 마법이 필요한지 보인다 → 철자를 놓는다
##   → 마법이 터진다 → 길이 열린다 → 도감에 남는다
##
## 한 단어가 한 사건이다. 이 흐름 하나가 재미없으면 단어를 400개 넣어도
## 소용없으므로, 먼저 이것만 끝까지 만든다.

signal scene_cleared(word: String)

## 어느 장면을 열지. 비워 두면 첫 장면.
@export var scene_id := "ice_wall"
## 테스트에서 연출을 기다리지 않고 넘기려고 쓴다.
@export var instant := false

var data: Dictionary = {}
var spell: SpellBar

var _bg: Node2D
var _ice: ColorRect
var _leader: TextureRect
var _partner: TextureRect
var _face: FaceCut
var _bubble: PanelContainer
var _line: Label
var _prompt: Label
var _dex_chip: Label
var _flash: ColorRect
var _panel: ColorRect
var _ice_shadow: ColorRect
var _t := 0.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	data = WordData.scene_by_id(scene_id)
	if data.is_empty():
		data = WordData.SCENES[0]

	_build_background()
	_build_characters()
	_build_bubble()
	_build_spell()
	_build_hud()
	if not instant:
		_play_intro()
	else:
		_show_spell()


# ── 배경 ──────────────────────────────────────────────────────────────
#
# 픽셀 화풍으로 갈아입기 전이라 도형으로 그린다. 색은 기존 팔레트에서
# 가져와 나중에 픽셀 변환을 그대로 태울 수 있게 둔다.

## 화면을 위아래로 나눈다. 위는 장면, 아래는 마법 거는 자리.
##
## 처음엔 한 화면에 다 얹었더니 쿼카가 철자 칸 위에 올라앉았다. 아이가
## 누를 곳과 볼 곳은 겹치면 안 된다.
const GROUND := 424.0        # 발이 닿는 선
const HORIZON := 330.0       # 하늘과 눈밭의 경계
const PANEL_TOP := 430.0     # 여기부터 아래는 마법 칸

func _build_background() -> void:
	var vp := Vector2(1280, 720)
	_bg = Node2D.new()
	add_child(_bg)

	_rect(_bg, Vector2.ZERO, Vector2(vp.x, HORIZON), Color("#8FB6D6"))          # 하늘
	_rect(_bg, Vector2(0, HORIZON), Vector2(vp.x, vp.y), Color("#E4EEF4"))       # 눈밭
	# 멀리 보이는 산
	for i in 3:
		var p := Polygon2D.new()
		var x := 180.0 + i * 420.0
		p.polygon = PackedVector2Array([
			Vector2(x - 300, HORIZON), Vector2(x, 90.0 + i * 30.0),
			Vector2(x + 300, HORIZON)])
		p.color = Color("#A9C6DC").darkened(i * 0.05)
		_bg.add_child(p)

	# 길을 막은 얼음 벽. 화면 안에 온전히 들어와야 "막혔다"가 읽힌다.
	_ice = ColorRect.new()
	_ice.color = Color("#5FBBD8")
	_ice.size = Vector2(250, 290)
	_ice.position = Vector2(940, GROUND - _ice.size.y)
	_ice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ice)
	# 결. 밝은 줄을 넣어야 벽이 아니라 **얼음**으로 보인다.
	for i in 4:
		var st := ColorRect.new()
		st.color = Color(1, 1, 1, 0.30)
		st.size = Vector2(20, _ice.size.y)
		st.position = Vector2(26 + i * 58, 0)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ice.add_child(st)
	# 눈밭에 지는 그림자. 이게 없으면 벽이 공중에 떠 보인다.
	var sh := ColorRect.new()
	sh.color = Color(0.44, 0.56, 0.66, 0.35)
	sh.size = Vector2(300, 22)
	sh.position = Vector2(915, GROUND - 8)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sh)
	_ice_shadow = sh

	# 아래 판. 마법 칸이 배경에 묻히지 않게 바닥을 깔아 준다.
	_panel = ColorRect.new()
	_panel.color = Color(0.16, 0.13, 0.18, 0.82)
	_panel.position = Vector2(0, PANEL_TOP)
	_panel.size = Vector2(vp.x, vp.y - PANEL_TOP)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)

	_flash = ColorRect.new()
	_flash.color = Color(1, 0.94, 0.72, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _rect(p: Node, pos: Vector2, to: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = to - pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)


const MASCOT := Vector2(152, 212)

func _build_characters() -> void:
	# 얼음 벽 앞에 선다. 둘과 벽 사이가 비어 있어야 "막혔다"가 보인다.
	_leader = _mascot("res://assets/mascots/sheet/leader-front.png", 580.0)
	_partner = _mascot("res://assets/mascots/sheet/partner-front.png", 720.0)


func _mascot(path: String, x: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = MASCOT
	t.size = MASCOT
	t.position = Vector2(x, GROUND - MASCOT.y + 8.0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


# ── 말풍선 + 표정 컷 ──────────────────────────────────────────────────

func _build_bubble() -> void:
	var box := HBoxContainer.new()
	box.name = "Bubble"
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(60, 60)
	box.custom_minimum_size = Vector2(900, 0)
	add_child(box)

	_face = FaceCut.new("partner", "cold")
	_face.custom_minimum_size = Vector2(150, 150)
	box.add_child(_face)

	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(6)
	sb.border_color = Color("#8C7B68")
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_bubble)

	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 46)
	_line.add_theme_color_override("font_color", Color("#3A2C2C"))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(560, 0)
	_bubble.add_child(_line)


func _build_spell() -> void:
	# 물음은 마법 칸 **바로 위**에 둔다. 어두운 판 위라 흰 글씨가 읽힌다.
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 40)
	_prompt.add_theme_color_override("font_color", Color("#FFF2C8"))
	_prompt.position = Vector2(0, PANEL_TOP + 8)
	_prompt.size = Vector2(1280, 48)
	_prompt.visible = false
	add_child(_prompt)

	spell = SpellBar.new()
	spell.name = "SpellBar"
	spell.position = Vector2(0, PANEL_TOP + 54)
	spell.size = Vector2(1280, 720 - PANEL_TOP - 64)
	spell.visible = false
	spell.completed.connect(_on_spell_completed)
	add_child(spell)


func _build_hud() -> void:
	_dex_chip = Label.new()
	_dex_chip.text = "📖 %d" % WordDex.count()
	_dex_chip.add_theme_font_size_override("font_size", 40)
	_dex_chip.add_theme_color_override("font_color", Color("#3A2C2C"))
	_dex_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dex_chip.position = Vector2(1280 - 260, 20)
	_dex_chip.size = Vector2(230, 52)
	_dex_chip.z_index = 15
	add_child(_dex_chip)


# ── 진행 ──────────────────────────────────────────────────────────────

func _play_intro() -> void:
	await _say_all(data.get("before", []))
	_show_spell()


func _say_all(lines: Array) -> void:
	for l in lines:
		_say(String(l[0]), String(l[1]), String(l[2]))
		if instant:
			continue
		await get_tree().create_timer(1.6).timeout


func _say(who: String, mood: String, text: String) -> void:
	_bubble.visible = true
	_face.visible = true
	_face.set_who(who)
	_face.set_mood(mood)
	_line.text = text


func _show_spell() -> void:
	_prompt.text = String(data.get("prompt", ""))
	_prompt.visible = true
	spell.visible = true
	_panel.visible = true
	if WordDex.tier == WordData.Tier.SEED:
		spell.setup_choices(data.get("choices", []), String(data["word"]))
	else:
		# 산 단계는 뜻만 보여 준다 — 그림 힌트를 뺀다.
		if WordDex.tier == WordData.Tier.MOUNTAIN:
			_prompt.text = "%s → ?" % String(data.get("ko", ""))
		spell.setup(String(data["word"]), WordDex.tier, data.get("extra", []))


func _on_spell_completed(word: String) -> void:
	if _done:
		return
	_done = true
	spell.visible = false
	_prompt.visible = false
	_panel.visible = false
	_bubble.visible = false
	_face.visible = false

	WordDex.learn(word, data, String(data.get("dex_note", "")))
	WordDex.mark_cleared(String(data.get("id", "")))
	_dex_chip.text = "📖 %d" % WordDex.count()
	SaveManager.save_now()

	if instant:
		_melt_now()
		scene_cleared.emit(word)
		return
	await _cast(word)
	await _say_all(data.get("after", []))
	scene_cleared.emit(word)


## 마법 발동 컷
func _cast(word: String) -> void:
	var big := Label.new()
	big.text = "%s %s!" % [String(data.get("emoji", "")), word.to_upper()]
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 150)
	big.add_theme_color_override("font_color", Color("#FF7A2F"))
	big.add_theme_color_override("font_outline_color", Color("#FFFDF6"))
	big.add_theme_constant_override("outline_size", 22)
	big.z_index = 20
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.offset_left = -600
	big.offset_right = 600
	big.offset_top = -100
	big.offset_bottom = 100
	big.scale = Vector2(0.4, 0.4)
	big.pivot_offset = Vector2(600, 100)
	add_child(big)

	var tw := create_tween()
	tw.tween_property(big, "scale", Vector2.ONE, 0.28) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_flash, "color:a", 0.6, 0.18)
	tw.tween_property(_flash, "color:a", 0.0, 0.5)
	# 얼음이 녹는다
	tw.parallel().tween_property(_ice, "size:y", 0.0, 0.6) \
		.set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_ice, "position:y", _ice.position.y + _ice.size.y, 0.6)
	tw.parallel().tween_property(_ice, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_ice_shadow, "modulate:a", 0.0, 0.6)
	tw.tween_property(big, "modulate:a", 0.0, 0.35)
	await tw.finished
	big.queue_free()

	# 배운 단어가 도감에 들어갔다고 알려 준다
	var chip := Label.new()
	chip.text = "📖 %s  %s" % [word, String(data.get("ko", ""))]
	chip.add_theme_font_size_override("font_size", 42)
	chip.add_theme_color_override("font_color", Color("#3A2C2C"))
	chip.z_index = 15
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.position = Vector2(340, 540)
	chip.size = Vector2(600, 60)
	add_child(chip)
	var t2 := create_tween()
	t2.tween_property(chip, "position:y", 500.0, 0.4).set_ease(Tween.EASE_OUT)
	t2.tween_interval(1.0)
	t2.tween_property(chip, "modulate:a", 0.0, 0.4)


func _melt_now() -> void:
	if _ice != null:
		_ice.visible = false
	if _ice_shadow != null:
		_ice_shadow.visible = false


func _process(delta: float) -> void:
	# 추울 때 파트너가 떤다. 표정만으로는 부족하다.
	_t += delta
	if _partner != null and not _done:
		_partner.position.x = 720.0 + sin(_t * 22.0) * 2.0

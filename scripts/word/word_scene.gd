extends Control
## 마법영자문 장면 하나.
##
##   막힌 곳을 만난다 → 무슨 마법이 필요한지 보인다 → 철자를 놓는다
##   → 마법이 터진다 → 길이 열린다 → 도감에 남는다
##
## 한 단어가 한 사건이다.
##
## 막는 것과 풀리는 것은 장면마다 달라야 한다. 얼음은 **녹고**, 불은
## **꺼지고**, 강은 **건넌다**. 같은 그림에 단어만 갈아 끼우면 세 번째에
## 들킨다. 그래서 look.kind 로 갈라 놓았다.

signal scene_cleared(word: String)

## 어느 장면을 열지. 비워 두면 첫 장면.
@export var scene_id := "ice_wall"
## 테스트에서 연출을 기다리지 않고 넘기려고 쓴다.
@export var instant := false

## 화면을 위아래로 나눈다. 위는 장면, 아래는 마법 거는 자리.
##
## 처음엔 한 화면에 다 얹었더니 쿼카가 철자 칸 위에 올라앉았다. 아이가
## 누를 곳과 볼 곳은 겹치면 안 된다.
const GROUND := 424.0        # 발이 닿는 선
const HORIZON := 330.0       # 하늘과 눈밭의 경계
const PANEL_TOP := 430.0     # 여기부터 아래는 마법 칸
const MASCOT := Vector2(152, 212)
const VP := Vector2(1280, 720)

var data: Dictionary = {}
var spell: SpellBar

var _bg: Node2D
var _block: Node2D          # 길을 막은 것
var _block_kind := "ice"
var _leader: TextureRect
var _partner: TextureRect
var _face: FaceCut
var _bubble: PanelContainer
var _line: Label
var _prompt: Label
var _dex_chip: Label
var _flash: ColorRect
var _panel: ColorRect
var _flames: Array[Polygon2D] = []
var _t := 0.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	data = WordData.scene_by_id(scene_id)
	if data.is_empty():
		data = WordData.SCENES[0]
	_block_kind = String(data.get("look", {}).get("kind", "ice"))

	_build_background()
	_build_block()
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
# 픽셀 화풍으로 갈아입기 전이라 도형으로 그린다. 색은 장면 데이터에서
# 가져오므로, 나중에 그림으로 바꿔도 배치는 그대로 쓸 수 있다.

func _look(key: String, fallback: String) -> Color:
	return Color(String(data.get("look", {}).get(key, fallback)))


func _build_background() -> void:
	_bg = Node2D.new()
	add_child(_bg)

	_rect(_bg, Vector2.ZERO, Vector2(VP.x, HORIZON), _look("sky", "#8FB6D6"))
	_rect(_bg, Vector2(0, HORIZON), VP, _look("ground", "#E4EEF4"))
	for i in 3:
		var p := Polygon2D.new()
		var x := 180.0 + i * 420.0
		p.polygon = PackedVector2Array([
			Vector2(x - 300, HORIZON), Vector2(x, 90.0 + i * 30.0),
			Vector2(x + 300, HORIZON)])
		p.color = _look("hill", "#A9C6DC").darkened(i * 0.05)
		_bg.add_child(p)

	# 아래 판. 마법 칸이 배경에 묻히지 않게 바닥을 깔아 준다.
	# 대사만 나올 때는 숨긴다 — 빈 검은 판이 화면 절반을 먹으면 안 된다.
	_panel = ColorRect.new()
	_panel.color = Color(0.16, 0.13, 0.18, 0.30)
	_panel.position = Vector2(0, PANEL_TOP)
	_panel.size = Vector2(VP.x, VP.y - PANEL_TOP)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


# ── 길을 막은 것 ──────────────────────────────────────────────────────

func _build_block() -> void:
	_block = Node2D.new()
	add_child(_block)
	match _block_kind:
		"fire": _build_fire()
		"gap": _build_gap()
		_: _build_ice()


## 얼음 벽 — 녹는다
func _build_ice() -> void:
	var wall := ColorRect.new()
	wall.name = "Wall"
	wall.color = Color("#5FBBD8")
	wall.size = Vector2(250, 290)
	wall.position = Vector2(940, GROUND - wall.size.y)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(wall)
	# 결. 밝은 줄을 넣어야 벽이 아니라 **얼음**으로 보인다.
	for i in 4:
		var st := ColorRect.new()
		st.color = Color(1, 1, 1, 0.30)
		st.size = Vector2(20, wall.size.y)
		st.position = Vector2(26 + i * 58, 0)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.add_child(st)
	_shadow(915, 300)


## 불타는 덤불 — 꺼진다
func _build_fire() -> void:
	var bush := Polygon2D.new()
	bush.name = "Bush"
	bush.polygon = PackedVector2Array([
		Vector2(920, GROUND), Vector2(950, GROUND - 90),
		Vector2(1010, GROUND - 130), Vector2(1080, GROUND - 95),
		Vector2(1120, GROUND - 30), Vector2(1140, GROUND)])
	bush.color = Color("#3F5136")
	_block.add_child(bush)

	_flames.clear()
	for i in 5:
		var f := Polygon2D.new()
		var x := 950.0 + i * 42.0
		var h := 90.0 + (i % 3) * 34.0
		f.polygon = PackedVector2Array([
			Vector2(x - 22, GROUND - 90), Vector2(x, GROUND - 90 - h),
			Vector2(x + 22, GROUND - 90)])
		f.color = Color("#FF8A3D") if i % 2 == 0 else Color("#FFC24A")
		_block.add_child(f)
		_flames.append(f)
	_shadow(915, 240)


## 강 — 디딤돌이 자라 건넌다
##
## 땅보다 아래로 파면 아래 판(PANEL_TOP)까지 6px 밖에 안 남아 강이 안
## 보였다. 그래서 **발밑 앞쪽으로 눕혀** 그린다 — 위에서 비스듬히 보는 강.
const RIVER_H := 74.0

func _build_gap() -> void:
	var top := GROUND - RIVER_H
	var water := Polygon2D.new()
	water.name = "Water"
	water.color = Color("#4E93C4")
	# 왼쪽 끝이 수직이면 네모 스티커처럼 보인다. 비스듬히 흘러 나가게 한다.
	water.polygon = PackedVector2Array([
		Vector2(940, top), Vector2(VP.x, top),
		Vector2(VP.x, GROUND), Vector2(830, GROUND)])
	_block.add_child(water)
	for i in 4:
		var w := ColorRect.new()
		w.color = Color(1, 1, 1, 0.24)
		w.size = Vector2(86, 5)
		w.position = Vector2(990 + i * 74, top + 18 + (i % 2) * 28)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_block.add_child(w)


func _shadow(x: float, w: float) -> void:
	var sh := ColorRect.new()
	sh.name = "Shadow"
	sh.color = Color(0.30, 0.34, 0.30, 0.28)
	sh.size = Vector2(w, 20)
	sh.position = Vector2(x, GROUND - 8)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(sh)


# ── 캐릭터 ────────────────────────────────────────────────────────────

func _build_characters() -> void:
	# 막힌 것 앞에 선다. 둘과 벽 사이가 비어 있어야 "막혔다"가 보인다.
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
	_prompt.size = Vector2(VP.x, 48)
	_prompt.visible = false
	add_child(_prompt)

	spell = SpellBar.new()
	spell.name = "SpellBar"
	spell.position = Vector2(0, PANEL_TOP + 54)
	spell.size = Vector2(VP.x, VP.y - PANEL_TOP - 64)
	spell.visible = false
	spell.completed.connect(_on_spell_completed)
	add_child(spell)


func _build_hud() -> void:
	_dex_chip = Label.new()
	_dex_chip.text = "📖 %d" % WordDex.count()
	_dex_chip.add_theme_font_size_override("font_size", 40)
	_dex_chip.add_theme_color_override("font_color", Color("#3A2C2C"))
	_dex_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dex_chip.position = Vector2(VP.x - 260, 20)
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
	create_tween().tween_property(_panel, "color:a", 0.82, 0.2)
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
	create_tween().tween_property(_panel, "color:a", 0.30, 0.25)
	_bubble.visible = false
	_face.visible = false

	WordDex.learn(word, data, String(data.get("dex_note", "")))
	WordDex.mark_cleared(String(data.get("id", "")))
	_dex_chip.text = "📖 %d" % WordDex.count()
	SaveManager.save_now()

	if instant:
		_clear_now()
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
	_play_clear(tw)
	tw.tween_property(big, "modulate:a", 0.0, 0.35)
	await tw.finished
	big.queue_free()
	_show_dex_chip(word)


## 막은 것이 사라지는 방식. 장면마다 다르다.
func _play_clear(tw: Tween) -> void:
	match _block_kind:
		"fire":
			# 불만 꺼진다. 덤불은 그을린 채 남는다 — 흔적이 있어야 겪은 일이 된다.
			for f in _flames:
				tw.parallel().tween_property(f, "scale", Vector2(1.0, 0.0), 0.5)
				tw.parallel().tween_property(f, "modulate:a", 0.0, 0.5)
			var bush := _block.get_node_or_null("Bush") as Polygon2D
			if bush != null:
				tw.parallel().tween_property(bush, "color", Color("#2A2622"), 0.5)
		"gap":
			# 물은 그대로 두고 디딤돌이 **자라 오른다**. 건너는 장면이라야 한다.
			_grow_steps(tw)
		_:
			var wall := _block.get_node_or_null("Wall") as ColorRect
			if wall != null:
				tw.parallel().tween_property(wall, "size:y", 0.0, 0.6) \
					.set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(wall, "position:y",
					wall.position.y + wall.size.y, 0.6)
				tw.parallel().tween_property(wall, "modulate:a", 0.0, 0.6)
	var sh := _block.get_node_or_null("Shadow") as ColorRect
	if sh != null and _block_kind != "fire":
		tw.parallel().tween_property(sh, "modulate:a", 0.0, 0.6)


func _grow_steps(tw: Tween) -> void:
	# 강 위에서 **자라 오른다.** 물이 사라지는 게 아니라 건널 길이 생긴다.
	for i in 3:
		var s := ColorRect.new()
		s.name = "Step%d" % i
		s.color = Color("#7BA85F")
		s.size = Vector2(96, 0)
		s.position = Vector2(890 + i * 118, GROUND - 14)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_block.add_child(s)
		tw.parallel().tween_property(s, "size:y", 46.0, 0.5) \
			.set_delay(i * 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(s, "position:y", GROUND - 60.0, 0.5) \
			.set_delay(i * 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## 배운 단어가 도감에 들어갔다고 알려 준다
func _show_dex_chip(word: String) -> void:
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


## 테스트용 — 연출 없이 결과 상태로
func _clear_now() -> void:
	match _block_kind:
		"fire":
			for f in _flames:
				f.visible = false
		"gap":
			pass
		_:
			var wall := _block.get_node_or_null("Wall")
			if wall != null:
				(wall as CanvasItem).visible = false
	var sh := _block.get_node_or_null("Shadow")
	if sh != null:
		(sh as CanvasItem).visible = false


func _process(delta: float) -> void:
	_t += delta
	# 아직 막혀 있는 동안에만 움직인다. 풀린 뒤에도 떨면 이상하다.
	if _done:
		return
	if _partner != null and _block_kind == "ice":
		_partner.position.x = 720.0 + sin(_t * 22.0) * 2.0     # 추워서 떤다
	for i in _flames.size():
		var f := _flames[i]
		f.scale.y = 1.0 + sin(_t * 7.0 + i * 1.3) * 0.16       # 불이 흔들린다

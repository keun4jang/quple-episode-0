class_name ShelfPanel
extends CanvasLayer
## 마을 선반 판. 가게 안에서 선반을 누르면 뜬다.
##
## **값이 없다.** 사는 게 아니라 고르고, 보여 주고, 챙기는 판이다
## (`Items` 의 주석 참고). 그래서 이 파일에도 값·잔액·재고를 그리는
## 곳이 없다 — 물건 그림과 이름, 그리고 왜 아직 못 받는지 한 줄뿐이다.
##
## 판 하나로 셋을 다 그린다. 마을이 아홉이어도 시스템은 이것 하나다.

signal closed

const KIND_FOOD := "food"
const KIND_KEEP := "keep"
const KIND_SHOW := "show"

var _village := ""
var _kind := ""
var _place: Node = null


static func open(place: Node, village: String, kind: String) -> ShelfPanel:
	if place.get_tree().get_first_node_in_group("shelf_panel") != null:
		return null
	var s := ShelfPanel.new()
	s._village = village
	s._kind = kind
	s._place = place
	place.add_child(s)
	return s


func _ready() -> void:
	layer = 11
	add_to_group("shelf_panel")
	# 안드로이드 뒤로가기가 이걸 먼저 닫는다 (`back_handler.gd`)
	add_to_group("overlay")
	_build()


func _title() -> String:
	match _kind:
		KIND_FOOD:
			return "오늘의 먹거리"
		KIND_KEEP:
			return "이 마을 물건"
	return "기억 선반"


func _rows() -> Array:
	var d: Dictionary = Items.of(_village)
	match _kind:
		KIND_FOOD:
			return d.get("food", [])
		KIND_KEEP:
			return d.get("keep", [])
	# 기억 선반에는 **지금 가진 것만** 올린다. 없는 것을 흐리게 늘어놓으면
	# 그것도 모으라는 숙제가 된다.
	var out: Array = []
	for s in d.get("show", []):
		if JourneyState.count(String(s["id"])) > 0:
			out.append(s)
	return out


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.09, 0.12, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed) \
				or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed):
			_close())
	root.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", Paper.lift(sb))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -300
	panel.offset_right = 300
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = _title()
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#3A2C2C"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var rows := _rows()
	if rows.is_empty():
		var e := Label.new()
		e.text = "아직 올려놓을 게 없어요."
		e.add_theme_font_size_override("font_size", 22)
		e.add_theme_color_override("font_color", Color("#A79A8A"))
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(e)
	for it in rows:
		box.add_child(_row(it))

	var close := Button.new()
	close.text = "그만 보기"
	close.custom_minimum_size = Vector2(0, 64)
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_color_override("font_color", Color("#3A2C2C"))
	_style(close, Color("#E7E0D6"))
	close.pressed.connect(_close)
	box.add_child(close)


## 버튼 겉면. 기본 테마 버튼은 **어두운 회색**이라, 크림색 판 위에
## 올리면 판에 회색 벽돌을 얹은 꼴이 된다 — 흐린 글씨는 아예 안 읽힌다.
## 여행판과 같은 종이 마감으로 맞춘다 (`travel_board.gd`).
func _style(b: Button, bg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color("#C6B8A5")
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	Paper.lift(sb)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_stylebox_override("pressed",
		Paper.press(sb.duplicate() as StyleBoxFlat))


## 물건 한 줄 — 그림, 이름, 그리고 지금 무엇을 할 수 있는지.
func _row(it: Dictionary) -> Control:
	var done := false
	var why := ""
	match _kind:
		KIND_FOOD:
			done = Items.tasted(_village, it)
			why = "먹어 봤어요" if done else ""
		KIND_KEEP:
			if Items.kept(it):
				done = true
				why = "배낭에 있어요"
			elif not Items.unlocked(_village, it):
				why = String(it.get("locked", ""))
		KIND_SHOW:
			done = Items.shown(_village, String(it["id"]))
			why = "보여 줬어요" if done else ""

	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 76)
	b.focus_mode = Control.FOCUS_NONE
	# 다 한 줄은 한 톤 가라앉힌다 — 지우지는 않는다. 무엇을 이미 했는지
	# 보이는 편이 낫다.
	_style(b, Color("#EFE7DA") if done else Color("#F6F0E4"))
	# 못 받는 것도 **눌리게 둔다.** 누르면 왜 아직인지 말해 준다 —
	# 눌리지도 않으면 고장으로 읽힌다.
	b.pressed.connect(func() -> void: _tap(it))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 겉면에 준 여백(content_margin)은 앵커로 붙인 자식에겐 안 먹는다.
	row.offset_left = 14
	row.offset_right = -14
	b.add_child(row)

	var icon := TextureRect.new()
	var path := "res://assets/sprites/%s.png" % String(it.get("icon", it["id"]))
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 아직 못 받는 것은 흐리게. 폰트에 자물쇠 글자가 없어서 색으로 말한다.
	var ready_now: bool = _kind != KIND_KEEP or Items.unlocked(_village, it)
	icon.modulate = Color(1, 1, 1, 1.0 if ready_now else 0.35)
	row.add_child(icon)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	# 한 줄뿐일 때 이름이 위에 붙어 그림과 어긋난다 — 가운데로 맞춘다.
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)

	var n := Label.new()
	n.text = String(it.get("name", JourneyHud.NAMES.get(String(it["id"]), it["id"])))
	n.add_theme_font_size_override("font_size", 24)
	n.add_theme_color_override("font_color",
		Color("#3A2C2C") if ready_now else Color("#8C7B68"))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(n)

	if why != "":
		var w := Label.new()
		w.text = why
		w.add_theme_font_size_override("font_size", 17)
		w.add_theme_color_override("font_color", Color("#7A6A58"))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(360, 0)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		names.add_child(w)
	return b


func _tap(it: Dictionary) -> void:
	var say: Variant = _place.get("say") if _place != null else null
	var lines: Array = []
	match _kind:
		KIND_FOOD:
			JourneyState.mark_quest("%s:맛봄:%s" % [_village, it["id"]])
			lines = [String(it["line"])]
			_remember(String(it.get("memory", "")))
		KIND_KEEP:
			if Items.kept(it):
				lines = [String(it.get("desc", "")), "배낭에 잘 있어요."]
			elif not Items.unlocked(_village, it):
				lines = [String(it.get("locked", "아직은 못 가져가요."))]
			else:
				# **챙긴다.** 배낭에 그대로 들어간다 — 따로 세는 곳을
				# 안 만든다. 값도 없고 개수도 하나뿐이다.
				JourneyState.pick(String(it["id"]))
				_remember(String(it.get("memory", "")))
				lines = it.get("got", ["가져가."])
		KIND_SHOW:
			JourneyState.mark_quest("%s:보여줌:%s" % [_village, it["id"]])
			# **수집품은 안 없어진다.** 보여 주는 것뿐이다.
			lines = it.get("lines", ["…"])
	_close()
	if say != null and say.has_method("say"):
		# `say()` 는 **한 겹 배열**을 받는다 — 원소가 배열이면
		# [누가, 무슨 말] 로 읽어 버린다 (`journey_say.gd`).
		say.call("say", String(Items.of(_village).get("owner", "가게")), lines)


## 사진첩에 한 줄 남긴다. 그림은 저장하지 않는다 — 이 게임의 사진은
## 원래 "어디서 무엇을 했다" 한 줄이다.
func _remember(line: String) -> void:
	if line == "":
		return
	JourneyState.photos.append({
		"place": _village, "subject": line,
		"day": JourneyState.day, "part": JourneyState.day_part(),
	})


func _close() -> void:
	closed.emit()
	queue_free()

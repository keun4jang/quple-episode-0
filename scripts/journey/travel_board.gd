class_name TravelBoard
extends CanvasLayer
## 떠나는 자리에서 뜨는 판. 어디로 갈지 고른다.
##
## 지도를 안 만든다 (`docs/redesign-journey.md` 4절). 목록 하나면 된다 —
## 1탄은 다섯 곳뿐이고, 지도를 만들면 그걸 읽는 법을 또 가르쳐야 한다.
##
## 다녀온 곳도 목록에 그대로 둔다. **돌아갈 수 있어야 한다** — 특히 고향은.

signal chose(scene_path: String)
signal closed

## 이름 → [씬 경로, 한 줄]
##
## **잿마루은 없다.** 회사는 한 번 나오면 돌아가지 않는다.
const PLACES := {
	"윤슬": ["res://scenes/journey/Yunseul.tscn", "바다와 등대"],
	"볕뉘": ["res://scenes/journey/Byeotnwi.tscn", "낮은 기와지붕"],
	"가풀재": ["res://scenes/journey/Gapuljae.tscn", "비탈진 항구"],
	"하늬섬": ["res://scenes/journey/Hanuiseom.tscn", "검은 돌담과 바람"],
	# 2탄 "담수 3부작" — 1탄 넷을 다 둘러봐야 열린다(`Quests.ORDER`).
	"굽이나루": ["res://scenes/journey/Gubinaru.tscn", "강 굽이와 나루"],
	"방울못": ["res://scenes/journey/Bangulmot.tscn", "둥근 연못"],
	"갈밭머리": ["res://scenes/journey/Galbatmeori.tscn", "갈대와 나무데크"],
	# 담수 3부작 다음, 물을 벗어난 첫 마을.
	"솔은재": ["res://scenes/journey/Soleunjae.tscn", "소나무 고개"],
	# 솔은재 다음, 처음으로 밭이 마을 골격인 곳.
	"꽃눈벌": ["res://scenes/journey/Kkonnunbeol.tscn", "꽃눈 피는 밭머리"],
	# 설명을 비워 두지 않는다 - "언제든 돌아갈 수 있는 곳" 이라는 것
	# 자체가 고향의 뜻이다. 목록 맨 위에 둔다 (`_row_order`).
	"고향": ["res://scenes/journey/Home.tscn", "언제든 돌아갈 수 있는 곳"],
}

var _panel: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _from := ""


func _ready() -> void:
	layer = 12
	add_to_group("travel_board")
	visible = false
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.09, 0.12, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF6")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", Paper.lift(sb))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 잠긴 줄에 남은 할 일을 적으면서 글이 길어졌다. 판이 글에 밀려
	# 화면 밖으로 자라던 걸 막는다 — 폭을 여기서 못 박는다.
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "어디로 갈까"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#3A2C2C"))
	box.add_child(title)

	# 여행지가 여덟 곳까지 늘었다 — 목록이 고정 칸보다 길어지면 스크롤로
	# 받는다. 안 그러면 화면 아래로 잘려 나가거나 겹쳐 보인다.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	var back := Button.new()
	back.text = "아직 더 있을래"
	back.custom_minimum_size = Vector2(0, 76)
	back.add_theme_font_size_override("font_size", 28)
	_style(back, false)
	back.pressed.connect(close)
	box.add_child(back)


func _style(b: Button, strong: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F4EDE2") if strong else Color("#E7E0D6")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.border_color = Color("#8C7B68")
	Paper.lift(sb)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color("#FFE39A")
	b.add_theme_stylebox_override("pressed", Paper.press(pr))
	b.add_theme_color_override("font_color", Color("#3A2C2C"))


## 판에 늘어놓을 순서. **고향을 맨 위로 뺀다.**
##
## `PLACES` 선언 순서 그대로 두면 고향이 맨 마지막 줄이라, 잠긴 2탄
## 마을 다섯 아래 묻힌다. 판은 네댓 줄만 보여 스크롤을 안 하면 화면
## 밖이었다 - "고향은 언제든 돌아갈 수 있어야 한다" 는 이 파일 위쪽
## 주석과 정반대였다. 엄마 편지가 계속 "먹고 싶을 때 와" 라고 부르는데
## 정작 정류장엔 그 길이 안 보였다.
func _row_order() -> Array:
	var out: Array = ["고향"]
	for name in PLACES:
		if name != "고향":
			out.append(name)
	return out


func open(from_place: String) -> void:
	_from = from_place
	for c in _list.get_children():
		c.queue_free()
	for name in _row_order():
		if name == _from:
			continue                      # 여기 있는데 여기로 갈 순 없다
		var entry: Array = PLACES[name]
		var b := Button.new()
		var been := JourneyState.visited.has(name)
		var unlocked := Quests.is_unlocked(name)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if unlocked:
			# 다녀온 곳은 조용히 표시한다. 안 가 본 곳을 굳이 부추기지 않는다.
			var tail := "  ·  " + String(entry[1]) if String(entry[1]) != "" else ""
			b.text = name + tail
			b.custom_minimum_size = Vector2(0, 84)
			b.add_theme_font_size_override("font_size", 32)
			# 넘치면 자른다 — 안 그러면 버튼의 최소 폭이 글 길이만큼
			# 자라 판을 화면 밖으로 밀어낸다.
			b.clip_text = true
		else:
			# **지운 게 아니라 흐리게.** 다음이 있다는 걸 알아야 기대가
			# 생긴다 — 아예 안 보이면 그냥 이 마을이 끝인 줄 안다.
			#
			# **두 줄로 나눈다.** 여태 한 줄에 가운뎃점으로만 이어 붙여서
			# "볕뉘 · 윤슬 · 이야기 2/3 · 저녁에 등대곶에서 불 켜진 등대 사진
			# 남기기" 가 됐다 — 열린 줄("윤슬 · 바다와 등대")과 서식이 같아서
			# 어느 게 갈 곳이고 어느 게 조건인지 읽을 수가 없었다. 그
			# 아주머니가 저 마을에 산다는 소개글로 읽힌다. 게다가 끝은
			# `clip_text` 로 잘려 나갔다.
			#
			# 이제 위는 마을 이름만, 아래는 **문장**이다. 2탄 해금 조건도
			# 이 줄로만 전해지니 여기가 안 읽히면 해금 전체가 안 읽힌다.
			b.text = ""              # 글은 아래 두 줄이 대신 그린다
			b.custom_minimum_size = Vector2(0, 108)
			b.modulate.a = 0.55
			_locked_lines(b, name)
		_style(b, not been)
		if unlocked:
			b.pressed.connect(_pick.bind(String(entry[0])))
		else:
			# **완전히 죽여 두지 않는다.** 눌러도 반응이 없으면 "고장인가?"
			# 가 된다는 지적을 받았다 — 화나게 하지 않으면서도 눌렀다는
			# 건 알려준다. 살짝 흔들리고, 이미 적혀 있는 글줄이 그 대답이다.
			b.pressed.connect(_shake.bind(b))
		_list.add_child(b)
	visible = true
	_fit_panel()


## 화면 높이에 맞춰 판을 키운다. 고정 520px 로 두면 폰마다, 또 지금처럼
## 여행지가 늘어난 지금은 목록이 판 밖으로 넘쳐 겹쳐 보인다.
func _fit_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	var h: float = clampf(vp.y * 0.82, 420.0, 760.0)
	_panel.offset_top = -h * 0.5
	_panel.offset_bottom = h * 0.5


## 잠긴 줄의 글 두 줄을 버튼 안에 그린다. 위는 마을 이름, 아래는
## 여는 조건을 적은 **문장**.
##
## 버튼의 `text` 는 비워 두고 자식으로 얹는다 — 버튼 글은 한 줄뿐이라
## 두 층을 만들 수가 없다. 자식은 눌림을 안 먹게(`MOUSE_FILTER_IGNORE`)
## 두어야 버튼이 그대로 눌린다.
func _locked_lines(b: Button, name: String) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 12
	col.offset_bottom = -12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	b.add_child(col)

	var top := Label.new()
	top.text = name
	top.add_theme_font_size_override("font_size", 30)
	top.add_theme_color_override("font_color", Color("#3A2C2C"))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)

	var sub := Label.new()
	sub.text = _blocking_line(name)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("#6B5B4E"))
	# 이쪽은 **줄바꿈을 켠다.** 버튼이 아니라 라벨이라 최소 높이가 안
	# 무너진다. 잘라 내는 것보다 두 줄로 접히는 편이 낫다 — 문장 끝
	# ("열려요")이 잘리면 조건인 줄도 모르게 된다.
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)


## 이 곳을 여는 조건 한 문장.
##
## **개수까지 적는다.** 남은 것 하나만 보여 주면 그것만 하면 열리는 줄
## 알게 되고, 하고 나면 줄이 다음 것으로 바뀌어 목표가 미끄러진다.
## 몇 개가 남았는지는 `Quests.unlock_todo` 가 센다 — 매듭 마을은 100% 가
## 아니라 이야기 하나와 샛길 둘이면 열리므로, 안 끝난 줄 수와 다르다.
func _blocking_line(name: String) -> String:
	var todo := Quests.unlock_todo(name)
	if todo.is_empty():
		return "아직 더 볼 게 있는 것 같다"
	var where := String(todo["village"])
	var need := int(todo["need"])
	var first := String(todo["first"])
	if first == "":
		return "%s에서 %d가지를 더 하면 열려요" % [where, need]
	if need <= 1:
		# 조사를 안 붙인다 — 받침에 따라 을/를 이 갈리는데 할 일 이름은
		# 그때그때 다르다 (`CLAUDE.md` 는 글자 하나까지 본다).
		return "%s에서 %s 하나만 더 하면 열려요" % [where, first]
	return "%s에서 %s 외 %d가지를 더 하면 열려요" % [where, first, need - 1]


## 잠긴 곳을 눌렀을 때. 화나게 하지 않되, 눌렀다는 건 알려준다.
func _shake(b: Button) -> void:
	AudioManager.touch_tap()
	var origin := b.position.x
	var tw := create_tween()
	for dx in [6.0, -5.0, 3.0, 0.0]:
		tw.tween_property(b, "position:x", origin + dx, 0.05)


func close() -> void:
	visible = false
	closed.emit()


## 씬 경로로 여행지 이름을 되찾는다.
func _place_name_of(path: String) -> String:
	for n in PLACES:
		if String(PLACES[n][0]) == path:
			return n
	return ""


func _pick(path: String) -> void:
	visible = false
	# 내가 떠나면 여행자도 떠난다.
	JourneyState.move_wanderer(_place_name_of(path), _from)
	# 다음 마을에는 아침에 닿는다. `Place` 가 지도를 깔면서 처리한다.
	JourneyState.arriving = true
	# **도착지**를 적어야 한다. `save_now()` 는 지금 씬을 보는데, 여기서는
	# 아직 떠나기 전 장소다. 그대로 두면 앱이 죽었을 때 이어하기가 방금
	# 떠나온 곳으로 되돌아간다.
	SaveManager.save_game(path)
	chose.emit(path)
	# **페이드를 거쳐 간다.** 게임에서 실제로 쓰는 씬 이동은 여기 하나뿐인데,
	# 이것만 `change_scene_to_file` 로 곧장 넘어가 한 프레임에 툭 바뀌었다.
	# `SceneTransition` 안의 문 여는 소리도 그래서 한 번도 안 났다.
	var st := get_node_or_null("/root/SceneTransition")
	if st != null and st.has_method("go_to"):
		st.go_to(path, "normal")
	else:
		get_tree().change_scene_to_file(path)

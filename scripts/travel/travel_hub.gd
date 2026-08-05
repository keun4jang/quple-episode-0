extends Control
## 쿼플 코어 루프 화면.
##   IDLE      목적지를 골라 여행을 보낸다
##   TRAVELING 앱을 꺼도 시간이 흐른다 (남은 시간 표시)
##   ARRIVED   돌아온 쿼카들에게서 사진과 일기를 받는다

const POSTER := "res://assets/splash/splash-poster-no-text.png"

@onready var bg: TextureRect        = $Bg
@onready var dim: ColorRect         = $Dim
@onready var title: Label           = $Safe/Header/Title
@onready var subtitle: Label        = $Safe/Header/Subtitle
@onready var panel: PanelContainer  = $Safe/Panel
@onready var body: VBoxContainer    = $Safe/Panel/Margin/Body
@onready var album_btn: Button      = $Safe/Footer/AlbumBtn
@onready var room_btn: Button       = $Safe/Footer/RoomBtn
@onready var home_btn: Button       = $Safe/Footer/HomeBtn

var _tick := 0.0
## 목록 필터 — 197개국을 다 스크롤할 수 없으니 걸러서 본다
##   all=전체 / unvisited=안 가본 곳 / visited=가본 곳
var _filter := "all"
var _region_filter := ""   # 빈 값이면 모든 대륙

func _ready() -> void:
	_load_poster()
	AudioManager.play_bgm("doraji")
	_update_ambient()
	album_btn.pressed.connect(_show_album)
	room_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/travel/SouvenirRoom3D.tscn", "hopeful"))
	home_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/menu/MainMenu3D.tscn"))
	_refresh()

func _process(delta: float) -> void:
	# 여행 중에는 남은 시간을 1초마다 갱신하고, 도착하면 화면을 바꾼다
	if not TravelState.is_traveling():
		return
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	if TravelState.has_arrived():
		_refresh()
		return
	var sky := body.get_node_or_null("Sky") as ColorRect
	if sky: _paint_sky(sky, TravelState.progress())
	# 남은 시간은 평소엔 감춘다. D 를 누르고 있는 동안만 보여준다.
	var lbl := body.get_node_or_null("TimeLeft") as Label
	if lbl:
		lbl.text = TravelState.format_time_left() if Input.is_action_pressed("wind_note") else ""
	# 보고 있는 중에 새 소식이 도착하면 알림을 띄운다
	var showing_msg_btn := body.get_node_or_null("MsgBtn") != null
	if TravelState.unread_count() > 0 and not showing_msg_btn:
		AudioManager.message_arrive()
		_refresh()

# ── 화면 전환 ───────────────────────────────────────────────────────────

func _refresh() -> void:
	for c in body.get_children():
		c.queue_free()
	if TravelState.has_arrived():
		_build_arrived()
	elif TravelState.is_traveling():
		_build_traveling()
	else:
		_build_idle()

## 1) 목적지 선택
func _build_idle() -> void:
	title.text = "어디로 보낼까요?"
	subtitle.text = "쿼카 커플이 다녀올 곳을 골라주세요"
	body.add_child(_make_filter_row())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	for ch in TravelState.CHAPTERS:
		var open: bool = TravelState.is_chapter_unlocked(str(ch.id))
		var done: int = TravelState.chapter_cleared(str(ch.id))
		var total := 0
		for d in TravelState.DESTINATIONS:
			if str(d.get("chapter", "")) == str(ch.id):
				total += 1
		list.add_child(_make_chapter_header(ch, open, done, total))
		if not open:
			continue
		if str(ch.id) == "world":
			# 해외는 197곳이라 대륙으로 다시 묶는다
			for rg in TravelState.REGIONS:
				if _region_filter != "" and str(rg.id) != _region_filter:
					continue
				var cards: Array = []
				for d in TravelState.DESTINATIONS:
					if str(d.get("region", "")) == str(rg.id) and _passes_filter(d):
						cards.append(d)
				if cards.is_empty():
					continue
				var rl := Label.new()
				rl.text = "%s (%d곳)" % [rg.name, cards.size()]
				rl.add_theme_font_size_override("font_size", 13)
				rl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.92))
				rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				list.add_child(rl)
				for d in cards:
					list.add_child(_make_dest_card(d))
		else:
			for d in TravelState.DESTINATIONS:
				if str(d.get("chapter", "")) == str(ch.id) and _passes_filter(d):
					list.add_child(_make_dest_card(d))
	scroll.add_child(list)
	body.add_child(scroll)
	body.add_child(_make_items_row())

## 필터 줄: 전체 / 안 가본 곳 / 가본 곳 + 대륙
func _make_filter_row() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for opt in [["all", "전체"], ["unvisited", "안 가본 곳"], ["visited", "가본 곳"]]:
		h.add_child(_filter_btn(str(opt[0]), str(opt[1]), _filter == str(opt[0]),
			func(id): _filter = id))
	v.add_child(h)

	var h2 := HBoxContainer.new()
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	h2.add_theme_constant_override("separation", 5)
	h2.add_child(_filter_btn("", "모든 대륙", _region_filter == "", func(id): _region_filter = id))
	for rg in TravelState.REGIONS:
		h2.add_child(_filter_btn(str(rg.id), str(rg.name), _region_filter == str(rg.id),
			func(id): _region_filter = id))
	v.add_child(h2)
	return v

func _filter_btn(id: String, label: String, on: bool, setter: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 13)
	var col := Color(1.0, 0.86, 0.55) if on else Color(0.42, 0.40, 0.55)
	b.add_theme_stylebox_override("normal", _card_style(col, on))
	b.add_theme_stylebox_override("hover", _card_style(col, true))
	b.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08) if on else Color(0.88, 0.86, 0.95))
	b.pressed.connect(func():
		AudioManager.ui_click()
		setter.call(id)
		_refresh())
	return b

## 이 여행지를 지금 필터에서 보여줄 것인가
func _passes_filter(d: Dictionary) -> bool:
	if _region_filter != "" and str(d.get("region", "")) != _region_filter:
		# 대륙 필터는 해외에만 적용한다
		if str(d.get("chapter", "")) == "world":
			return false
	var visited: bool = TravelState.visit_count(str(d.id)) > 0
	match _filter:
		"unvisited": return not visited
		"visited": return visited
	return true

## 막 제목 줄
func _make_chapter_header(ch: Dictionary, open: bool, done: int, total: int) -> Label:
	var l := Label.new()
	if open:
		l.text = "──  %s   %d/%d  ──" % [ch.name, done, total]
		l.add_theme_color_override("font_color", Color(1, 0.90, 0.62))
	else:
		var idx: int = TravelState.chapter_index(str(ch.id))
		var prev: Dictionary = TravelState.CHAPTERS[maxi(0, idx - 1)]
		var need: int = int(ch.get("need_prev", 3)) - TravelState.chapter_cleared(str(prev.id))
		l.text = "──  🔒 %s   (%s %d곳 더)  ──" % [ch.name, prev.name, maxi(0, need)]
		l.add_theme_color_override("font_color", Color(0.62, 0.60, 0.75))
	l.add_theme_font_size_override("font_size", 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## 여행지 색. 여행지마다 tint 를 다 적을 수 없으므로 막·대륙으로 정한다.
const CHAPTER_TINT := {
	"korea":  Color(0.55, 0.78, 0.55),
	"space":  Color(0.65, 0.72, 0.95),
	"beyond": Color(1.00, 0.86, 0.62),
}
const REGION_TINT := {
	"asia":    Color(0.90, 0.66, 0.62),
	"europe":  Color(0.72, 0.72, 0.92),
	"africa":  Color(0.92, 0.80, 0.55),
	"america": Color(0.62, 0.82, 0.72),
	"oceania": Color(0.55, 0.78, 0.88),
}

func _dest_tint(d: Dictionary) -> Color:
	if d.has("tint"):
		return d.tint
	var rg := str(d.get("region", ""))
	if REGION_TINT.has(rg):
		return REGION_TINT[rg]
	return CHAPTER_TINT.get(str(d.get("chapter", "")), Color(0.72, 0.75, 0.88))

func _make_dest_card(d: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	var tint: Color = _dest_tint(d)
	var visits: int = TravelState.visit_count(d.id)
	var unlocked: bool = TravelState.is_unlocked(d.id)
	var secs: int = TravelState.duration_of(d)
	var dur := _format_duration(secs)
	if unlocked:
		b.text = "%s  %s\n%s\n소요 %s%s" % [
			d.emoji, d.name, d.tagline, dur,
			("   ·   %d번 다녀옴" % visits) if visits > 0 else "",
		]
	else:
		b.text = "🔒  %s" % TravelState.unlock_hint(d.id)
		b.disabled = true
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10))
	b.add_theme_color_override("font_hover_color", Color(0.10, 0.07, 0.05))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_stylebox_override("normal", _card_style(tint, false))
	b.add_theme_stylebox_override("hover",  _card_style(tint, true))
	b.add_theme_stylebox_override("pressed",_card_style(tint, true))
	b.pressed.connect(func():
		if TravelState.start_trip(d.id):
			AudioManager.ui_confirm()
			_refresh())
	return b

func _format_duration(secs: int) -> String:
	if secs >= 3600:
		var h := secs / 3600
		var m := (secs % 3600) / 60
		return ("%d시간 %d분" % [h, m]) if m > 0 else ("%d시간" % h)
	if secs >= 60:
		return "%d분" % (secs / 60)
	return "%d초" % secs

## 0편에서 챙긴 여행 물품 표시
func _make_items_row() -> Label:
	var l := Label.new()
	var st := get_node_or_null("/root/Episode0State")
	var parts: Array[String] = []
	if st == null or st.has_camera: parts.append("📷 카메라")
	if st == null or st.has_notebook: parts.append("📓 수첩")
	if st == null or st.has_travel_bag: parts.append("🎒 가방")
	l.text = ("가진 것: " + "   ".join(parts)) if parts.size() > 0 else "아직 챙긴 것이 없어요"
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## 2) 여행 중 — 앱을 꺼도 진행된다
## 남은 시간을 숫자로 보여주지 않는다. 하늘빛과 해의 위치가 진행도를 말해준다.
func _build_traveling() -> void:
	var d := TravelState.get_destination(TravelState.trip.get("dest_id", ""))
	title.text = "%s 여행 중" % d.get("name", "")
	subtitle.text = "앱을 꺼도 괜찮아요"

	# 하늘: 출발(새벽) → 도착(노을)
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.custom_minimum_size = Vector2(0, 120)
	body.add_child(sky)
	_paint_sky(sky, TravelState.progress())

	var emoji := Label.new()
	emoji.text = d.get("emoji", "✈")
	emoji.add_theme_font_size_override("font_size", 54)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(emoji)

	# 중간 소식
	body.add_child(_make_message_row())

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "돌아오면 사진과 일기를 보여줄 거예요"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)

	# 숫자가 궁금하면 D 를 눌러 잠깐 볼 수 있다
	var peek := Label.new()
	peek.name = "TimeLeft"
	peek.text = ""
	peek.add_theme_font_size_override("font_size", 13)
	peek.add_theme_color_override("font_color", Color(0.70, 0.68, 0.85))
	peek.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(peek)

## 진행도를 하늘로 그린다. 0=새벽, 1=노을.
func _paint_sky(rect: ColorRect, prog: float) -> void:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	# 시간대별 하늘 색
	var top_dawn := Color(0.16, 0.20, 0.42)
	var bot_dawn := Color(0.42, 0.44, 0.62)
	var top_noon := Color(0.42, 0.66, 0.90)
	var bot_noon := Color(0.78, 0.88, 0.96)
	var top_dusk := Color(0.30, 0.26, 0.52)
	var bot_dusk := Color(0.98, 0.68, 0.52)
	var top: Color
	var bot: Color
	if prog < 0.5:
		var t := prog / 0.5
		top = top_dawn.lerp(top_noon, t)
		bot = bot_dawn.lerp(bot_noon, t)
	else:
		var t := (prog - 0.5) / 0.5
		top = top_noon.lerp(top_dusk, t)
		bot = bot_noon.lerp(bot_dusk, t)
	for y in range(96):
		var c := top.lerp(bot, float(y) / 95.0)
		for x in range(64):
			img.set_pixel(x, y, c)
	# 해: 진행도에 따라 왼쪽에서 오른쪽으로, 가운데서 가장 높이
	var sx := int(6.0 + prog * 52.0)
	var sy := int(70.0 - sin(prog * PI) * 46.0)
	var sun := Color(1.0, 0.95, 0.72) if prog < 0.75 else Color(1.0, 0.78, 0.52)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if dx * dx + dy * dy > 16:
				continue
			var px := sx + dx
			var py := sy + dy
			if px >= 0 and px < 64 and py >= 0 and py < 96:
				img.set_pixel(px, py, sun)
	var tex := ImageTexture.create_from_image(img)
	var tr := rect.get_node_or_null("Tex") as TextureRect
	if tr == null:
		tr = TextureRect.new()
		tr.name = "Tex"
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(tr)
	tr.texture = tex
	rect.color = Color(0, 0, 0, 0)

## 소식 버튼: 안 읽은 게 있으면 강조, 없으면 다음 소식까지 안내
func _make_message_row() -> Control:
	var unread: int = TravelState.unread_count()
	var arrived: int = TravelState.arrived_messages().size()

	if unread > 0:
		var b := Button.new()
		b.name = "MsgBtn"
		b.custom_minimum_size = Vector2(0, 60)
		b.text = "💌  새 소식 %d개  ·  눌러서 읽기" % unread
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(0.24, 0.12, 0.30))
		b.add_theme_stylebox_override("normal", _card_style(Color(1.0, 0.72, 0.82), false))
		b.add_theme_stylebox_override("hover", _card_style(Color(1.0, 0.82, 0.90), true))
		b.pressed.connect(func(): AudioManager.ui_click(); _show_messages())
		return b

	var l := Label.new()
	l.name = "MsgHint"
	if arrived > 0:
		l.text = "읽은 소식 %d개  ·  다음 소식을 기다리는 중" % arrived
	else:
		var nxt: int = TravelState.seconds_to_next_message()
		l.text = ("곧 첫 소식이 올 거예요" if nxt < 0 else "첫 소식까지 %s" % _format_duration(nxt))
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.78, 0.75, 0.90))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## 도착한 소식들을 순서대로 보여준다
func _show_messages() -> void:
	var msgs: Array = TravelState.arrived_messages()
	TravelState.mark_messages_read()
	for c in body.get_children():
		c.queue_free()
	var d := TravelState.get_destination(TravelState.trip.get("dest_id", ""))
	title.text = "%s에서 온 소식" % d.get("name", "")
	subtitle.text = "여행 중인 애인이 보냈어요"

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in msgs:
		list.add_child(_make_message_card(m))
	scroll.add_child(list)
	body.add_child(scroll)

	var back := Button.new()
	back.text = "돌아가기"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_refresh)
	body.add_child(back)

func _make_message_card(m: Dictionary) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _card_style(Color(0.62, 0.52, 0.80), false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var e := Label.new()
	e.text = str(m.get("emoji", "💌"))
	e.add_theme_font_size_override("font_size", 34)
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(e)
	var t := Label.new()
	t.text = str(m.get("text", ""))
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	pc.add_child(h)
	return pc

## 3) 도착 — 사진과 일기를 받는다
func _build_arrived() -> void:
	var d := TravelState.get_destination(TravelState.trip.get("dest_id", ""))
	title.text = "돌아왔어요!"
	subtitle.text = "%s에서 무언가를 가져왔대요" % d.get("name", "")

	var open_btn := Button.new()
	open_btn.text = "🎁  사진 받기"
	open_btn.custom_minimum_size = Vector2(0, 72)
	open_btn.add_theme_font_size_override("font_size", 24)
	open_btn.add_theme_color_override("font_color", Color(0.22, 0.10, 0.03))
	open_btn.add_theme_stylebox_override("normal", _card_style(Color(1.0, 0.78, 0.52), false))
	open_btn.add_theme_stylebox_override("hover",  _card_style(Color(1.0, 0.86, 0.62), true))
	open_btn.pressed.connect(func():
		var was_final: bool = bool(TravelState.get_destination(
			str(TravelState.trip.get("dest_id", ""))).get("final", false))
		# 이 여행으로 새 막이 열리는지 미리 본다
		var before_open: Array[String] = []
		for c in TravelState.CHAPTERS:
			if TravelState.is_chapter_unlocked(str(c.id)):
				before_open.append(str(c.id))
		var s := TravelState.collect_arrival()
		if s.is_empty():
			return
		AudioManager.souvenir_get()
		if was_final:
			# 다른 차원에서 돌아왔다 — 엔딩
			SaveManager.save_game()
			var es := load("res://scenes/ui/EndingScreen.tscn") as PackedScene
			if es:
				add_child(es.instantiate())
				return
		# 새로 열린 막이 있으면 알려준다
		var newly := ""
		for c in TravelState.CHAPTERS:
			if TravelState.is_chapter_unlocked(str(c.id)) and not before_open.has(str(c.id)):
				newly = str(c.id)
				break
		if newly != "":
			_show_chapter_unlocked(newly, s)
		else:
			_show_souvenir(s))

## 새 막이 열렸을 때의 연출
func _show_chapter_unlocked(chapter_id: String, souvenir: Dictionary) -> void:
	var ch := TravelState.get_chapter(chapter_id)
	for c in body.get_children():
		c.queue_free()
	title.text = "%s 여행이 열렸어요" % ch.get("name", "")
	subtitle.text = "더 멀리 갈 수 있게 됐어요"
	AudioManager.souvenir_get()

	# 그 막의 대표 여행지 몇 곳을 보여준다
	var samples: Array = []
	for d in TravelState.DESTINATIONS:
		if str(d.get("chapter", "")) == chapter_id:
			samples.append(d)
		if samples.size() >= 6:
			break

	var emo := Label.new()
	var line := ""
	for d in samples:
		line += str(d.get("emoji", "")) + "  "
	emo.text = line
	emo.add_theme_font_size_override("font_size", 44)
	emo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(emo)

	var msg := Label.new()
	var total := 0
	for d in TravelState.DESTINATIONS:
		if str(d.get("chapter", "")) == chapter_id:
			total += 1
	msg.text = "%s  %d곳이 기다리고 있어요" % [ch.get("name", ""), total]
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(1, 0.90, 0.62))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(msg)

	var next_btn := Button.new()
	next_btn.text = "이번 여행 기록 보기"
	next_btn.custom_minimum_size = Vector2(0, 60)
	next_btn.add_theme_font_size_override("font_size", 20)
	next_btn.add_theme_color_override("font_color", Color(0.22, 0.10, 0.03))
	next_btn.add_theme_stylebox_override("normal", _card_style(Color(1.0, 0.78, 0.52), false))
	next_btn.add_theme_stylebox_override("hover", _card_style(Color(1.0, 0.86, 0.62), true))
	next_btn.pressed.connect(func():
		AudioManager.ui_click()
		_show_souvenir(souvenir))
	body.add_child(next_btn)

	# 이모지가 커지며 등장
	emo.scale = Vector2(0.5, 0.5)
	emo.pivot_offset = emo.size / 2.0
	var tw := create_tween()
	tw.tween_property(emo, "scale", Vector2.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	body.add_child(open_btn)

## 받은 사진 + 일기 공개 — 엽서가 도착한 것처럼
func _show_souvenir(sv: Dictionary) -> void:
	for c in body.get_children():
		c.queue_free()
	var quiet: bool = bool(sv.get("quiet", false))
	title.text = "조용한 하루" if quiet else "엽서가 도착했어요"
	subtitle.text = "앨범에 저장했어요"

	# 폴라로이드 액자
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.90, 0.97)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0.05, 0.03, 0.15, 0.5)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	# 사진 — 여행지 색으로 그린다
	var photo := TextureRect.new()
	photo.custom_minimum_size = Vector2(300, 150)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_SCALE
	photo.texture = _make_photo(sv, quiet)
	inner.add_child(photo)

	# 손글씨 자리 — 제목
	var t := Label.new()
	t.text = str(sv.get("title", ""))
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", Color(0.32, 0.24, 0.14))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t)

	var diary := Label.new()
	diary.text = str(sv.get("diary", ""))
	diary.add_theme_font_size_override("font_size", 15)
	diary.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16))
	diary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diary.custom_minimum_size = Vector2(300, 0)
	inner.add_child(diary)

	card.add_child(inner)
	body.add_child(card)

	var again := Button.new()
	again.text = "다시 보내기"
	again.custom_minimum_size = Vector2(0, 52)
	again.add_theme_font_size_override("font_size", 19)
	again.add_theme_color_override("font_color", Color(0.22, 0.10, 0.03))
	again.add_theme_stylebox_override("normal", _card_style(Color(1.0, 0.78, 0.52), false))
	again.add_theme_stylebox_override("hover", _card_style(Color(1.0, 0.86, 0.62), true))
	again.pressed.connect(func(): AudioManager.ui_click(); _refresh())
	body.add_child(again)

	# 엽서가 살짝 기울어져 내려앉는다
	card.pivot_offset = Vector2(160, 100)
	card.rotation = deg_to_rad(-4.0)
	card.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.5)
	tw.tween_property(card, "rotation", deg_to_rad(-1.2), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 여행지 색으로 사진을 그린다 (외부 이미지 없이)
func _make_photo(sv: Dictionary, quiet: bool) -> ImageTexture:
	var d := TravelState.get_destination(str(sv.get("dest_id", "")))
	var tint: Color = _dest_tint(d) if not d.is_empty() else Color(0.7, 0.72, 0.82)
	if quiet:
		tint = tint.lerp(Color(0.72, 0.72, 0.76), 0.55)   # 조용한 날은 색이 옅다
	var W := 120
	var H := 60
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var sky_top := tint.lerp(Color(0.16, 0.18, 0.34), 0.42)
	var sky_bot := tint.lerp(Color(1, 0.90, 0.74), 0.45)
	var ground := tint.darkened(0.32)
	var horizon := int(H * 0.62)
	for y in range(H):
		for x in range(W):
			if y < horizon:
				img.set_pixel(x, y, sky_top.lerp(sky_bot, float(y) / float(horizon)))
			else:
				var t := float(y - horizon) / float(H - horizon)
				img.set_pixel(x, y, ground.lerp(ground.darkened(0.25), t))
	# 지평선 위 실루엣 (여행지 id 로 모양이 달라진다)
	var h: int = abs(hash(str(sv.get("dest_id", "x"))))
	for i in range(3):
		var cx := 14 + ((h >> (i * 5)) % (W - 28))
		var hgt := 6 + ((h >> (i * 3)) % 14)
		var wid := 3 + ((h >> (i * 7)) % 7)
		for x in range(maxi(0, cx - wid), mini(W, cx + wid)):
			for y in range(maxi(0, horizon - hgt), horizon):
				img.set_pixel(x, y, ground.darkened(0.35))
	# 해 또는 달
	if not quiet:
		var sx := 20 + (h % (W - 40))
		var sy := int(horizon * 0.35)
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				if dx * dx + dy * dy > 15: continue
				var px := sx + dx
				var py := sy + dy
				if px >= 0 and px < W and py >= 0 and py < H:
					img.set_pixel(px, py, Color(1, 0.94, 0.76))
	# 두 쿼카 실루엣 (항상 둘)
	for k in range(2):
		var bx := W / 2 - 5 + k * 8
		for x in range(bx, mini(W, bx + 5)):
			for y in range(horizon - 7, horizon):
				img.set_pixel(x, y, Color(0.18, 0.13, 0.10))
	return ImageTexture.create_from_image(img)

## 모은 기념품 목록
func _show_album() -> void:
	for c in body.get_children():
		c.queue_free()
	title.text = "우리의 앨범"
	var n := TravelState.collection.size()
	subtitle.text = ("아직 비어 있어요" if n == 0 else "기록 %d개" % n)

	if n == 0:
		var empty := Label.new()
		empty.text = "여행을 보내면\n사진이 하나씩 쌓여요"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(empty)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 250)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 16)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		# 최신순
		for i in range(TravelState.collection.size() - 1, -1, -1):
			list.add_child(_make_album_row(TravelState.collection[i]))
		body.add_child(scroll)

	var back := Button.new()
	back.text = "돌아가기"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_refresh)
	body.add_child(back)

func _make_album_row(s: Dictionary) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _card_style(Color(0.55, 0.50, 0.80), false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var ph := Label.new()
	ph.text = s.get("photo", "📷")
	ph.add_theme_font_size_override("font_size", 32)
	h.add_child(ph)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = s.get("title", "")
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(1, 0.90, 0.62))
	v.add_child(t)
	var dl := Label.new()
	dl.text = str(s.get("diary", "")).replace("\n", " ")
	dl.add_theme_font_size_override("font_size", 15)
	dl.add_theme_color_override("font_color", Color(0.95, 0.93, 1.0))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dl)
	h.add_child(v)
	pc.add_child(h)
	return pc

# ── 유틸 ────────────────────────────────────────────────────────────────

func _card_style(tint: Color, bright: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := tint
	sb.bg_color = Color(c.r, c.g, c.b, 0.95 if bright else 0.82)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.55 if bright else 0.32)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0.05, 0.03, 0.15, 0.45)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	return sb

func _load_poster() -> void:
	var abs := ProjectSettings.globalize_path(POSTER)
	if not FileAccess.file_exists(abs):
		return
	var img := Image.load_from_file(abs)
	if img:
		bg.texture = ImageTexture.create_from_image(img)


## 지금 여행 중인 곳에 어울리는 주변 소리를 튼다
func _update_ambient() -> void:
	if not TravelState.is_traveling():
		AudioManager.play_ambient("room")
		return
	var d := TravelState.get_destination(str(TravelState.trip.get("dest_id", "")))
	var ch := str(d.get("chapter", ""))
	var rg := str(d.get("region", ""))
	if ch == "space" or ch == "beyond":
		AudioManager.play_ambient("space")
	elif rg == "oceania" or str(d.get("id", "")) in ["busan", "jeju", "jeonnam", "gangneung"]:
		AudioManager.play_ambient("wave")
	elif ch == "korea":
		AudioManager.play_ambient("wind")
	else:
		AudioManager.play_ambient("wind")

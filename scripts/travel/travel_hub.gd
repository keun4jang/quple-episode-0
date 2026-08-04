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
@onready var home_btn: Button       = $Safe/Footer/HomeBtn

var _tick := 0.0

func _ready() -> void:
	_load_poster()
	album_btn.pressed.connect(_show_album)
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
	else:
		var lbl := body.get_node_or_null("TimeLeft") as Label
		var bar := body.get_node_or_null("Bar") as ProgressBar
		if lbl: lbl.text = TravelState.format_time_left()
		if bar: bar.value = TravelState.progress() * 100.0

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
	for d in TravelState.DESTINATIONS:
		body.add_child(_make_dest_card(d))
	body.add_child(_make_items_row())

func _make_dest_card(d: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 78)
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
		b.text = "🔒  ???\n%s" % TravelState.unlock_hint(d.id)
		b.disabled = true
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10))
	b.add_theme_color_override("font_hover_color", Color(0.10, 0.07, 0.05))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_stylebox_override("normal", _card_style(d.tint, false))
	b.add_theme_stylebox_override("hover",  _card_style(d.tint, true))
	b.add_theme_stylebox_override("pressed",_card_style(d.tint, true))
	b.pressed.connect(func():
		if TravelState.start_trip(d.id):
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
func _build_traveling() -> void:
	var d := TravelState.get_destination(TravelState.trip.get("dest_id", ""))
	title.text = "%s 여행 중" % d.get("name", "")
	subtitle.text = "앱을 꺼도 괜찮아요. 둘이서 잘 다니고 있어요"

	var emoji := Label.new()
	emoji.text = d.get("emoji", "✈")
	emoji.add_theme_font_size_override("font_size", 60)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(emoji)

	var lbl := Label.new()
	lbl.name = "TimeLeft"
	lbl.text = TravelState.format_time_left()
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1, 0.94, 0.78))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lbl)

	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 26)
	bar.max_value = 100.0
	bar.value = TravelState.progress() * 100.0
	bar.show_percentage = false
	body.add_child(bar)

	var hint := Label.new()
	hint.text = "돌아오면 사진과 일기를 보여줄 거예요"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)

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
		var s := TravelState.collect_arrival()
		if not s.is_empty():
			_show_souvenir(s))
	body.add_child(open_btn)

## 받은 사진 + 일기 공개
func _show_souvenir(s: Dictionary) -> void:
	for c in body.get_children():
		c.queue_free()
	title.text = "새로운 기록"
	subtitle.text = "앨범에 저장했어요"

	var photo := Label.new()
	photo.text = s.get("photo", "📷")
	photo.add_theme_font_size_override("font_size", 76)
	photo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(photo)

	var t := Label.new()
	t.text = s.get("title", "")
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(1, 0.90, 0.62))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)

	var diary := Label.new()
	diary.text = s.get("diary", "")
	diary.add_theme_font_size_override("font_size", 19)
	diary.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	diary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(diary)

	var again := Button.new()
	again.text = "다시 보내기"
	again.custom_minimum_size = Vector2(0, 60)
	again.add_theme_font_size_override("font_size", 22)
	again.add_theme_color_override("font_color", Color(0.22, 0.10, 0.03))
	again.add_theme_stylebox_override("normal", _card_style(Color(1.0, 0.78, 0.52), false))
	again.add_theme_stylebox_override("hover",  _card_style(Color(1.0, 0.86, 0.62), true))
	again.pressed.connect(_refresh)
	body.add_child(again)

	# 사진이 커지며 나타나는 연출
	photo.scale = Vector2(0.6, 0.6)
	photo.pivot_offset = photo.size / 2.0
	var tw := create_tween()
	tw.tween_property(photo, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

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
		scroll.custom_minimum_size = Vector2(0, 300)
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

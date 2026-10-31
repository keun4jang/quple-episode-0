extends CanvasLayer
## 설정 창. 메인메뉴가 "settings_ui" 그룹으로 찾아 open() 을 호출한다.

@onready var panel: PanelContainer = $Root/Panel
@onready var bgm: HSlider          = $Root/Panel/Margin/Body/BgmRow/Slider
@onready var sfx: HSlider          = $Root/Panel/Margin/Body/SfxRow/Slider
@onready var close_btn: Button     = $Root/Panel/Margin/Body/CloseBtn
@onready var reset_btn: Button     = $Root/Panel/Margin/Body/ResetBtn
@onready var reset_hint: Label     = $Root/Panel/Margin/Body/ResetHint

const CFG := "user://settings.cfg"
var _reset_armed := false

func _ready() -> void:
	add_to_group("settings_ui")
	visible = false
	_load()
	bgm.value_changed.connect(func(v): _apply("BGM", v); AudioManager.set_bgm_volume(v); AudioManager.set_ambient_volume(v); _save())
	sfx.value_changed.connect(func(v): _apply("SFX", v); AudioManager.set_sfx_volume(v); _save())
	close_btn.pressed.connect(close)
	reset_btn.pressed.connect(_on_reset)
	_close_on_outside_tap()
	_add_home_button()
	_add_update_row()
	_add_calm_row()
	_make_scrollable()
	_restyle()


## 2026-10 UI 개편: 게임 화면과 같은 한 벌(`IdleUi`) - 짙은 보랏빛 판 + 금빛 테두리 + 크림색 글씨.
## 장면 파일의 옛 올리브색 상자를 코드로 덮는다 (장면 파일을 고치지 않아 다른 쓰임이 깨지지 않는다).
func _restyle() -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", IdleUi.panel_style())
	var shade := get_node_or_null("Root/Shade") as ColorRect
	if shade != null:
		shade.color = Color(0.06, 0.03, 0.12, 0.6)
	var body := close_btn.get_parent()
	if body == null:
		return
	var sc := body.get_parent() as ScrollContainer
	if sc != null:
		IdleUi.style_scroll(sc)
	_restyle_tree(body)


func _restyle_tree(node: Node) -> void:
	for n in node.get_children():
		if n is Button:
			var kind := "plum"
			if n == reset_btn:
				kind = "danger"
			elif n == close_btn:
				kind = "gold"
			_copy_style(n as Button, IdleUi.button("", 10, kind), kind)
		elif n is HSlider:
			_style_slider(n as HSlider)
		elif n is Label:
			if n.name == "Title":
				(n as Label).add_theme_color_override("font_color", IdleUi.GOLD)
			elif n.get_parent() is HBoxContainer:
				(n as Label).add_theme_color_override("font_color", IdleUi.CREAM)
		if n.get_child_count() > 0 and not (n is Button):
			_restyle_tree(n)


func _copy_style(b: Button, tpl: Button, kind: String) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := tpl.get_theme_stylebox(st)
		if sb != null:
			b.add_theme_stylebox_override(st, sb)
	var fc := Color("#3A2410") if kind == "gold" else IdleUi.CREAM
	for c in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, fc)
	tpl.free()


func _style_slider(sl: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = IdleUi.GOLD
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)


## 창 **밖**을 누르면 닫는다.
##
## 지금까지 나가는 길이 "닫기" 버튼 하나뿐이었다. 그런데 창을 열어 놓고
## 밖을 누르는 건 거의 반사에 가깝다 — 그때 아무 일도 안 일어나면
## 잠긴 것처럼 느껴진다.
##
## 뒤 그림자(`Shade`)가 화면 전체를 덮고 있으니 거기서 받는다.
## 창 안쪽은 패널이 먼저 받으므로 여기까지 안 온다.
func _close_on_outside_tap() -> void:
	var shade := get_node_or_null("Root/Shade") as Control
	if shade == null:
		return
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if not visible:
			return
		var tap: bool = (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventMouseButton and e.pressed
				and e.button_index == MOUSE_BUTTON_LEFT)
		if tap:
			close()
			shade.accept_event())
	# 패널은 눌러도 안 닫힌다. 안쪽을 만지다 창이 사라지면 안 된다.
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP


## 설정창이 화면을 넘치지 않게 한다.
##
## 줄이 하나 늘 때마다 창이 같이 길어지다가, 업데이트 줄을 넣은 순간
## 제목과 "닫기" 가 화면 밖으로 밀려났다. 설정은 앞으로도 늘어날 것이니
## 항목을 줄이는 대신 넘치면 굴러가게 한다.
##
## @onready 는 _ready 가 시작될 때 이미 다 잡혔으므로, 여기서 부모를
## 바꿔도 위쪽 참조들은 그대로 살아 있다.
func _make_scrollable() -> void:
	var body := close_btn.get_parent()
	var margin := body.get_parent() if body != null else null
	if body == null or margin == null or body is ScrollContainer:
		return
	var sc := ScrollContainer.new()
	TouchScroll.setup(sc)
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.remove_child(body)
	margin.add_child(sc)
	sc.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 창 자체도 화면보다 커지지 않게 잡아 둔다.
	var vp := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(panel.custom_minimum_size.x, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_fit_panel()
	get_viewport().size_changed.connect(_fit_panel)


## 창 크기를 화면에 맞춘다 - 세로 화면(폭 720)에서 800 폭 창이 양옆으로 잘렸고,
## 높이를 화면의 94% 로 고정해서 아래가 텅 비어 보였다. 폭은 화면 안쪽으로, 높이는 내용만큼(넘치면 굴러감).
func _fit_panel() -> void:
	if panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var w := minf(800.0, vp.x - 40.0)
	var body := close_btn.get_parent() as Control
	var want := 0.0
	if body != null:
		want = body.get_combined_minimum_size().y + 80.0
	var h := clampf(want, 300.0, vp.y * 0.86)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5


func _add_home_button() -> void:
	var body := close_btn.get_parent()
	if body == null:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("MainMenu3D.tscn"):
		return

	var b := Button.new()
	b.name = "HomeBtn"
	b.text = "메인 화면으로"
	b.custom_minimum_size = close_btn.custom_minimum_size
	b.add_theme_font_size_override("font_size",
		close_btn.get_theme_font_size("font_size"))
	for st in ["normal", "hover", "pressed"]:
		var sb := close_btn.get_theme_stylebox(st)
		if sb != null:
			b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", close_btn.get_theme_color("font_color"))
	b.pressed.connect(_go_home)
	body.add_child(b)
	body.move_child(b, close_btn.get_index())


# ── 업데이트 ──────────────────────────────────────────────────────────
#
# 갱신은 원래 부팅할 때 조용히 알아서 됐다. 그건 대부분의 경우 맞다 —
# 사용자가 신경 쓸 일이 아니다.
#
# 문제는 **안 될 때**다. 새 버전을 냈다고 했는데 폰에 안 보이면, 지금
# 무슨 버전인지도, 왜 안 오는지도 알 길이 없었다. 껐다 켜기를 반복하는
# 것 말고는 할 수 있는 게 없었다.
#
# 그래서 지금 버전을 늘 보여 주고, 눌러서 직접 확인할 수 있게 한다.

var _ver_label: Label
var _update_btn: Button
var _update_hint: Label


## "화면 흔들림·번쩍임 줄이기" - 흔들림·번쩍임에 어지러운 사람을 위한 끄개 (`game-feel` 스킬의 접근성 항목).
func _add_calm_row() -> void:
	var body := close_btn.get_parent()
	if body == null or body.has_node("CalmRow"):
		return
	var b := Button.new()
	b.name = "CalmRow"
	b.custom_minimum_size = close_btn.custom_minimum_size
	b.add_theme_font_size_override("font_size", close_btn.get_theme_font_size("font_size"))
	for st in ["normal", "hover", "pressed"]:
		var sb := close_btn.get_theme_stylebox(st)
		if sb != null:
			b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", close_btn.get_theme_color("font_color"))
	var c := ConfigFile.new()
	var on := c.load(CFG) == OK and bool(c.get_value("fx", "calm", false))
	b.text = _calm_text(on)
	b.pressed.connect(func() -> void:
		var c2 := ConfigFile.new()
		c2.load(CFG)
		var now := not bool(c2.get_value("fx", "calm", false))
		c2.set_value("fx", "calm", now)
		c2.save(CFG)
		b.text = _calm_text(now))
	body.add_child(b)
	body.move_child(b, reset_btn.get_index())


func _calm_text(on: bool) -> String:
	return "화면 흔들림·번쩍임 줄이기: %s" % ("켜짐" if on else "꺼짐")


func _add_update_row() -> void:
	var body := close_btn.get_parent()
	if body == null:
		return

	var box := VBoxContainer.new()
	box.name = "UpdateBox"
	box.add_theme_constant_override("separation", 4)
	body.add_child(box)
	body.move_child(box, reset_btn.get_index())

	_ver_label = Label.new()
	_ver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ver_label.add_theme_font_size_override("font_size", 26)
	_ver_label.add_theme_color_override("font_color", Color("#8A6FB8"))
	box.add_child(_ver_label)

	_update_btn = Button.new()
	_update_btn.name = "UpdateBtn"
	_update_btn.text = "업데이트 확인"
	_update_btn.custom_minimum_size = close_btn.custom_minimum_size
	_update_btn.add_theme_font_size_override("font_size",
		close_btn.get_theme_font_size("font_size"))
	for st in ["normal", "hover", "pressed"]:
		var sb := close_btn.get_theme_stylebox(st)
		if sb != null:
			_update_btn.add_theme_stylebox_override(st, sb)
	_update_btn.add_theme_color_override("font_color", close_btn.get_theme_color("font_color"))
	_update_btn.pressed.connect(_on_check_update)
	box.add_child(_update_btn)

	_update_hint = Label.new()
	_update_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_hint.add_theme_font_size_override("font_size", 26)
	_update_hint.add_theme_color_override("font_color", Color(0.86, 0.83, 0.96))
	box.add_child(_update_hint)

	var au := get_node_or_null("/root/AutoUpdate")
	if au == null:
		# 에디터에서 이 씬만 따로 열었을 때. 버튼을 눌러도 할 일이 없다.
		_update_btn.disabled = true
		_ver_label.text = "버전 정보를 읽을 수 없어요"
		return
	au.check_started.connect(_on_check_started)
	au.up_to_date.connect(_on_up_to_date)
	au.update_ready.connect(_on_update_ready)
	au.update_failed.connect(_on_update_failed)
	_refresh_version()


func _refresh_version() -> void:
	var au := get_node_or_null("/root/AutoUpdate")
	if au == null or _ver_label == null:
		return
	_ver_label.text = "지금 버전  v%s" % au.current_version


func _on_check_update() -> void:
	var au := get_node_or_null("/root/AutoUpdate")
	if au == null:
		return
	if not au.check_now():
		return                       # 이미 확인 중이다


func _on_check_started() -> void:
	_set_update_state(true, "확인하는 중…", Color(0.86, 0.83, 0.96))


func _on_up_to_date(v: String) -> void:
	_set_update_state(false, "최신 버전이에요 (v%s)" % v, Color(0.72, 0.90, 0.76))


## 받아 놓기만 하고 다음 실행에 적용한다. 돌아가는 중에 갈아끼우면
## 이미 올라간 씬과 새 코드가 섞여 재현도 안 되는 버그가 난다.
func _on_update_ready(v: String) -> void:
	_set_update_state(false, "새 이야기를 받았어요 (v%s)\n앱을 껐다 켜면 적용돼요" % v,
		Color(1.0, 0.88, 0.52))
	_refresh_version()
	if _update_btn != null:
		_update_btn.text = "받기 완료"


func _on_update_failed(reason: String) -> void:
	# 사람이 누르지 않았는데 뜬 실패는 굳이 보여 주지 않는다.
	if _update_btn == null or not visible:
		return
	# 실패 색으로 산호를 쓰면 안 된다 — 쿼카 스카프 색이라 UI 에서는 금지다.
	_set_update_state(false, reason + "\n인터넷 연결을 확인해 주세요",
		Color(1.0, 0.86, 0.62))


func _set_update_state(busy: bool, msg: String, col: Color) -> void:
	if _update_btn != null:
		_update_btn.disabled = busy
		if not busy and _update_btn.text == "확인하는 중…":
			_update_btn.text = "업데이트 확인"
	if _update_hint != null:
		Wrap.put(_update_hint, msg)
		_update_hint.add_theme_color_override("font_color", col)


func _go_home() -> void:
	# 나가기 전에 저장한다. 여기까지 온 걸 잃게 하면 안 된다.
	SaveManager.save_now()
	close()
	SceneTransition.go_to("res://scenes/menu/MainMenu3D.tscn")

func open() -> void:
	_reset_armed = false
	reset_hint.text = ""
	_refresh_version()
	if _update_hint != null:
		Wrap.put(_update_hint, "")
	if _update_btn != null and not _update_btn.disabled:
		_update_btn.text = "업데이트 확인"
	reset_btn.text = "기록 초기화"
	visible = true
	_fit_panel()
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func close() -> void:
	visible = false

func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("cancel") or e.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()

## 한 번 더 눌러야 실제로 지운다 (실수 방지)
func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_btn.text = "정말 지울까요? (한 번 더)"
		reset_hint.text = "키운 기록이 모두 사라져요"
		return
	SaveManager.clear_save()
	# 지금 게임(쿼카 군단) 기록도 지운다. 옛 게임 선물은 이미 받았으니 다시 주지 않는다.
	LaneState.clear_save()
	LaneState.migrated = true
	LaneState.save()
	_reset_armed = false
	reset_btn.text = "기록 초기화"
	reset_hint.text = "초기화했어요"

func _apply(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) != OK:
		return
	bgm.value = c.get_value("audio", "bgm", 0.8)
	sfx.value = c.get_value("audio", "sfx", 0.9)
	_apply("BGM", bgm.value)
	AudioManager.set_bgm_volume(bgm.value)
	AudioManager.set_ambient_volume(bgm.value)
	_apply("SFX", sfx.value)
	AudioManager.set_sfx_volume(sfx.value)

func _save() -> void:
	var c := ConfigFile.new()
	c.load(CFG)                     # 다른 항목(화면 흔들림 등)을 지우지 않게 읽고 고친다
	c.set_value("audio", "bgm", bgm.value)
	c.set_value("audio", "sfx", sfx.value)
	c.save(CFG)

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
	_add_home_button()
	_add_update_row()
	_make_scrollable()


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
	var root := $Root as Control
	if root != null:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_top = -vp.y * 0.44
		panel.offset_bottom = vp.y * 0.44


## 게임 도중에는 여기서 메인화면으로 나갈 수 있어야 한다.
##
## 지금까지 게임에 들어가면 나오는 길이 없었다. 폰에는 Esc 가 없고,
## 안드로이드 뒤로가기는 한 화면 뒤로만 간다. 앱을 죽이는 것 말고는
## 메인화면으로 돌아갈 방법이 없었던 셈이다.
## 메인화면에서 연 설정에는 이 버튼을 넣지 않는다 — 이미 거기다.
func _add_home_button() -> void:
	var body := close_btn.get_parent()
	if body == null:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("MainMenu3D.tscn"):
		return

	var b := Button.new()
	b.name = "HomeBtn"
	b.text = "메인화면으로"
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


func _add_update_row() -> void:
	var body := close_btn.get_parent()
	if body == null:
		return

	var box := VBoxContainer.new()
	box.name = "UpdateBox"
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	body.move_child(box, reset_btn.get_index())

	_ver_label = Label.new()
	_ver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ver_label.add_theme_font_size_override("font_size", 30)
	_ver_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.88))
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
	_update_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_hint.add_theme_font_size_override("font_size", 30)
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
	_set_update_state(true, "확인하는 중...", Color(0.86, 0.83, 0.96))


func _on_up_to_date(v: String) -> void:
	_set_update_state(false, "최신 버전이에요 (v%s)" % v, Color(0.72, 0.90, 0.76))


## 받아 놓기만 하고 다음 실행에 적용한다. 돌아가는 중에 갈아끼우면
## 이미 올라간 씬과 새 코드가 섞여 재현도 안 되는 버그가 난다.
func _on_update_ready(v: String) -> void:
	_set_update_state(false, "v%s 를 받았어요.\n앱을 껐다 켜면 적용돼요" % v,
		Color(1.0, 0.88, 0.52))
	_refresh_version()
	if _update_btn != null:
		_update_btn.text = "받기 완료"


func _on_update_failed(reason: String) -> void:
	# 사람이 누르지 않았는데 뜬 실패는 굳이 보여 주지 않는다.
	if _update_btn == null or not visible:
		return
	# 실패 색으로 산호를 쓰면 안 된다 — 파트너 스카프 색이라 UI 에서는 금지다.
	_set_update_state(false, reason + "\n인터넷 연결을 확인해 주세요",
		Color(1.0, 0.86, 0.62))


func _set_update_state(busy: bool, msg: String, col: Color) -> void:
	if _update_btn != null:
		_update_btn.disabled = busy
		if not busy and _update_btn.text == "확인하는 중...":
			_update_btn.text = "업데이트 확인"
	if _update_hint != null:
		_update_hint.text = msg
		_update_hint.add_theme_color_override("font_color", col)


func _go_home() -> void:
	# 나가기 전에 저장한다. 여기까지 온 걸 잃게 하면 안 된다.
	if SaveManager.has_method("autosave") and get_tree().current_scene != null:
		SaveManager.autosave(get_tree().current_scene.scene_file_path)
	close()
	SceneTransition.go_to("res://scenes/menu/MainMenu3D.tscn")

func open() -> void:
	_reset_armed = false
	reset_hint.text = ""
	_refresh_version()
	if _update_hint != null:
		_update_hint.text = ""
	if _update_btn != null and not _update_btn.disabled:
		_update_btn.text = "업데이트 확인"
	reset_btn.text = "기록 초기화"
	visible = true
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
		reset_hint.text = "여행 기록과 앨범이 모두 사라져요"
		return
	SaveManager.clear_save()
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
	c.set_value("audio", "bgm", bgm.value)
	c.set_value("audio", "sfx", sfx.value)
	c.save(CFG)

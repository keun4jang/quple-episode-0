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


func _go_home() -> void:
	# 나가기 전에 저장한다. 여기까지 온 걸 잃게 하면 안 된다.
	if SaveManager.has_method("autosave") and get_tree().current_scene != null:
		SaveManager.autosave(get_tree().current_scene.scene_file_path)
	close()
	SceneTransition.go_to("res://scenes/menu/MainMenu3D.tscn")

func open() -> void:
	_reset_armed = false
	reset_hint.text = ""
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

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

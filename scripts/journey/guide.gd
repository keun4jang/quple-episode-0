class_name Guide
extends CanvasLayer
## 처음 잡은 사람에게 조작을 알려 주는 안내.
##
## `CLAUDE.md` 는 "버튼을 누르세요 같은 안내를 안 쓴다. 하고 싶게 만들어서
## 하게 한다" 고 적어 두었다. 그 원칙은 여전히 옳지만, 폰에서 처음
## 잡아 보면 **어디를 눌러야 하는지조차 모른다.** 그래서 딱 이만큼만 둔다.
##
## 지키는 선:
##
## - **한 번에 한 줄.** 목록도, 진행도도, 별점도 없다
## - **해내면 저절로 사라진다.** 확인 버튼을 누르게 하지 않는다
## - **못 해도 벌이 없다.** 그냥 다음 줄로 넘어가지 않고 기다릴 뿐이다
## - **한 번만 나온다.** 두 번째 여행부터는 조용하다
## - 말투는 시키는 말이 아니라 **곁에서 알려 주는 말**로 쓴다

const FLAG := "guide_done"
const FADE := 0.35

## [열쇠, 안내 문구]. 열쇠는 `done()` 이 받는 이름이다.
const STEPS := [
	["walk", "가고 싶은 곳을 톡 눌러 보세요."],
	["talk", "누군가에게 다가가 눌러 보면 말을 걸 수 있어요."],
	["act",  "오른쪽 아래 버튼으로도 할 수 있어요."],
	["map",  "오른쪽 위 작은 지도를 누르면 크게 볼 수 있어요."],
	["bag",  "오른쪽 아래 배낭에 사진과 편지가 쌓여요."],
	["go",   "정류장에 서면 다음 마을로 떠날 수 있어요."],
]

var _at := 0
var _panel: PanelContainer
var _label: Label
var _tw: Tween
var _shown := ""


func _ready() -> void:
	layer = 9
	add_to_group("guide")
	_build()
	if SaveManager.get_flag(FLAG, false):
		queue_free()
		return
	# 화면이 자리를 잡은 뒤에 첫 줄을 띄운다. 켜자마자 뜨면 급해 보인다.
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		_show_step()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.18, 0.80)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 92.0
	_panel.modulate.a = 0.0
	root.add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _show_step() -> void:
	if _at >= STEPS.size():
		return
	var text: String = STEPS[_at][1]
	if text == _shown:
		return
	_shown = text
	_label.text = text
	_fade_to(1.0)


func _fade_to(a: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_panel, "modulate:a", a, FADE)


## 그 일을 해냈다고 알려 준다. 지금 기다리던 것이면 다음으로 넘어간다.
func done(key: String) -> void:
	if _at >= STEPS.size() or String(STEPS[_at][0]) != key:
		return
	_at += 1
	_shown = ""
	if _at >= STEPS.size():
		_finish()
		return
	# 해낸 것이 눈에 남게 잠깐 비워 두고 다음 줄로.
	_fade_to(0.0)
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		_show_step()


func _finish() -> void:
	SaveManager.set_flag(FLAG, true)
	_fade_to(0.0)
	await get_tree().create_timer(FADE + 0.1).timeout
	if is_inside_tree():
		queue_free()


## 지금 무엇을 기다리고 있나 (테스트·디버그용)
func waiting_for() -> String:
	return String(STEPS[_at][0]) if _at < STEPS.size() else ""

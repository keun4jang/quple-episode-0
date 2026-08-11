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
## "quests" 를 맨 앞으로 옮기며 순서를 바꿨다. 옛 `guide_step` 값은
## **자리 번호**라, 순서가 바뀌면 같은 번호가 다른 줄을 가리키게 된다
## (예: 옛 2번="go" 였는데 새 순서에선 2번="talk"). 진행 중이던 사람이
## "go" 줄만 보고 "quests" 줄은 영영 못 보는 사고가 난다 — 그래서 키
## 이름을 바꿔 새로 센다. 이미 다 끝낸 사람(`FLAG` 참)은 어차피 옛
## 순서로도 다 봤으니 영향이 없다.
const STEP_FLAG := "guide_step2"
const FADE := 0.35

## [열쇠, 안내 문구]. 열쇠는 `done()` 이 받는 이름이다.
##
## **순서가 진행과 맞아야 한다.** 처음엔 배낭·미니맵을 프롤로그에서
## 가르쳤는데, 잿마루에는 주울 것도 편지도 없어서 배낭 네 칸이 전부
## "아직 아무것도 없어요" 였고 미니맵은 색 띠 네 줄이었다.
## **없는 것을 열어 보라고 시키는 셈**이라 지금은 뒤로 미뤘다 —
## 첫 여행지에 닿아야 볼 것이 생긴다.
## 문구를 이렇게 다듬은 이유(친구들 플레이 피드백): "버튼을 누르세요"
## 식보다 부드럽게, 그러면서도 **오른쪽 아래 버튼**과 **행복첩**이라는
## 두 낱말은 꼭 넣는다 — 막혔을 때 돌아올 자리 둘이다.
## **"quests" 를 맨 앞에 둔다.** "시작하자마자 퀘스트가 있어야
## 뭘 해야 할지 안다" 는 지적 — 걷기부터 가르치고 한참 뒤에야
## 행복첩을 알려 주면, 그 사이엔 "그냥 둘러보는" 느낌만 남는다.
const STEPS := [
	["quests", "이 마을에서 해볼 일은 행복첩에 접어 두었어요."],
	["walk", "가고 싶은 곳을 톡 누르면 천천히 걸어요."],
	["talk", "인연을 톡 누르면 다가가서 저절로 말을 걸어요."],
	["go",   "표지판이 선 자리에 서면 오른쪽 아래 버튼으로 떠날 수 있어요."],
	["map",  "새로 받은 지도는 오른쪽 위에 놓였어요."],
	["bag",  "배낭에 주운 것과 편지가 쌓여요."],
	["sleep", "잠자리에 서면 오른쪽 아래 버튼으로 하루를 마쳐요."],
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
	# 마을을 옮기면 `Place` 가 안내를 새로 만든다. 어디까지 왔는지
	# 남겨 두지 않으면 **첫 줄부터 다시 시작**한다 — 윤슬에 도착해서
	# "가고 싶은 곳을 톡 눌러 보세요" 를 또 읽게 된다.
	_at = clampi(int(SaveManager.get_flag(STEP_FLAG, 0)), 0, STEPS.size())
	if _at >= STEPS.size():
		SaveManager.set_flag(FLAG, true)
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
	# 줍기 알림("○○ 주웠어요")이 CENTER_TOP y=90 에 뜬다. 같은 자리에
	# 두면 안내가 위 레이어라 알림을 통째로 덮는다. 한 줄 아래로 내린다.
	_panel.offset_top = 150.0
	_panel.modulate.a = 0.0
	root.add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


## 그 단계가 지금 보여 줄 만한가.
##
## "map" 단계는 지도를 실제로 받은 뒤에야 뜻이 통한다 — 지도가 없으면
## 미니맵 자체가 안 보이는데(`docs/quest-journey.md` 3.5절), 안내가
## 먼저 뜨면 "누르라는 게 어디 있지?" 하고 헤매게 된다.
func _step_ready(key: String) -> bool:
	if key == "map":
		return Quests.has_map()
	return true


## 다른 창이 떠 있으면 잠깐 물러난다. 배낭 위에 겹쳐 뜨면 지저분하다.
func _process(_delta: float) -> void:
	# 아직 조건이 안 된 단계면 조용히 기다린다 — 조건이 갖춰지는 순간
	# (지도를 받는 순간) 저절로 뜬다.
	if _at < STEPS.size() and _shown == "" and _step_ready(String(STEPS[_at][0])):
		_show_step()
	if _panel == null or _shown == "":
		return
	var busy := false
	for g in ["journey_say", "travel_board"]:
		var n := get_tree().get_first_node_in_group(g)
		if n != null and n.visible:
			busy = true
	var hud := get_tree().get_first_node_in_group("journey_hud")
	if hud != null and hud.has_method("bag_open") and hud.bag_open():
		busy = true
	var mm := get_tree().get_first_node_in_group("mini_map")
	if mm != null and mm.has_method("is_big") and mm.is_big():
		busy = true
	_panel.visible = not busy


func _show_step() -> void:
	if _at >= STEPS.size():
		return
	if not _step_ready(String(STEPS[_at][0])):
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
	SaveManager.set_flag(STEP_FLAG, _at)
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

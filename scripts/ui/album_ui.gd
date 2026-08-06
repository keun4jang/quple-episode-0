extends CanvasLayer

@onready var content_label: Label = $Panel/MarginContainer/VBoxContainer/ContentLabel
@onready var hint_label: Label = $Panel/MarginContainer/VBoxContainer/HintLabel
@onready var panel: Panel = $Panel

var _current_page: int = 0

# 게임 진행에 따라 사진이 잠금 해제됨
const PHOTOS = [
	{
		"title": "[ 야근의 창문 ]",
		"text": "수없이 올려다보던 사무실 창문.\n오늘은 저 불빛들 속으로 나간다.",
		"hint": "쿼카전자 4층 | 밤 11시",
		"min_state": 7
	},
	{
		"title": "[ 첫 번째 기록 ]",
		"text": "오늘은 퇴근이 아니라\n출발이었다.",
		"hint": "쿼카전자 앞 | 자정",
		"min_state": 11
	},
]

const D := preload("res://scripts/ui/design.gd")

var _scrim: ColorRect
var _hint: Label


func _ready() -> void:
	add_to_group("album_ui")     # 뒤로가기가 이걸 찾아 닫는다
	layer = 20                   # 게임 UI(8) 와 방향 표시(6) 위로
	_build_scrim()
	visible = false
	visibility_changed.connect(_on_visibility)


## 앨범이 열렸는데 뒤 배경이 그대로 보이면 붕 떠 보인다. 뒤를 눌러 어둡게 깐다.
func _build_scrim() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0.05, 0.04, 0.08, 0.72)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	move_child(_scrim, 0)
	# CanvasLayer 직속 Control 은 부모가 Control 이 아니라 앵커만으로 안 커진다.
	# 화면 크기를 직접 넣고, 화면이 바뀌면 따라가게 한다.
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)

	_hint = D.label("화면을 누르면 닫혀요", D.TEXT_S, D.ACCENT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 화면 전체를 덮고, 안내는 아래 가운데에 놓는다.
func _fit_to_screen() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _scrim != null:
		_scrim.position = Vector2.ZERO
		_scrim.size = vp
	if _hint != null:
		_hint.size = Vector2(vp.x, 40)
		_hint.position = Vector2(0, vp.y - 168)


## 열려 있는 동안에는 조작 버튼과 방향 표시를 감춘다.
## 앨범을 보는 중에 조이스틱과 화살표가 같이 떠 있으면 화면이 시끄럽다.
func _on_visibility() -> void:
	if visible:
		_fit_to_screen()
		_page_sound()
	for g in ["touch_controls", "quest_marker"]:
		var n := get_tree().get_first_node_in_group(g)
		if n != null and n is CanvasLayer:
			n.visible = not visible


## 종이 넘기는 소리. 앨범을 열 때와 장을 넘길 때 난다.
func _page_sound() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("page_turn"):
		am.page_turn()


## 화면 아무 데나 톡 치면 닫힌다. 폰에는 B 키가 없다.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and not event.pressed:
		visible = false
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("album"):
		if visible:
			visible = false
		else:
			refresh()
			_play_open_animation()
			visible = true
	if not visible:
		return
	var unlocked = _get_unlocked()
	if unlocked.size() == 0:
		return
	if event.is_action_pressed("move_left"):
		var before := _current_page
		_current_page = max(0, _current_page - 1)
		_show_page(unlocked)
		if _current_page != before:
			_page_sound()
	elif event.is_action_pressed("move_right"):
		var before2 := _current_page
		_current_page = min(unlocked.size() - 1, _current_page + 1)
		_show_page(unlocked)
		if _current_page != before2:
			_page_sound()

func _get_unlocked() -> Array:
	var result = []
	for p in PHOTOS:
		if Episode0State.current_state >= p.min_state:
			result.append(p)
	return result

func refresh() -> void:
	var unlocked = _get_unlocked()
	if unlocked.size() == 0:
		content_label.text = "아직 비어 있어요."
		hint_label.text = "첫 사진을 찍으면 기록됩니다."
		visible = true
		return
	_current_page = clamp(_current_page, 0, unlocked.size() - 1)
	_show_page(unlocked)

func _show_page(unlocked: Array) -> void:
	var p = unlocked[_current_page]
	content_label.text = p.title + "\n\n" + p.text
	hint_label.text = p.hint + "  (" + str(_current_page + 1) + " / " + str(unlocked.size()) + ")"

# 앨범 열기 애니메이션: 0.8 스케일에서 1.0으로 ease_out 확대
func _play_open_animation() -> void:
	if panel == null:
		return
	panel.scale = Vector2(0.8, 0.8)
	var tw = create_tween()
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

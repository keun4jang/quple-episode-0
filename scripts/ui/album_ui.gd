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

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("key_album"):
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
	if event.is_action_pressed("ui_left"):
		_current_page = max(0, _current_page - 1)
		_show_page(unlocked)
	elif event.is_action_pressed("ui_right"):
		_current_page = min(unlocked.size() - 1, _current_page + 1)
		_show_page(unlocked)

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

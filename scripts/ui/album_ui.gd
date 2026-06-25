extends CanvasLayer

@onready var content_label: Label = $Panel/MarginContainer/VBoxContainer/ContentLabel
@onready var hint_label: Label = $Panel/MarginContainer/VBoxContainer/HintLabel

var _current_page: int = 0

# Photos unlock as game progresses
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

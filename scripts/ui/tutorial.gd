extends CanvasLayer
## 첫 3분. 처음 켠 사람이 무엇을 할 수 있는지 알게 만든다.
##
## 읽고 넘기는 안내문은 아무도 안 읽는다. 그래서 각 단계는 **해내야** 넘어간다.
## 걸어보기 → 조사해보기. 두 개면 충분하다. 나머지는 목표(바람 노트)가 이끈다.
##
## 한 번 끝내면 다시 안 나온다. 저장 파일에 표시가 남는다.
## 저장이 없거나 깨졌을 때 튜토리얼이 매번 뜨는 것보다는 낫다 — 안 뜨는 쪽이 덜 거슬린다.

const DONE_KEY := "tutorial_done"
const D := preload("res://scripts/ui/design.gd")

## 단계 정의. check 는 매 프레임 불려서 "해냈는가" 를 판정한다.
enum Step { MOVE, INTERACT, DONE }

@export var enabled := true

var _step := Step.MOVE
var _panel: PanelContainer
var _label: Label
var _hint: Label
var _elapsed := 0.0
var _moved := 0.0
var _start_pos := Vector3.ZERO
var _player: Node3D
var _finished := false


func _ready() -> void:
	add_to_group("tutorial")
	layer = 9                       # 터치 UI(8) 위, 전환(10) 아래
	if not enabled or _already_done():
		queue_free()
		return
	_build()
	# 씬이 다 서고 대사가 뜬 뒤에 시작한다. 첫 대사와 겹치면 둘 다 안 읽힌다.
	await get_tree().create_timer(0.6).timeout
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_start_pos = _player.global_position
	set_process(true)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	match _step:
		Step.MOVE:
			_check_move()
		Step.INTERACT:
			_check_interact()


# ── 단계 ───────────────────────────────────────────────────────────────

func _check_move() -> void:
	# 대사가 열려 있는 동안은 못 움직인다. 그때는 "넘기기" 를 먼저 안내한다.
	var db := get_tree().get_first_node_in_group("dialogue_box")
	var talking: bool = db != null and db.has_method("is_open") and db.is_open()
	if talking:
		_show("대사를 넘겨볼까요", "조사 버튼을 누르면 다음으로 넘어가요")
		return
	_show("걸어볼까요", "왼쪽 화면을 손가락으로 밀어보세요")
	if _player == null or not is_instance_valid(_player):
		return
	_moved = _start_pos.distance_to(_player.global_position)
	if _moved > 1.2:
		_advance(Step.INTERACT)


func _check_interact() -> void:
	var tc := get_tree().get_first_node_in_group("touch_controls")
	var can: bool = tc != null and tc.has_method("_can_use") and tc._can_use("interact")
	if can:
		_show("가까이 왔어요", "오른쪽 아래 '조사' 를 눌러보세요")
	else:
		_show("무언가 있는 곳으로", "왼쪽 위 목표를 따라가 보세요")
	# 상호작용이 실제로 일어났는지는 대사가 새로 열리는 것으로 안다
	var db := get_tree().get_first_node_in_group("dialogue_box")
	if db != null and db.has_method("is_open") and db.is_open() and _elapsed > 2.0:
		_advance(Step.DONE)


func _advance(next: int) -> void:
	_step = next
	if _step == Step.DONE:
		_finish()


func _finish() -> void:
	_finished = true
	_mark_done()
	_show("좋아요", "이제 목표를 따라가 보세요")
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


# ── 표시 ───────────────────────────────────────────────────────────────

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", D.panel())
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position = Vector2(0, 30)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", D.GAP_XS)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", D.TEXT_L)
	_label.add_theme_color_override("font_color", D.TEXT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", D.TEXT_S)
	_hint.add_theme_color_override("font_color", D.ACCENT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)

	add_child(_panel)


func _show(title: String, hint: String) -> void:
	if _label.text == title and _hint.text == hint:
		return
	_label.text = title
	_hint.text = hint


# ── 완료 기록 ──────────────────────────────────────────────────────────

func _already_done() -> bool:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("get_flag"):
		return false
	return bool(sm.get_flag(DONE_KEY, false))


func _mark_done() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("set_flag"):
		sm.set_flag(DONE_KEY, true)

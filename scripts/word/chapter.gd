extends Control
## 한 챕터를 이어서 돌린다. 단어 셋에 미니게임 하나.
##
## 이 파일이 하는 일은 하나뿐이다 — **끊을 자리를 안 만드는 것.**
##
## 장면이 끝나면 곧바로 다음 장면이 시작된다. "다음" 버튼도, 결과 화면도,
## 진도율 막대도 없다. 대신 넘어가기 직전 **다음 장면이 0.4초 스친다.**
## 뭔지 모를 만큼 짧게 — 그게 궁금해서 계속 하게 된다.

signal chapter_done()

## 돌릴 차례. `@` 로 시작하면 미니게임.
@export var steps: Array[String] = []
@export var instant := false

const PEEK := 0.4

var _i := 0
var _current: Node = null
var _peek: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if steps.is_empty():
		steps = WordData.CHAPTER_1.duplicate()

	_peek = ColorRect.new()
	_peek.color = Color(0, 0, 0, 0.0)
	_peek.set_anchors_preset(Control.PRESET_FULL_RECT)
	_peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peek.z_index = 30
	add_child(_peek)

	_start_step()


func _start_step() -> void:
	if _i >= steps.size():
		chapter_done.emit()
		return

	var step := steps[_i]
	if WordData.is_minigame(step):
		_current = preload("res://scenes/word/Minigame.tscn").instantiate()
		_current.minigame_id = step.substr(1)
		_current.instant = instant
		_current.minigame_done.connect(_on_step_done.unbind(1))
	else:
		_current = preload("res://scenes/word/WordScene.tscn").instantiate()
		_current.scene_id = step
		_current.instant = instant
		_current.scene_cleared.connect(_on_step_done.unbind(1))
	add_child(_current)
	move_child(_peek, get_child_count() - 1)     # 미리보기는 늘 맨 위


func _on_step_done() -> void:
	_i += 1
	if instant:
		_swap()
		return
	await _peek_next()
	_swap()


## 다음 장면을 0.4초만 보여 준다.
##
## 온전한 미리보기가 아니다 — **다 보이면 안 된다.** 화면이 잠깐 밝아졌다
## 어두워지는 사이로 다음 배경색이 스칠 뿐이다.
func _peek_next() -> void:
	if _i >= steps.size():
		return
	var col := _next_tint()
	var tw := create_tween()
	_peek.color = Color(col.r, col.g, col.b, 0.0)
	tw.tween_property(_peek, "color:a", 0.9, PEEK * 0.5)
	tw.tween_property(_peek, "color:a", 0.0, PEEK * 0.5).set_delay(0.1)
	await tw.finished


func _next_tint() -> Color:
	var step := steps[_i]
	if WordData.is_minigame(step):
		return Color("#7FA8CC")
	var d := WordData.scene_by_id(step)
	return Color(String(d.get("look", {}).get("sky", "#8FB6D6")))


func _swap() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
		_current = null
	_start_step()

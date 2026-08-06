extends Node
## 안드로이드 뒤로가기 버튼.
##
## 기본 동작은 **앱 종료**다. 실수로 한 번만 눌러도 게임이 꺼진다.
## 폰 게임에서 이건 사고에 가깝다. 열려 있는 화면을 하나씩 닫고,
## 더 닫을 게 없을 때만 "한 번 더 누르면 나갑니다" 를 보여준다.
##
## 이 노드가 SceneTransition 씬 안에 사는 이유:
## 오토로드 **목록**은 project.godot 에 있고, 그건 APK 를 새로 깔아야 바뀐다.
## 그런데 SceneTransition 은 오토로드가 씬이라, 그 씬에 자식을 넣는 건
## 리소스 팩 갱신만으로 폰에 전달된다. 새 오토로드를 만드는 대신 여기 얹는다.
##
## project.godot 의 quit_on_go_back 도 같은 이유로 못 고친다.
## 대신 실행 중에 SceneTree 로 끈다. 이건 코드라서 갱신으로 전달된다.

const CONFIRM_WINDOW := 2.5      # 이 안에 한 번 더 누르면 종료
const D := preload("res://scripts/ui/design.gd")

var _armed_at := -100.0
var _toast: Label


func _ready() -> void:
	add_to_group("back_handler")
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 뒤로가기와 창 닫기를 우리가 받는다. 안 그러면 엔진이 바로 꺼버린다.
	get_tree().set_quit_on_go_back(false)
	get_tree().set_auto_accept_quit(false)
	_build_toast()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_quit()


func _on_back() -> void:
	if _close_topmost():
		_armed_at = -100.0
		return
	# 더 닫을 게 없다. 두 번 눌러야 나간다.
	var now := _now()
	if now - _armed_at <= CONFIRM_WINDOW:
		_quit()
		return
	_armed_at = now
	_show_toast("한 번 더 누르면 나가요")


## 열려 있는 것 중 가장 위를 닫는다. 닫았으면 true.
##
## 순서가 곧 "위" 다. 전체 화면을 덮는 것부터 닫는다.
func _close_topmost() -> bool:
	var tree := get_tree()

	# 씬이 넘어가는 중이면 아무것도 하지 않는다. 도중에 끼어들면 상태가 꼬인다.
	var st := get_parent()
	if st != null and ("is_transitioning" in st) and st.is_transitioning:
		return true

	var settings := tree.get_first_node_in_group("settings_ui")
	if settings != null and settings.visible and settings.has_method("close"):
		settings.close()
		return true

	var stats := tree.get_first_node_in_group("stats_ui")
	if stats != null and stats.visible and stats.has_method("_close"):
		stats._close()
		return true

	var album := tree.get_first_node_in_group("album_ui")
	if album != null and album.visible:
		album.visible = false
		return true

	# 바람 노트는 펼친 상태만 닫는다. 왼쪽 위 작은 표시는 항상 떠 있는 게 맞다.
	var wind := tree.get_first_node_in_group("wind_note")
	if wind != null:
		var full := wind.get_node_or_null("Full")
		if full != null and full.visible:
			full.visible = false
			return true

	# 선택지는 뒤로가기로 못 넘긴다. 골라야 이야기가 나아간다.
	var choice := tree.get_first_node_in_group("choice_box")
	if choice != null and choice.visible:
		return true

	var dialogue := tree.get_first_node_in_group("dialogue_box")
	if dialogue != null and dialogue.has_method("is_open") and dialogue.is_open():
		dialogue.hide_box()
		return true

	return false


func _quit() -> void:
	# 나가기 전에 저장한다. 여행은 실제 시각으로 흐르니 기록만 남으면 된다.
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("save_game"):
		sm.save_game()
	get_tree().quit()


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


# ── 안내 ───────────────────────────────────────────────────────────────

func _build_toast() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)
	_toast = D.label("", D.TEXT_M)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position = Vector2(0, -120)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	cl.add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(CONFIRM_WINDOW * 0.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

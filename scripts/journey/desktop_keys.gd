class_name DesktopKeys
extends Node
## PC(윈도우·맥) 키보드 단축키. 폰에서는 키가 안 들어오니 아무 일도 안 한다.
##
##   Esc      열린 것 닫기 (없으면 설정)
##   I · B    배낭          Q · J  이 마을 할 일(퀘스트)     C  캐릭터
##   L        편지          M      큰 지도                   H  하는 법
##   F11 · Alt+Enter   전체 화면 켜고 끄기
## 이동(화살표)·공격(Z)·스킬(1~7)·말 걸기(스페이스·엔터)는 원래 있던 자리에서 받는다.

const TABS := {KEY_I: 0, KEY_B: 0, KEY_L: 2, KEY_Q: 4, KEY_J: 4, KEY_C: 5}

var hud: Node = null


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var code := k.keycode
	if code == KEY_F11 or (code == KEY_ENTER and k.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if code == KEY_ESCAPE:
		_escape()
		get_viewport().set_input_as_handled()
		return
	if hud == null or not is_instance_valid(hud):
		return
	# 대사가 떠 있을 땐 메뉴를 안 연다 - 대사 넘기기와 엉키지 않게.
	var p = hud.call("_place") if hud.has_method("_place") else null
	if p != null and p.say != null and p.say.is_busy():
		return
	if TABS.has(code):
		hud.open_tab(int(TABS[code]))
		get_viewport().set_input_as_handled()
	elif code == KEY_M and p != null and p.minimap != null:
		p.minimap.toggle()
		get_viewport().set_input_as_handled()
	elif code == KEY_H:
		HowToPlay.open(get_tree())
		get_viewport().set_input_as_handled()


static func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Esc - 폰의 뒤로가기처럼 가장 위에 열린 것을 닫는다. 닫을 게 없으면 설정을 연다
## (PC 에서는 Esc 두 번에 게임이 꺼지면 안 된다 - 끄는 건 창 닫기로).
func _escape() -> void:
	var back := get_node_or_null("/root/SceneTransition/BackHandler")
	if back != null and back.has_method("_close_topmost") and back._close_topmost():
		return
	var sv := get_tree().get_first_node_in_group("settings_ui")
	if sv != null and sv.has_method("open"):
		sv.open()

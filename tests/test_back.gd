extends Node
## 안드로이드 뒤로가기.
##
## 기본값은 앱 종료다. 실수로 한 번 눌러서 게임이 꺼지면 그건 사고다.
## 열린 화면을 하나씩 닫고, 더 닫을 게 없을 때만 두 번 눌러 나가게 한다.

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

var _bh


func _ready() -> void:
	print("=== 뒤로가기 테스트 ===")
	var map = load("res://scenes/maps/CompanyFront3D.tscn").instantiate()
	add_child(map)
	for i in 30:
		await get_tree().process_frame

	_bh = get_tree().get_first_node_in_group("back_handler")
	ck("뒤로가기 처리기가 살아 있다", _bh != null)
	if _bh == null:
		_done()
		return

	print("\n[1] 엔진이 바로 끄지 못하게 막았는가")
	# 이걸 안 끄면 뒤로가기 한 번에 앱이 종료된다.
	ck("quit_on_go_back 꺼짐", not get_tree().quit_on_go_back)
	ck("auto_accept_quit 꺼짐", not get_tree().auto_accept_quit)

	print("\n[2] 열린 화면부터 닫는다")
	var db = get_tree().get_first_node_in_group("dialogue_box")
	db.show_text("테스트 대사")
	await get_tree().process_frame
	ck("대사가 열려 있다", db.is_open())
	ck("뒤로가기가 대사를 닫았다", _bh._close_topmost() and not db.is_open())

	var wind = get_tree().get_first_node_in_group("wind_note")
	var full = wind.get_node_or_null("Full")
	full.visible = true
	ck("바람 노트를 닫았다", _bh._close_topmost() and not full.visible)

	var album = get_tree().get_first_node_in_group("album_ui")
	ck("앨범을 그룹으로 찾는다", album != null)
	if album != null:
		album.visible = true
		ck("앨범을 닫았다", _bh._close_topmost() and not album.visible)

	print("\n[3] 선택지는 뒤로가기로 못 넘긴다")
	# 골라야 이야기가 나아간다. 여기서 빠져나가면 진행이 막힌다.
	var choice = get_tree().get_first_node_in_group("choice_box")
	if choice != null:
		choice.visible = true
		ck("선택지는 닫지 않고 삼킨다", _bh._close_topmost() and choice.visible)
		choice.visible = false

	print("\n[4] 닫을 게 없으면 두 번 눌러야 나간다")
	ck("닫을 것이 없다", not _bh._close_topmost())
	# 첫 번째 뒤로가기 — 안내만 뜨고 종료되지 않아야 한다.
	# (두 번째는 실제로 앱을 끄기 때문에 테스트에서 부를 수 없다.
	#  대신 "언제 끄기로 결정하는가" 인 _armed_at 을 본다.)
	_bh._armed_at = -100.0
	_bh._on_back()
	ck("첫 번째로는 안 나간다 (종료 대기 상태로만 들어감)",
		_bh._now() - _bh._armed_at < 1.0)
	ck("안내를 보여준다", _bh._toast != null and _bh._toast.modulate.a > 0.5,
		"문구: %s" % (_bh._toast.text if _bh._toast else ""))

	print("\n[5] 시간이 지나면 다시 처음부터")
	var stale: float = _bh._now() - _bh.CONFIRM_WINDOW - 1.0
	_bh._armed_at = stale
	_bh._on_back()
	ck("한참 뒤 누르면 또 안내부터 (종료 안 함)", _bh._armed_at > stale)

	_done()


func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)

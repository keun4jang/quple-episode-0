extends SceneTree
## 목록 끌기 점검 (DragScroll). 단추·카드 위를 잡고 끌어도 넘어가는가, 끄는 동안 단추가 안 눌리는가,
## 톡 누르면 눌리는가, 팝업이 떠 있으면 뒤 목록이 그대로인가.
##   QUPLE_RES=720x1560 tools/godot-run.sh --render --path . -s res://tools/sim/check_scroll.gd
var g

func _ev_btn(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(e, true)

func _ev_move(p: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)

func _drag(a: Vector2, b: Vector2) -> void:
	_ev_move(a, Vector2.ZERO)
	await process_frame
	_ev_btn(a, true)
	await process_frame
	for i in 10:
		var p := a.lerp(b, float(i + 1) / 10.0)
		_ev_move(p, (b - a) / 10.0)
		await process_frame
	_ev_btn(b, false)
	await process_frame

func _init() -> void:
	await process_frame
	LaneState.reset()
	LaneState.tut = 99
	LaneState.migrated = true
	LaneState.seen_intro = true
	LaneState.cleared = 40
	for id in LaneData.ALL_ORDER:
		LaneState.units[id] = 3
	LaneState.unlock_by_stage()
	LaneState.daily_day = int(Time.get_unix_time_from_system()) / 86400
	LaneState.save(int(Time.get_unix_time_from_system()))
	g = load("res://scenes/lane/LaneGame.tscn").instantiate()
	root.add_child(g)
	await create_timer(1.0).timeout
	g._home_tab = "lineup"
	g._fill_home()
	await create_timer(0.5).timeout
	var sc: ScrollContainer = g._home.find_child("Scroll", true, false)
	var r := sc.get_global_rect()
	var lineup0 := LaneState.lineup.duplicate()
	# 1) 버튼(편성 칸) 위를 잡고 위로 끌기
	var a := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.7)
	await _drag(a, a + Vector2(0, -300))
	await create_timer(0.3).timeout
	var s1 := sc.scroll_vertical
	print("DRAG_ON_BUTTON scroll=%d lineup_same=%s" % [s1, str(LaneState.lineup == lineup0)])
	# 2) 그냥 톡 누르기 - 버튼이 눌려야 한다
	var lineup1 := LaneState.lineup.duplicate()
	var tb: Button = null
	for btn in g._home_body.find_children("*", "Button", true, false):
		var br: Rect2 = btn.get_global_rect()
		if r.encloses(br) and br.size.y >= 150.0:
			tb = btn
			break
	if tb != null:
		a = tb.get_global_rect().get_center()
	await _drag(a, a)
	await create_timer(0.3).timeout
	print("TAP toggled=%s" % str(LaneState.lineup != lineup1))
	# 3) 팝업이 떠 있으면 뒤 목록은 안 움직인다
	var s2 := sc.scroll_vertical
	g._popup("시험")
	await create_timer(0.2).timeout
	await _drag(a + Vector2(0, -100), a + Vector2(0, 150))
	await create_timer(0.3).timeout
	print("MODAL scroll_same=%s" % str(sc.scroll_vertical == s2))
	for m in get_nodes_in_group("modal"):
		if m.name == "Popup":
			m.free()
	g._home_tab = "units"
	g._fill_home()
	await create_timer(0.5).timeout
	sc.scroll_vertical = 0
	await create_timer(0.2).timeout
	var c := r.position + Vector2(90, r.size.y * 0.6)   # 카드 왼쪽 (초상화 자리)
	await _drag(c, c + Vector2(0, -350))
	await create_timer(0.3).timeout
	print("DRAG_ON_CARD scroll=%d" % sc.scroll_vertical)
	LaneState.clear_save()
	quit()

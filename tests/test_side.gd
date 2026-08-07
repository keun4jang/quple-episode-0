extends Node
## 옆에서 보는 맵: 걷기 · 점프 · 사다리 · 계단 · 엘리베이터 · 문
##
## 이것들은 정지 화면으로는 확인할 수 없다. 실제로 눌러 보고 캐릭터가
## 어디로 갔는지를 재야 한다. 발판 높이 하나만 잘못 바꿔도 점프로 못
## 닿는 곳이 생기는데, 그건 손으로 해 보기 전에는 안 드러난다.

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

var map: SideMap
var w: SideWalker

func hold(action: String, secs: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(secs).timeout
	Input.action_release(action)
	await get_tree().physics_frame

func settle(secs := 0.4) -> void:
	await get_tree().create_timer(secs).timeout

func place(x: float, y: float) -> void:
	w.global_position = Vector2(x, y)
	w.velocity = Vector2.ZERO
	await settle(0.35)

func _ready() -> void:
	print("=== 옆에서 보는 맵 테스트 ===")
	map = load("res://scenes/side/SideMap.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await settle(0.6)
	w = map.walker
	ck("캐릭터가 세워졌다", w != null)
	if w == null:
		return _done()

	print("\n[1] 걷기")
	ck("바닥을 딛고 있다", w.state == SideWalker.State.GROUND, "state=%d" % w.state)
	var x0 := w.global_position.x
	await hold("move_right", 0.8)
	var dx := w.global_position.x - x0
	ck("오른쪽으로 걸었다", dx > 200.0, "%.0f px" % dx)
	ck("오른쪽을 보고 있다", w.facing == 1)
	await settle(0.3)
	ck("손을 떼면 선다", absf(w.velocity.x) < 20.0, "vx=%.1f" % w.velocity.x)

	var x1 := w.global_position.x
	await hold("move_left", 0.6)
	ck("왼쪽으로도 걷는다", w.global_position.x < x1)
	ck("왼쪽을 보고 있다", w.facing == -1)

	print("\n[2] 점프")
	await place(400, 880)
	var y0 := w.global_position.y
	Input.action_press("jump")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("jump")
	await get_tree().create_timer(0.20).timeout
	var rose := y0 - w.global_position.y
	ck("살짝 누르면 낮게 뛴다", rose > 20.0 and rose < 190.0, "%.0f px" % rose)
	await settle(1.2)

	await place(400, 880)
	y0 = w.global_position.y
	var peak := y0
	Input.action_press("jump")
	for i in range(30):
		await get_tree().physics_frame
		peak = minf(peak, w.global_position.y)
	Input.action_release("jump")
	var high := y0 - peak
	ck("꾹 누르면 높게 뛴다", high > 190.0, "%.0f px" % high)
	ck("공중에 있었다", true)
	await settle(1.4)
	ck("다시 땅에 내려왔다", w.state == SideWalker.State.GROUND, "state=%d" % w.state)

	print("\n[3] 사다리")
	await place(700, 880)
	ck("사다리 앞에서 그냥 서 있다", w.state == SideWalker.State.GROUND,
		"지나가기만 해도 붙으면 안 된다")
	var ly := w.global_position.y
	await hold("move_up", 1.3)
	ck("위를 누르면 오른다", w.global_position.y < ly - 200.0,
		"%.0f px 올라감" % (ly - w.global_position.y))
	ck("사다리를 타는 중이다", w.state == SideWalker.State.LADDER, "state=%d" % w.state)
	var uy := w.global_position.y
	await hold("move_down", 0.5)
	ck("아래를 누르면 내려온다", w.global_position.y > uy)

	print("\n[4] 계단")
	await place(2060, 860)
	var sy := w.global_position.y
	await hold("move_right", 1.6)
	var up := sy - w.global_position.y
	ck("걷기만 해도 계단을 오른다", up > 150.0, "%.0f px 올라감" % up)
	ck("계단 위에서도 땅을 딛고 있다", w.state == SideWalker.State.GROUND)
	var dy := w.global_position.y
	await hold("move_right", 3.6)
	ck("반대쪽 계단으로 내려온다", w.global_position.y > dy + 100.0,
		"%.0f px 내려옴" % (w.global_position.y - dy))

	print("\n[5] 엘리베이터")
	await place(3300, 620)
	await settle(0.5)
	var ey := w.global_position.y
	await hold("move_up", 2.4)
	ck("올라간다", w.global_position.y < ey - 300.0,
		"%.0f px 올라감" % (ey - w.global_position.y))
	var ty := w.global_position.y
	await hold("move_down", 2.4)
	ck("내려온다", w.global_position.y > ty + 300.0)

	print("\n[6] 배경 겹")
	ck("겹이 두 장 이상 깔렸다", map._layers.size() >= 2, "%d 장" % map._layers.size())
	var far = map._layers[0]
	var near = map._layers[map._layers.size() - 1]
	ck("먼 겹이 더 천천히 지나간다", float(far["factor"]) < float(near["factor"]),
		"%.2f < %.2f" % [far["factor"], near["factor"]])

	print("\n[7] 폰 조작")
	var touch := map.get_node_or_null("SideTouch")
	if touch == null:
		for c in map.get_children():
			if c is SideTouch: touch = c
	ck("터치 조작이 있다", touch != null)
	if touch != null:
		# 방향은 조이스틱, 버튼은 점프와 조사 둘이다.
		ck("  조이스틱이 있다", touch._stick_base != null)
		for a in ["jump", "interact"]:
			ck("  %s 버튼" % a, touch._btns.has(a))
		# 스틱을 오른쪽으로 민 것처럼 넣어 본다
		touch._stick_finger = 0
		touch._stick_update(touch._stick_center + Vector2(200, 0))
		ck("  스틱 오른쪽 → 걷기", Input.is_action_pressed("move_right"))
		touch._stick_update(touch._stick_center + Vector2(0, -200))
		ck("  스틱 위 → 오르기", Input.is_action_pressed("move_up"))
		ck("  위로 밀면 걷기는 풀린다", not Input.is_action_pressed("move_right"))
		touch._stick_release()
		ck("  놓으면 전부 풀린다", not Input.is_action_pressed("move_up"))

	print("\n[8] 0편 맵이 옆에서 보는 판으로 갈아끼워졌는가")
	# 맵을 부르는 곳이 열 군데 넘게 흩어져 있어서, 길목 한 곳에서 바꾼다.
	# 그 표가 빠지면 어떤 문은 옛 3D 맵으로 새어 나간다.
	var pairs := {
		"res://scenes/maps/CompanyFront3D.tscn": "res://scenes/side/Front.tscn",
		"res://scenes/maps/CompanyLobby3D.tscn": "res://scenes/side/Lobby.tscn",
		"res://scenes/maps/Office3D.tscn": "res://scenes/side/Office.tscn",
		"res://scenes/maps/BossDoorHallway3D.tscn": "res://scenes/side/Hallway.tscn",
	}
	for old in pairs:
		ck("%s → 옆맵" % old.get_file(), SceneTransition.route(old) == pairs[old],
			SceneTransition.route(old))
	ck("모르는 경로는 그대로 둔다",
		SceneTransition.route("res://scenes/travel/TravelHub.tscn")
			== "res://scenes/travel/TravelHub.tscn")

	print("\n[9] 네 맵이 실제로 서는가")
	Episode0State.reset()
	for spec in [{"p": "res://scenes/side/Front.tscn", "n": "회사 앞"},
			{"p": "res://scenes/side/Lobby.tscn", "n": "로비"},
			{"p": "res://scenes/side/Office.tscn", "n": "사무실"},
			{"p": "res://scenes/side/Hallway.tscn", "n": "복도"}]:
		var m: Node = load(str(spec["p"])).instantiate()
		add_child(m)
		await get_tree().create_timer(0.5).timeout
		ck("%s 가 선다" % spec["n"], m.walker != null)
		if m.walker != null:
			ck("  바닥을 딛는다", m.walker.state == SideWalker.State.GROUND,
				"state=%d y=%.0f" % [m.walker.state, m.walker.global_position.y])
			# 바닥이 없으면 캐릭터가 끝없이 떨어진다. 화면으로는 한동안 안 보인다.
			ck("  아래로 새지 않는다", m.walker.global_position.y < m.FLOOR_Y + 60.0,
				"y=%.0f" % m.walker.global_position.y)
		ck("  할 수 있는 일이 있다", m._spots.size() >= 2, "%d 곳" % m._spots.size())
		ck("  곳 이름이 있다", m.map_title() != "", m.map_title())
		ck("  대사창이 아래 조작을 덮지 않는다", _dialogue_clear(m))
		# 터치 선택 버튼이 실제로 일을 시키는가 — 사무실에서 애인 앞에 서서
		# SideTouch._press 를 부르면 대사창이 떠야 한다. action_press 만으로는
		# 이벤트가 없어서 안 떴다 (폰에서 문이 안 열리던 원인).
		if m.map_title().contains("사무실") and m.walker != null:
			m.walker.global_position = Vector2(1360, m.FLOOR_Y - 10)
			await get_tree().create_timer(0.6).timeout
			var st2: SideTouch = m._touch
			st2._press(7, "interact")
			st2._release(7)
			await get_tree().create_timer(0.8).timeout
			ck("  터치 선택 → 말 걸기가 된다", m.dialogue_box.visible)
		# 맵 끝 벽 — 캐릭터를 맵 밖 40px 에 두고 왼쪽으로 밀면 벽에 막혀야 한다
		if m.walker != null:
			m.walker.global_position = Vector2(30, m.FLOOR_Y - 10)
			Input.action_press("move_left")
			await get_tree().create_timer(0.8).timeout
			Input.action_release("move_left")
			ck("  왼쪽 끝 벽에 막힌다", m.walker.global_position.x > -80.0,
				"x=%.0f" % m.walker.global_position.x)
		m.queue_free()
		await get_tree().process_frame

	print("\n[10] 로비 2층 문이 그림과 같은 높이에 서는가")
	# 그림은 1층에, 들어가는 자리는 2층에 있던 적이 있다. 1층에서 빛나는
	# 문 앞에 서도 아무 일이 없고, 문이 하나도 없는 2층 끝에서야 열렸다.
	Episode0State.reset()
	var lob: Node = load("res://scenes/side/Lobby.tscn").instantiate()
	add_child(lob)
	await get_tree().create_timer(0.8).timeout
	var office_door: Dictionary = {}
	for r in lob._spots:
		if str(r["label"]).contains("사무실"):
			office_door = r
	ck("사무실 문이 있다", not office_door.is_empty())
	if not office_door.is_empty():
		var dy: float = (office_door["area"] as Area2D).position.y
		ck("  판정이 2층 높이에 있다", absf(dy - lob.UPPER_Y) < 1.0,
			"y=%.0f (2층 %.0f)" % [dy, lob.UPPER_Y])
		# 그림도 같은 높이인가 — 문틀은 fy-268 에서 시작한다
		var found := false
		for c in lob.get_children():
			if c is Node2D and c.get_child_count() > 0:
				for g in c.get_children():
					if g is ColorRect and absf(g.position.y - (lob.UPPER_Y - 268.0)) < 2.0:
						found = true
		ck("  문 그림도 2층 높이다", found)
	# 1층에서 걸어도 문이 안 열려야 정상 (그림이 거기 없으므로)
	lob.walker.global_position = Vector2(3150, lob.FLOOR_Y - 10)
	await get_tree().create_timer(0.6).timeout
	var live := lob._live_spot()
	ck("  1층 같은 x 에서는 안 열린다",
		live.is_empty() or not str(live.get("label", "")).contains("사무실"),
		str(live.get("label", "-")))
	lob.queue_free()
	await get_tree().process_frame

	print("\n[11] 0편 도중에 저장되는가")
	# 전화 한 통에 진행이 통째로 날아가던 문제. 맵에 들어설 때마다 적는다.
	SaveManager.clear_save()
	Episode0State.reset()
	Episode0State.advance_to(Episode0State.State.FIND_PARTNER)
	var off: Node = load("res://scenes/side/Office.tscn").instantiate()
	add_child(off)
	await get_tree().create_timer(0.8).timeout
	ck("맵에 들어서면 저장된다", SaveManager.has_save())
	ck("  그 맵으로 이어진다",
		SaveManager.get_saved_scene().ends_with("Office.tscn"),
		SaveManager.get_saved_scene())
	off.queue_free()
	SaveManager.clear_save()
	await get_tree().process_frame

	_done()


## 대사창이 화면 아래쪽 조작 버튼 자리를 침범하지 않는가.
## 겹치면 대사를 읽는 동안 걷지도 뛰지도 못한다.
func _dialogue_clear(m: Node) -> bool:
	var db = m.dialogue_box
	if db == null:
		return false
	var p := db.get_node_or_null("PanelRect") as Control
	if p == null:
		return false
	return p.anchor_top < 0.5 and p.offset_top < 400.0


func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)

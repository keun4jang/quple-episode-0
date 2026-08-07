extends Node
## 0편 전체 시뮬레이션. 실제 입력으로 처음부터 클리어까지 간다.
##
## 상태 기계 테스트(TestEpisode0Flow)는 함수를 직접 부른다. 이건 다르다 —
## **화면에 있는 것만 쓴다.** 걸어가고, 선택 버튼을 누르고, 장면이 넘어가길
## 기다린다. 그래서 "코드는 맞는데 화면에서는 안 되는" 종류의 문제를 잡는다.
## 이 파일은 씬이 바뀌어도 살아남도록 root 바로 밑에 붙는다.

var shots := 0
var fails := 0

func say(s: String) -> void: print("  [시뮬] ", s)

func ck(n: String, c: bool) -> void:
	if c: print("  ✔ ", n)
	else: fails += 1; print("  ✘ ", n)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sim/%02d-%s.png" % [shots, name])
	shots += 1

## 지금 떠 있는 옆맵.
func map() -> SideEpisode:
	var n := get_tree().current_scene
	return n if n is SideEpisode else null

## 장면이 이 이름의 맵으로 바뀔 때까지 기다린다.
func wait_map(title_part: String, secs := 12.0) -> bool:
	var t := 0.0
	while t < secs:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		var m := map()
		if m != null and m.map_title().contains(title_part) and m.walker != null:
			await get_tree().create_timer(0.9).timeout
			return true
	return false

## 실제로 걸어서 x 까지 간다. 화면의 조작과 같은 액션을 쓴다.
func walk_to(x: float, secs := 26.0) -> bool:
	var m := map()
	if m == null: return false
	var t := 0.0
	while t < secs:
		var dx := x - m.walker.global_position.x
		if absf(dx) < 90.0:
			Input.action_release("move_left")
			Input.action_release("move_right")
			await get_tree().create_timer(0.35).timeout
			return true
		Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_release("move_left" if dx > 0 else "move_right")
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	Input.action_release("move_left"); Input.action_release("move_right")
	return false

## 선택 버튼을 누른 것과 같은 입력.
func press_select() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.2).timeout
	var up := InputEventAction.new()
	up.action = "interact"
	Input.parse_input_event(up)

func _ready() -> void:
	# 씬이 바뀌어도 죽지 않게 root 로 옮겨 탄다
	if get_parent() != get_tree().root:
		get_tree().root.add_child.call_deferred(self.duplicate())
	await get_tree().process_frame
	Episode0State.reset()
	TravelState.reset()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/side/Front.tscn")
	await run()
	print("\n=== 시뮬레이션 결과: %s (실패 %d) — 최종 상태 %d ===" %
		["클리어" if Episode0State.current_state == Episode0State.State.CLEAR else "미달",
		fails, Episode0State.current_state])
	get_tree().quit(1 if fails > 0 else 0)

func run() -> void:
	ck("회사 앞에 선다", await wait_map("쿼카전자 앞"))
	await get_tree().create_timer(1.2).timeout
	await shot("회사앞")

	say("문까지 걸어가 안으로 들어간다")
	ck("문까지 걸었다", await walk_to(2760))
	await press_select()
	ck("로비로 들어왔다", await wait_map("로비"))
	ck("상태: 애인 찾기", Episode0State.current_state == Episode0State.State.FIND_PARTNER)
	await shot("로비")

	say("엘리베이터를 타고 2층 사무실 문으로")
	ck("엘리베이터 앞까지", await walk_to(2260))
	Input.action_press("move_up")
	await get_tree().create_timer(3.0).timeout
	Input.action_release("move_up")
	ck("2층에 올라왔다", map().walker.global_position.y < 500.0)
	await shot("로비2층")
	ck("사무실 문까지", await walk_to(3150))
	await press_select()
	ck("사무실에 들어왔다", await wait_map("사무실"))
	await shot("사무실")

	say("애인에게 말을 건다")
	ck("애인 자리까지", await walk_to(1360))
	await press_select()
	await get_tree().create_timer(2.4).timeout
	ck("선택지가 떴다", map().choice_box.visible)
	await shot("선택지")
	map().choice_box.choice_made.emit(0)
	ck("복도로 넘어왔다", await wait_map("복도"))
	await shot("복도")

	say("대표실 문 앞에서 듣는다")
	ck("문 앞까지", await walk_to(3000))
	await press_select()
	# 대사 4줄 x 2.2초
	ck("사무실로 돌아왔다", await wait_map("사무실", 16.0))
	ck("상태: 애인에게 돌아가기", Episode0State.current_state == Episode0State.State.RETURN_TO_PARTNER)

	say("애인과 이야기하고 물품 셋을 챙긴다")
	ck("애인 자리까지", await walk_to(1360))
	await press_select()
	await get_tree().create_timer(2.4).timeout
	ck("상태: 물품 챙기기", Episode0State.current_state == Episode0State.State.COLLECT_TRAVEL_ITEMS)
	await shot("물품챙기기_HUD")

	ck("카메라 자리까지", await walk_to(2340))
	await press_select()
	ck("카메라 챙김", Episode0State.has_camera)
	ck("수첩 자리까지", await walk_to(3000))
	await press_select()
	ck("수첩 챙김", Episode0State.has_notebook)
	say("사다리로 선반 위 가방까지")
	ck("사다리 밑까지", await walk_to(3380))
	Input.action_press("move_up")
	await get_tree().create_timer(2.6).timeout
	Input.action_release("move_up")
	ck("선반까지", await walk_to(3700, 12.0))
	await press_select()
	ck("가방 챙김", Episode0State.has_travel_bag)
	await shot("셋다챙김")

	# 선반에서 내려온다
	ck("사다리 쪽으로", await walk_to(3380, 12.0))
	Input.action_press("move_down")
	await get_tree().create_timer(2.6).timeout
	Input.action_release("move_down")

	say("애인에게 보고하고 로비에서 사원증을 반납한다")
	ck("애인 자리까지", await walk_to(1360))
	await press_select()
	await get_tree().create_timer(1.0).timeout
	ck("상태: 사원증 반납", Episode0State.current_state == Episode0State.State.RETURN_BADGE)
	ck("로비 문까지", await walk_to(180))
	await press_select()
	ck("로비로 돌아왔다", await wait_map("로비"))
	ck("반납함까지", await walk_to(1500))
	await press_select()
	await get_tree().create_timer(1.0).timeout
	ck("상태: 합류", Episode0State.current_state == Episode0State.State.PARTNER_JOINED)
	ck("파트너가 나타났다", map().partner != null)
	await shot("합류")

	say("둘이 함께 밖으로 나가 첫 사진을 찍는다")
	ck("바깥 문까지", await walk_to(280))
	await press_select()
	ck("회사 앞으로 나왔다", await wait_map("쿼카전자 앞"))
	await get_tree().create_timer(4.0).timeout   # 도착 대사
	ck("사진 자리까지", await walk_to(1500))
	await shot("사진자리")
	await press_select()
	await get_tree().create_timer(8.0).timeout   # 찰칵 + 저장 + 클리어 연출
	ck("0편 클리어", Episode0State.current_state == Episode0State.State.CLEAR)
	await shot("클리어")

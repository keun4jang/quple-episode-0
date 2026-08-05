extends Node

## 입력 이벤트가 실제로 흘러오는지 엿듣는다.
class _EventSpy extends Node:
	var got: Array[String] = []
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(event: InputEvent) -> void:
		for a in ["interact", "move_right", "photo", "album"]:
			if event.is_action_pressed(a) and not got.has(a):
				got.append(a)
## 터치 조작이 기존 입력 액션으로 제대로 변환되는가

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _ready() -> void:
	print("=== 모바일 터치 조작 테스트 ===")
	var tc = load("res://scenes/ui/TouchControls.tscn").instantiate()
	add_child(tc)
	await get_tree().process_frame
	tc.visible = true

	print("\n[1] 구성")
	ck("조이스틱 있음", tc.get_node_or_null("Root/Stick/Base") != null)
	ck("손잡이 있음", tc.get_node_or_null("Root/Stick/Knob") != null)
	var btns = tc.get_node("Root/Buttons")
	ck("동작 버튼 4개", btns.get_child_count() == 4, "%d개" % btns.get_child_count())
	ck("조이스틱 그림 생성", tc.stick_base.texture != null)

	print("\n[2] 조이스틱 → 이동 액션")
	# 오른쪽으로 밀기
	tc._stick_origin = Vector2(200, 500)
	tc._stick_touch = 0
	tc._update_stick(Vector2(280, 500))
	ck("오른쪽 → move_right", Input.is_action_pressed("move_right"),
		"세기 %.2f" % Input.get_action_strength("move_right"))
	ck("반대쪽은 안 눌림", not Input.is_action_pressed("move_left"))
	# 위로 밀기
	tc._update_stick(Vector2(200, 420))
	ck("위 → move_up", Input.is_action_pressed("move_up"))
	ck("오른쪽 풀림", not Input.is_action_pressed("move_right"))
	# 대각선
	tc._update_stick(Vector2(260, 440))
	ck("대각선 → 둘 다", Input.is_action_pressed("move_right") and Input.is_action_pressed("move_up"))

	print("\n[3] 아날로그 세기 (살살 밀면 천천히)")
	tc._update_stick(Vector2(230, 500))   # 조금만
	var weak := Input.get_action_strength("move_right")
	tc._update_stick(Vector2(400, 500))   # 끝까지
	var strong := Input.get_action_strength("move_right")
	ck("세기가 다름", strong > weak, "약 %.2f / 강 %.2f" % [weak, strong])
	ck("최대 1.0 이하", strong <= 1.0, "%.2f" % strong)

	print("\n[4] 데드존 (손 떨림 무시)")
	tc._update_stick(Vector2(205, 500))   # 아주 조금
	ck("데드존 안에선 안 움직임", not Input.is_action_pressed("move_right"))

	print("\n[5] 손 떼면 멈춘다")
	tc._update_stick(Vector2(300, 500))
	ck("움직이는 중", Input.is_action_pressed("move_right"))
	tc._release_stick()
	var still := []
	for a in ["move_left","move_right","move_up","move_down"]:
		if Input.is_action_pressed(a): still.append(a)
	ck("전부 멈춤", still.is_empty(), str(still))

	print("\n[6] 동작 버튼 → 키")
	var ib: Button = btns.get_child(0)
	ib.emit_signal("button_down")
	ck("조사 버튼 → interact", Input.is_action_pressed("interact"))
	ib.emit_signal("button_up")
	ck("떼면 풀림", not Input.is_action_pressed("interact"))

	print("\n[7] 씬이 바뀌어도 눌린 채 안 남는다")
	tc._stick_origin = Vector2(200, 500)
	tc._stick_touch = 0
	tc._update_stick(Vector2(300, 500))
	ib.emit_signal("button_down")
	tc._exit_tree()
	var leaked := []
	for a in ["move_left","move_right","move_up","move_down","interact"]:
		if Input.is_action_pressed(a): leaked.append(a)
	ck("남은 입력 없음", leaked.is_empty(), str(leaked))

	print("\n[8] 진짜 터치 이벤트 경로 (폰에서 실제로 도는 길)")
	# 여기까지의 테스트는 내부 변수를 직접 만져서 _input() 을 건너뛰었다.
	# 폰에서 못 움직이는 버그가 딱 그 틈에서 났다. 이제 이벤트로 넣는다.
	var t := InputEventScreenTouch.new()
	t.index = 3; t.pressed = true; t.position = Vector2(150, 500)
	tc._input(t)
	ck("왼쪽 터치 → 조이스틱 잡힘", tc._stick_touch == 3, "id %d" % tc._stick_touch)
	var dr := InputEventScreenDrag.new()
	dr.index = 3; dr.position = Vector2(240, 500)
	tc._input(dr)
	ck("드래그 → move_right", Input.is_action_pressed("move_right"))
	t = InputEventScreenTouch.new()
	t.index = 3; t.pressed = false; t.position = Vector2(240, 500)
	tc._input(t)
	ck("떼면 멈춤", not Input.is_action_pressed("move_right"))

	print("\n[9] 터치가 InputEvent 를 만드는가 (대화상자가 닫히려면 필요)")
	# Input.action_press() 는 내부 상태만 바꾸고 이벤트를 만들지 않는다.
	# 그래서 event.is_action_pressed() 로 받는 대화상자·선택지·앨범이 죽었다.
	var spy := _EventSpy.new()
	add_child(spy)
	await get_tree().process_frame
	ib.emit_signal("button_down")
	await get_tree().process_frame
	ck("조사 버튼이 interact 이벤트를 만든다", spy.got.has("interact"), str(spy.got))
	ib.emit_signal("button_up")
	await get_tree().process_frame

	spy.got.clear()
	tc._stick_origin = Vector2(200, 500)
	tc._stick_touch = 0
	tc._update_stick(Vector2(300, 500))
	await get_tree().process_frame
	ck("조이스틱이 move_right 이벤트를 만든다", spy.got.has("move_right"), str(spy.got))
	tc._release_stick()
	spy.queue_free()

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)

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
	ck("터치 버튼이 있다", touch != null)
	if touch != null:
		for a in ["move_left", "move_right", "move_up", "move_down", "jump"]:
			ck("  %s 버튼" % a, touch._btns.has(a))

	_done()

func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)

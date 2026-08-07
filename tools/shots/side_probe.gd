extends Node
## 옆 맵을 실제로 조작해 보며 찍는다.
## 걷기·점프·사다리·계단·엘리베이터는 정지 화면으로 확인할 수 없다.
var map: Node2D
var shots := 0

func _ready() -> void:
	map = load("res://scenes/side/SideMap.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await run()
	get_tree().quit()

func hold(action: String, secs: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(secs).timeout
	Input.action_release(action)

func tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().create_timer(0.08).timeout
	Input.action_release(action)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/side/%d-%s.png" % [shots, name])
	shots += 1
	print("SHOT ", name, "  walker=", map.walker.global_position, " state=", map.walker.state)

func run() -> void:
	var w = map.walker
	await get_tree().create_timer(0.6).timeout
	await shot("시작")

	# 걷기
	await hold("move_right", 0.9)
	await shot("걷는중")

	# 점프
	Input.action_press("move_right")
	await tap("jump")
	await get_tree().create_timer(0.18).timeout
	await shot("점프")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_right")
	await shot("착지후")

	# 사다리 — 700 근처로 되돌아가 오른다
	w.global_position = Vector2(700, 880)
	await get_tree().create_timer(0.4).timeout
	await hold("move_up", 1.4)
	await shot("사다리")

	# 계단 — 2100 부터 오른쪽으로
	w.global_position = Vector2(2060, 860)
	await get_tree().create_timer(0.3).timeout
	await hold("move_right", 1.6)
	await shot("계단")

	# 엘리베이터
	w.global_position = Vector2(3300, 620)
	await get_tree().create_timer(0.6).timeout
	await hold("move_up", 2.2)
	await shot("엘리베이터")

	# 문
	w.global_position = Vector2(5060, 880)
	await get_tree().create_timer(0.5).timeout
	await shot("문앞")

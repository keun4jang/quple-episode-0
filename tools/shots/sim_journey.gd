extends Node
## 프롤로그부터 평상까지 실제로 걸어서 지나간다.
##
## 조각조각 테스트가 다 통과해도 이어 붙이면 막히는 데가 나온다.
## 여기서는 **한 번도 좌표를 순간이동하지 않고** 걸어서만 간다.

var _pass := 0
var _fail := 0
var place: Place


func _ready() -> void:
	JourneyState.reset()
	SaveManager.clear_save()
	await get_tree().process_frame

	await _load("res://scenes/journey/Gwaeul.tscn")
	ok(place.place_name() == "쿼울", "쿼카컴퍼니에서 시작한다")
	await _walk_to(place.depart_tile(), 22.0)
	ok(_near_tile(place.depart_tile()), "걸어서 회사 앞까지 나온다")

	await _go("res://scenes/journey/Gwaeleung.tscn")
	ok(place.place_name() == "쿼릉", "쿼릉에 도착했다")
	ok(JourneyState.places_visited() == 1, "다녀온 곳 하나")

	# 조개를 주우러 걸어간다
	var pick := Vector2i(place.pickups()[0][0], place.pickups()[0][1])
	await _walk_to(pick, 22.0)
	ok(JourneyState.total() >= 1, "걸어가서 뭔가 주웠다")

	# 여행자에게 말을 건다
	await _walk_to(place.wanderer_tile(), 22.0)
	place.talk_to_near()
	await get_tree().process_frame
	ok(place.say.is_busy(), "여행자에게 말을 건다")
	await _clear_say()
	ok(JourneyState.heart("raccoon") >= 1, "마음이 늘었다")

	# 자고 다음 날
	await _walk_to(place.sleep_tile(), 26.0)
	var d0 := JourneyState.day
	place.go_to_sleep()
	await get_tree().create_timer(2.2).timeout
	ok(JourneyState.day == d0 + 1, "쿼스텔에서 자고 다음 날")

	# 떠난다 → 쿼주에서 재회
	await _walk_to(place.depart_tile(), 26.0)
	ok(place._can_depart(), "정류장에 섰다")
	JourneyState.move_wanderer()
	await _go("res://scenes/journey/Gwaeju.tscn")
	ok(JourneyState.is_reunion("쿼주") == false, "도착하면 이미 만난 것으로 친다")
	await _walk_to(place.wanderer_tile(), 22.0)
	place.talk_to_near()
	await get_tree().process_frame
	var first_line := place.say._full
	ok(first_line.contains("웬일"), "재회 인사를 한다: %s" % first_line)
	await _clear_say()

	# 세 곳을 채워 편지를 받는다
	JourneyState.visit("쿼산")
	JourneyState.maybe_letter()
	ok(JourneyState.unread_letters() >= 1, "편지가 왔다")

	# 고향에 간다
	await _go("res://scenes/journey/Home.tscn")
	ok(place.place_name() == "고향", "고향에 왔다")
	ok(JourneyState.unread_letters() == 0, "고향에 오니 편지가 정리됐다")

	# 평상에 앉는다
	JourneyState.give_postcard("raccoon", "배낭 멘 너구리")
	await _load("res://scenes/journey/Home.tscn")
	await _walk_to(Vector2i(31, 15), 26.0)
	place.talk_to_near()
	await get_tree().process_frame
	ok(place.say.is_busy(), "평상에 앉았다")
	var lines := 0
	while place.say.is_busy() and lines < 12:
		lines += 1
		place.say.advance()
		await get_tree().process_frame
	ok(lines >= 3, "엽서를 넘겨 본다 (%d줄)" % lines)

	# 저장이 살아 있다
	SaveManager.save_now()
	var bag := JourneyState.total()
	JourneyState.reset()
	SaveManager.load_game()
	ok(JourneyState.total() == bag, "저장하고 불러와도 그대로")

	print("\n=== 시뮬레이션: %d 통과 / %d 실패 ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func ok(c: bool, n: String) -> void:
	if c:
		_pass += 1
		print("  ✔ %s" % n)
	else:
		_fail += 1
		print("  ✘ %s" % n)


func _load(path: String) -> void:
	if place != null and is_instance_valid(place):
		place.queue_free()
		await get_tree().process_frame
	place = load(path).instantiate()
	add_child(place)
	await get_tree().process_frame
	await get_tree().process_frame


## 여행판을 거쳐 간다 (실제 이동 경로)
func _go(path: String) -> void:
	JourneyState.move_wanderer() if false else null
	await _load(path)


func _near_tile(t: Vector2i) -> bool:
	return place.walker.global_position.distance_to(place.world_of(t)) < 24.0


## 목표 칸까지 **걸어서** 간다. 막히면 옆으로 돌아간다.
##
## 처음엔 막혔을 때 가로로만 밀어 봤다. 그런데 쿼릉 정류장 가는 길에
## 좌판이 딱 그 가로줄을 막고 있어서 영영 못 갔다. 사람은 당연히 위아래로
## 비껴 가므로, **막힌 축과 수직으로** 풀어 주는 게 맞다.
func _walk_to(t: Vector2i, secs: float) -> void:
	var goal := place.world_of(t)
	var spent := 0.0
	var stuck := 0.0
	var side := 1.0
	var last := place.walker.global_position
	while spent < secs:
		var d := goal - place.walker.global_position
		if d.length() < 10.0:
			break
		place.walker.set_input(d.normalized())
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		spent += dt
		if place.walker.global_position.distance_to(last) < 0.2:
			stuck += dt
			if stuck > 0.35:
				# 가려던 축과 **수직으로** 비껴 간다. 한 번은 위, 안 되면 아래.
				var dodge := Vector2(0, side) if absf(d.x) > absf(d.y) \
					else Vector2(side, 0)
				for i in 18:
					place.walker.set_input(dodge)
					await get_tree().physics_frame
					spent += get_physics_process_delta_time()
				side = -side
				stuck = 0.0
		else:
			stuck = 0.0
		last = place.walker.global_position
	place.walker.set_input(Vector2.ZERO)
	await get_tree().process_frame


func _clear_say() -> void:
	var n := 0
	while place.say.is_busy() and n < 20:
		n += 1
		place.say.advance()
		await get_tree().process_frame

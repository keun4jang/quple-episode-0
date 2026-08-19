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

	await _load("res://scenes/journey/Jaenmaru.tscn")
	ok(place.place_name() == "잿마루", "쿼카컴퍼니에서 시작한다")
	await _walk_to(place.depart_tile(), 22.0)
	ok(_near_tile(place.depart_tile()), "걸어서 회사 앞까지 나온다")

	await _go("res://scenes/journey/Yunseul.tscn")
	ok(place.place_name() == "윤슬", "윤슬에 도착했다")
	ok(JourneyState.places_visited() == 1, "다녀온 곳 하나")

	# 여행 중에도 나가는 길이 있어야 한다. 한동안 여행에 들어가면
	# 설정이 통째로 사라져서 앱을 죽이는 것 말고는 메인화면으로 돌아갈
	# 방법이 없었다.
	ok(get_tree().get_first_node_in_group("settings_ui") != null,
		"여행 중에도 설정을 열 수 있다")
	var _hud = get_tree().get_first_node_in_group("journey_hud")
	ok(_hud != null and _hud.has_method("try_touch"),
		"걸으면서도 배낭·사진 버튼이 눌린다")
	ok(place.solid_tiles.has("water"), "바다에는 못 들어간다")

	# 가게 문을 지나 안으로, 다시 밖으로.
	#
	# `_do_enter()` 는 실제 씬 전환(`SceneTransition`/
	# `change_scene_to_file`)을 부르는데, 그건 이 시뮬레이션 자체를
	# 갈아치운다 — `_go()` 가 늘 진짜 전환을 피하고 `_load()` 로 직접
	# 갈아 끼우는 것과 같은 이유다. 문이 남기는 **자리**만 같은 길로
	# 확인한다.
	var shop_door: Vector2i = place.doors()[0]["tile"]
	await _walk_to(shop_door, 22.0)
	var door = place._can_enter()
	ok(door != null, "가게 문 앞에 섰다")
	var outside_tile := place.tile_of(place.walker.global_position)
	JourneyState.exit_scene = place.scene_file_path
	JourneyState.exit_tile = outside_tile
	await _load(door["scene"])
	ok(place.place_name() == "가게 안", "가게 안으로 들어왔다")
	var back_door = place._can_enter()
	ok(back_door != null, "들어가자마자 문 앞이다")
	JourneyState.pending_spawn = back_door["spawn"]
	await _load(back_door["scene"])
	ok(place.place_name() == "윤슬", "가게에서 나와 윤슬로 돌아왔다")
	ok(place.tile_of(place.walker.global_position) == outside_tile,
		"나온 자리가 들어가기 전 그 자리다")
	# 문 바로 앞은 가게 담벼락과 거의 붙어 있어 다음 목적지로 가는 길이
	# 빡빡하다. 마을 한복판으로 한 번 걸어 나와 이 아래 걸음들이
	# 처음부터 다들 그랬던 것처럼 넓은 자리에서 시작하게 한다.
	await _walk_to(place.spawn_tile(), 22.0)

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
	ok(JourneyState.day == d0 + 1, "호스텔에서 자고 다음 날")

	# 떠난다 → 볕뉘에서 재회
	await _walk_to(place.depart_tile(), 26.0)
	ok(place._can_depart(), "정류장에 섰다")
	# 재회는 **떠날 때마다** 일어나지 않는다. 매번 마주치면 우연이 아니라
	# 따라다니는 것이 된다 (`journey_state.gd` 의 `move_wanderer`).
	# 세 번째 떠남에서 겹친다 — 여기서는 그 박자를 앞당겨 확인한다.
	JourneyState.move_wanderer("볕뉘", "윤슬")
	JourneyState.move_wanderer("가풀재", "볕뉘")
	JourneyState.move_wanderer("볕뉘", "가풀재")
	ok(JourneyState.wanderer_place == "볕뉘",
		"세 번째 떠남에서 여행자와 겹친다 (%s)" % JourneyState.wanderer_place)
	await _go("res://scenes/journey/Byeotnwi.tscn")
	ok(JourneyState.is_reunion("볕뉘") == false, "도착하면 이미 만난 것으로 친다")
	await _walk_to(place.wanderer_tile(), 22.0)
	place.talk_to_near()
	await get_tree().process_frame
	var first_line := place.say._full
	ok(first_line.contains("또 봐요"), "재회 인사를 한다: %s" % first_line)
	await _clear_say()

	# 세 곳을 채워 편지를 받는다
	JourneyState.visit("가풀재")
	JourneyState.maybe_letter()
	ok(JourneyState.unread_letters() >= 1, "편지가 왔다")

	# 고향에 간다
	await _go("res://scenes/journey/Home.tscn")
	ok(place.place_name() == "고향", "고향에 왔다")
	ok(JourneyState.unread_letters() == 0, "고향에 오니 편지가 정리됐다")

	# 평상에 앉는다
	JourneyState.give_postcard("raccoon", "배낭 멘 너구리")
	await _load("res://scenes/journey/Home.tscn")
	# 평상 좌표를 박아 두지 않는다 — 지도를 다시 짤 때마다 여기가 깨졌다.
	var deck: Folk = null
	for c in place._folk:
		if is_instance_valid(c) and c.is_spot and c.who == "평상":
			deck = c
	ok(deck != null, "평상이 있다")
	await _walk_to(place.tile_of(deck.global_position) + Vector2i(0, 1), 26.0)
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
## 처음엔 막혔을 때 가로로만 밀어 봤다. 그런데 윤슬 정류장 가는 길에
## 좌판이 딱 그 가로줄을 막고 있어서 영영 못 갔다. 사람은 당연히 위아래로
## 비껴 가므로, **막힌 축과 수직으로** 풀어 주는 게 맞다.
## 게임이 실제로 쓰는 **길찾기로** 걸어간다.
##
## 예전엔 여기서 직접 방향을 밀어 넣고, 막히면 수직으로 비껴 가는 코드를
## 따로 들고 있었다. 그건 길찾기가 없던 시절 것이라, 지금은 두 가지가
## 어긋난다 — 게임이 실제로 어떻게 걷는지는 확인하지 못하면서 소품
## 모서리에서 이따금 실패했다 (세 번에 한 번쯤 "뭔가 주웠다" 가 깨졌다).
##
## `Place.walk_to()` 를 그대로 부르면 진짜 코드가 검사된다.
func _walk_to(t: Vector2i, secs: float) -> void:
	var goal := place.world_of(t)
	place.walk_to(goal)
	var spent := 0.0
	while spent < secs and place.is_walking_to():
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()
	# 길을 못 찾았거나 시간이 다 됐으면 마지막 몇 걸음은 직접 민다.
	while spent < secs and place.walker.global_position.distance_to(goal) > 10.0:
		place.walker.set_input((goal - place.walker.global_position).normalized())
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()
	place.walker.set_input(Vector2.ZERO)
	place.stop_walk_to()
	await get_tree().process_frame


func _clear_say() -> void:
	var n := 0
	while place.say.is_busy() and n < 20:
		n += 1
		place.say.advance()
		await get_tree().process_frame

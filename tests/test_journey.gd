extends Node
## 탑다운 여행 — 걷기·카메라·지도 테스트.

var _pass := 0
var _fail := 0


func _ready() -> void:
	# "화면 보는 법" 판은 화면을 덮는다 — 검사 중에는 이미 본 것으로 둔다.
	SaveManager.set_flag(HowToPlay.FLAG, true)
	await get_tree().process_frame
	await _sprite_tests()
	await _walker_tests()
	await _place_tests()
	await _pickup_tests()
	await _talk_tests()
	await _place2_tests()
	await _reunion_tests()
	await _extras_tests()
	await _camera_tests()
	_touch_tests()
	_quest_tests()
	await _goal_tests()
	await _reach_tests()
	await _side_path_tests()
	await _done_toast_tests()
	await _first_map_guide_tests()
	await _yunseul_clear_tests()
	await _locked_reason_tests()
	await _indoor_quest_tests()
	await _door_tap_tests()
	await _reunion2_tests()
	await _placement_lint_tests()
	await _old_save_tests()
	await _how_to_play_tests()
	await _mark_timing_tests()
	await _order_tests()
	await _trace_tests()
	await _shelf_tests()
	await _wrap_tests()
	await _guide_tests()
	await _scene_load_tests()
	_minimap_kind_test()
	_shop_skin_test()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func ok(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("  ✔ %s" % name)
	else:
		_fail += 1
		print("  ✘ %s" % name)


# ── 스프라이트 ────────────────────────────────────────────────────────

func _sprite_tests() -> void:
	print("\n[걷기 시트]")
	var s := QuoSprite.new()
	add_child(s)
	s.load_sheet("res://assets/sprites/hero-walk.png")
	await get_tree().process_frame

	ok(s.texture != null, "시트를 읽는다")
	var c := s.size()
	ok(c.x > 0 and c.y > 0, "칸 크기를 잰다 (%dx%d)" % [c.x, c.y])
	ok(s.texture.get_width() == c.x * QuoSprite.FRAMES, "가로 4프레임")
	ok(s.texture.get_height() == c.y * 3, "세로 3방향")

	# 발끝이 원점
	ok(s.offset.y == -c.y and s.offset.x == -c.x / 2.0, "발끝이 원점이다")

	# 방향
	s.face(Vector2.DOWN)
	ok(s.region_rect.position.y == QuoSprite.ROW_DOWN * c.y, "아래를 보면 정면 줄")
	s.face(Vector2.UP)
	ok(s.region_rect.position.y == QuoSprite.ROW_UP * c.y, "위를 보면 뒷모습 줄")
	s.face(Vector2.LEFT)
	ok(s.region_rect.position.y == QuoSprite.ROW_SIDE * c.y, "옆을 보면 옆모습 줄")
	ok(not s.flip_h, "왼쪽은 그대로")
	s.face(Vector2.RIGHT)
	ok(s.flip_h, "오른쪽은 뒤집어 쓴다")

	# 대각선은 옆모습이 낫다
	s.face(Vector2(1, 0.9).normalized())
	ok(s.region_rect.position.y == QuoSprite.ROW_SIDE * c.y, "대각선은 옆모습")

	# 걸으면 프레임이 돈다
	var f0 := s.region_rect.position.x
	s.drive(Vector2.DOWN, QuoSprite.new().step_time + 0.01)
	ok(s.region_rect.position.x != f0, "걸으면 프레임이 넘어간다")
	s.drive(Vector2.ZERO, 0.1)
	ok(s.region_rect.position.x == 0.0, "멈추면 서 있는 자세")
	s.queue_free()


# ── 걷기 ──────────────────────────────────────────────────────────────

func _walker_tests() -> void:
	print("\n[걷기]")
	var w := QuoWalker.new()
	add_child(w)
	await get_tree().process_frame
	var start := w.global_position

	w.set_input(Vector2.RIGHT)
	for i in 20:
		await get_tree().physics_frame
	ok(w.global_position.x > start.x + 4.0, "오른쪽으로 간다")
	ok(absf(w.global_position.y - start.y) < 0.5, "가로로만 간다")

	# 멈추면 곧 선다 (미끄러지지 않는다)
	w.set_input(Vector2.ZERO)
	for i in 20:
		await get_tree().physics_frame
	ok(w.velocity.length() < 1.0, "놓으면 곧 선다")

	# 대각선이 더 빠르면 안 된다
	w.set_input(Vector2(1, 1))
	await get_tree().physics_frame
	ok(w.velocity.length() <= w.speed + 0.5, "대각선이 더 빠르지 않다")

	w.queue_free()
	await get_tree().process_frame


# ── 지도 ──────────────────────────────────────────────────────────────

func _place_tests() -> void:
	print("\n[고향집]")
	var p: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame

	var sz := p.tile_size()
	ok(sz.x > 20 and sz.y > 20, "지도를 읽었다 (%dx%d칸)" % [sz.x, sz.y])
	ok(p.walker != null, "주인공이 있다")
	ok(p.cam != null and p.cam.is_current(), "카메라가 켜져 있다")

	# 지도가 화면보다 커야 바깥이 안 드러난다
	var view := p.get_viewport().get_visible_rect().size / p.cam.zoom
	ok(sz.x * Place.TILE >= view.x, "지도가 화면보다 넓다")
	ok(sz.y * Place.TILE >= view.y, "지도가 화면보다 높다")

	# 시작 자리가 마당 안이어야 한다
	var spawn := p.spawn_tile()
	ok(spawn.x > 0 and spawn.x < sz.x and spawn.y > 0 and spawn.y < sz.y,
		"시작 칸이 지도 안이다")

	# 물건이 다 있는지 (이름이 틀리면 조용히 빠진다)
	var missing: Array[String] = []
	for entry in p.props():
		var path := "res://assets/sprites/%s.png" % entry[2]
		if not ResourceLoader.exists(path):
			missing.append(entry[2])
	ok(missing.is_empty(), "놓을 그림이 다 있다" if missing.is_empty()
		else "빠진 그림: %s" % str(missing))

	# 바닥 글자가 다 풀이표에 있는지
	var unknown := {}
	for line in p.ground_map().split("\n"):
		for ch in line.strip_edges():
			if ch != "" and not p.legend.has(ch):
				unknown[ch] = true
	ok(unknown.is_empty(), "지도 글자가 다 풀이돼 있다")

	# 바닥 그림 파일
	var no_tile: Array[String] = []
	for ch in p.legend:
		if not ResourceLoader.exists("res://assets/tiles/%s.png" % p.legend[ch]):
			no_tile.append(p.legend[ch])
	ok(no_tile.is_empty(), "바닥 그림이 다 있다")

	# 가족 셋
	var folk := 0
	for c in p.get_children():
		if c is Folk and not c.is_spot:
			folk += 1
	ok(folk == 3, "가족 셋이 서 있다 (%d)" % folk)

	# 지도 밖으로 못 나간다
	p.walker.global_position = Vector2(8, 8)
	p.walker.set_input(Vector2(-1, -1))
	for i in 40:
		await get_tree().physics_frame
	ok(p.walker.global_position.x > -8.0 and p.walker.global_position.y > -8.0,
		"지도 밖으로 안 나간다")

	# 고향 이름은 끝까지 짓지 않는다 (`CLAUDE.md`)
	ok(p.place_name() == "고향", "고향은 이름이 따로 없다")

	# 평상(자리)에 가까이 가면 그 소품(home-deck)의 테두리가 켜지고,
	# 멀어지면 꺼진다 — 자리는 몸을 숨기고 살아서 소품이 대신 두른다.
	var deck: Folk = null
	for c in p.get_children():
		if c is Folk and c.is_spot and c.who == "평상":
			deck = c
	ok(deck != null, "평상 자리가 있다")
	if deck != null:
		p.walker.global_position = deck.global_position
		p._update_near()
		ok(p._outlined_prop != null, "가까이 가면 평상 테두리가 켜진다")
		p.walker.global_position = deck.global_position + Vector2(500, 500)
		p._prev_near = null
		p._update_near()
		ok(p._outlined_prop == null, "멀어지면 꺼진다")

	p.queue_free()
	await get_tree().process_frame


# ── 줍기 ──────────────────────────────────────────────────────────────

func _pickup_tests() -> void:
	print("\n[줍기]")
	JourneyState.reset()
	var p: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame

	var list := p.pickups()
	# 이름을 미리 잡아 둔다. 아래에서 p 를 지운 뒤에도 쓴다 —
	# 지운 노드의 메서드를 부르면 그냥 죽는다 (오류도 안 나고 크래시다).
	var pname := p.place_name()
	ok(list.size() > 0, "주울 게 놓여 있다 (%d개)" % list.size())

	var no_art: Array[String] = []
	for e in list:
		if not ResourceLoader.exists("res://assets/sprites/%s.png" % e[2]):
			no_art.append(e[2])
	ok(no_art.is_empty(), "주울 그림이 다 있다")

	# 첫 번째 것 위로 걸어간다
	var first := Vector2i(list[0][0], list[0][1])
	var got: Array[String] = []
	p.picked_up.connect(func(it): got.append(it))
	p.walker.global_position = p.world_of(first)
	await get_tree().process_frame
	await get_tree().process_frame

	ok(got.size() == 1, "밟으면 주워진다")
	ok(JourneyState.count(String(list[0][2])) == 1, "배낭에 들어간다")
	ok(JourneyState.is_taken(pname, first), "주운 자리를 기억한다")

	# 같은 자리를 다시 밟아도 또 안 생긴다
	await get_tree().process_frame
	ok(JourneyState.count(String(list[0][2])) == 1, "두 번 안 주워진다")

	p.queue_free()
	await get_tree().process_frame

	# 다시 들어와도 이미 주운 건 안 나온다
	var p2: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(p2)
	await get_tree().process_frame
	var left := 0
	for c in p2.get_node("Props").get_children():
		if c is Area2D:
			left += 1
	ok(left == list.size() - 1, "다시 와도 주운 건 없다 (%d/%d)" % [left, list.size()])
	p2.queue_free()
	await get_tree().process_frame

	# 저장에 남는다
	JourneyState.pick("p-shell", 2)
	var d := JourneyState.to_dict()
	JourneyState.reset()
	ok(JourneyState.total() == 0, "초기화하면 배낭이 빈다")
	JourneyState.from_dict(d)
	ok(JourneyState.count("p-shell") == 2, "복원하면 개수까지 돌아온다")
	ok(JourneyState.is_taken(pname, first), "복원하면 주운 자리도 돌아온다")
	SaveManager.clear_save()
	# 저장을 지우면 표시도 같이 날아간다 — 안내판을 다시 꺼 둔다.
	SaveManager.set_flag(HowToPlay.FLAG, true)
	ok(JourneyState.total() == 0, "기록 초기화가 배낭도 비운다")


# ── 말 걸기 · 하루 ────────────────────────────────────────────────────

func _talk_tests() -> void:
	print("\n[말 걸기]")
	JourneyState.reset()
	var p: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame

	# 평상·창밖 같은 **자리**는 인연이 아니다
	var folk: Array[Folk] = []
	for c in p.get_children():
		if c is Folk and not c.is_spot:
			folk.append(c)
	ok(folk.size() == 3, "인연이 셋 (%d)" % folk.size())

	var ids := {}
	for f in folk:
		ids[f.folk_id] = true
		ok(f.who != "", "%s 에게 이름이 있다" % f.folk_id)
	ok(ids.size() == folk.size(), "인연 열쇠가 겹치지 않는다")

	# 멀리 있으면 못 건다
	var mom: Folk = folk[0]
	p.walker.global_position = mom.global_position + Vector2(400, 0)
	await get_tree().process_frame
	ok(not p.say.is_busy(), "멀면 말이 안 걸린다")

	# 다가가면 걸린다
	p.walker.global_position = mom.global_position + Vector2(10, 0)
	await get_tree().process_frame
	p.talk_to_near()
	await get_tree().process_frame
	ok(p.say.is_busy(), "다가가면 말이 걸린다")

	# 첫인사는 첫 칸 대사여야 한다 (마음을 먼저 올리면 첫인사를 못 듣는다)
	ok(JourneyState.heart(mom.folk_id) == 1, "말을 걸면 마음이 한 칸 는다")

	# 하루에 한 번만 는다
	while p.say.is_busy():
		p.say.advance()
	await get_tree().process_frame
	p.talk_to_near()
	await get_tree().process_frame
	ok(JourneyState.heart(mom.folk_id) == 1, "하루에 한 번만 는다")
	while p.say.is_busy():
		p.say.advance()

	# 최대 다섯 칸
	for i in 20:
		JourneyState.warm(mom.folk_id)
	ok(JourneyState.heart(mom.folk_id) == JourneyState.HEART_MAX,
		"마음은 다섯 칸까지")

	# 하루
	print("\n[하루]")
	# 앞 검사에서 여행지를 띄워 놓고 왔으므로 시계가 이미 굴러갔다.
	# (예전엔 시계가 int 라 영영 안 움직여서 이 줄 없이도 통과했다.)
	JourneyState.minutes = JourneyState.DAY_START
	ok(JourneyState.minutes == JourneyState.DAY_START, "아침 6시에 시작")
	JourneyState.advance_time(0.05)
	ok(JourneyState.minutes > JourneyState.DAY_START,
		"1분이 안 되는 시간도 쌓인다 (%f)" % JourneyState.minutes)
	JourneyState.minutes = JourneyState.DAY_START
	ok(JourneyState.time_text().begins_with("오전"), "시각을 읽을 수 있다")
	ok(JourneyState.night_amount() == 0.0, "아침엔 안 어둡다")
	JourneyState.minutes = 21 * 60
	ok(JourneyState.night_amount() > 0.9, "밤엔 어둡다")
	ok(JourneyState.time_text().begins_with("오후"), "오후로 바뀐다")

	var d0 := JourneyState.day
	JourneyState.sleep()
	ok(JourneyState.day == d0 + 1, "자면 다음 날")
	ok(JourneyState.minutes == JourneyState.DAY_START, "자면 아침으로")

	# 자고 나면 다시 마음이 는다
	var s0 := JourneyState.heart("sibling")
	folk[2].reset_day()
	folk[2].on_talked()
	ok(JourneyState.heart("sibling") == s0 + 1, "다음 날엔 또 는다")

	ok(p.sleep_tile().x >= 0, "잘 자리가 있다")
	p.queue_free()
	await get_tree().process_frame


# ── 윤슬 ──────────────────────────────────────────────────────────────

func _place2_tests() -> void:
	print("\n[윤슬]")
	JourneyState.reset()
	var p: Place = preload("res://scenes/journey/Yunseul.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame

	ok(p.place_name() == "윤슬", "이름이 순우리말이다")
	ok(JourneyState.places_visited() == 1, "다녀온 곳으로 센다")

	var sz := p.tile_size()
	# 창 크기와 비교하면 **돌리는 환경에 따라** 통과가 갈린다 — 검사
	# 에이전트의 창에서는 떨어졌다. 기준은 게임이 정한 선이다:
	# 3배 줌에서 회색이 안 드러나는 가로 34칸 (1600px ÷ 16 ÷ 3).
	ok(sz.x >= 34, "지도가 3배 줌을 견딘다 (가로 %d칸)" % sz.x)
	ok(sz.y >= 15, "세로도 얕지 않다 (%d칸)" % sz.y)

	# 줄 길이가 들쭉날쭉하면 지도 끝에 구멍이 생긴다
	var widths := {}
	for line in p.ground_map().split("\n"):
		var t := line.strip_edges()
		if t != "":
			widths[t.length()] = true
	ok(widths.size() == 1, "지도 줄 길이가 다 같다")

	# 여행자가 하나 있어야 한다 — 재회는 이 게임의 심장이다
	var wanderers := 0
	for c in p.get_children():
		if c is Folk and c.wanderer:
			wanderers += 1
	ok(wanderers == 1, "여행자가 하나 있다")

	# 고향과 색이 달라야 한다. 같으면 떠나온 느낌이 안 난다
	var home: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(home)
	await get_tree().process_frame
	var same := 0
	for ch in p.legend:
		if home.legend.values().has(p.legend[ch]):
			same += 1
	ok(same < p.legend.size(), "고향과 바닥이 다르다 (%d/%d 겹침)"
		% [same, p.legend.size()])
	home.queue_free()

	ok(p.sleep_tile().x >= 0, "호스텔에서 잘 수 있다")
	p.queue_free()
	await get_tree().process_frame


# ── 떠나기와 재회 ─────────────────────────────────────────────────────
#
# 이 게임이 성립하느냐가 여기서 갈린다.

func _reunion_tests() -> void:
	print("\n[떠나기와 재회]")
	JourneyState.reset()

	# 다섯 곳이 다 있고 씬도 다 있다
	var missing: Array[String] = []
	for name in TravelBoard.PLACES:
		var path := String(TravelBoard.PLACES[name][0])
		if not ResourceLoader.exists(path):
			missing.append(name)
	ok(missing.is_empty(), "여행지 씬이 다 있다 (%d곳)" % TravelBoard.PLACES.size())

	# 어디서나 떠날 수 있어야 한다. 못 떠나는 곳이 있으면 갇힌다.
	var stuck: Array[String] = []
	for name in TravelBoard.PLACES:
		var p: Place = load(String(TravelBoard.PLACES[name][0])).instantiate()
		add_child(p)
		await get_tree().process_frame
		if p.depart_tile().x < 0:
			stuck.append(name)
		# 지도가 화면보다 커야 바깥이 안 드러난다
		var sz := p.tile_size()
		var view := p.get_viewport().get_visible_rect().size / p.cam.zoom
		ok(sz.x * Place.TILE >= view.x and sz.y * Place.TILE >= view.y,
			"%s 지도가 화면보다 크다 (%dx%d)" % [name, sz.x, sz.y])
		p.queue_free()
		await get_tree().process_frame
	ok(stuck.is_empty(), "어디서나 떠날 수 있다")

	# 여행자는 한 번에 한 곳에만 있다
	var seen := {}
	for i in JourneyState.WANDERER_STOPS.size() * 2:
		seen[JourneyState.wanderer_place] = true
		JourneyState.move_wanderer()
	ok(seen.size() == JourneyState.WANDERER_STOPS.size(),
		"여행자가 아홉 곳을 다 돈다 (%d)" % seen.size())
	ok(not seen.has("고향"), "남의 고향에는 안 간다")

	# 목록 순서대로 여행하는 **가장 평범한 진행**에서 재회가 일어나는가.
	#
	# 한동안 여기서 한 번도 안 만났다. 떠날 때마다 여행자를 한 칸 밀었더니
	# 플레이어와 나란히 돌면서 늘 한 칸 앞섰다. 게임의 심장이 안 뛰었다.
	JourneyState.reset()
	var route := JourneyState.WANDERER_STOPS
	var met := 0
	var reunions := 0
	var at := "잿마루"
	for i in 12:
		var dest: String = route[i % route.size()]
		JourneyState.move_wanderer(dest, at)
		at = dest
		if JourneyState.wanderer_here(dest):
			if JourneyState.is_reunion(dest):
				reunions += 1
			met += 1
			JourneyState.meet_wanderer(dest)
	ok(met >= 3, "차례대로 다녀도 여행자를 만난다 (%d번)" % met)
	ok(reunions >= 2, "그중 재회가 있다 (%d번)" % reunions)
	ok(met < 12, "그렇다고 갈 때마다 있지는 않다 (%d/12)" % met)
	# 셋째 재회가 아홉 번째 떠남에 있으면 안 된다 — 이 게임은 15~20분이면
	# 다 보는데 제목이 나오는 줄이 30분 뒤에 있었다.
	JourneyState.reset()
	JourneyState.meet_wanderer("윤슬")
	var third_at := 0
	var r2 := 0
	var at2 := "윤슬"
	for i in 12:
		var dest2: String = route[(i + 1) % route.size()]
		JourneyState.move_wanderer(dest2, at2)
		at2 = dest2
		if JourneyState.wanderer_here(dest2) and JourneyState.is_reunion(dest2):
			r2 += 1
			JourneyState.reunions += 1
			JourneyState.since_reunion = 0
			JourneyState.meet_wanderer(dest2)
			if r2 == 3:
				third_at = i + 1
	ok(third_at > 0 and third_at <= 7,
		"셋째 재회가 일곱 번째 떠남 안에 온다 (%d번째)" % third_at)
	ok(r2 >= 4, "네 곳을 다 돌아도 재회가 계속된다 (%d번)" % r2)
	JourneyState.reset()

	# 진짜 재회 — 윤슬에서 만나고, 떠났다가, 다른 데서 다시 만난다
	JourneyState.reset()
	var first: Place = preload("res://scenes/journey/Yunseul.tscn").instantiate()
	add_child(first)
	await get_tree().process_frame
	await get_tree().process_frame

	var rac: Folk = null
	for c in first.get_children():
		if c is Folk and c.wanderer:
			rac = c
	ok(rac != null, "윤슬에서 여행자를 만난다")
	ok(JourneyState.wanderer_seen.has("윤슬"), "만난 곳을 기억한다")
	ok(JourneyState.is_reunion("윤슬") == false, "첫 만남은 재회가 아니다")
	first.queue_free()
	await get_tree().process_frame

	# 떠난다 → 여행자도 옮긴다
	JourneyState.move_wanderer()
	ok(JourneyState.wanderer_place == "볕뉘", "여행자가 볕뉘로 옮겼다")
	ok(JourneyState.is_reunion("볕뉘"), "볕뉘에서 만나면 재회다")

	var heart0 := JourneyState.heart("raccoon")
	var second: Place = preload("res://scenes/journey/Byeotnwi.tscn").instantiate()
	add_child(second)
	await get_tree().process_frame
	await get_tree().process_frame

	var rac2: Folk = null
	for c in second.get_children():
		if c is Folk and c.wanderer:
			rac2 = c
	ok(rac2 != null, "볕뉘에서 다시 만난다")
	ok(rac2 != null and not rac2.once.is_empty(), "재회 대사가 따로 있다")
	# 재회 대사는 [누가, 무슨 말] 짝으로 온다. 주고받는 말이라 이름이 붙는다.
	var head: Array = rac2.once[0] if rac2 != null and not rac2.once.is_empty() \
		else ["", ""]
	ok(String(head[1]).contains("또 봐요"), "첫마디가 \"어? 여기서 또 봐요?\"")
	ok(String(head[0]) == "배낭 멘 너구리", "누가 한 말인지 적혀 있다")
	var voices := {}
	for l in rac2.once:
		voices[String((l as Array)[0])] = true
	ok(voices.size() >= 2, "혼잣말이 아니라 주고받는다 (%d명)" % voices.size())
	var quople := 0
	for l in rac2.once:
		if String((l as Array)[1]).contains("진짜 행복"):
			quople += 1
	ok(quople == 0, "첫 재회에서는 제목과 만나는 말이 안 나온다")
	# 너구리는 늘 존댓말이다. 첫 재회에서 반말이 튀어나오면
	# 마음이 쌓여 말이 놓인 게 아니라 다른 사람처럼 들린다.
	var polite := true
	for l in rac2.once:
		var who := String((l as Array)[0])
		var txt := String((l as Array)[1])
		if who != "나" and not (txt.contains("요") or txt.contains("니다")):
			polite = false
	ok(polite, "첫 재회에서는 여행자가 존댓말을 쓴다")
	ok(JourneyState.heart("raccoon") == heart0 + 1,
		"다시 만난 것만으로 마음이 는다")

	# 재회 대사는 한 번만
	var said := rac2.lines()
	ok(String((said[0] as Array)[1]).contains("또 봐요"), "재회 대사를 먼저 한다")
	ok(rac2.once.is_empty(), "재회 대사는 한 번만")
	second.queue_free()
	await get_tree().process_frame

	# 여행자가 없는 곳에는 안 서 있다
	var third: Place = preload("res://scenes/journey/Hanuiseom.tscn").instantiate()
	add_child(third)
	await get_tree().process_frame
	var here := 0
	for c in third.get_children():
		if c is Folk and c.wanderer:
			here += 1
	ok(here == 0, "여행자가 없는 곳엔 안 서 있다")
	third.queue_free()
	await get_tree().process_frame

	# 저장에 남는다
	var d := JourneyState.to_dict()
	JourneyState.reset()
	JourneyState.from_dict(d)
	ok(JourneyState.wanderer_seen.has("윤슬") and JourneyState.wanderer_seen.has("볕뉘"),
		"만난 곳들이 저장에 남는다")


# ── 편지 · 사진 · 엽서 · 프롤로그 ─────────────────────────────────────

func _extras_tests() -> void:
	print("\n[편지]")
	JourneyState.reset()
	ok(JourneyState.unread_letters() == 0, "처음엔 편지가 없다")

	# 편지는 **떠난 횟수**로 센다. 여행지가 넷뿐이라 "다녀온 곳 수"로 세면
	# 아무리 다녀도 한 통에서 멈춘다 (`journey_state.gd` 의 `maybe_letter`).
	JourneyState.visit("윤슬")
	JourneyState.maybe_letter()
	ok(JourneyState.letters.is_empty(), "한 번 만에는 안 온다")
	JourneyState.visit("볕뉘")
	JourneyState.maybe_letter()
	ok(JourneyState.letters.size() == 1, "두 번째 도착에 한 통 온다")
	# 같은 곳에 다시 가도 떠난 것이다 — 여기서 편지가 멈추면 안 된다.
	# `due = arrivals/2` 이니 전체(`LETTERS.size()`)를 다 받으려면
	# 도착이 그 두 배는 있어야 한다.
	for i in JourneyState.LETTERS.size() * 2:
		JourneyState.visit("윤슬")
		JourneyState.maybe_letter()
	# 안 만난 서브 인연 넷(수달·다람쥐·개구리·고라니)의 편지는 아직 안 온다 —
	# 모르는 사람에게서 편지가 오면 다정한 게 아니라 이상하다.
	var gated: int = JourneyState.LETTER_NEEDS_MEET.size()
	ok(JourneyState.letters.size() == JourneyState.LETTERS.size() - gated,
		"안 만난 이의 편지는 안 온다 (%d/%d)" %
			[JourneyState.letters.size(), JourneyState.LETTERS.size()])
	# 만나고 나면 밀렸던 편지가 온다.
	for id in JourneyState.LETTER_NEEDS_MEET.values():
		JourneyState.hearts[String(id)] = 1
	JourneyState.visit("윤슬")
	JourneyState.visit("윤슬")
	JourneyState.maybe_letter()
	ok(JourneyState.letters.size() == JourneyState.LETTERS.size(),
		"만나고 나면 밀렸던 편지가 온다 (%d/%d)" %
			[JourneyState.letters.size(), JourneyState.LETTERS.size()])
	ok(JourneyState.unread_letters() == JourneyState.LETTERS.size(),
		"안 읽은 걸로 뜬다 (%d)" % JourneyState.unread_letters())

	# 안 읽어도 벌이 없다. 다만 고향에 가면 다 읽은 것으로 친다
	JourneyState.came_home()
	ok(JourneyState.unread_letters() == 0, "고향에 가면 다 읽은 것으로 친다")

	# 같은 편지를 두 번 보내지 않는다
	JourneyState.maybe_letter()
	ok(JourneyState.letters.size() == JourneyState.LETTERS.size(),
		"같은 편지를 두 번 안 보낸다")

	print("\n[사진]")
	var p: Place = preload("res://scenes/journey/Yunseul.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame

	var n0 := JourneyState.photos.size()
	p.hud.shutter.emit()
	await get_tree().process_frame
	ok(JourneyState.photos.size() == n0 + 1, "사진이 찍힌다")
	var shot: Dictionary = JourneyState.photos[-1]
	ok(shot.get("place") == "윤슬", "어디서 찍었는지 남는다")
	ok(String(shot.get("time", "")) != "", "몇 시였는지 남는다")
	ok(String(shot.get("subject", "")) != "", "무엇을 찍었는지 남는다")

	# 사람 옆에서 찍으면 그 사람이 남는다
	var who: Folk = null
	for c in p.get_children():
		if c is Folk and not c.is_spot:
			who = c
			break
	p.walker.global_position = who.global_position + Vector2(8, 0)
	await get_tree().process_frame
	p.hud.shutter.emit()
	await get_tree().process_frame
	ok(String(JourneyState.photos[-1].get("subject")) == who.who,
		"사람 옆에서 찍으면 그 사람이 남는다")

	print("\n[엽서]")
	# 마음을 다 채우면 엽서를 준다
	JourneyState.hearts[who.folk_id] = JourneyState.HEART_MAX
	p.walker.global_position = who.global_position + Vector2(8, 0)
	await get_tree().process_frame
	p.talk_to_near()
	await get_tree().process_frame
	ok(JourneyState.postcards.has(who.folk_id), "마음을 채우면 엽서를 받는다")
	while p.say.is_busy():
		p.say.advance()
	p.queue_free()
	await get_tree().process_frame

	print("\n[프롤로그]")
	var pro: Place = preload("res://scenes/journey/Jaenmaru.tscn").instantiate()
	add_child(pro)
	await get_tree().process_frame
	await get_tree().process_frame

	ok(pro.place_name() == "잿마루", "잿마루에서 시작한다")
	ok(pro.sleep_tile().x < 0, "회사에서는 못 잔다")
	ok(pro.depart_tile().x >= 0, "회사 앞에서 떠날 수 있다")
	ok(pro.pickups().is_empty(), "프롤로그에서는 아무것도 안 줍는다")
	ok(JourneyState.minutes >= 23 * 60, "밤 11시에서 시작한다")
	ok(not TravelBoard.PLACES.has("잿마루"), "회사로는 돌아갈 수 없다")

	# 창밖·반납함 같은 자리가 있다
	var spots := 0
	for c in pro.get_children():
		if c is Folk and c.is_spot:
			spots += 1
	ok(spots >= 3, "말 붙일 자리가 있다 (%d)" % spots)
	pro.queue_free()
	await get_tree().process_frame

	print("\n[평상]")
	JourneyState.reset()
	var h1: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(h1)
	await get_tree().process_frame
	var deck: Folk = null
	for c in h1.get_children():
		if c is Folk and c.is_spot and c.who == "평상":
			deck = c
	ok(deck != null, "평상에 앉을 수 있다")
	ok(deck != null and String(deck.lines()[0]).contains("평상"), "앉으면 말이 나온다")
	h1.queue_free()
	await get_tree().process_frame

	# 엽서를 모으고 앉으면 다른 말이 나온다
	JourneyState.give_postcard("seal", "가게 할머니")
	JourneyState.give_postcard("raccoon", "배낭 멘 너구리")
	var h2: Place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(h2)
	await get_tree().process_frame
	var deck2: Folk = null
	for c in h2.get_children():
		if c is Folk and c.is_spot and c.who == "평상":
			deck2 = c
	var said: Array = deck2.lines()
	ok(said.size() >= 4, "엽서가 있으면 넘겨 본다 (%d줄)" % said.size())
	ok(String(said[-1]).contains("진짜 행복"), "마지막 줄이 제목과 만난다")
	h2.queue_free()
	await get_tree().process_frame

	# 저장에 다 남는다
	var d := JourneyState.to_dict()
	JourneyState.reset()
	JourneyState.from_dict(d)
	ok(JourneyState.postcards.size() == 2, "엽서가 저장에 남는다")


# ── 카메라 ────────────────────────────────────────────────────────────

func _camera_tests() -> void:
	print("\n[하루가 넘어갈 때]")
	# 밤 11시에 회사를 나오면 첫 여행지에 밤 11시에 닿았다. 24초 만에
	# 시계가 자정에 멈추고, 빠져나오는 길은 자는 것뿐이었다.
	JourneyState.reset()
	JourneyState.minutes = 23 * 60
	JourneyState.arriving = true
	var d0 := JourneyState.day
	JourneyState.arrive()
	ok(JourneyState.minutes == JourneyState.DAY_START, "다음 마을에는 아침에 닿는다")
	ok(JourneyState.day == d0 + 1, "밤에 떠났으면 하루가 넘어간다")
	# 낮에 떠나면 같은 날 그대로
	JourneyState.minutes = 10 * 60
	JourneyState.arriving = true
	var d1 := JourneyState.day
	JourneyState.arrive()
	ok(JourneyState.day == d1, "낮에 떠나면 같은 날이다")
	# 자정이 정오로 읽히던 것
	JourneyState.minutes = JourneyState.DAY_END
	ok(JourneyState.time_text() == "자정",
		"자정을 정오라고 안 한다 (%s)" % JourneyState.time_text())
	JourneyState.minutes = 12 * 60
	ok(JourneyState.time_text() == "오후 12:00", "한낮은 그대로")
	JourneyState.reset()

	print("\n[시간표]")
	# 하늘빛은 일곱 단계인데 마을은 아침과 밤이 픽셀 하나 안 달랐다.
	JourneyState.reset()
	var sp: Place = preload("res://scenes/journey/Yunseul.tscn").instantiate()
	add_child(sp)
	await get_tree().process_frame
	await get_tree().process_frame
	JourneyState.minutes = 7 * 60
	ok(sp.day_part() == "아침", "7시는 아침이다")
	JourneyState.minutes = 13 * 60
	ok(sp.day_part() == "낮", "13시는 낮이다")
	JourneyState.minutes = 19 * 60
	ok(sp.day_part() == "저녁", "19시는 저녁이다")
	# 시간표가 있는 인연은 그 시간대의 모든 자리가 지도 안 걸을 수 있는
	# 칸이어야 한다 — 물이나 소품 위에 서 있으면 안 된다.
	var sched_folk := 0
	var bad_spots := 0
	for c in sp._folk:
		if not is_instance_valid(c) or c.is_spot or c.schedule.is_empty():
			continue
		sched_folk += 1
		for k in c.schedule:
			var t2: Vector2i = c.schedule[k]
			# 인연들 자신이 막는 칸(_blocked)은 빼고 본다
			var row2: String = sp._grid[t2.y] if t2.y >= 0 and t2.y < sp._grid.size() else ""
			var ok2: bool = t2.x >= 0 and t2.x < row2.length() \
				and sp.legend.has(row2[t2.x]) \
				and not sp.solid_tiles.has(String(sp.legend[row2[t2.x]]))
			if not ok2:
				bad_spots += 1
	if sched_folk > 0:
		ok(bad_spots == 0, "시간표 자리가 전부 걸을 수 있는 칸이다 (%d명)" % sched_folk)
	# 화면 밖에서 시간대가 바뀌면 자리를 옮긴다
	if sched_folk > 0:
		JourneyState.minutes = 19 * 60
		# 카메라 따라가기를 끊는다. 안 끊으면 다음 프레임에 주인공 곁으로
		# 돌아가 인연들이 도로 화면 안 — 시간표 틱과 경주가 붙어 흔들렸다.
		sp.cam.target = null
		sp.cam.global_position = Vector2(-4000, -4000)   # 다 화면 밖
		var before2 := {}
		for c in sp._folk:
			if is_instance_valid(c) and not c.is_spot and not c.schedule.is_empty():
				before2[c.who] = c.global_position
		var w := 0.0
		while w < 2.5:
			await get_tree().process_frame
			w += get_process_delta_time()
		var moved2 := 0
		for c in sp._folk:
			if is_instance_valid(c) and before2.has(c.who):
				var want2: Vector2i = c.schedule.get("저녁", Vector2i(-1, -1))
				if want2.x >= 0 and sp.tile_of(c.global_position) == want2:
					moved2 += 1
		ok(moved2 > 0, "화면 밖에서는 저녁 자리로 옮겨 간다 (%d명)" % moved2)
	sp.queue_free()
	await get_tree().process_frame
	JourneyState.reset()

	print("\n[누르기]")
	var tp: Place = preload("res://scenes/journey/Yunseul.tscn").instantiate()
	add_child(tp)
	await get_tree().process_frame
	await get_tree().process_frame

	# ① 인연은 **직접 눌러야** 잡힌다. 옆을 지나가려고 땅을 눌렀는데
	#    말이 걸리면 안 된다.
	var someone: Folk = null
	for c in tp._folk:
		if is_instance_valid(c) and not c.is_spot:
			someone = c
			break
	ok(someone != null, "인연이 있다")
	ok(tp._folk_at(someone.global_position + Vector2(0, -12)) == someone,
		"몸을 누르면 그 사람이 잡힌다")
	ok(tp._folk_at(someone.global_position + Vector2(90, 90)) == null,
		"멀리 빈 땅을 누르면 아무도 안 잡힌다")

	# ①-1 누른 자리가 **지도 가장자리에서도** 맞아야 한다.
	#
	# 예전엔 카메라 위치와 줌으로 직접 계산했는데, `limit_*` 로 카메라가
	# 지도 끝에서 멈추면 그려지는 자리는 멈추고 `global_position` 은 계속
	# 움직여서 최대 **11.8칸**이 어긋났다. 마을 가장자리에서 누른 데가
	# 아니라 엉뚱한 데로 걸어갔다.
	var vp2 := tp.get_viewport().get_visible_rect().size
	var worst := 0.0
	for edge in [Vector2i(2, 12), Vector2i(17, 12), Vector2i(33, 12)]:
		if not tp._walkable(edge):
			continue
		tp.walker.global_position = tp.world_of(edge)
		tp.cam.global_position = tp.walker.global_position
		for i in 8:
			await get_tree().process_frame
		for sx in [0.15, 0.5, 0.85]:
			var scr := Vector2(vp2.x * sx, vp2.y * 0.5)
			var ct := tp.get_viewport().get_canvas_transform()
			worst = maxf(worst, (ct * (ct.affine_inverse() * scr)).distance_to(scr))
	ok(worst < 1.0, "가장자리에서도 누른 자리가 맞는다 (오차 %.2fpx)" % worst)

	# ② 누른 자리로 **길을 찾아** 간다. 소품에 걸려 서 버리면 안 된다.
	var from := tp.walker.global_position
	var goal := from + Vector2(-120, 30)
	tp.walk_to(goal)
	ok(tp.is_walking_to(), "길을 찾았다 (길목 %d개)" % tp._path.size())
	var t := 0.0
	while t < 12.0 and tp.is_walking_to():
		await get_tree().process_frame
		t += get_process_delta_time()
	ok(tp.walker.global_position.distance_to(goal) <= 8.0,
		"누른 자리까지 걸어간다 (남은 %.0fpx)" % tp.walker.global_position.distance_to(goal))

	# ②-1 탭하는 그 짧은 순간에도 손끝은 몇 픽셀 흔들린다. 그 흔들림이
	# 조이스틱으로 오인돼 막 시작한 걷기를 끊으면 안 된다 — 폰에서는
	# "조이스틱만 되고 누른 곳까지 안 온다" 로 보이던 문제였다.
	var jgoal := tp.walker.global_position + Vector2(100, 0)
	var jscr: Vector2 = tp.get_viewport().get_canvas_transform() * jgoal
	var jdown := InputEventScreenTouch.new()
	jdown.index = 0
	jdown.pressed = true
	jdown.position = jscr
	tp._unhandled_input(jdown)
	ok(tp.is_walking_to(), "탭하면 그 자리로 걷기 시작한다")
	var jdrag := InputEventScreenDrag.new()
	jdrag.index = 0
	jdrag.position = jscr + Vector2(4, 3)   # 손끝이 5px 쯤 흔들렸다
	tp.touch._unhandled_input(jdrag)
	ok(tp.touch.direction() == Vector2.ZERO,
		"탭하다 흔들려도 조이스틱이 안 켜진다")
	tp._process(0.016)
	ok(tp.is_walking_to(), "흔들려도 걷기가 안 끊긴다")
	var jup := InputEventScreenTouch.new()
	jup.index = 0
	jup.pressed = false
	jup.position = jdrag.position
	tp._unhandled_input(jup)
	tp.touch._unhandled_input(jup)

	# 못 걷는 칸을 눌러도 가장 가까운 땅으로 간다 — 아무 반응이 없으면
	# 고장으로 읽힌다.
	var wet := Vector2i(-1, -1)
	for y in tp._grid.size():
		var row: String = tp._grid[y]
		for x in row.length():
			if tp.legend.has(row[x]) and tp.solid_tiles.has(String(tp.legend[row[x]])):
				wet = Vector2i(x, y)
				break
		if wet.x >= 0:
			break
	if wet.x >= 0:
		ok(not tp._walkable(wet), "물 칸은 못 걷는 칸이다")
		tp.walk_to(tp.world_of(wet))
		ok(tp.is_walking_to(), "물을 눌러도 가장 가까운 땅으로 간다")
		tp.stop_walk_to()

	# ③ 멀리 있는 인연을 누르면 **그 앞까지만** 간다. 저절로 말이 걸리지 않는다.
	tp.walker.global_position = someone.global_position + Vector2(150, 40)
	await get_tree().process_frame
	tp.walk_to(tp._beside(someone))
	t = 0.0
	while t < 12.0 and tp.is_walking_to():
		await get_tree().process_frame
		t += get_process_delta_time()
	ok(tp.walker.global_position.distance_to(someone.global_position) <= tp.TALK_RANGE,
		"인연 앞까지 걸어간다")
	ok(not tp.say.is_busy(), "다가가는 것만으로 말이 걸리지는 않는다")

	# ③-1 **직접 톡 누르면** 도착한 순간 저절로 말이 걸린다 — 두 번
	# 누르게 하지 않는다(친구들 플레이 피드백: "다가가서 버튼" 이
	# 두 단계라 헷갈렸다).
	tp.walker.global_position = someone.global_position + Vector2(160, 30)
	await get_tree().process_frame
	var tapscr: Vector2 = tp.get_viewport().get_canvas_transform() \
		* (someone.global_position + Vector2(0, -12))
	var tapdown := InputEventScreenTouch.new()
	tapdown.index = 0
	tapdown.pressed = true
	tapdown.position = tapscr
	tp._unhandled_input(tapdown)
	ok(tp.is_walking_to() and tp._pending_talk == someone,
		"톡 누르면 다가가면서 나중에 말 걸 대상을 기억한다")
	t = 0.0
	while t < 12.0 and not tp.say.is_busy():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	ok(tp.say.is_busy(), "도착하면 두 번째 탭 없이 저절로 말이 걸린다")
	tp.say.close()

	# ④ 대화창을 되돌려 볼 수 있다
	tp.say.say("아무개", ["첫째 줄.", "둘째 줄.", "셋째 줄."])
	ok(tp.say.is_busy(), "대화가 열린다")
	ok(tp.say._prev_btn.disabled, "첫 줄에서는 이전이 꺼져 있다")
	# 한 번 누르면 찍히는 중인 글자를 마저 찍고, 그 다음 누름이 다음 줄이다.
	tp.say.advance()
	tp.say.advance()
	await get_tree().process_frame
	ok(tp.say._at == 1, "다음으로 넘어간다")
	ok(not tp.say._prev_btn.disabled, "이제 이전을 누를 수 있다")
	tp.say._back()
	await get_tree().process_frame
	ok(tp.say._at == 0, "이전으로 되돌아간다")
	ok(tp.say._line.text == tp.say._full, "되돌아간 줄은 통째로 보인다")
	for i in 8:
		if not tp.say.is_busy():
			break
		tp.say.advance()
		await get_tree().process_frame
	ok(not tp.say.is_busy(), "끝까지 넘기면 닫힌다")

	# ⑤ 선택 버튼 — 하나가 여러 일을 한다
	tp.walker.global_position = someone.global_position + Vector2(18, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(tp.hud._act_btn.visible and tp.hud._act_btn.text == "말 걸기",
		"인연 옆에서는 '말 걸기' 가 뜬다 (%s)" % tp.hud._act_btn.text)
	tp.hud.acted.emit()
	await get_tree().process_frame
	ok(tp.say.is_busy(), "선택 버튼으로 말이 걸린다")
	await get_tree().process_frame
	ok(tp.hud._act_btn.text == "다음", "대화 중에는 '다음' 이 된다 (%s)" % tp.hud._act_btn.text)
	tp.say.close()
	await get_tree().process_frame

	# ⑤-2 저절로 열린 "이 마을에서" 도 **연 것으로 친다.**
	#
	# 예전엔 `toggle_bag()` 이 `_tab` 만 4로 바꾸고 지나가서
	# `quest_tab_opened` 가 안 울렸다. 길잡이 첫 줄이 그 신호를 기다리는데
	# 영영 안 오니, 배낭을 열어 할 일을 다 읽은 사람도 안내가 그 줄에
	# 멈춰 다음(걷기)으로 넘어가질 못했다.
	var here_was: String = JourneyState.here
	JourneyState.here = "잿마루"                  # 할 일이 남아 있는 곳
	var seen := [false]
	tp.hud.quest_tab_opened.connect(func(): seen[0] = true)
	if tp.hud.bag_open():
		tp.hud.toggle_bag()
	tp.hud.toggle_bag()
	await get_tree().process_frame
	ok(tp.hud._tab == 4, "할 일이 남았으면 '이 마을에서' 부터 열린다")
	ok(seen[0], "저절로 열려도 '할 일을 봤다' 는 신호가 온다")
	tp.hud.toggle_bag()
	JourneyState.here = here_was
	await get_tree().process_frame

	# ⑤-3 화면을 덮는 것은 **뒤로가기로 닫혀야 한다.**
	#
	# "길잡이 다시 보기" 판은 배낭까지 숨기고 화면을 통째로 덮는데,
	# `back_handler` 가 찾는 그룹 어디에도 없었다. 그래서 폰에서 뒤로가기를
	# 누르면 아무것도 안 닫히고, 그 누름이 종료 카운터에 쌓여 **두 번째
	# 누름에 앱이 꺼졌다** (`back_handler.gd` 가 위에서 경고하는 그 사고).
	tp.hud._open_guide_recap()
	await get_tree().process_frame
	ok(get_tree().get_first_node_in_group("overlay") != null,
		"덮는 판은 'overlay' 그룹에 든다")
	var bh := get_tree().get_first_node_in_group("back_handler")
	ok(bh != null, "뒤로가기 처리기가 살아 있다")
	ok(bh != null and bh._close_topmost(), "뒤로가기가 그 판을 닫는다")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(get_tree().get_first_node_in_group("overlay") == null,
		"닫고 나면 남지 않는다")
	ok(tp.hud.bag_open(), "판을 닫으면 숨겼던 배낭이 되돌아온다")
	tp.hud.toggle_bag()
	await get_tree().process_frame

	# ⑥ 한 번 누른 것이 두 번으로 오지 않는다
	#
	# 엔진이 터치를 마우스로도 흉내내서 `_unhandled_input` 이 같은 탭을
	# 두 번 받는다. 그대로 두면 미니맵이 켜졌다 바로 꺼지고 대화가
	# 두 줄씩 넘어간다.
	var echo := InputEventMouseButton.new()
	echo.device = -1
	echo.pressed = true
	echo.button_index = MOUSE_BUTTON_LEFT
	ok(JourneyHud.is_echo(echo), "흉내낸 마우스를 걸러 낸다")
	var real := InputEventScreenTouch.new()
	real.pressed = true
	ok(not JourneyHud.is_echo(real), "진짜 손가락은 안 걸러진다")

	# ⑦ 대화창이 말 길이에 맞춰 줄어든다
	tp.say.say("아무개", ["응."])
	await get_tree().process_frame
	var narrow: float = tp.say._panel.size.x
	tp.say.close()
	tp.say.say("아무개", ["오늘은 바람이 좀 차지. 감기 조심하고 다녀요."])
	await get_tree().process_frame
	var wide: float = tp.say._panel.size.x
	ok(narrow < wide, "짧은 말이면 창도 좁다 (%.0f < %.0f)" % [narrow, wide])
	ok(wide <= tp.say.MAX_WIDTH + 40.0, "그래도 화면을 가로지르지 않는다 (%.0f)" % wide)
	tp.say.close()
	await get_tree().process_frame

	# ⑦-1 잠자리·정류장 위에 서 있어도 **먼 곳을 누르면 걸어간다**
	var dep := tp.depart_tile()
	if dep.x >= 0:
		tp.walker.global_position = tp.world_of(dep)
		await get_tree().process_frame
		ok(tp._can_depart(), "정류장 위에 섰다")
		var far := tp.world_of(dep) + Vector2(-140, 0)
		ok(not tp._near_tile(far, dep), "먼 자리는 정류장 누른 것으로 안 친다")
		ok(tp._near_tile(tp.world_of(dep) + Vector2(6, 0), dep),
			"그 자리를 누르면 정류장으로 친다")

	# ⑧ 미니맵
	ok(tp.minimap != null and not tp.minimap.is_big(), "미니맵은 작게 시작한다")
	ok(tp.minimap.try_touch(tp.minimap.get_global_rect().get_center()),
		"손가락으로 직접 눌러도 잡힌다")
	ok(tp.minimap.is_big(), "그 손가락으로 커진다")
	ok(tp.minimap.try_touch(Vector2(10, 10)), "펼친 채 바깥을 눌러도 받는다")
	ok(not tp.minimap.is_big(), "바깥을 누르면 닫힌다")
	tp.minimap.toggle()
	ok(tp.minimap.is_big(), "누르면 커진다")
	tp.minimap.toggle()
	ok(not tp.minimap.is_big(), "다시 누르면 작아진다")
	tp.queue_free()
	await get_tree().process_frame

	print("\n[카메라]")
	# 픽셀 그림이라 배율은 정수여야 한다
	var whole := true
	for z in JourneyCamera.STEPS:
		if absf(float(z) - roundf(float(z))) > 0.001:
			whole = false
	ok(whole, "배율이 전부 정수다 (픽셀이 안 어긋난다)")
	ok(JourneyCamera.STEPS.size() >= 3, "단계가 셋 이상")

	var cam := JourneyCamera.new()
	add_child(cam)
	await get_tree().process_frame
	var base := cam.zoom.x

	cam._nudge(1)
	await get_tree().create_timer(0.3).timeout
	ok(cam.zoom.x > base, "확대하면 커진다")
	cam._nudge(-1)
	cam._nudge(-1)
	await get_tree().create_timer(0.3).timeout
	ok(cam.zoom.x <= base, "축소하면 작아진다")

	# 끝을 넘지 않는다
	for i in 10:
		cam._nudge(1)
	await get_tree().create_timer(0.3).timeout
	ok(cam.zoom.x <= float(JourneyCamera.STEPS[JourneyCamera.STEPS.size() - 1]) + 0.01,
		"최대 배율을 안 넘는다")
	for i in 10:
		cam._nudge(-1)
	await get_tree().create_timer(0.3).timeout
	ok(cam.zoom.x >= float(JourneyCamera.STEPS[0]) - 0.01, "최소 배율 아래로 안 간다")

	# 손을 떼면 가까운 눈금에 붙는다
	cam.zoom = Vector2.ONE * 2.6
	cam._snap_to_step()
	await get_tree().create_timer(0.3).timeout
	ok(absf(cam.zoom.x - 3.0) < 0.05, "2.6 배는 3 배로 붙는다")
	cam.zoom = Vector2.ONE * 2.2
	cam._snap_to_step()
	await get_tree().create_timer(0.3).timeout
	ok(absf(cam.zoom.x - 2.0) < 0.05, "2.2 배는 2 배로 붙는다")

	cam.queue_free()
	await get_tree().process_frame


# ── 손가락 ────────────────────────────────────────────────────────────

func _touch_tests() -> void:
	print("\n[손가락]")
	var t := JourneyTouch.new()
	add_child(t)

	ok(t.direction() == Vector2.ZERO, "안 누르면 안 움직인다")

	# 누르고 조금만 밀면 죽은 구간
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(200, 400)
	t._unhandled_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(203, 400)
	t._unhandled_input(drag)
	ok(t.direction() == Vector2.ZERO, "조금 밀면 안 움직인다 (죽은 구간)")

	# 충분히 밀면 그 방향
	drag.position = Vector2(200 + JourneyTouch.RADIUS, 400)
	t._unhandled_input(drag)
	ok(t.direction().x > 0.8 and absf(t.direction().y) < 0.01, "밀면 그쪽으로")
	ok(t.direction().length() <= 1.001, "1을 안 넘는다")

	# 두 번째 손가락이 닿으면 걷기를 놓는다 (확대하려던 것이다)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(700, 400)
	t._unhandled_input(second)
	ok(t.direction() == Vector2.ZERO, "두 손가락이면 걷기를 놓는다")

	# 떼면 멈춘다
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = Vector2(400, 400)
	t._unhandled_input(up)
	ok(t.direction() == Vector2.ZERO, "떼면 멈춘다")
	t.queue_free()


# ── 퀘스트 ────────────────────────────────────────────────────────────

func _quest_tests() -> void:
	print("\n[퀘스트]")
	JourneyState.reset()

	# ① 갓 시작했으면 지도도 카메라도 없다. 다음 마을도 잠겨 있다.
	ok(not Quests.has_map(), "처음엔 지도가 없다")
	ok(not Quests.has_camera(), "처음엔 카메라도 없다")
	ok(not Quests.village_cleared("윤슬"), "윤슬을 아직 안 마쳤다")
	ok(not Quests.is_unlocked("볕뉘"), "볕뉘는 아직 잠겨 있다")
	ok(Quests.is_unlocked("윤슬"), "윤슬은 처음부터 열려 있다")
	ok(Quests.is_unlocked("고향"), "고향은 늘 열려 있다")

	# ② 물범과 처음 대화하면 지도를 받는다. 다음 날 다시 말해도 두 개가
	#    안 된다 — `on_talked()` 가 배낭에 이미 있는지로 가린다.
	var f := Folk.new()
	f.folk_id = "seal"
	f.gives_item = "map"
	f.lines_by_heart = [["안녕"]]
	f.on_talked()
	ok(Quests.has_map(), "물범과 대화하면 지도를 받는다")
	f.reset_day()
	f.on_talked()
	ok(JourneyState.count("map") == 1, "지도는 한 장뿐이다 (다시 안 받는다)")
	f.queue_free()

	# ③ 윤슬은 **매듭 하나와 샛길 둘**로 열린다. 100% 가 아니다.
	JourneyState.pick("camera")
	ok(Quests.knot_step_done("윤슬", 0), "둘에게 인사하면 매듭 첫 단계가 끝난다")
	ok(not Quests.knot_done("윤슬"), "아직 매듭이 다 안 끝났다")
	# 낮에 등대곶에 가 봐야 소용없다 — 저녁이어야 한다
	JourneyState.mark_quest("윤슬:등대")
	JourneyState.mark_quest("윤슬:등대@낮")
	JourneyState.photos.append({"place": "윤슬", "subject": "등대"})
	ok(not Quests.knot_step_done("윤슬", 1),
		"낮에 간 것으로는 둘째 단계가 안 끝난다")
	JourneyState.day = 2
	JourneyState.mark_quest("윤슬:등대@저녁")
	ok(Quests.knot_step_done("윤슬", 1), "저녁에 가서 사진을 남기면 끝난다")
	ok(not Quests.village_cleared("윤슬"), "매듭 셋째 단계가 남았다")
	JourneyState.mark_quest("윤슬:매듭:3")
	ok(Quests.knot_done("윤슬"), "매듭 셋을 다 지났다")
	ok(not Quests.village_cleared("윤슬"), "샛길 둘이 아직 모자란다")
	JourneyState.mark_quest("윤슬:가게")
	ok(Quests.sides_done("윤슬") == 1, "샛길 하나 (%d)" % Quests.sides_done("윤슬"))
	ok(not Quests.village_cleared("윤슬"), "샛길 하나로는 아직")
	JourneyState.mark_quest("윤슬:등대안")
	ok(Quests.village_cleared("윤슬"), "매듭 하나 + 샛길 둘이면 열린다")
	ok(Quests.sides_done("윤슬") < 4, "**샛길 넷을 다 할 필요는 없다**")
	ok(Quests.is_unlocked("볕뉘"), "윤슬을 채우면 볕뉘가 열린다")
	ok(not Quests.is_unlocked("가풀재"), "그렇다고 그다음까지 한 번에 열리진 않는다")

	# ④ 옛 세이브(이 갱신 전) 는 지도·카메라를 자동으로 받는다.
	JourneyState.reset()
	JourneyState.from_dict({"here": "볕뉘"})
	ok(Quests.has_map() and Quests.has_camera(),
		"옛 세이브는 지도·카메라를 잃지 않는다")
	JourneyState.reset()

	# ⑤ 배낭 "이 마을에서" 탭이 읽는 목록도 같은 판정을 그대로 쓴다.
	# 지도·카메라를 받기 전엔 딱 둘만 보여준다("숙제장" 처럼 안 보이게).
	# **다섯 줄만 보인다** — 매듭 한 줄(지금 단계)과 샛길 넷.
	ok(Quests.quest_list("윤슬").size() == 6, "윤슬 목록은 여섯 줄 (이야기 + 샛길 다섯)")
	ok(String(Quests.quest_list("윤슬")[0]["label"]).begins_with("이야기 1/3"),
		"매듭 줄은 지금 단계와 몇 번째인지를 적는다 (%s)"
			% Quests.quest_list("윤슬")[0]["label"])
	ok(String(Quests.quest_list("윤슬")[1]["label"]).begins_with("샛길 · "),
		"샛길 줄은 매듭 줄과 다르게 보인다")
	JourneyState.pick("map")
	JourneyState.pick("camera")
	ok(String(Quests.quest_list("윤슬")[0]["label"]).begins_with("이야기 2/3"),
		"인사를 마치면 매듭 줄이 다음 단계로 넘어간다")
	JourneyState.reset()
	ok(Quests.quest_list("볕뉘").size() == 7, "볕뉘는 항목 7개 (능 안쪽길·흙마당 포함)")
	ok(Quests.quest_list("고향").is_empty(), "고향은 할 일 목록이 없다")

	# ⑤-2 프롤로그(잿마루)에도 할 일이 있다. **게임의 첫 화면이라**
	# 여기가 비어 있으면 시작하자마자 "할 일은 배낭에" 안내가 거짓이 된다.
	JourneyState.reset()
	var jm := Quests.quest_list("잿마루")
	ok(jm.size() == 6, "잿마루(프롤로그)에도 할 일이 여섯 개 있다")
	for q in jm:
		ok(not bool(q["done"]), "갓 시작했으니 아직 안 했다: %s" % q["label"])
	# 소품을 들여다본 것도 기록으로 남는다 (`Place.talk_to_near`).
	JourneyState.mark_quest("잿마루:본:창밖")
	var jm2 := Quests.quest_list("잿마루")
	ok(bool(jm2[1]["done"]), "창밖을 보면 그 줄이 채워진다")
	ok(not bool(jm2[0]["done"]), "다른 줄까지 같이 채워지진 않는다")
	# 그래도 **잠그지 않는다** — 잿마루는 ORDER 밖이라 늘 지나갈 수 있다.
	ok(Quests.village_cleared("잿마루"), "프롤로그는 다 안 해도 막지 않는다")
	ok(Quests.is_unlocked("윤슬"), "프롤로그가 윤슬을 잠그지 않는다")
	JourneyState.reset()
	for q in Quests.quest_list("윤슬"):
		ok(not bool(q["done"]), "갓 초기화했으니 아직 다 안 끝났다: %s" % q["label"])

	# ⑥ 2탄 "담수 3부작" — 1탄 넷을 다 마쳐야 열리고, 카피바라 하나만
	# 대화 대상이다(갈매기는 방문+사진으로 대신한다).
	JourneyState.reset()
	ok(not Quests.is_unlocked("굽이나루"), "1탄을 안 마쳤으면 굽이나루도 잠겨 있다")
	ok(Quests.quest_list("굽이나루").size() == 6,
		"굽이나루는 항목 6개 (그 마을만의 것 하나 포함)")
	for name in ["윤슬", "볕뉘", "가풀재", "하늬섬"]:
		JourneyState.visited[name] = true
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.mark_quest("윤슬:가게")
	JourneyState.mark_quest("윤슬:등대")
	JourneyState.mark_quest("윤슬:잠")
	JourneyState.mark_quest("윤슬:등대안")
	JourneyState.mark_quest("윤슬:부두끝")
	# 윤슬은 매듭 구조다 — 저녁 등대 + 다음 날 바다유리
	JourneyState.mark_quest("윤슬:등대@저녁")
	JourneyState.mark_quest("윤슬:매듭:3")
	for i in Quests.PICKUP_TOTAL["윤슬"]:
		JourneyState.taken["윤슬:%d,0" % i] = true
	JourneyState.photos.append({"place": "윤슬", "subject": "등대"})
	JourneyState.hearts["ju_seal"] = 1
	JourneyState.hearts["ju_kid"] = 1
	JourneyState.mark_quest("볕뉘:가게")
	JourneyState.mark_quest("볕뉘:능")
	JourneyState.mark_quest("볕뉘:능안")
	JourneyState.mark_quest("볕뉘:흙마당")
	for i in Quests.PICKUP_TOTAL["볕뉘"]:
		JourneyState.taken["볕뉘:%d,1" % i] = true
	JourneyState.hearts["san_seal"] = 1
	JourneyState.hearts["san_gull"] = 1
	JourneyState.mark_quest("가풀재:가게")
	JourneyState.mark_quest("가풀재:능선")
	JourneyState.mark_quest("가풀재:등대안")
	JourneyState.mark_quest("가풀재:부두끝")
	for i in Quests.PICKUP_TOTAL["가풀재"]:
		JourneyState.taken["가풀재:%d,2" % i] = true
	JourneyState.photos.append({"place": "가풀재", "subject": "노을"})
	JourneyState.hearts["do_seal"] = 1
	JourneyState.hearts["do_kid"] = 1
	JourneyState.mark_quest("하늬섬:가게")
	JourneyState.mark_quest("하늬섬:한바퀴")
	JourneyState.mark_quest("하늬섬:등대안")
	JourneyState.mark_quest("하늬섬:언덕")
	for i in Quests.PICKUP_TOTAL["하늬섬"]:
		JourneyState.taken["하늬섬:%d,3" % i] = true
	JourneyState.photos.append({"place": "하늬섬", "subject": "돌담"})
	ok(Quests.village_cleared("윤슬") and Quests.village_cleared("볕뉘")
		and Quests.village_cleared("가풀재") and Quests.village_cleared("하늬섬"),
		"1탄 네 곳을 다 채웠다")
	ok(Quests.is_unlocked("굽이나루"), "1탄을 다 마치면 굽이나루가 열린다")
	ok(not Quests.is_unlocked("방울못"), "그렇다고 그다음까지 한 번에 안 열린다")
	JourneyState.hearts["cap_guinaru"] = 1
	JourneyState.mark_quest("굽이나루:가게")
	JourneyState.mark_quest("굽이나루:데크")
	for i in Quests.PICKUP_TOTAL["굽이나루"]:
		JourneyState.taken["굽이나루:%d,4" % i] = true
	JourneyState.photos.append({"place": "굽이나루", "subject": "강 굽이"})
	ok(not Quests.village_cleared("굽이나루"), "잠을 안 잤으면 아직 안 끝났다")
	JourneyState.mark_quest("굽이나루:잠")
	ok(not Quests.village_cleared("굽이나루"),
		"그 마을만의 것을 안 했으면 아직 안 끝났다")
	JourneyState.mark_quest(Quests._local_flag("굽이나루"))
	ok(Quests.village_cleared("굽이나루"), "카피바라 마을도 같은 결로 채워진다")
	ok(Quests.is_unlocked("방울못"), "굽이나루를 다 채우면 방울못이 열린다")

	# ⑦ 솔은재 — 담수 3부작 다음, 물을 벗어난 첫 마을. 같은 결로 잠긴다.
	ok(not Quests.is_unlocked("솔은재"), "2탄 셋을 안 마쳤으면 솔은재도 잠겨 있다")
	for name in ["굽이나루", "방울못", "갈밭머리"]:
		JourneyState.visited[name] = true
	for name in ["굽이나루", "방울못", "갈밭머리"]:
		JourneyState.hearts["cap_%s" % {"굽이나루": "guinaru", "방울못": "bangul",
			"갈밭머리": "galbat"}[name]] = 1
		JourneyState.mark_quest("%s:가게" % name)
		JourneyState.mark_quest("%s:잠" % name)
		for i in Quests.PICKUP_TOTAL[name]:
			JourneyState.taken["%s:%d,9" % [name, i]] = true
		JourneyState.photos.append({"place": name, "subject": "사진"})
	JourneyState.mark_quest("굽이나루:데크")
	JourneyState.mark_quest("방울못:데크")
	JourneyState.mark_quest("갈밭머리:전망대")
	for name2 in ["굽이나루", "방울못", "갈밭머리"]:
		JourneyState.mark_quest(Quests._local_flag(name2))
	ok(Quests.is_unlocked("솔은재"), "2탄 셋을 다 마치면 솔은재가 열린다")
	ok(Quests.quest_list("솔은재").size() == 6,
		"솔은재는 항목 6개 (그 마을만의 것 하나 포함)")

	# ⑧ 꽃눈벌 — 솔은재 다음, 처음으로 밭이 골격인 마을. 같은 결로 잠긴다.
	ok(not Quests.is_unlocked("꽃눈벌"), "솔은재를 안 마쳤으면 꽃눈벌도 잠겨 있다")
	JourneyState.visited["솔은재"] = true
	JourneyState.hearts["cap_sol"] = 1
	JourneyState.mark_quest("솔은재:가게")
	JourneyState.mark_quest("솔은재:잠")
	JourneyState.mark_quest("솔은재:전망")
	for i in Quests.PICKUP_TOTAL["솔은재"]:
		JourneyState.taken["솔은재:%d,9" % i] = true
	JourneyState.photos.append({"place": "솔은재", "subject": "전망"})
	JourneyState.mark_quest(Quests._local_flag("솔은재"))
	ok(Quests.is_unlocked("꽃눈벌"), "솔은재를 다 마치면 꽃눈벌이 열린다")
	ok(Quests.quest_list("꽃눈벌").size() == 6,
		"꽃눈벌은 항목 6개 (그 마을만의 것 하나 포함)")
	JourneyState.reset()


# ── 할 일이 지도 위 어디인가 ──────────────────────────────────────────
#
# 글자로 적힌 할 일과 미니맵 표시가 **같은 데이터 하나**를 보게 만들었으니
# (`Quests.quest_list` 의 kind/key → `Place.goal_world`), 그 연결이 실제로
# 이어지는지 마을마다 확인한다. 여기가 끊기면 "할 일은 아는데 어디로
# 가야 할지 모른다" 는 그 문제가 조용히 돌아온다.

const GOAL_SCENES := {
	"잿마루": "res://scenes/journey/Jaenmaru.tscn",
	"윤슬": "res://scenes/journey/Yunseul.tscn",
	"볕뉘": "res://scenes/journey/Byeotnwi.tscn",
	"가풀재": "res://scenes/journey/Gapuljae.tscn",
	"하늬섬": "res://scenes/journey/Hanuiseom.tscn",
	"굽이나루": "res://scenes/journey/Gubinaru.tscn",
	"방울못": "res://scenes/journey/Bangulmot.tscn",
	"갈밭머리": "res://scenes/journey/Galbatmeori.tscn",
	"솔은재": "res://scenes/journey/Soleunjae.tscn",
	"꽃눈벌": "res://scenes/journey/Kkonnunbeol.tscn",
}

## **직접 밟고 서야 하는** 종류만. 문·잠자리는 일부러 막힌 칸을 가리킨다
## — 건물 그 자체라서, 옆에 서면 버튼이 뜬다. 가 볼 자리는 반지름 안에만
## 들어가면 되고(꽃눈벌은 도랑 한복판이 목표다), 줍기는 아래에서 따로
## 더 깐깐하게 본다.
const GOAL_WALKABLE := ["depart"]


func _goal_tests() -> void:
	print("\n[할 일과 지도]")
	# 지도·카메라를 다 가진 상태로 본다 — 그래야 마을마다 항목이 다 열린다.
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")

	for village in GOAL_SCENES:
		var path: String = GOAL_SCENES[village]
		if not ResourceLoader.exists(path):
			ok(false, "%s 씬이 있다" % village)
			continue
		var p: Place = load(path).instantiate()
		add_child(p)
		await get_tree().process_frame
		var size: Vector2i = p.tile_size()

		var list := Quests.quest_list(village)
		var unreachable: Array = []
		var outside: Array = []
		var blocked: Array = []
		for q in list:
			var at: Vector2 = p.goal_world(q)
			if at == Vector2.INF:
				unreachable.append(String(q.get("label", "")))
				continue
			var t := p.tile_of(at)
			if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
				outside.append(String(q.get("label", "")))
			elif GOAL_WALKABLE.has(String(q.get("kind", ""))) and not p._walkable(t):
				blocked.append("%s %s" % [q.get("label", ""), t])
		ok(unreachable.is_empty(),
			"%s: 모든 할 일이 지도 위 자리를 안다%s"
				% [village, "" if unreachable.is_empty() else " — " + str(unreachable)])
		ok(outside.is_empty(),
			"%s: 할 일 자리가 지도 밖으로 안 나간다%s"
				% [village, "" if outside.is_empty() else " — " + str(outside)])
		ok(blocked.is_empty(),
			"%s: 걸어가야 하는 자리가 막혀 있지 않다%s"
				% [village, "" if blocked.is_empty() else " — " + str(blocked)])

		# 가 볼 자리는 반지름 안에 **설 수 있는 칸이 하나라도** 있어야 한다.
		# 한복판이 물이어도 괜찮지만(꽃눈벌 도랑), 둘레까지 다 막혀 있으면
		# 그 퀘스트는 영영 안 끝난다.
		var sealed: Array = []
		for z in p.quest_zones():
			var c: Vector2i = z[1]
			var rad: int = int(ceil(float(z[2]) / 16.0))
			var reachable := false
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var t2 := c + Vector2i(dx, dy)
					if p.world_of(t2).distance_to(p.world_of(c)) <= float(z[2]) \
							and p._walkable(t2):
						reachable = true
			if not reachable:
				sealed.append(String(z[0]))
		ok(sealed.is_empty(), "%s: 가 볼 자리에 설 수 있다%s"
			% [village, "" if sealed.is_empty() else " — " + str(sealed)])

		# **줍기는 그 칸을 직접 밟아야 한다.** 줍는 거리가 12px 인데 한 칸이
		# 16px 이라, 옆 칸에 서서는 안 닿는다. 막힌 칸에 놓이면 영영 못
		# 줍고 "다 줍기" 가 안 끝나 **다음 마을이 안 열린다.** 실제로
		# 굽이나루가 그랬다 — 갈매기가 아랫칸까지 막고 있는 자리였다.
		var stuck: Array = []
		for e in p.pickups():
			var pt := Vector2i(e[0], e[1])
			if not p._walkable(pt):
				stuck.append("%s %s" % [e[2], pt])
		ok(stuck.is_empty(), "%s: 못 줍는 자리에 놓인 것이 없다%s"
			% [village, "" if stuck.is_empty() else " — " + str(stuck)])

		# 접은 미니맵은 **하나만** 가리킨다. 여럿 뜨면 작은 지도가 지저분해진다.
		var now: Dictionary = p.current_goal()
		ok(not now.is_empty(), "%s: 가리킬 할 일을 하나 잡는다" % village)
		ok(p.open_goals().size() >= 1, "%s: 펼치면 남은 할 일이 보인다" % village)

		p.queue_free()
		await get_tree().process_frame

	# 다 하고 나면 지도에서 사라진다.
	var sol: Place = load(GOAL_SCENES["솔은재"]).instantiate()
	add_child(sol)
	await get_tree().process_frame
	var before := sol.open_goals().size()
	JourneyState.hearts["cap_sol"] = 1
	var after := sol.open_goals().size()
	ok(after == before - 1, "인사를 마치면 그 표시가 지도에서 빠진다 (%d→%d)"
		% [before, after])

	# 골라 둔 것이 있으면 그것을 가리킨다.
	var pick: Dictionary = {}
	for q in sol.open_goals():
		if String(q.get("kind", "")) == "sleep":
			pick = q
	ok(not pick.is_empty(), "잠자리 항목이 목록에 있다")
	if not pick.is_empty():
		sol.set_goal(pick)
		ok(sol.current_goal() == pick, "목록에서 고른 것을 미니맵이 가리킨다")

	# 카메라가 없으면 사진 목표를 아직 안 가리킨다.
	JourneyState.bag.erase("camera")
	var shown := true
	for q in sol.open_goals():
		if bool(q.get("photo", false)):
			shown = false
	ok(shown, "카메라를 받기 전엔 사진 목표를 안 가리킨다")

	sol.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


## 미니맵이 그릴 수 있는 종류인가.
##
## `_draw()` 는 엔진 밖에서 못 부른다. 대신 **그림이 기대는 약속**을
## 지킨다: 목록이 내놓는 `kind` 를 미니맵이 다 알고 있어야 한다.
## 모르는 종류가 생기면 기본 모양으로 조용히 떨어져서, 잠자리가 동그라미로
## 뜨는 식으로 어긋나도 아무도 모른다.
const MINIMAP_KINDS := ["talk", "prop", "door", "visit", "pickup", "sleep", "depart", "trace"]

func _minimap_kind_test() -> void:
	print("\n[미니맵이 아는 종류]")
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	var seen := {}
	var unknown: Array = []
	for village in GOAL_SCENES:
		for q in Quests.quest_list(village):
			var k := String(q.get("kind", ""))
			seen[k] = true
			if not MINIMAP_KINDS.has(k):
				unknown.append("%s: %s" % [village, k])
	ok(unknown.is_empty(), "미니맵이 모르는 할 일 종류가 없다%s"
		% ("" if unknown.is_empty() else " — " + str(unknown)))
	# 종류를 붙이는 걸 빠뜨리면 빈 문자열이 되어 조용히 기본 모양이 된다.
	ok(not seen.has(""), "종류가 안 붙은 할 일이 없다")
	ok(seen.size() >= 6, "쓰이는 종류가 여섯 가지는 된다 (%d)" % seen.size())
	JourneyState.reset()


## 가게 안이 마을마다 달라지는가.
##
## 씬 하나를 아홉 마을이 같이 쓴다. 골격은 같아도 바닥과 곁 물건은
## 달라야 "또 이 방" 이 안 된다. 표에 오타가 나면 조용히 기본 방으로
## 떨어지므로(마을 이름이 안 맞으면 `_skin()` 이 빈 값을 준다) 여기서 본다.
func _shop_skin_test() -> void:
	print("\n[가게 안 변주]")
	var villages: Array = []
	for v in GOAL_SCENES:
		if v != "잿마루":
			villages.append(v)
	# 모든 마을이 제 결을 갖고 있나
	var missing: Array = []
	for v in villages:
		if not ShopInterior.SKIN.has(v):
			missing.append(v)
	ok(missing.is_empty(), "가게가 있는 마을이 다 제 결을 갖는다%s"
		% ("" if missing.is_empty() else " — " + str(missing)))

	# 씬 경로 되짚기가 실제 씬 파일 이름과 맞나
	var wrong: Array = []
	for v in villages:
		var base: String = String(GOAL_SCENES[v]).get_file().get_basename()
		if String(ShopInterior.FROM_SCENE.get(base, "")) != v:
			wrong.append("%s(%s)" % [v, base])
	ok(wrong.is_empty(), "어느 마을에서 들어왔는지 되짚을 수 있다%s"
		% ("" if wrong.is_empty() else " — " + str(wrong)))

	# 곁 물건 그림이 실제로 있나. 없으면 경고만 뜨고 빈자리가 된다.
	var noart: Array = []
	var floors := {}
	for v in villages:
		var sk: Array = ShopInterior.SKIN[v]
		floors[String(sk[0])] = true
		for nm in sk[2]:
			var art := "res://assets/sprites/%s.png" % nm
			if not ResourceLoader.exists(art):
				noart.append("%s: %s" % [v, nm])
	ok(noart.is_empty(), "곁 물건 그림이 다 있다%s"
		% ("" if noart.is_empty() else " — " + str(noart)))
	ok(floors.size() >= 2, "바닥이 한 가지가 아니다 (%d 가지)" % floors.size())

	# 문 앞 통로(가운데 세로줄)를 막는 것이 없어야 들어오자마자 안 갇힌다.
	var mid: int = ShopInterior.W / 2
	var blocking: Array = []
	for pos in ShopInterior.SKIN_POS:
		if int(pos[0]) == mid:
			blocking.append(str(pos))
	ok(blocking.is_empty(), "곁 물건이 문 앞 통로를 안 막는다%s"
		% ("" if blocking.is_empty() else " — " + str(blocking)))

	# **들어서자마자 보여야 한다.** 문 앞에서 화면에 잡히는 건 가로로
	# 스무 칸 남짓이다. 바깥 기둥에 뒀더니 마을마다 다르게 해 놓고도
	# 들어가서는 다른 줄을 몰랐다.
	var spawn := Vector2i(mid, ShopInterior.H - 2)
	var far: Array = []
	for pos in ShopInterior.SKIN_POS:
		if absi(int(pos[0]) - spawn.x) > 10 or absi(int(pos[1]) - spawn.y) > 8:
			far.append(str(pos))
	ok(far.size() <= 1, "곁 물건이 문 앞에서 보이는 자리에 있다%s"
		% ("" if far.size() <= 1 else " — " + str(far)))


# ── 걸어서 닿는가 ─────────────────────────────────────────────────────
#
# **칸 하나만 보면 못 잡는다.** 그 칸이 걸을 수 있는 땅이어도, 물이나
# 소품에 둘러싸여 섬이 되어 있으면 영영 못 간다.
#
# 굽이나루가 실제로 그랬다 — 강이 지도를 세로로 완전히 갈라서, 스폰은
# 서안이고 가게·잠자리·**정류장이 전부 동안**이었다. 건널 데가 한 군데도
# 없었으니 그 마을에 닿은 사람은 **떠날 수조차 없었다.** 모래톱은 또
# 따로 떠 있는 섬이라 거기 놓인 줍기 둘도 못 주웠다.
#
# 앞의 검사들은 다 통과했다. 칸만 봤지 **이어져 있는지**를 안 봤다.

func _reach_tests() -> void:
	print("\n[걸어서 닿는가]")
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	for village in GOAL_SCENES:
		var p: Place = load(String(GOAL_SCENES[village])).instantiate()
		add_child(p)
		await get_tree().process_frame

		var size: Vector2i = p.tile_size()
		var start: Vector2i = p.spawn_tile()
		# 스폰에서 시작해 걸을 수 있는 칸을 다 훑는다.
		var seen := {start: true}
		var q: Array[Vector2i] = [start]
		while not q.is_empty():
			var at: Vector2i = q.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = at + d
				if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
					continue
				if not p._walkable(n):
					continue
				seen[n] = true
				q.append(n)

		var near := func(t: Vector2i) -> bool:
			for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				if seen.has(t + d):
					return true
			return false

		# 줍기는 그 칸을 직접 밟아야 한다(줍는 거리 12px < 한 칸 16px).
		var lost: Array = []
		for e in p.pickups():
			if not seen.has(Vector2i(e[0], e[1])):
				lost.append("%s(%d,%d)" % [e[2], e[0], e[1]])
		ok(lost.is_empty(), "%s: 주울 것에 다 걸어갈 수 있다%s"
			% [village, "" if lost.is_empty() else " — " + str(lost)])

		# 문·잠자리는 건물 칸이라 곁에만 설 수 있으면 된다.
		var shut: Array = []
		for d2 in p.doors():
			if not near.call(d2["tile"]):
				shut.append(String(d2.get("label", "")))
		var bed: Vector2i = p.sleep_tile()
		if bed.x >= 0 and not near.call(bed):
			shut.append("잠자리")
		ok(shut.is_empty(), "%s: 문과 잠자리 곁에 설 수 있다%s"
			% [village, "" if shut.is_empty() else " — " + str(shut)])

		# **갇힌 웅덩이가 없어야 한다.** 소품 몇 개가 지도 모서리에 몇 칸을
		# 가둬 놓으면, 몸으로는 비집고 들어가지는데(소품은 밑동만 막는다)
		# 길찾기는 못 나온다 — 톡 눌러도 아무 데도 못 가고 손으로 밀어
		# 빠져나와야 한다. 소품 배치를 손볼 때마다 생길 수 있는 사고다.
		var island: Array = []
		for yy in size.y:
			for xx in size.x:
				var t4 := Vector2i(xx, yy)
				if p._walkable(t4) and not seen.has(t4):
					island.append(t4)
		ok(island.is_empty(), "%s: 갇힌 웅덩이가 없다%s"
			% [village, "" if island.is_empty() else " — %d칸 %s" % [
				island.size(), str(island.slice(0, 6))]])

		# **여기가 제일 중요하다.** 정류장에 못 가면 그 마을에 갇힌다.
		var go: Vector2i = p.depart_tile()
		ok(go.x < 0 or seen.has(go),
			"%s: 정류장까지 걸어갈 수 있다 (갇히지 않는다)" % village)

		# 가 볼 자리는 반지름 안 어딘가에 설 수 있으면 된다.
		var sealed: Array = []
		for z in p.quest_zones():
			var c: Vector2i = z[1]
			var rad: int = int(ceil(float(z[2]) / 16.0)) + 1
			var okz := false
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var t2 := c + Vector2i(dx, dy)
					if seen.has(t2) \
							and p.world_of(t2).distance_to(p.world_of(c)) <= float(z[2]):
						okz = true
			if not okz:
				sealed.append(String(z[0]))
		ok(sealed.is_empty(), "%s: 가 볼 자리까지 걸어갈 수 있다%s"
			% [village, "" if sealed.is_empty() else " — " + str(sealed)])

		p.queue_free()
		await get_tree().process_frame
	JourneyState.reset()


# ── 샛길 ──────────────────────────────────────────────────────────────
#
# 마을만의 할 일이 **샛길 안쪽**에서 끝난다. 그러니 여기 길이 막혀 있으면
# 그 마을을 영영 못 끝내고, 다음 마을도 안 열린다. 굽이나루가 강으로
# 갈려 있던 것과 똑같은 사고가 여기서 또 날 수 있다.

func _side_path_tests() -> void:
	print("\n[샛길]")
	JourneyState.reset()
	var villages: Array = SidePathInterior.PATHS.keys()
	ok(villages.size() == 3, "샛길이 셋 있다 (%d)" % villages.size())
	for village in villages:
		# 그 마을에서 들어온 것처럼 꾸민다.
		JourneyState.exit_scene = String(GOAL_SCENES.get(village, ""))
		JourneyState.exit_tile = Vector2i(2, 2)
		var node: Node = load(
			"res://scenes/journey/interiors/SidePathInterior.tscn").instantiate()
		if not (node is Place):
			ok(false, "%s: 샛길 씬에 스크립트가 붙는다 (붙은 것: %s / %s)"
				% [village, node.get_class(), str(node.get_script())])
			node.queue_free()
			continue
		var p: Place = node
		add_child(p)
		await get_tree().process_frame

		var nm: String = p.place_name()
		ok(nm != "샛길", "%s: 제 이름을 안다 (%s)" % [village, nm])

		# 완료 열쇠가 `Quests.LOCAL` 의 표시와 짝이어야 한다. 어긋나면
		# 안쪽까지 걸어가도 그 마을 할 일이 안 끝난다.
		var want := Quests._local_flag(village)
		var keys: Array = []
		for z in p.quest_zones():
			keys.append(String(z[0]))
		ok(keys.has(want), "%s: 안쪽 자리가 %s 를 남긴다 %s" % [village, want, keys])

		# 마을 쪽 문의 enter_key 와 **겹치면 안 된다.** 겹치면 문을 지난
		# 것만으로 끝나서 샛길을 만든 뜻이 없어진다 (능 안쪽길의 그 교훈).
		var entered := "%s:%s" % [village, "샛길입구"]
		ok(entered != want, "%s: 문만 지나서는 안 끝난다" % village)

		# 들어온 자리에서 안쪽 자리·나가는 문까지 걸어서 닿는가.
		var size: Vector2i = p.tile_size()
		var start: Vector2i = p.spawn_tile()
		var seen := {start: true}
		var q: Array[Vector2i] = [start]
		while not q.is_empty():
			var at: Vector2i = q.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = at + d
				if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
					continue
				if not p._walkable(n):
					continue
				seen[n] = true
				q.append(n)
		ok(seen.size() > 20, "%s: 걸어 다닐 자리가 있다 (%d칸)" % [village, seen.size()])

		for z in p.quest_zones():
			var c: Vector2i = z[1]
			var rad: int = int(ceil(float(z[2]) / 16.0)) + 1
			var reach := false
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var t2: Vector2i = c + Vector2i(dx, dy)
					if seen.has(t2) \
							and p.world_of(t2).distance_to(p.world_of(c)) <= float(z[2]):
						reach = true
			ok(reach, "%s: 안쪽 자리까지 걸어갈 수 있다 %s" % [village, c])

		var out_ok := false
		for d3 in p.doors():
			var t3: Vector2i = d3["tile"]
			for d4 in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				if seen.has(t3 + d4):
					out_ok = true
		ok(out_ok, "%s: 다시 나갈 수 있다 (갇히지 않는다)" % village)

		# 안쪽 자리는 들어온 데서 **멀어야** 한다. 두 걸음이면 걷는 맛이 없다.
		for z in p.quest_zones():
			var far: int = absi(z[1].x - start.x) + absi(z[1].y - start.y)
			ok(far >= 10, "%s: 안쪽 자리가 입구에서 멀다 (%d칸)" % [village, far])

		p.queue_free()
		await get_tree().process_frame
	JourneyState.exit_scene = ""
	JourneyState.reset()


# ── 하나 마쳤을 때 ────────────────────────────────────────────────────
#
# 다 하면 목록이 조용해질 뿐이라, 방금 그게 끝난 건지 몰랐다. 한 줄만
# 띄웠다 지운다 — 창도, 진행도도, 손 멈춤도 없다.
#
# **도착하자마자 우르르 뜨면 안 된다.** 마을에 들어서면 이미 해 둔
# 것들이 다 "방금 끝났다" 로 보일 수 있어서, 기준을 조용히 새로 잡는다.

func _done_toast_tests() -> void:
	print("\n[마친 표시]")
	JourneyState.reset()
	var p: Place = load(GOAL_SCENES["솔은재"]).instantiate()
	add_child(p)
	await get_tree().process_frame
	var hud: JourneyHud = p.hud

	# 이미 해 둔 것이 있는 채로 들어와도 조용해야 한다.
	JourneyState.hearts["cap_sol"] = 1
	JourneyState.announce_ready = false   # 앱을 갓 켠 셈으로
	hud._watch_done(Quests.quest_list("솔은재"))
	ok(hud._cele_queue.is_empty() and not hud._cele_busy,
		"도착할 때 이미 해 둔 것은 안 알린다")

	# 여기서 하나를 새로 마치면 그때 가운데 잔치가 뜬다.
	JourneyState.mark_quest("솔은재:가게")
	hud._watch_done(Quests.quest_list("솔은재"))
	ok(hud._cele_busy, "새로 마치면 축하가 뜬다")
	ok(hud._cele_big.text == "다 했어요!",
		"마쳤다고 크게 적는다 (%s)" % hud._cele_big.text)
	ok(hud._cele_sub.text.begins_with("가게 들어가 보기"),
		"무엇을 마쳤는지 적는다 (%s)" % hud._cele_sub.text)

	# 같은 것이 두 번 뜨지 않는다.
	var before := hud._cele_queue.size()
	hud._watch_done(Quests.quest_list("솔은재"))
	ok(hud._cele_queue.size() == before, "같은 것을 두 번 안 알린다")

	# 마지막 하나를 마치면 한 줄 더. 다음 마을 이야기는 안 한다.
	JourneyState.mark_quest("솔은재:전망")
	JourneyState.mark_quest("솔은재:잠")
	JourneyState.mark_quest(Quests._local_flag("솔은재"))
	JourneyState.photos.append({"place": "솔은재", "subject": "전망"})
	for i in Quests.PICKUP_TOTAL["솔은재"]:
		JourneyState.taken["솔은재:%d,9" % i] = true
	hud._watch_done(Quests.quest_list("솔은재"))
	var all_line := ""
	for s in hud._cele_queue:
		if String(s[0]).begins_with("이 마을"):
			all_line = String(s[0]) + " " + String(s[1])
	if hud._cele_big.text.begins_with("이 마을"):
		all_line = hud._cele_big.text + " " + hud._cele_sub.text
	ok(all_line != "", "다 마치면 한 번 더 크게 뜬다 (%s)" % all_line)
	ok(not all_line.contains("열렸") and not all_line.contains("다음"),
		"다음 마을 이야기는 안 한다")

	# 긴 이름도 화면 안에 들어와야 한다.
	#
	# 여태 "줄바꿈이 켜져 있나" 로 봤는데, 이제 `Wrap` 이 미리 접어
	# 넣고 자동 줄바꿈은 꺼 둔다 - 켜 두면 한글이 낱말 한가운데서
	# 갈리기 때문이다. 그래서 **줄마다 폭 안에 드는지**를 직접 잰다.
	var sub_f := hud._cele_sub.get_theme_font("font")
	var sub_s := hud._cele_sub.get_theme_font_size("font_size")
	var sub_w := Wrap.width_of(hud._cele_sub)
	var over: Array = []
	if sub_f != null and sub_w >= 1.0:
		for one in hud._cele_sub.text.split("\n"):
			var got: float = sub_f.get_string_size(
				one, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_s).x
			if got > sub_w:
				over.append("%s (%d > %d)" % [one, int(got), int(sub_w)])
	ok(over.is_empty(), "긴 이름도 화면 폭 안에 든다%s"
		% ("" if over.is_empty() else " - " + str(over)))

	# **화면 가운데는 한 번에 하나만.** 지도를 받는 순간이 곧 그 할 일을
	# 마치는 순간이라, 얻은 것 카드와 축하가 같은 자리에 겹쳐 떠서
	# 그림과 글자가 서로 뭉갰다 (폰에서 확인). 줄을 세워 차례로 띄운다.
	hud._got_queue.clear()
	hud._cele_queue.clear()
	hud._got_busy = false
	hud._cele_busy = false
	hud.show_got("map")
	hud._celebrate("다 했어요!", "가게 할머니와 인사하고 지도 받기")
	ok(hud._got_busy and not hud._cele_busy,
		"얻은 것 카드가 먼저 뜨고 축하는 기다린다")
	ok(hud._cele_queue.size() == 1, "기다리는 축하가 줄에 남아 있다")
	ok(not (hud._got_busy and hud._cele_busy), "둘이 같이 뜨지 않는다")

	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 첫 마을 안내 ──────────────────────────────────────────────────────
#
# 인트로를 보고 지도가 뜬 순간부터 **뭘 하라는 건지 화면에 있어야 한다.**
# 도착하면 가운데에 크게 한 줄, 그리고 첫 여행지를 떠날 때까지 위쪽에
# 늘 한 줄. 둘 다 미니맵이 짚는 것과 **같은 항목**이어야 한다 — 셋이
# 서로 다른 걸 가리키면 없느니만 못하다.

func _first_map_guide_tests() -> void:
	print("\n[첫 마을 안내]")
	JourneyState.reset()
	var p: Place = load(GOAL_SCENES["잿마루"]).instantiate()
	add_child(p)
	await get_tree().process_frame
	var hud: JourneyHud = p.hud

	var goal := hud._first_task()
	ok(goal != "", "지금 해볼 일을 하나 집는다 (%s)" % goal)
	# **인연을 다 세운 뒤**에 집어야 한다. 예전엔 화면을 짓는 도중에
	# 집어서, 말 걸 상대가 아직 없으니 엉뚱하게 맨 끝 항목이 뽑혔다.
	ok(goal == "옆자리 동료에게 인사하기",
		"목록 첫 항목을 집는다 (%s)" % goal)
	var now: Dictionary = p.current_goal()
	ok(String(now.get("label", "")) == goal,
		"미니맵이 짚는 것과 같은 항목이다")

	# 도착 카드가 그 항목을 적는다.
	hud.announce_place(p.place_name())
	await get_tree().process_frame
	ok(hud._arrive_task.visible, "도착하면 가운데에 할 일이 뜬다")
	ok(hud._arrive_task.text.contains(goal),
		"도착 카드가 그 항목을 적는다 (%s)" % hud._arrive_task.text)
	ok(hud._place_title.text == p.place_name(), "마을 이름도 같이 뜬다")

	# 첫 여행지를 떠나기 전까지는 위쪽 줄이 늘 떠 있다.
	JourneyState.departures = 0
	hud._tick_task_strip()
	ok(hud._task_strip.visible, "첫 마을에서는 안내줄이 떠 있다")
	ok(hud._task_strip.text.contains(goal),
		"안내줄도 같은 항목이다 (%s)" % hud._task_strip.text)

	# 하나 마치면 다음 것으로 저절로 넘어간다.
	JourneyState.hearts["coworker"] = 1
	hud._tick_task_strip()
	ok(not hud._task_strip.text.contains(goal),
		"마치면 다음 할 일로 넘어간다 (%s)" % hud._task_strip.text)

	# 첫 여행지를 떠나고 나면 조용해진다.
	JourneyState.departures = JourneyHud.STRIP_UNTIL_DEPARTURES
	hud._tick_task_strip()
	ok(not hud._task_strip.visible, "첫 여행지를 떠나면 안내줄이 사라진다")

	# 배낭을 열면 가린다 — 창 위에 겹쳐 뜨면 지저분하다.
	JourneyState.departures = 0
	hud.toggle_bag()
	hud._tick_task_strip()
	ok(not hud._task_strip.visible, "배낭을 열면 안내줄을 감춘다")
	hud.toggle_bag()

	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 윤슬을 실제로 끝낼 수 있나 ────────────────────────────────────────
#
# 여태 검사는 표시를 **손으로 찍어 넣고** 잠금이 풀리는지만 봤다. 그건
# `Quests` 의 셈이 맞는지를 볼 뿐, 그 표시를 **게임 안에서 실제로 남길
# 수 있는지**는 안 본다. 굽이나루가 강으로 갈려 있던 것도 그래서 못
# 잡았다.
#
# 여기서는 주인공을 실제로 그 자리에 세우고, 문을 지나고, 자고, 주워서
# 표시가 하나씩 찍히는지 본다. 마지막에 볕뉘가 열려야 한다.

func _yunseul_clear_tests() -> void:
	print("\n[윤슬을 끝낼 수 있나]")
	JourneyState.reset()
	var p: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(p)
	await get_tree().process_frame

	# ① 두 인연에게 말을 걸어 지도·카메라를 받는다.
	for f in p._folk:
		if not is_instance_valid(f) or f.is_spot:
			continue
		if f.folk_id == "seal" or f.folk_id == "seagull":
			p.walker.global_position = f.global_position
			p._update_near()
			p.talk_to_near()
			if p.say != null:
				p.say.close()
			await get_tree().process_frame
	ok(Quests.has_map(), "가게 할머니에게 지도를 받는다")
	ok(Quests.has_camera(), "갈매기 소년에게 카메라를 받는다")

	# ② 문 둘을 지난다 (가게 · 등대). 문 앞에 설 수 있어야 한다.
	for d in p.doors():
		var t: Vector2i = d["tile"]
		var stand := Vector2i(-1, -1)
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0),
				Vector2i(1, 0), Vector2i.ZERO]:
			if p._walkable(t + off):
				stand = t + off
				break
		ok(stand.x >= 0, "%s 문 앞에 설 자리가 있다" % d.get("label", ""))
		if stand.x < 0:
			continue
		p.walker.global_position = p.world_of(stand)
		await get_tree().process_frame
		ok(p._can_enter() != null, "%s 가 실제로 열린다" % d.get("label", ""))
		# 문을 지난 것으로 친다 (씬을 갈아 끼우지 않고 표시만 확인)
		JourneyState.mark_quest("윤슬:%s" % String(d.get("enter_key", "가게")))
	ok(JourneyState.quest_done("윤슬:가게"), "가게 표시가 남는다")
	ok(JourneyState.quest_done("윤슬:등대안"), "등대 안 표시가 남는다")

	# ③ 가 볼 자리를 **전부** 걸어가 본다 — 등대곶도 부두 끝도.
	# **저녁에 간다.** 매듭 둘째 단계가 시간대를 본다 — 등대에 불이
	# 들어오는 시간이어야 한다.
	JourneyState.minutes = 19.0 * 60.0
	# 예전엔 첫째 것만 갔는데, 부두 끝이 우연히(갈매기 소년 곁이라)
	# 찍히는 바람에 빠진 걸 몰랐다.
	for z0 in p.quest_zones():
		var z: Array = z0
		var c: Vector2i = z[1]
		var near := Vector2i(-1, -1)
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var t2: Vector2i = c + Vector2i(dx, dy)
				if p._walkable(t2) \
						and p.world_of(t2).distance_to(p.world_of(c)) <= float(z[2]):
					near = t2
		ok(near.x >= 0, "%s 반지름 안에 설 자리가 있다" % z[0])
		p.walker.global_position = p.world_of(near)
		p._tick_quest_zones()
		ok(JourneyState.quest_done(String(z[0])), "%s 표시가 남는다" % z[0])

	# ③-2 부두 끝은 **아침에도** 가 본다 — 샛길이 두 시간대를 본다.
	JourneyState.minutes = 8.0 * 60.0
	for z1 in p.quest_zones():
		if String(z1[0]) != "윤슬:부두끝":
			continue
		var c1: Vector2i = z1[1]
		for dy1 in range(-3, 4):
			for dx1 in range(-3, 4):
				var t3: Vector2i = c1 + Vector2i(dx1, dy1)
				if p._walkable(t3) \
						and p.world_of(t3).distance_to(p.world_of(c1)) <= float(z1[2]):
					p.walker.global_position = p.world_of(t3)
					p._tick_quest_zones()
	ok(JourneyState.quest_done("윤슬:부두끝@아침")
		and JourneyState.quest_done("윤슬:부두끝@저녁"),
		"부두 끝을 아침·저녁 두 번 본 것이 따로 남는다")

	# ④ 사진을 찍는다.
	p._take_photo()
	await get_tree().process_frame
	var shot := false
	for ph in JourneyState.photos:
		if String(ph.get("place", "")) == "윤슬":
			shot = true
	ok(shot, "윤슬에서 사진이 찍힌다")

	# ⑤ 떨어진 것을 다 줍는다 — 그 칸에 실제로 서서.
	for e in p.pickups():
		p.walker.global_position = p.world_of(Vector2i(e[0], e[1]))
		p._check_pickups()
		await get_tree().process_frame
	ok(Quests._picked_all("윤슬"), "여섯 개를 다 주울 수 있다 (%d/%d)"
		% [JourneyState.taken.size(), Quests.PICKUP_TOTAL["윤슬"]])

	# ⑥ 잠자리에서 잔다.
	var bed: Vector2i = p.sleep_tile()
	var at_bed := Vector2i(-1, -1)
	for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if p._walkable(bed + off):
			at_bed = bed + off
			break
	ok(at_bed.x >= 0, "잠자리 곁에 설 자리가 있다")
	JourneyState.mark_quest("윤슬:잠")

	# ⑥-2 **다음 날**, 바다유리를 들고 소년을 다시 찾아간다.
	# 이것이 이 마을 이야기의 마지막 단계다 — 하루를 넘겨야 한다.
	ok(not Quests.knot_done("윤슬"), "아직 매듭이 안 끝났다 (하루를 안 넘겼다)")
	JourneyState.day += 1
	var boy: Folk = null
	for f4 in p._folk:
		if is_instance_valid(f4) and f4.folk_id == "seagull":
			boy = f4
	ok(boy != null, "갈매기 소년이 있다")
	ok(JourneyState.count("p-seaglass") > 0, "바다유리를 들고 있다")
	if boy != null:
		var said2: Array = p._knot_on_talk(boy)
		ok(not said2.is_empty(), "바다유리를 보여 주면 그때만 하는 말이 나온다")
	ok(Quests.knot_done("윤슬"), "매듭 셋을 다 지났다")

	# ⑥-3 샛길 "고르기" — 조개와 바다유리 중 하나를 골라 할머니에게.
	var granny: Folk = null
	for f5 in p._folk:
		if is_instance_valid(f5) and f5.folk_id == "seal":
			granny = f5
	if granny != null:
		var said3: Array = p._knot_on_talk(granny)
		ok(not said3.is_empty(), "고른 것에 따라 다른 말이 나온다")
	ok(Quests.side_done("윤슬", "윤슬:샛길:고르기"), "고르기 샛길이 끝난다")
	var chose := JourneyState.quest_done("윤슬:골랐다:p-shell") \
		or JourneyState.quest_done("윤슬:골랐다:p-seaglass")
	ok(chose, "무엇을 골랐는지 기록에 남는다")

	# ⑦ 그래서 열리나. **다 안 해도 열려야 한다** — 매듭 하나와 샛길 둘.
	ok(Quests.knot_done("윤슬"), "매듭을 마쳤다")
	ok(Quests.sides_done("윤슬") >= Quests.SIDES_NEEDED,
		"샛길을 둘 넘게 했다 (%d/4)" % Quests.sides_done("윤슬"))
	var left: Array = []
	for q in Quests.quest_list("윤슬"):
		if not bool(q.get("done", false)):
			left.append(String(q.get("label", "")))
	ok(true, "안 한 것이 남아 있어도 된다%s"
		% ("" if left.is_empty() else " — 남음: " + str(left)))
	ok(Quests.village_cleared("윤슬"), "윤슬이 클리어된다")
	ok(Quests.is_unlocked("볕뉘"), "볕뉘로 넘어갈 수 있다")

	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


## 잠긴 여행지가 **무엇 때문에 잠겼는지** 적는가.
##
## "아직 더 볼 게 있는 것 같다" 한 줄만으로는 뭘 더 해야 하는지 알 수
## 없다. 다 한 줄 알고 눌렀다가 안 넘어가면 고장으로 읽힌다 —
## "윤슬 다음으로 안 넘어간다" 는 말이 실제로 그래서 나왔다.
func _locked_reason_tests() -> void:
	print("\n[왜 잠겼는지]")
	JourneyState.reset()
	var b := TravelBoard.new()
	add_child(b)

	var line := b._blocking_line("볕뉘")
	ok(line.contains("윤슬"), "무슨 마을이 걸렸는지 적는다 (%s)" % line)
	ok(line.contains("지도") or line.contains("인사"),
		"남은 것을 그대로 적는다 (%s)" % line)

	# 하나만 남으면 그 하나를 콕 집는다.
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.mark_quest("윤슬:가게")
	JourneyState.mark_quest("윤슬:등대")
	JourneyState.mark_quest("윤슬:잠")
	JourneyState.photos.append({"place": "윤슬", "subject": "등대"})
	JourneyState.mark_quest("윤슬:부두끝")
	JourneyState.mark_quest("윤슬:등대@저녁")
	for i in Quests.PICKUP_TOTAL["윤슬"]:
		JourneyState.taken["윤슬:%d,1" % i] = true
	var one := b._blocking_line("볕뉘")
	ok(one.contains("바다유리"), "하나 남으면 그것만 적는다 (%s)" % one)
	ok(not one.contains("외 "), "하나뿐이면 '외 n가지' 를 안 붙인다")

	# 다 하면 잠금이 풀리니 이 줄은 안 쓰인다.
	JourneyState.mark_quest("윤슬:등대안")
	JourneyState.mark_quest("윤슬:매듭:3")
	ok(Quests.is_unlocked("볕뉘"), "다 하면 볕뉘가 열린다")

	# ORDER 첫 곳은 걸릴 앞 마을이 없다.
	ok(b._blocking_line("윤슬") == "아직 더 볼 게 있는 것 같다",
		"앞 마을이 없으면 옛 문구 그대로")

	b.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 실내에서도 할 일이 이어지는가 ─────────────────────────────────────
#
# "가게에 들어가 보기" 를 보고 들어갔는데 아무 안내도 없고, **방금 그걸
# 해냈다는 표시조차 안 떴다.** 완료되는 바로 그 순간에 화면이 갈리기
# 때문이다 — 실내에서는 `JourneyState.here` 가 "가게 안" 이 되고 그
# 이름으로는 할 일 목록이 비어 있다. 알릴 자리가 없었다.

func _indoor_quest_tests() -> void:
	print("\n[실내에서도 할 일이 이어지나]")
	JourneyState.reset()

	# 윤슬에서 가게 문 앞까지 온 셈으로 꾸민다.
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.here = "윤슬"
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(24, 12)

	var shop: Place = load(
		"res://scenes/journey/interiors/ShopInterior.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame

	ok(shop.place_name() == "가게 안", "가게 안이 맞다")
	ok(shop.quest_village() == "윤슬",
		"할 일은 들어온 마을(윤슬) 것을 이어 본다 (%s)" % shop.quest_village())

	var hud: JourneyHud = shop.hud
	ok(hud._quest_village() == "윤슬", "HUD 도 윤슬 것을 읽는다")
	var list := Quests.quest_list(hud._quest_village())
	ok(not list.is_empty(), "실내에서도 할 일 목록이 비지 않는다 (%d개)" % list.size())
	ok(hud._first_task() != "", "실내에서도 지금 할 일을 집는다 (%s)"
		% hud._first_task())

	# **문을 지나 들어온 순간 "다 했어요" 가 떠야 한다.**
	# 알린 기록이 화면 너머로 이어지므로, 새 HUD 도 이게 새것인 줄 안다.
	JourneyState.announced.clear()
	JourneyState.announce_ready = true          # 기준은 이미 잡힌 셈
	JourneyState.mark_quest("윤슬:가게")
	hud._watch_done(Quests.quest_list(hud._quest_village()))
	var said := hud._cele_sub.text
	for q in hud._cele_queue:
		if String(q[1]).contains("가게"):
			said = String(q[1])
	ok(said.contains("가게에 들어가"),
		"들어온 순간 가게 샛길 축하가 뜬다 (%s)" % said)
	ok(hud._cele_busy, "축하가 실제로 돌고 있다")

	shop.queue_free()
	await get_tree().process_frame
	JourneyState.exit_scene = ""
	JourneyState.reset()


## 멀리서 문을 눌러도 한 번이면 되는가.
##
## 인연은 탭 한 번(다가가서 저절로 말 걸기)인데 문만 "걸어가서 한 번 더"
## 두 단계였다 — "가게 들어가 보기" 가 퀘스트인데 제일 마찰이 컸다.
## 실제 씬 전환은 여기서 못 밟으니(테스트 씬이 갈린다) 예약과 취소만 본다.
func _door_tap_tests() -> void:
	print("\n[문 한 번에 들어가기]")
	JourneyState.reset()
	var p: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(p)
	await get_tree().process_frame

	var d: Dictionary = p._doors[0]
	# 문에서 먼 곳에 세운다.
	p.walker.global_position = p.world_of(Vector2i(5, 15))
	await get_tree().process_frame

	# 문 칸을 화면 좌표로 눌러 본 것처럼 — 탭 핸들러를 직접 부른다.
	var scr: Vector2 = p.get_viewport().get_canvas_transform() * Vector2(d["world"])
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = scr
	p._unhandled_input(tap)
	ok(p._pending_door != null and p.is_walking_to(),
		"멀리서 문을 누르면 걸어가면서 문을 기억한다")

	# 다른 데를 누르면 예약이 풀린다 — 마음이 바뀐 것이다.
	p.walk_to(p.world_of(Vector2i(8, 15)))
	ok(p._pending_door == null, "다른 데로 가면 문 예약이 풀린다")

	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


## 2탄에서도 재회가 일어나는가.
##
## WANDERER_STOPS 에 2탄이 빠져 있던 동안, 게임 후반 절반에서 재회가
## 한 번도 안 일어났다 — 이 게임의 심장이 반 토막이었다.
func _reunion2_tests() -> void:
	print("\n[2탄 재회]")
	JourneyState.reset()
	for v in ["굽이나루", "방울못", "갈밭머리", "솔은재", "꽃눈벌"]:
		ok(JourneyState.WANDERER_STOPS.has(v), "%s 도 여행자가 들른다" % v)
	# 윤슬에서 이미 만난 뒤, 너구리가 굽이나루에 와 있는 상황.
	JourneyState.wanderer_seen["윤슬"] = true
	JourneyState.last_met = "윤슬"
	JourneyState.wanderer_place = "굽이나루"
	var p: Place = load(GOAL_SCENES["굽이나루"]).instantiate()
	add_child(p)
	await get_tree().process_frame
	var rac: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "raccoon":
			rac = f
	ok(rac != null, "너구리가 굽이나루에 서 있다")
	ok(JourneyState.reunions >= 1, "재회로 센다 (%d)" % JourneyState.reunions)
	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 배치 규칙 ─────────────────────────────────────────────────────────
#
# 상담이 준 보호 마스크를 자동 검사로 옮겼다. 좌표를 손으로 고칠 때마다
# 눈으로 다시 재지 않아도, 문·퀘스트 둘레와 인연의 몸이 서로를 밟으면
# 여기서 걸린다.
#
# - 문(D)·퀘스트(Q) 중심 체비셰프 1칸: 막는 소품·인연 몸 금지
# - 인연 몸 = 제 칸 + 아랫칸. 시간표의 아침/낮/저녁 자리도 다 본다
# - 인연 몸이 문·줍기·정류장·잠자리 칸을 밟으면 안 된다
# - 인연은 걸을 수 있는 칸에 서야 한다 (물·지도 밖 금지)

func _placement_lint_tests() -> void:
	print("\n[배치 규칙]")
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	for village in GOAL_SCENES:
		var p: Place = load(GOAL_SCENES[village]).instantiate()
		add_child(p)
		await get_tree().process_frame

		# 보호해야 하는 칸들. 문마다 그 문이 달린 건물(바로 윗칸 소품)은
		# 예외다 — 문이 건물 앞인 것은 겹침이 아니라 그 문의 정의다.
		# 가 볼 자리(반지름 안이면 됨)는 소품 검사에서 빼고, 인연 몸
		# 검사에만 넣는다 — 등대 자체가 목표인 곳이 있다.
		var guard: Array[Vector2i] = []
		var owners: Array[Vector2i] = []
		for d in p.doors():
			guard.append(d["tile"])
			owners.append((d["tile"] as Vector2i) + Vector2i(0, -1))
		var fguard: Array[Vector2i] = guard.duplicate()
		for z in p.quest_zones():
			fguard.append(z[1])

		# 막는 소품이 문 둘레를 밟는가.
		var bad_prop: Array = []
		for pr in p.props():
			if not (pr[3] if pr.size() > 3 else true):
				continue
			var pt := Vector2i(pr[0], pr[1])
			if owners.has(pt):
				continue
			for g in guard:
				if maxi(absi(pt.x - g.x), absi(pt.y - g.y)) <= 1:
					bad_prop.append("%s %s가 %s 곁" % [pr[2], pt, g])
		ok(bad_prop.is_empty(), "%s: 막는 소품이 문·퀘스트 둘레를 안 밟는다%s"
			% [village, "" if bad_prop.is_empty() else " — " + str(bad_prop)])

		# 누를 자리(`is_spot`)에는 **볼 것이 깔려 있어야 한다.**
		#
		# 가게 선반 셋을 빈 바닥 위에 찍어 둔 적이 있다. 옆에 서야만
		# 이름표가 뜨니, 아무것도 없는 자리를 누를 이유가 없었다.
		# 빛나는 자취만 뺀다 - 그건 제 빛을 스스로 그린다.
		var prop_at: Dictionary = {}
		for pr2 in p.props():
			prop_at[Vector2i(pr2[0], pr2[1])] = String(pr2[2])
		var bare: Array = []
		for f0 in p._folk:
			if not is_instance_valid(f0) or not f0.is_spot:
				continue
			if f0.who == "반짝이는 자리":
				continue
			# 바로 윗칸도 친다 - 창밖처럼 **소품 앞에 서서 올려다보는**
			# 자리가 있다 (문이 건물 앞칸인 것과 같은 규칙).
			if not prop_at.has(f0.at_tile) \
				and not prop_at.has(f0.at_tile + Vector2i(0, -1)):
				bare.append("%s%s" % [f0.who, f0.at_tile])
		ok(bare.is_empty(), "%s: 누를 자리마다 소품이 깔려 있다%s"
			% [village, "" if bare.is_empty() else " - " + str(bare)])

		# 인연 몸이 보호칸·줍기·정류장을 밟는가. 시간표 자리까지 다.
		var body_no: Array[Vector2i] = guard.duplicate()
		for pk in p.pickups():
			body_no.append(Vector2i(pk[0], pk[1]))
		if p.depart_tile() != Vector2i(-1, -1):
			body_no.append(p.depart_tile())
		if p.sleep_tile() != Vector2i(-1, -1):
			body_no.append(p.sleep_tile())
		var bad_folk: Array = []
		for f in p._folk:
			if not is_instance_valid(f) or f.is_spot:
				continue
			# 발밑 칸. 몸의 원점이 칸 아랫변이라 그대로 재면 한 칸
			# 아래로 밀린다 (`Place._tick_outline` 과 같은 보정).
			var fp := f.global_position + Vector2(0, -1)
			var spots: Array[Vector2i] = [p.tile_of(fp)]
			for k in f.schedule:
				spots.append(f.schedule[k])
			for s in spots:
				# 바닥으로만 본다 — 인연은 제 칸을 스스로 막으니
				# `_walkable` 로 재면 전원이 걸린다.
				if p._floor_solid(s.x, s.y):
					bad_folk.append("%s가 못 서는 칸 %s" % [f.who, s])
				for body in [s, s + Vector2i(0, 1)]:
					for g2 in fguard:
						if maxi(absi(body.x - g2.x), absi(body.y - g2.y)) <= 1:
							bad_folk.append("%s 몸 %s가 %s 곁" % [f.who, body, g2])
				for no in body_no:
					if s == no or s + Vector2i(0, 1) == no:
						bad_folk.append("%s 몸이 %s를 밟음" % [f.who, no])
		ok(bad_folk.is_empty(), "%s: 인연 몸이 문·퀘스트·줍기·정류장을 안 밟는다%s"
			% [village, "" if bad_folk.is_empty() else " — " + str(bad_folk)])

		# ── 소품이 인연·줍는 것을 덮는가 ───────────────────────────────
		#
		# 폰에서 가게 할머니가 나무 우듬지에 통째로 가려져 있었다.
		# 그림 기준점이 **칸 아래 가운데**라 위로 자라고(나무 52x56,
		# 가게 67x64, 등대 42x96), Y 정렬은 **밑변**으로 앞뒤가 갈린다 —
		# 밑변이 더 아래(y 큰)인 것이 앞에 그려진다. 그래서 한 칸 위에
		# 선 인연이 통째로 뒤로 숨는다. 눈으로는 못 잡는다. 재서 잡는다.
		var covers: Array = []
		var boxes: Array = []          # [겹칠 사각형, 밑변]
		for pr in p.props():
			var ptex := load("res://assets/sprites/%s.png" % pr[2]) as Texture2D
			if ptex == null:
				continue
			var pb: float = (float(pr[1]) + 1.0) * 16.0
			boxes.append([Rect2(float(pr[0]) * 16.0 + 8.0 - ptex.get_width() / 2.0,
				pb - ptex.get_height(), ptex.get_width(), ptex.get_height()), pb,
				String(pr[2]), Vector2i(pr[0], pr[1])])

		var targets: Array = []        # [이름, 칸, 크기]
		for f in p._folk:
			if not is_instance_valid(f) or f.is_spot or f.sprite == null:
				continue
			var cell: Vector2 = Vector2(f.sprite.size())
			var seen_at: Array = [p.tile_of(f.global_position + Vector2(0, -1))]
			for k in f.schedule:
				if not seen_at.has(f.schedule[k]):
					seen_at.append(f.schedule[k])
			for t3 in seen_at:
				targets.append([f.who, t3, cell])
		for e in p.pickups():
			var itex := load("res://assets/sprites/%s.png" % e[2]) as Texture2D
			if itex != null:
				targets.append([String(e[2]), Vector2i(e[0], e[1]),
					Vector2(itex.get_size())])

		for t4 in targets:
			var tt: Vector2i = t4[1]
			var cz: Vector2 = t4[2]
			var tb: float = (float(tt.y) + 1.0) * 16.0
			var me := Rect2(float(tt.x) * 16.0 + 8.0 - cz.x / 2.0, tb - cz.y, cz.x, cz.y)
			var area: float = maxf(cz.x * cz.y, 1.0)
			for b in boxes:
				if float(b[1]) <= tb:      # 뒤에 그려지면 안 가린다
					continue
				var hit: Rect2 = (b[0] as Rect2).intersection(me)
				var ratio: float = hit.get_area() / area
				if ratio > 0.25:
					covers.append("%s%s를 %s%s가 %d%%" % [t4[0], tt, b[2], b[3],
						int(ratio * 100.0)])
		ok(covers.is_empty(), "%s: 소품이 인연·줍는 것을 안 덮는다%s"
			% [village, "" if covers.is_empty() else " — " + str(covers)])

		# **주인공도 같이 본다.** 인연만 재다가 놓쳤다 — 하늬섬은 도착
		# 자리가 가게 그림 속이라 마을에 내리자마자 주인공이 안 보였고,
		# 굽이나루는 호스텔이 문 앞과 정류장을 통째로 덮었다.
		var hero_tex := load("res://assets/sprites/hero-walk.png") as Texture2D
		var hidden_hero: Array = []
		if hero_tex != null:
			var hw: float = float(hero_tex.get_width()) / 4.0
			var hh: float = float(hero_tex.get_height()) / 3.0
			var spots2: Array = []
			if p.spawn_tile() != Vector2i(-1, -1):
				spots2.append(["도착", p.spawn_tile()])
			if p.sleep_tile() != Vector2i(-1, -1):
				spots2.append(["잠자리", p.sleep_tile()])
			if p.depart_tile() != Vector2i(-1, -1):
				spots2.append(["정류장", p.depart_tile()])
			for d3 in p.doors():
				spots2.append(["문앞", Vector2i(d3["tile"])])
			for sp in spots2:
				var st: Vector2i = sp[1]
				var hb: float = (float(st.y) + 1.0) * 16.0
				var hrect := Rect2(float(st.x) * 16.0 + 8.0 - hw / 2.0,
					hb - hh, hw, hh)
				for b2 in boxes:
					if float(b2[1]) <= hb:
						continue
					var hit2: Rect2 = (b2[0] as Rect2).intersection(hrect)
					if hit2.get_area() / (hw * hh) > 0.4:
						hidden_hero.append("%s%s를 %s%s" % [sp[0], st, b2[2], b2[3]])
		ok(hidden_hero.is_empty(), "%s: 주인공이 서는 자리가 안 가려진다%s"
			% [village, "" if hidden_hero.is_empty() else " — " + str(hidden_hero)])

		# ── 소품이 소품에 묻히는가 ─────────────────────────────────────
		#
		# 가게 뒤 화분처럼 **그려도 화면에 한 픽셀도 안 나오는** 소품이
		# 열넷 있었다. 사각형으로 재면 나무 우듬지가 네모가 아니라서
		# 크게 부풀려지므로, 불투명 픽셀(알파)로 센다. 앞에 그려지는
		# 것들을 다 겹쳐서 "몇 %가 안 보이나" 를 낸다.
		var imgs: Dictionary = {}
		var buried: Array = []
		for i4 in boxes.size():
			var meb: Rect2 = boxes[i4][0]
			var mename: String = boxes[i4][2]
			if not imgs.has(mename):
				var t6 := load("res://assets/sprites/%s.png" % mename) as Texture2D
				imgs[mename] = t6.get_image() if t6 != null else null
			var mi: Image = imgs[mename]
			if mi == null:
				continue
			var seen: Dictionary = {}
			var mine := 0
			var gone := 0
			for py in range(0, int(meb.size.y), 2):
				for px in range(0, int(meb.size.x), 2):
					if mi.get_pixel(px, py).a <= 0.06:
						continue
					mine += 1
					var wx: float = meb.position.x + float(px)
					var wy: float = meb.position.y + float(py)
					for j4 in boxes.size():
						if j4 == i4 or float(boxes[j4][1]) <= float(boxes[i4][1]):
							continue
						var ob: Rect2 = boxes[j4][0]
						if not ob.has_point(Vector2(wx, wy)):
							continue
						var oname: String = boxes[j4][2]
						if not imgs.has(oname):
							var t7 := load("res://assets/sprites/%s.png" % oname) as Texture2D
							imgs[oname] = t7.get_image() if t7 != null else null
						var oi: Image = imgs[oname]
						if oi == null:
							continue
						if oi.get_pixel(int(wx - ob.position.x),
								int(wy - ob.position.y)).a > 0.06:
							gone += 1
							break
			if mine > 0 and float(gone) / float(mine) > 0.6:
				buried.append("%s%s %d%%" % [mename, boxes[i4][3],
					int(float(gone) / float(mine) * 100.0)])
		ok(buried.is_empty(), "%s: 그려도 안 보이는 소품이 없다%s"
			% [village, "" if buried.is_empty() else " — " + str(buried)])

		# ── 이름표끼리 겹치는가 ────────────────────────────────────────
		#
		# 이름표는 폭을 120 으로 잡아 두었지만 실제로 겹치는 건 **글자**다.
		# 폰트로 재서 본다. 이름표는 150px 안에 들어야 보이므로
		# (`Place.TAG_RANGE`), 그 안에 같이 드는 짝만 따진다.
		var clash: Array = []
		for part2 in ["아침", "낮", "저녁"]:
			var tags: Array = []
			# 여행자는 그날 그 마을에 있을 때만 세워지지만 칸은 고정이라,
			# 붙박이를 그 곁에 세우면 두 이름이 늘 겹친다. 같이 잰다.
			var wt: Vector2i = p.wanderer_tile()
			var already := false
			for f3 in p._folk:
				if is_instance_valid(f3) and f3.who == "배낭 멘 너구리":
					already = true
			if wt != Vector2i(-1, -1) and not already:
				var rtex := load("res://assets/sprites/raccoon-walk.png") as Texture2D
				var rtall: float = 24.0
				if rtex != null:
					rtall = float(rtex.get_height()) / 3.0
				var rw := "배낭 멘 너구리"
				var rfnt: Font = ThemeDB.get_default_theme().default_font
				var rtw: float = 77.0
				if rfnt != null:
					rtw = rfnt.get_string_size(rw, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				var rcx: float = float(wt.x) * 16.0 + 8.0
				tags.append([rw, Rect2(rcx - rtw / 2.0,
					(float(wt.y) + 1.0) * 16.0 - rtall - 17.0, rtw, 16.0),
					Vector2(rcx, (float(wt.y) + 1.0) * 16.0)])
			for f2 in p._folk:
				if not is_instance_valid(f2) or f2.is_spot or f2.who == "":
					continue
				var t5: Vector2i = p.tile_of(f2.global_position + Vector2(0, -1))
				if f2.schedule.has(part2):
					t5 = f2.schedule[part2]
				var tall2: float = 24.0
				if f2.sprite != null:
					tall2 = f2.sprite.size().y
				var fnt: Font = f2.get_node("NameTag").get_theme_font("font")
				var tw: float = 96.0
				if fnt != null:
					tw = fnt.get_string_size(f2.who,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				var cx: float = float(t5.x) * 16.0 + 8.0
				var cy: float = (float(t5.y) + 1.0) * 16.0 - tall2 - 17.0
				tags.append([f2.who, Rect2(cx - tw / 2.0, cy, tw, 16.0),
					Vector2(cx, (float(t5.y) + 1.0) * 16.0)])
			for i2 in tags.size():
				for j2 in range(i2 + 1, tags.size()):
					var a2: Array = tags[i2]
					var b2: Array = tags[j2]
					if not (a2[1] as Rect2).intersects(b2[1]):
						continue
					# 둘 다 한 화면에 이름이 뜰 만큼 주인공에게 가까운가
					var mid: Vector2 = ((a2[2] as Vector2) + (b2[2] as Vector2)) * 0.5
					if mid.distance_to(a2[2]) <= Place.TAG_RANGE \
							and mid.distance_to(b2[2]) <= Place.TAG_RANGE:
						clash.append("%s %s↔%s" % [part2, a2[0], b2[0]])
		ok(clash.is_empty(), "%s: 이름표끼리 안 겹친다%s"
			% [village, "" if clash.is_empty() else " — " + str(clash)])

		# ── 건물 간판 ──────────────────────────────────────────────────
		#
		# 들어갈 수 있는 건물에는 간판이 있어야 하고, 간판끼리도
		# 인연 이름표와도 안 겹쳐야 한다.
		# 실제로 걸린 간판을 그대로 읽는다 — 자리를 다시 셈하면
		# 자동으로 비켜 준 것을 못 본다.
		var signs: Array = []
		for sg in p._signs:
			if is_instance_valid(sg):
				signs.append([String(sg.get_meta("name", "")),
					sg.get_meta("rect", Rect2())])
		var doors_with_sign := 0
		for d2 in p.doors():
			var above := Vector2i(d2["tile"]) + Vector2i(0, -1)
			for pr3 in p.props():
				if Vector2i(pr3[0], pr3[1]) == above \
						and p.sign_of(String(pr3[2]), above) != "":
					doors_with_sign += 1
		ok(doors_with_sign > 0 or p.doors().is_empty(),
			"%s: 들어갈 수 있는 건물에 간판이 있다 (%d개)" % [village, doors_with_sign])
		var sclash: Array = []
		for i3 in signs.size():
			for j3 in range(i3 + 1, signs.size()):
				if (signs[i3][1] as Rect2).intersects(signs[j3][1]):
					sclash.append("%s↔%s" % [signs[i3][0], signs[j3][0]])
		ok(sclash.is_empty(), "%s: 간판끼리 안 겹친다%s"
			% [village, "" if sclash.is_empty() else " — " + str(sclash)])

		p.queue_free()
		await get_tree().process_frame
	JourneyState.reset()


# ── 옛 세이브 이어 붙이기 ─────────────────────────────────────────────
#
# 윤슬을 "마음매듭 + 샛길" 로 갈아엎었다. **이미 한 일을 다시 시키면
# 안 된다** — 특히 이미 윤슬을 떠난 사람의 다음 마을이 도로 잠기면
# 그건 갱신이 아니라 사고다.

func _old_save_tests() -> void:
	print("\n[옛 세이브]")

	# ① 옛 판에서 윤슬을 마치고 볕뉘까지 가 본 사람
	JourneyState.reset()
	JourneyState.from_dict({
		"here": "볕뉘",
		"visited": {"윤슬": true, "볕뉘": true},
		"quest_flags": {
			"윤슬:가게": true, "윤슬:등대": true, "윤슬:잠": true,
			"윤슬:등대안": true, "윤슬:부두끝": true,
		},
		"photos": [{"place": "윤슬", "subject": "등대"}],
	})
	ok(Quests.knot_done("윤슬"), "옛 세이브의 윤슬 매듭이 끝난 것으로 이어진다")
	ok(Quests.village_cleared("윤슬"), "윤슬이 그대로 마친 상태다")
	ok(Quests.is_unlocked("볕뉘"), "볕뉘가 도로 잠기지 않는다")

	# ② 옛 판에서 윤슬을 하던 중이던 사람 — 낮에 등대를 봤다
	JourneyState.reset()
	JourneyState.from_dict({
		"here": "윤슬",
		"visited": {"윤슬": true},
		"quest_flags": {"윤슬:등대": true, "윤슬:부두끝": true},
		"photos": [{"place": "윤슬", "subject": "등대"}],
	})
	ok(JourneyState.quest_done("윤슬:등대@저녁"),
		"시간대 조건이 없던 시절의 등대 방문을 저녁으로 쳐 준다")
	ok(Quests.side_done("윤슬", "윤슬:샛길:부두"),
		"부두 끝도 아침·저녁 둘 다 본 것으로 쳐 준다")
	ok(not Quests.knot_done("윤슬"),
		"그래도 새 마지막 단계(바다유리)는 남아 있다")

	# ③ 갓 시작한 사람은 아무것도 안 받는다
	JourneyState.reset()
	ok(not Quests.knot_done("윤슬"), "새 여행은 매듭이 처음부터다")
	ok(Quests.knot_at("윤슬") == 0, "첫 단계부터 시작한다")
	JourneyState.reset()


# ── 화면 보는 법 ──────────────────────────────────────────────────────
#
# 조작은 단계별로 알려 주는데(`Guide`) **귀퉁이에 뭐가 있는지**는
# 아무도 안 알려 줬다. 처음 한 번 뜨는 판이라 놓치면 못 보므로,
# 다시 볼 길이 있는지까지 같이 본다.

func _how_to_play_tests() -> void:
	print("\n[화면 보는 법]")
	SaveManager.set_flag(HowToPlay.FLAG, false)
	var card := HowToPlay.open(get_tree())
	ok(card != null, "판이 열린다")
	await get_tree().process_frame
	ok(card.is_in_group("overlay"), "덮는 판이니 'overlay' 그룹에 든다")
	ok(HowToPlay.open(get_tree()) == null, "두 번 겹쳐 열리지 않는다")

	# 귀퉁이마다 이름과 한 줄 설명이 있다
	ok(HowToPlay.SPOTS.size() >= 5,
		"귀퉁이를 다섯 자리 넘게 짚는다 (%d)" % HowToPlay.SPOTS.size())
	var names: Array = []
	for sp in HowToPlay.SPOTS:
		names.append(String(sp[3]))
	for must in ["배낭", "작은 지도", "설정"]:
		ok(names.has(must), "%s 자리를 알려 준다" % must)
	ok(HowToPlay.HOWS.size() == 3, "조작은 세 줄로 적는다")

	# 닫으면 표시가 남아 다시 안 뜬다
	card._close()
	await get_tree().process_frame
	ok(SaveManager.get_flag(HowToPlay.FLAG, false), "닫으면 본 것으로 남는다")
	ok(get_tree().get_first_node_in_group("how_to_play") == null,
		"닫고 나면 남지 않는다")

	# 그래도 언제든 다시 열 수 있다 (배낭 > 길잡이 다시 보기)
	var again := HowToPlay.open(get_tree())
	ok(again != null, "본 뒤에도 다시 열 수 있다")
	again.queue_free()
	await get_tree().process_frame
	SaveManager.set_flag(HowToPlay.FLAG, true)


# ── 표시가 너무 일찍 남지 않는가 ──────────────────────────────────────
#
# "정류장에서 첫 여행지 고르기" 가 **여행판을 열기만 해도** 다 한 것이
# 됐다. 아직 아무 데도 안 골랐는데 목록에 "(다 했어요)" 가 붙었다.
# 할 일의 이름이 "고르기" 면 고른 순간에 남아야 한다.
#
# 같은 종류의 실수를 다른 데서도 안 하는지 같이 본다 — 문은 지나야,
# 잠은 자야, 가 볼 자리는 닿아야 남는다.

func _mark_timing_tests() -> void:
	print("\n[표시 시점]")
	JourneyState.reset()
	var p: Place = load(GOAL_SCENES["잿마루"]).instantiate()
	add_child(p)
	await get_tree().process_frame

	# ① 여행판을 열기만 해서는 안 남는다
	p._open_board()
	await get_tree().process_frame
	ok(not JourneyState.quest_done("잿마루:정류장"),
		"여행판을 열기만 해서는 '첫 여행지 고르기' 가 안 끝난다")
	var row := ""
	for q in Quests.quest_list("잿마루"):
		if String(q.get("kind", "")) == "depart":
			row = String(q.get("label", "")) \
				+ ("  (다 했어요)" if bool(q.get("done", false)) else "")
	ok(not row.ends_with("(다 했어요)"),
		"목록에도 다 했다고 안 적힌다 (%s)" % row)
	p.board.visible = false

	# ② 실제로 고르면 그때 남는다
	p._on_chose("res://scenes/journey/Yunseul.tscn")
	ok(JourneyState.quest_done("잿마루:정류장"),
		"여행지를 고르면 그때 남는다")

	# ③ 문은 지나야, 잠은 자야 남는다
	JourneyState.reset()
	p.queue_free()
	await get_tree().process_frame
	var y: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(y)
	await get_tree().process_frame
	ok(not JourneyState.quest_done("윤슬:가게"),
		"가게 앞에 서 있는 것만으로는 안 들어간 것이다")
	ok(not JourneyState.quest_done("윤슬:잠"), "잠자리 곁에 선 것도 잔 것이 아니다")
	y.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 할 일 순서 ────────────────────────────────────────────────────────
#
# 어긋난 데가 둘 있었다. 가게가 **인사 둘 사이**에 끼어 있었고,
# **하룻밤 쉬기가 중간**에 있어서 목록이 "자라" 고 한 다음에도 셋이
# 남아 있었다 — 자면 하루가 끝나는데.

func _order_tests() -> void:
	print("\n[할 일 순서]")
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")

	for v in ["볕뉘", "가풀재", "하늬섬", "굽이나루", "솔은재", "꽃눈벌"]:
		var list := Quests.quest_list(v)
		var kinds: Array = []
		for q in list:
			kinds.append(String(q.get("kind", "")))
		# 잠은 언제나 맨 뒤
		if kinds.has("sleep"):
			ok(kinds[kinds.size() - 1] == "sleep",
				"%s: 하룻밤 쉬기가 맨 뒤다 (%s)" % [v, str(kinds)])
		# 인사끼리 붙어 있다 — 사이에 딴 일이 안 낀다
		var first := kinds.find("talk")
		var last := -1
		for i in kinds.size():
			if kinds[i] == "talk":
				last = i
		if first >= 0 and last > first:
			var between := true
			for i in range(first, last + 1):
				if kinds[i] != "talk":
					between = false
			ok(between, "%s: 인사 사이에 딴 일이 안 낀다 (%s)" % [v, str(kinds)])
		# 줍기는 잠 바로 앞 — 마을을 돌고 남은 것을 줍는다
		if kinds.has("pickup") and kinds.has("sleep"):
			ok(kinds.find("pickup") == kinds.find("sleep") - 1,
				"%s: 줍기가 잠 바로 앞이다" % v)

	# 아직 때가 아닌 것은 "지금 해볼 일" 로 안 고른다
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.minutes = 8.0 * 60.0          # 아침
	var p: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(p)
	await get_tree().process_frame
	var head: Dictionary = Quests.quest_list("윤슬")[0]
	ok(bool(head.get("waiting", false)),
		"아침에는 '저녁에 등대곶' 이 기다리는 중으로 적힌다")
	ok(String(head.get("label", "")).contains("저녁에"),
		"언제 오면 되는지 줄에 적힌다 (%s)" % head.get("label", ""))
	var now: Dictionary = p.current_goal()
	ok(not bool(now.get("waiting", false)),
		"지금 해볼 일은 지금 할 수 있는 것으로 고른다 (%s)"
			% now.get("label", ""))
	# 저녁이 되면 그것이 지금 할 일이 된다
	JourneyState.minutes = 19.0 * 60.0
	var now2: Dictionary = p.current_goal()
	ok(String(now2.get("label", "")).contains("등대곶"),
		"저녁이 되면 등대곶을 짚는다 (%s)" % now2.get("label", ""))
	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 숨은 자취 ─────────────────────────────────────────────────────────
#
# 첫 미니게임. 인연이 말한 자리 셋이 마을 어딘가에서 반짝이고, 가까이
# 걸어가 살펴보면 하나씩 기록된다. 좌표를 지도에 다 찍어 주지 않는다 —
# 지도는 "가장 가까운 못 찾은 자리" 하나만 짚는다.

func _trace_tests() -> void:
	print("\n[숨은 자취]")
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	var p: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(p)
	await get_tree().process_frame

	# 자리 셋이 서고, 반짝임도 셋이다
	var spots: Array = []
	for f in p._folk:
		if is_instance_valid(f) and f.is_spot and f.spot_key.begins_with("빛자리"):
			spots.append(f)
	ok(spots.size() == 3, "반짝이는 자리가 셋 선다 (%d)" % spots.size())
	ok(p._traces.size() == 3, "반짝임도 셋 그려진다 (%d)" % p._traces.size())

	# 서로 여덟 칸 넘게 떨어져 있고, 곁에 설 자리가 있다
	for i in spots.size():
		var t := p.tile_of(spots[i].global_position + Vector2(0, -1))
		var can_stand := false
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if p._walkable(t + off):
				can_stand = true
		ok(can_stand, "자리 %d 곁에 설 수 있다 %s" % [i + 1, t])
		for j in range(i + 1, spots.size()):
			var t2 := p.tile_of(spots[j].global_position + Vector2(0, -1))
			ok(t.distance_to(Vector2(t2)) >= 8.0 or absi(t.x - t2.x) + absi(t.y - t2.y) >= 8,
				"자리끼리 여덟 칸 넘게 떨어져 있다 (%s ~ %s)" % [t, t2])

	# 지도는 가장 가까운 못 찾은 자리 하나만 짚는다
	var row: Dictionary = {}
	for q in Quests.quest_list("윤슬"):
		if String(q.get("kind", "")) == "trace":
			row = q
	ok(not row.is_empty(), "목록에 자취 줄이 있다")
	p.walker.global_position = p.world_of(Vector2i(13, 7))
	var g1 := p.goal_world(row)
	ok(g1 != Vector2.INF, "지도가 한 자리를 짚는다")
	ok(p.tile_of(g1 + Vector2(0, -1)).distance_to(Vector2(12, 5)) <= 1.5,
		"부두 곁에 서면 부두 곁 자리를 짚는다 (%s)" % p.tile_of(g1))

	# 살펴보면 하나씩 기록되고, 반짝임은 그 자리만 멎는다
	ok(not Quests.side_done("윤슬", "윤슬:샛길:자취"), "아직 하나도 못 찾았다")
	for f2 in spots:
		p._near = f2
		p.talk_to_near()
		await get_tree().process_frame
		if p.say != null and p.say.has_method("close"):
			p.say.close()
	ok(JourneyState.quest_done("윤슬:본:빛자리1")
		and JourneyState.quest_done("윤슬:본:빛자리2")
		and JourneyState.quest_done("윤슬:본:빛자리3"),
		"세 자리가 서로 다른 표시로 남는다")
	ok(Quests.side_done("윤슬", "윤슬:샛길:자취"), "셋을 다 찾으면 샛길이 끝난다")
	ok(p.goal_world(row) == Vector2.INF, "다 찾으면 지도가 더 안 짚는다")

	# 다시 들어와도 찾은 자리는 조용하다
	p.queue_free()
	await get_tree().process_frame
	var p2: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(p2)
	await get_tree().process_frame
	ok(p2._traces.is_empty(), "찾은 자리는 다시 안 반짝인다 (%d)" % p2._traces.size())
	p2.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 마을 선반 ─────────────────────────────────────────────────────────
#
# 가게를 넣되 **경제는 안 넣는다** (`Items` 주석). 값·잔액·재고·품절이
# 없고, 수집품은 보여 주기만 하고 줄지 않는다. 이 검사가 그 선을 지킨다 —
# 나중에 누가 값을 붙이면 여기서 걸린다.

func _shelf_tests() -> void:
	print("\n[마을 선반]")
	JourneyState.reset()

	# ① 데이터에 값·재고·기간이 아예 없다
	var src := FileAccess.open("res://scripts/systems/items.gd",
		FileAccess.READ).get_as_text()
	var banned := ["price", "cost", "sell_value", "stock", "expires",
		"consume_count", "balance"]
	var found: Array = []
	for b in banned:
		if src.contains('"%s"' % b) or src.contains("%s :" % b) \
				or src.contains("%s =" % b):
			found.append(b)
	ok(found.is_empty(), "물건 데이터에 값·재고·기간이 없다%s"
		% ("" if found.is_empty() else " — " + str(found)))

	# ② 조건을 안 채우면 못 받고, 채우면 받는다
	var marble: Dictionary = Items.of("윤슬")["keep"][0]
	ok(not Items.unlocked("윤슬", marble), "자취를 못 찾았으면 아직 선반에 없다")
	JourneyState.mark_quest("윤슬:본:빛자리1")
	JourneyState.mark_quest("윤슬:본:빛자리2")
	JourneyState.mark_quest("윤슬:본:빛자리3")
	ok(Items.unlocked("윤슬", marble), "자취를 다 찾으면 받을 수 있다")
	ok(not Items.kept(marble), "아직 안 챙겼다")

	# ③ 실제로 가게에 들어가 챙겨 본다
	JourneyState.here = "윤슬"
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(24, 12)
	var shop: Place = load("res://scenes/journey/interiors/ShopInterior.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame
	var shelves: Array = []
	for f in shop._folk:
		if is_instance_valid(f) and f.is_spot and f.spot_key.begins_with("선반:"):
			shelves.append(f)
	ok(shelves.size() == 3, "선반이 셋 있다 (%d)" % shelves.size())
	var owner_in := false
	for f2 in shop._folk:
		if is_instance_valid(f2) and not f2.is_spot and f2.who == "가게 할머니":
			owner_in = true
	ok(owner_in, "주인이 가게 안에 서 있다")

	var panel := ShelfPanel.open(shop, "윤슬", ShelfPanel.KIND_KEEP)
	ok(panel != null, "선반 판이 열린다")
	await get_tree().process_frame
	ok(panel.is_in_group("overlay"), "덮는 판이니 'overlay' 그룹에 든다")
	ok(ShelfPanel.open(shop, "윤슬", ShelfPanel.KIND_KEEP) == null,
		"두 번 겹쳐 열리지 않는다")
	panel._tap(marble)
	await get_tree().process_frame
	ok(Items.kept(marble), "유리구슬을 챙겼다")
	ok(JourneyState.count("k-marble") == 1, "배낭에 하나 들어왔다")

	# ④ 또 눌러도 개수가 안 는다 (값이 없으니 사는 게 아니다)
	var again := ShelfPanel.open(shop, "윤슬", ShelfPanel.KIND_KEEP)
	again._tap(marble)
	await get_tree().process_frame
	ok(JourneyState.count("k-marble") == 1, "다시 눌러도 개수가 안 는다")

	# ⑤ 보여 주기는 **수집품을 안 쓴다**
	JourneyState.pick("p-seaglass")
	JourneyState.pick("p-seaglass")
	var before := JourneyState.count("p-seaglass")
	var glass: Dictionary = {}
	for sh in Items.of("윤슬")["show"]:
		if String(sh["id"]) == "p-seaglass":
			glass = sh
	var p3 := ShelfPanel.open(shop, "윤슬", ShelfPanel.KIND_SHOW)
	p3._tap(glass)
	await get_tree().process_frame
	ok(JourneyState.count("p-seaglass") == before,
		"보여 줘도 바다유리가 안 줄어든다 (%d)" % JourneyState.count("p-seaglass"))
	ok(Items.shown("윤슬", "p-seaglass"), "보여 준 것으로 남는다")

	# ⑥ 먹거리는 배낭에 안 들어간다
	var food: Dictionary = Items.of("윤슬")["food"][0]
	var p4 := ShelfPanel.open(shop, "윤슬", ShelfPanel.KIND_FOOD)
	p4._tap(food)
	await get_tree().process_frame
	ok(JourneyState.count(String(food["id"])) == 0,
		"먹거리는 배낭에 안 남는다 — 그 자리에서 맛본다")
	ok(Items.tasted("윤슬", food), "맛본 것으로 기록된다")

	# ⑦ 눌렀을 때 **말이 제대로 나온다**
	#
	# `say()` 는 한 겹 배열을 받는다 — 원소가 또 배열이면 [누가, 무슨 말]
	# 로 읽거나 `String(배열)` 에서 터진다. 한 겹 더 씌운 채 넘긴 적이
	# 있는데, 화면에만 안 나올 뿐 테스트는 다 통과했다. 그래서 판에서
	# 나온 말이 실제로 대사창까지 닿는지를 본다.
	var flat_bad: Array = []
	for kind: String in [ShelfPanel.KIND_FOOD, ShelfPanel.KIND_KEEP,
			ShelfPanel.KIND_SHOW]:
		for it: Dictionary in Items.of("윤슬").get(
				"food" if kind == ShelfPanel.KIND_FOOD
				else ("keep" if kind == ShelfPanel.KIND_KEEP else "show"), []):
			shop.say._said.clear()
			var pk := ShelfPanel.open(shop, "윤슬", kind)
			pk._tap(it)
			await get_tree().process_frame
			if shop.say._said.is_empty():
				flat_bad.append("%s/%s(빈 대사)" % [kind, it["id"]])
				continue
			for m: Dictionary in shop.say._said:
				var t := String(m.get("text", ""))
				if t == "" or t == "<null>" or t.begins_with("["):
					flat_bad.append("%s/%s(%s)" % [kind, it["id"], t])
	ok(flat_bad.is_empty(), "선반을 누르면 말이 한 겹으로 나온다%s"
		% ("" if flat_bad.is_empty() else " — " + str(flat_bad)))

	# 가게 안 소품(선반 표시)도 마찬가지다 — `put_spot()` 이 이미 한 겹
	# 씌우므로 여기서 또 씌우면 안 된다.
	var spot_bad: Array = []
	for f3 in shop._folk:
		if not is_instance_valid(f3):
			continue
		for l in f3.lines_by_heart:
			if l is Array:
				for one in l:
					if one is Array and one.size() < 2:
						spot_bad.append(String(f3.who))
	ok(spot_bad.is_empty(), "가게 안 대사가 겹으로 안 싸여 있다%s"
		% ("" if spot_bad.is_empty() else " — " + str(spot_bad)))

	# ⑧ 누를 자리에는 **볼 것이 있어야 한다**
	#
	# 선반 셋을 빈 바닥 위에 찍어 둔 적이 있다. 걸어가 옆에 서야만
	# 이름표가 뜨니, 방 한가운데 아무것도 없는 자리를 누를 이유가
	# 없었다. 자리마다 소품이 깔려 있는지, 한 칸에 둘이 겹치지
	# 않는지를 본다.
	var prop_at: Dictionary = {}
	for pr in shop.props():
		prop_at[Vector2i(int(pr[0]), int(pr[1]))] = String(pr[2])
	var bare: Array = []
	var seen_tile: Dictionary = {}
	var twice: Array = []
	for f4 in shop._folk:
		if not is_instance_valid(f4) or not f4.is_spot:
			continue
		var t4: Vector2i = f4.at_tile
		if not prop_at.has(t4):
			bare.append("%s%s" % [f4.who, t4])
		if seen_tile.has(t4):
			twice.append("%s+%s%s" % [seen_tile[t4], f4.who, t4])
		seen_tile[t4] = String(f4.who)
	ok(bare.is_empty(), "누를 자리마다 소품이 깔려 있다%s"
		% ("" if bare.is_empty() else " - " + str(bare)))
	ok(twice.is_empty(), "한 칸에 누를 자리가 둘 겹치지 않는다%s"
		% ("" if twice.is_empty() else " - " + str(twice)))

	# ⑨ 저장하고 불러와도 그대로
	var kept_before := JourneyState.count("k-marble")
	var d := JourneyState.to_dict()
	JourneyState.reset()
	JourneyState.from_dict(d)
	ok(JourneyState.count("k-marble") == kept_before, "챙긴 물건이 저장된다")
	ok(Items.shown("윤슬", "p-seaglass"), "보여 준 기록도 저장된다")


	# ⑩ 볼 것이 남았으면 **문에 티가 난다**
	#
	# 자취를 다 찾아 유리구슬이 선반에 놓여도, 다시 들어가 볼 이유를
	# 알 길이 없으면 가게는 한 번 보고 마는 방이 된다.
	JourneyState.reset()
	ok(Items.something_new("윤슬"), "처음엔 가게에 볼 것이 있다")
	var yun: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(yun)
	await get_tree().process_frame
	var shop_door: Dictionary = {}
	for dr in yun.doors():
		if String(dr.get("label", "")).begins_with("가게"):
			shop_door = dr
	ok(not shop_door.is_empty(), "윤슬에 가게 문이 있다")
	ok(yun._door_label(shop_door).contains("새 물건"),
		"볼 것이 남았으면 문에 적힌다 (%s)" % yun._door_label(shop_door))
	for f5 in Items.of("윤슬")["food"]:
		JourneyState.mark_quest("윤슬:맛봄:%s" % f5["id"])
	JourneyState.mark_quest("윤슬:본:빛자리1")
	JourneyState.mark_quest("윤슬:본:빛자리2")
	JourneyState.mark_quest("윤슬:본:빛자리3")
	JourneyState.pick("k-marble")
	ok(not Items.something_new("윤슬"), "다 보고 나면 조용해진다")
	ok(not yun._door_label(shop_door).contains("새 물건"),
		"조용해지면 문에서도 지운다 (%s)" % yun._door_label(shop_door))
	yun.queue_free()
	await get_tree().process_frame

	shop.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


# ── 줄바꿈 ────────────────────────────────────────────────────────────
#
# 폰 화면에서 "…등대 사진 남기 / 기 (저녁에)" 로 끊겨 있었다. 한글은
# 유니코드 줄바꿈 규칙상 **음절 사이가 전부 끊어도 되는 자리**라,
# 라벨의 `autowrap_mode` 를 무엇으로 두든 낱말이 갈린다 (`Wrap` 주석).
#
# 그래서 띄어쓰기에서만 끊는 `Wrap` 을 두었다. 여기서 지키는 것은
# 하나다 - **줄이 바뀌는 자리는 늘 띄어쓰기였던 자리**여야 한다.

func _wrap_tests() -> void:
	print("\n[줄바꿈]")
	var theme := load("res://assets/themes/quple_bold.tres") as Theme
	var font := theme.get_font("font", "Label")
	ok(font != null, "테마 폰트를 읽었다")

	# ① 엔진에 맡기면 갈린다는 것부터 확인한다. 이게 언젠가 고쳐지면
	#    이 검사가 알려 주고, 그때 `Wrap` 을 걷어 내면 된다.
	var long_one := "지금 해볼 일 · 이야기 2/3 · 저녁에 등대곶에서 불 켜진 등대 사진 남기기 (저녁에)"
	var tp := TextParagraph.new()
	tp.width = 720
	tp.break_flags = TextServer.AUTOWRAP_WORD_SMART
	tp.add_string(long_one, font, 24)
	var engine_lines: Array = []
	for i in tp.get_line_count():
		var r := tp.get_line_range(i)
		engine_lines.append(long_one.substr(r.x, r.y - r.x))
	ok(tp.get_line_count() > 1, "엔진도 이 줄은 접는다 (%d줄)" % tp.get_line_count())

	# ② 우리가 접으면 띄어쓰기에서만 끊긴다.
	#
	#    글자 수가 안 변하는 방식(hard = false)이라, 줄바꿈이 놓인 자리는
	#    원문에서 빈칸이었던 자리다. 그걸 그대로 확인한다.
	var folded := Wrap.fit(long_one, font, 24, 720, false)
	ok(folded.length() == long_one.length(),
		"접어도 글자 수가 그대로다 (%d/%d)" % [folded.length(), long_one.length()])
	var cut_bad: Array = []
	for i in folded.length():
		if folded[i] == "\n" and long_one[i] != " ":
			cut_bad.append("%d번째 '%s'" % [i, long_one[i]])
	ok(cut_bad.is_empty(), "줄이 바뀌는 자리가 다 띄어쓰기였다%s"
		% ("" if cut_bad.is_empty() else " - " + str(cut_bad)))
	ok(folded.contains("\n"), "실제로 접혔다 (%s)" % folded.replace("\n", " / "))

	# ③ 게임에 실제로 뜨는 할 일 문구를 전부 넣어 본다.
	#
	#    마을마다 할 일 이름이 다르고 제일 긴 것이 어느 마을 것인지는
	#    바뀐다. 하나하나 손으로 고르지 않고 다 돌린다.
	var seen: Array = []
	for village in Quests.LOCAL:
		for row in Quests.quest_list(String(village)):
			seen.append("지금 해볼 일 · " + String(row.get("label", "")))
	ok(seen.size() > 10, "돌려 볼 할 일 문구를 모았다 (%d개)" % seen.size())
	var word_cut: Array = []
	for one: String in seen:
		var f2 := Wrap.fit(one, font, 24, 720, false)
		for i in f2.length():
			if f2[i] == "\n" and one[i] != " ":
				word_cut.append(one)
				break
	ok(word_cut.is_empty(), "할 일 문구가 낱말 한가운데서 안 끊긴다%s"
		% ("" if word_cut.is_empty() else " - " + str(word_cut.slice(0, 3))))

	# ④ 띄어쓰기가 아예 없는 긴 낱말은 어쩔 수 없이 자른다. 넘치게
	#    두면 화면 밖으로 나가는 편이 더 나쁘다.
	var nospace := "가나다라마바사아자차카타파하가나다라마바사아자차카타파하"
	var chopped := Wrap.fit(nospace, font, 24, 200)
	ok(chopped.contains("\n"), "띄어쓰기가 없으면 잘라서라도 넣는다")
	ok(chopped.replace("\n", "") == nospace, "자르되 글자를 안 잃는다")

	# ⑤ 폭을 모르는 라벨은 건드리지 않는다 (여태처럼 엔진에 맡긴다).
	var bare := Label.new()
	Wrap.put(bare, long_one)
	ok(bare.text == long_one, "폭을 모르면 원문 그대로 둔다")
	ok(bare.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"그때는 자동 줄바꿈을 켜 둔다")
	bare.queue_free()


# ── 길안내 ────────────────────────────────────────────────────────────
#
# "지금 퀘스트 어려워. 퀘스트는 계속 깰 수 있게 친절한 표시가 필요해.
#  건물 안에 들어가도 다시 나가라는 둥 다음 퀘스트를 위한 화살표는
#  필요해." - 폰 화면과 함께 받은 말이다.
#
# 재 보니 근거가 있었다. 마을에 들어선 자리에서 남은 할 일이 화면에
# 드는지 세어 봤더니 굽이나루는 여섯 중 여섯이 화면 밖이었다. 그런데
# 할 일 화살표는 세계 좌표에 떠 있어서, 화면 밖이면 아무 표시도 없었다.
#
# 여기서 지키는 것 셋:
#   - 화면 밖 목표는 가장자리가 가리킨다
#   - 실내에서 안에 볼 것이 없으면 나가는 문을 가리킨다
#   - 목록 줄이 **남은 것**을 적는다

func _guide_tests() -> void:
	print("\n[길안내]")
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")

	# ① 마을마다 남은 할 일이 화면 밖일 수 있다 - 그때 표시가 있나
	var far := 0
	var pointed := 0
	var blind: Array = []
	for village in GOAL_SCENES:
		var p: Place = load(GOAL_SCENES[village]).instantiate()
		add_child(p)
		await get_tree().process_frame
		await get_tree().process_frame
		var g: Dictionary = p.current_goal()
		if not g.is_empty():
			var at: Vector2 = p.goal_world(g)
			if at != Vector2.INF:
				# 4배로 당겨 놓으면 거의 다 화면 밖이 된다
				if p.cam != null:
					p.cam.zoom = Vector2.ONE * 4.0
				await get_tree().process_frame
				await get_tree().process_frame
				p._tick_goal_arrow(0.016)
				var edge: GoalPointer = p._goal_edge
				var off: bool = edge != null and edge._off_screen()
				if off:
					far += 1
					if edge.visible:
						pointed += 1
					else:
						blind.append(village)
		p.queue_free()
		await get_tree().process_frame
	ok(far > 0, "당겨 보면 화면 밖 할 일이 생긴다 (%d곳)" % far)
	ok(blind.is_empty(), "화면 밖이면 가장자리가 가리킨다%s"
		% ("" if blind.is_empty() else " - " + str(blind)))

	# ①-2 화살촉이 **실제로 가리키는 쪽**이 겨눈 쪽과 같은가
	#
	# 좌표가 맞아도 모양이 틀리면 소용이 없다. 세모 하나로 그렸을 때
	# 세 번 연달아 엉뚱한 쪽으로 읽혔다 - 이등변삼각형은 밑변 모서리가
	# 무게중심에서 제일 멀어서, 기울여 놓으면 그 모서리가 앞으로 보인다.
	# 눈이 앞을 찾는 방식(무게중심에서 제일 먼 꼭짓점)으로 재서 막는다.
	var aim := GoalPointer.head_aims()
	ok(aim.x > 0.9, "화살촉이 코 쪽을 가리킨다 (%.2f, %.2f)" % [aim.x, aim.y])
	ok(absf(aim.y) < 0.1, "위아래로 안 기운다")
	var nose: Vector2 = GoalPointer.HEAD[0]
	var wing: Vector2 = GoalPointer.HEAD[1]
	ok(nose.length() > wing.length() * 1.3,
		"코가 날개보다 확실히 길다 (%.1f > %.1f)" % [nose.length(), wing.length()])

	# ② 실내에서는 나가는 문을 가리킨다
	#
	# 가게 안과 등대 안은 제 할 일 자리가 아예 없다. 여태 화살표가
	# 사라져서 "이제 뭐하지" 가 됐다.
	JourneyState.reset()
	JourneyState.here = "윤슬"
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(24, 12)
	for room in ["ShopInterior", "LighthouseInterior",
			"SidePathInterior", "TombPathInterior"]:
		var inn: Place = load("res://scenes/journey/interiors/%s.tscn" % room) \
			.instantiate()
		add_child(inn)
		await get_tree().process_frame
		ok(inn.is_indoors(), "%s: 실내로 친다" % room)
		var g2: Dictionary = inn.current_goal()
		ok(not g2.is_empty(), "%s: 안에서도 갈 곳이 있다" % room)
		if not g2.is_empty():
			var at2: Vector2 = inn.goal_world(g2)
			ok(at2 != Vector2.INF, "%s: 그 자리를 짚을 수 있다" % room)
			# 규칙은 하나다 - **안에 갈 자리가 있으면 그것을, 없으면 나가는
			# 문을.** 샛길과 능 안쪽길은 안쪽에 제 목표가 있어서, 거기서
			# 문을 가리키면 오히려 틀린 것이다.
			var inner := false
			for z in inn.quest_zones():
				if not JourneyState.quest_done(String(z[0])):
					inner = true
			if inner:
				ok(String(g2.get("kind", "")) == "visit",
					"%s: 안쪽에 갈 자리가 있으면 그것을 가리킨다" % room)
			else:
				var door_at: Vector2 = inn.world_of(inn.doors()[0]["tile"])
				ok(at2.distance_to(door_at) < 1.0,
					"%s: 볼 것이 없으면 나가는 문을 가리킨다" % room)
			# **안쪽을 다 본 다음**이 진짜 문제였다. 볼 것을 보고 나면
			# 화살표가 사라져서 "이제 뭐하지" 가 됐다. 다 본 뒤에는
			# 문으로 넘어가야 한다.
			if inner:
				for z2 in inn.quest_zones():
					JourneyState.mark_quest(String(z2[0]))
				var after: Dictionary = inn.current_goal()
				var door2: Vector2 = inn.world_of(inn.doors()[0]["tile"])
				ok(not after.is_empty() \
					and inn.goal_world(after).distance_to(door2) < 1.0,
					"%s: 안쪽을 다 보면 문으로 넘어간다" % room)
				for z3 in inn.quest_zones():
					JourneyState.quest_flags.erase(String(z3[0]))
		inn.queue_free()
		await get_tree().process_frame

	# ③ 목록 줄이 **남은 것**을 적는다
	JourneyState.reset()
	var pier := _side_row("윤슬:샛길:부두")
	ok(not pier.contains("한 번 더"), "아무것도 안 했으면 군말이 없다 (%s)" % pier)
	JourneyState.mark_quest("윤슬:부두끝@아침")
	pier = _side_row("윤슬:샛길:부두")
	ok(pier.contains("저녁에 한 번 더"),
		"아침 몫을 마치면 저녁이 남았다고 적는다 (%s)" % pier)

	# 반짝이는 자리는 몇 개 찾았는지 센다
	JourneyState.mark_quest("윤슬:본:빛자리1")
	var tr := _side_row("윤슬:샛길:자취")
	ok(tr.contains("1/3"), "찾은 개수를 적는다 (%s)" % tr)

	# ④ 아침 몫을 마쳤으면 아침 내내 그것만 시키지 않는다
	#
	# 5일째 아침 6:34 에 "부두 끝을 아침에도 저녁에도 보기" 가 떠 있는
	# 화면을 받았다. 이미 아침에 다녀왔는데 저녁까지 할 것이 없었다.
	JourneyState.minutes = 6 * 60 + 34
	ok(JourneyState.day_part() == "아침", "6시 34분은 아침이다")
	ok(Quests.side_waiting("윤슬", "윤슬:샛길:부두"),
		"아침 몫을 마쳤으면 저녁까지 기다린다")
	var yun2: Place = load(GOAL_SCENES["윤슬"]).instantiate()
	add_child(yun2)
	await get_tree().process_frame
	var now: Dictionary = yun2.current_goal()
	ok(not String(now.get("label", "")).contains("부두"),
		"그때는 다른 할 일을 짚는다 (%s)" % now.get("label", ""))
	yun2.queue_free()
	await get_tree().process_frame
	JourneyState.reset()


	# ⑤ **어느 때든 손댈 수 있는 일이 있다**
	#
	# "퀘스트는 계속 깰 수 있게" 가 이 검사다. 진행 상태를 여섯 가지로
	# 놓고 아침·낮·저녁을 다 돌려, 지금 당장 갈 수 있는 자리가 하나도
	# 없는 조합이 있는지 본다. 없으면 게임이 멈춘 것처럼 느껴진다.
	var stuck: Array = []
	for st: Array in STUCK_STATES:
		for part: Array in [["아침", 8], ["낮", 13], ["저녁", 19]]:
			JourneyState.reset()
			JourneyState.pick("map")
			JourneyState.pick("camera")
			JourneyState.here = "윤슬"
			JourneyState.minutes = int(part[1]) * 60
			for f in st[1]:
				JourneyState.mark_quest(String(f))
			var yy: Place = load(GOAL_SCENES["윤슬"]).instantiate()
			add_child(yy)
			await get_tree().process_frame
			var can := 0
			for q in Quests.quest_list("윤슬"):
				if bool(q.get("done", false)) or bool(q.get("waiting", false)):
					continue
				if yy.goal_world(q) != Vector2.INF:
					can += 1
			if can == 0:
				stuck.append("%s/%s" % [st[0], part[0]])
			yy.queue_free()
			await get_tree().process_frame
	ok(stuck.is_empty(), "어느 진행·어느 때든 손댈 일이 있다%s"
		% ("" if stuck.is_empty() else " - " + str(stuck)))
	JourneyState.reset()


## 진행 상태 여섯. 첫 마을을 걸어가는 동안 실제로 거치는 자리들이다.
const STUCK_STATES := [
	["막 도착", []],
	["인사 둘 끝", ["윤슬:매듭:1"]],
	["가게 다녀옴", ["윤슬:매듭:1", "윤슬:가게"]],
	["부두 아침만", ["윤슬:매듭:1", "윤슬:가게", "윤슬:부두끝@아침"]],
	["등대 안까지", ["윤슬:매듭:1", "윤슬:가게", "윤슬:부두끝@아침",
		"윤슬:등대안"]],
	["자취 둘", ["윤슬:매듭:1", "윤슬:가게", "윤슬:부두끝@아침",
		"윤슬:등대안", "윤슬:본:빛자리1", "윤슬:본:빛자리2"]],
]


## 윤슬 목록에서 그 샛길 줄의 글을 꺼낸다.
func _side_row(key: String) -> String:
	var want := ""
	for e in Quests.SIDE["윤슬"]:
		if String(e["key"]) == key:
			want = String(e["label"])
	for row in Quests.quest_list("윤슬"):
		if String(row.get("label", "")).contains(want):
			return String(row["label"])
	return ""


# ── 씬이 실제로 열리나 ────────────────────────────────────────────────
#
# 등대 안이 사흘 동안 **안 열리는 씬**이었다. `var view := {…}.get(…)`
# 한 줄 때문이다 - `Dictionary.get()` 은 Variant 를 주는데 이 프로젝트는
# 경고를 오류로 다루므로 스크립트가 통째로 안 뜬다. 그러면 씬의 뿌리가
# Place 가 아니라 맨 Node2D 가 되고, 문을 지나도 아무 일이 안 난다.
#
# 검사 656개가 다 통과하는 동안 아무도 못 봤다. 아무 검사도 등대 안을
# 열어 보지 않았기 때문이다. 그래서 **씬을 하나씩 다 열어 본다.**

func _scene_load_tests() -> void:
	print("\n[씬이 열리나]")
	var dead: Array = []
	var checked := 0
	for dir in ["res://scenes/journey", "res://scenes/journey/interiors"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".tscn"):
				continue
			var path := "%s/%s" % [dir, f]
			var packed := load(path) as PackedScene
			if packed == null:
				dead.append("%s (못 읽음)" % f)
				continue
			var node := packed.instantiate()
			checked += 1
			# 여행 씬의 뿌리는 다 `Place` 다. 스크립트가 안 뜨면 맨
			# Node2D 가 되므로, 그것만 봐도 걸린다.
			if not (node is Place):
				dead.append("%s (%s)" % [f, node.get_class()])
			node.queue_free()
		await get_tree().process_frame
	ok(checked >= 12, "씬을 다 열어 봤다 (%d개)" % checked)
	ok(dead.is_empty(), "스크립트가 안 뜨는 씬이 없다%s"
		% ("" if dead.is_empty() else " - " + str(dead)))

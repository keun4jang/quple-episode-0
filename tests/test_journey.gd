extends Node
## 탑다운 여행 — 걷기·카메라·지도 테스트.

var _pass := 0
var _fail := 0


func _ready() -> void:
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

	# 고향에는 쿼- 낱말이 없다 (docs/world-quo.md 5절)
	ok(not p.place_name().begins_with("쿼"), "고향은 쿼로 시작하지 않는다")

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

	ok(p.place_name() == "윤슬", "이름이 쿼로 시작한다")
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

	ok(p.sleep_tile().x >= 0, "쿼스텔에서 잘 수 있다")
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
	for i in 8:
		seen[JourneyState.wanderer_place] = true
		JourneyState.move_wanderer()
	ok(seen.size() == JourneyState.WANDERER_STOPS.size(),
		"여행자가 네 곳을 다 돈다 (%d)" % seen.size())
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
	ok(JourneyState.letters.size() == JourneyState.LETTERS.size(),
		"다니다 보면 편지가 다 온다 (%d/%d)" %
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

	# ③ 윤슬을 실제로 다 채우면 클리어된다.
	JourneyState.pick("camera")
	JourneyState.mark_quest("윤슬:가게")
	JourneyState.mark_quest("윤슬:등대")
	JourneyState.mark_quest("윤슬:잠")
	for i in Quests.PICKUP_TOTAL["윤슬"]:
		JourneyState.taken["윤슬:%d,0" % i] = true
	ok(not Quests.village_cleared("윤슬"), "사진이 없으면 아직 못 채운다")
	JourneyState.photos.append({"place": "윤슬", "subject": "등대"})
	ok(not Quests.village_cleared("윤슬"), "등대 안에도 안 들어갔으면 아직 못 채운다")
	JourneyState.mark_quest("윤슬:등대안")
	ok(Quests.village_cleared("윤슬"),
		"지도·카메라·가게·방문·사진·줍기·잠·등대안을 다 채웠다")
	ok(Quests.is_unlocked("볕뉘"), "윤슬을 다 채우면 볕뉘가 열린다")
	ok(not Quests.is_unlocked("가풀재"), "그렇다고 그다음까지 한 번에 열리진 않는다")

	# ④ 옛 세이브(이 갱신 전) 는 지도·카메라를 자동으로 받는다.
	JourneyState.reset()
	JourneyState.from_dict({"here": "볕뉘"})
	ok(Quests.has_map() and Quests.has_camera(),
		"옛 세이브는 지도·카메라를 잃지 않는다")
	JourneyState.reset()

	# ⑤ 배낭 "이 마을에서" 탭이 읽는 목록도 같은 판정을 그대로 쓴다.
	# 지도·카메라를 받기 전엔 딱 둘만 보여준다("숙제장" 처럼 안 보이게).
	ok(Quests.quest_list("윤슬").size() == 2,
		"지도·카메라를 받기 전엔 윤슬 목록이 둘뿐이다")
	JourneyState.pick("map")
	JourneyState.pick("camera")
	ok(Quests.quest_list("윤슬").size() == 7,
		"둘 다 받으면 나머지(가게·방문·줍기·잠·등대안)까지 다 보인다")
	JourneyState.reset()
	ok(Quests.quest_list("볕뉘").size() == 6, "볕뉘는 항목 6개 (능 안쪽길 포함)")
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
	for i in Quests.PICKUP_TOTAL["윤슬"]:
		JourneyState.taken["윤슬:%d,0" % i] = true
	JourneyState.photos.append({"place": "윤슬", "subject": "등대"})
	JourneyState.hearts["ju_seal"] = 1
	JourneyState.hearts["ju_kid"] = 1
	JourneyState.mark_quest("볕뉘:가게")
	JourneyState.mark_quest("볕뉘:능")
	JourneyState.mark_quest("볕뉘:능안")
	for i in Quests.PICKUP_TOTAL["볕뉘"]:
		JourneyState.taken["볕뉘:%d,1" % i] = true
	JourneyState.hearts["san_seal"] = 1
	JourneyState.hearts["san_gull"] = 1
	JourneyState.mark_quest("가풀재:가게")
	JourneyState.mark_quest("가풀재:능선")
	JourneyState.mark_quest("가풀재:등대안")
	for i in Quests.PICKUP_TOTAL["가풀재"]:
		JourneyState.taken["가풀재:%d,2" % i] = true
	JourneyState.photos.append({"place": "가풀재", "subject": "노을"})
	JourneyState.hearts["do_seal"] = 1
	JourneyState.hearts["do_kid"] = 1
	JourneyState.mark_quest("하늬섬:가게")
	JourneyState.mark_quest("하늬섬:한바퀴")
	JourneyState.mark_quest("하늬섬:등대안")
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
const MINIMAP_KINDS := ["talk", "prop", "door", "visit", "pickup", "sleep", "depart"]

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
	hud._done_place = ""              # 갓 도착한 셈으로
	hud._watch_done(Quests.quest_list("솔은재"))
	ok(hud._hint_queue.is_empty() and not hud._hint_busy,
		"도착할 때 이미 해 둔 것은 안 알린다")

	# 여기서 하나를 새로 마치면 그때 알린다.
	JourneyState.mark_quest("솔은재:가게")
	hud._watch_done(Quests.quest_list("솔은재"))
	ok(hud._hint_busy, "새로 마치면 한 줄 뜬다")
	ok(hud._hint.text.ends_with("다 했어요"),
		"마쳤다고 적는다 (%s)" % hud._hint.text)
	ok(hud._hint.text.begins_with("가게 들어가 보기"),
		"무엇을 마쳤는지 적는다 (%s)" % hud._hint.text)

	# 같은 것이 두 번 뜨지 않는다.
	var before := hud._hint_queue.size()
	hud._watch_done(Quests.quest_list("솔은재"))
	ok(hud._hint_queue.size() == before, "같은 것을 두 번 안 알린다")

	# 마지막 하나를 마치면 한 줄 더. 다음 마을 이야기는 안 한다.
	JourneyState.mark_quest("솔은재:전망")
	JourneyState.mark_quest("솔은재:잠")
	JourneyState.mark_quest(Quests._local_flag("솔은재"))
	JourneyState.photos.append({"place": "솔은재", "subject": "전망"})
	for i in Quests.PICKUP_TOTAL["솔은재"]:
		JourneyState.taken["솔은재:%d,9" % i] = true
	hud._watch_done(Quests.quest_list("솔은재"))
	var all_line := ""
	for s in hud._hint_queue:
		if String(s).begins_with("이 마을에서"):
			all_line = String(s)
	if hud._hint.text.begins_with("이 마을에서"):
		all_line = hud._hint.text
	ok(all_line != "", "다 마치면 마무리 한 줄이 더 뜬다 (%s)" % all_line)
	ok(not all_line.contains("열렸") and not all_line.contains("다음"),
		"다음 마을 이야기는 안 한다")

	# 긴 이름도 화면 안에 들어와야 한다 (줄바꿈이 켜져 있나).
	ok(hud._hint.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"긴 이름은 줄을 바꾼다")

	p.queue_free()
	await get_tree().process_frame
	JourneyState.reset()

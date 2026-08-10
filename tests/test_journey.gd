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
	var view := p.get_viewport().get_visible_rect().size / p.cam.zoom
	ok(sz.x * Place.TILE >= view.x and sz.y * Place.TILE >= view.y,
		"지도가 화면보다 크다 (%dx%d칸)" % [sz.x, sz.y])

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
	ok(reunions >= 2, "그중 처음 보는 곳에서의 재회가 있다 (%d번)" % reunions)
	ok(met < 12, "그렇다고 갈 때마다 있지는 않다 (%d/12)" % met)
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
	# 같은 곳에 다시 가도 떠난 것이다 — 여기서 편지가 멈추면 안 된다
	for i in 8:
		JourneyState.visit("윤슬")
		JourneyState.maybe_letter()
	ok(JourneyState.letters.size() == JourneyState.LETTERS.size(),
		"다니다 보면 다섯 통이 다 온다 (%d)" % JourneyState.letters.size())
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

	# ⑤ 미니맵
	ok(tp.minimap != null and not tp.minimap.is_big(), "미니맵은 작게 시작한다")
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

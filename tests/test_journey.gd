extends Node
## 탑다운 여행 — 걷기·카메라·지도 테스트.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	await _sprite_tests()
	await _walker_tests()
	await _place_tests()
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
		if c is QuoWalker and c != p.walker:
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


# ── 카메라 ────────────────────────────────────────────────────────────

func _camera_tests() -> void:
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

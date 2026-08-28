extends Node
## 화면을 몇 장 찍어 파일로 남긴다. 눈으로 검토하려고 쓰는 것이다.
##
## **`--headless` 로 돌리면 안 된다.** 그때는 그리기가 아예 꺼져서
## 화면을 못 가져온다. xvfb 안에서 진짜 렌더러로 돌려야 한다:
##
##     xvfb-run -a godot --path . --rendering-driver opengl3 \
##         res://tools/shots/ShotScreens.tscn
##
## 찍은 그림은 `user://shots/` 가 아니라 프로젝트 밖 임시 폴더에 둔다 —
## 저장소에 그림을 쌓을 일이 아니다. `OUT` 를 환경변수로 받는다.

const SHOT_DIR := "SHOT_DIR"

var _out := "/tmp/shots"
var _n := 0


func _ready() -> void:
	if OS.has_environment(SHOT_DIR):
		_out = OS.get_environment(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(_out)
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _shot(name: String) -> void:
	# 그리기가 끝난 뒤에 가져와야 빈 그림이 안 나온다.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("  ✘ %s — 화면을 못 가져왔다" % name)
		return
	_n += 1
	var path := "%s/%02d-%s.png" % [_out, _n, name]
	img.save_png(path)
	print("  ✔ %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## 한 장면을 띄우고 잠시 둔다.
func _open(path: String) -> Place:
	for c in get_children():
		c.queue_free()
	await _wait(2)
	var p: Place = load(path).instantiate()
	add_child(p)
	await _wait(8)
	return p


func _run() -> void:
	JourneyState.reset()
	SaveManager.set_flag(Guide.FLAG, false)
	SaveManager.set_flag(Guide.STEP_FLAG, 0)
	SaveManager.set_flag(HowToPlay.FLAG, true)

	# ⓪ 인트로 넉 장
	var intro = load("res://scenes/menu/IntroSlides.tscn").instantiate()
	add_child(intro)
	await _wait(40)
	await _shot("intro-1")
	intro._next(); await _wait(40); await _shot("intro-2")
	intro._next(); await _wait(40); await _shot("intro-3")
	intro._next(); await _wait(40); await _shot("intro-4")
	intro.queue_free()
	await _wait(4)

	# ① 프롤로그 — 길잡이 첫 줄과 배낭 고리가 같이 보여야 한다
	var p := await _open("res://scenes/journey/Jaenmaru.tscn")
	await _wait(30)                       # 도착 카드가 떠 있는 동안
	await _shot("arrive-card")
	await _wait(160)                      # 카드가 걷히고 안내줄만 남는다
	await _shot("prologue-guide")

	# ①-2 얻은 것 카드 + 이름표
	p.hud.show_got("map")
	await _wait(20)
	await _shot("got-map")
	p.hud.show_got("p-shell")
	await _wait(20)
	await _shot("got-shell")

	# ② 프롤로그 배낭 — "이 마을에서" 가 먼저 열려야 한다
	p.hud.toggle_bag()
	await _wait(6)
	await _shot("prologue-quests")
	p.hud.toggle_bag()
	await _wait(4)

	# ③ 윤슬 — 미니맵 표시 (지도·카메라를 받은 뒤)
	SaveManager.set_flag(Guide.FLAG, true)
	JourneyState.pick("map")
	JourneyState.pick("camera")
	p = await _open("res://scenes/journey/Yunseul.tscn")
	await _wait(30)
	await _shot("yunseul-minimap-small")

	# ④ 펼친 미니맵 — 남은 할 일이 다 보인다
	p.minimap.toggle()
	await _wait(30)
	await _shot("yunseul-minimap-big")
	p.minimap.toggle()
	await _wait(20)

	# ⑤ 할 일 목록 (누를 수 있는 줄)
	p.hud.toggle_bag()
	await _wait(6)
	await _shot("yunseul-quests")

	# ⑥ 길잡이 다시 보기
	p.hud._open_guide_recap()
	await _wait(8)
	await _shot("guide-recap")

	# ⑦ 2탄 한 곳 — 꽃눈벌 (밭 지형과 미니맵)
	p = await _open("res://scenes/journey/Kkonnunbeol.tscn")
	await _wait(30)
	await _shot("kkonnunbeol")
	p.minimap.toggle()
	await _wait(30)
	await _shot("kkonnunbeol-minimap-big")

	# ⑧ 여행판
	p.board.open(p.place_name())
	await _wait(20)
	await _shot("travel-board")

	# ⑧-2 하나 마쳤을 때 뜨는 줄
	p = await _open("res://scenes/journey/Soleunjae.tscn")
	await _wait(20)
	JourneyState.mark_quest("솔은재:가게")
	await _wait(6)
	await _shot("done-toast")

	# ⑧-3 가게에 막 들어선 순간 — 안내와 완료 표시가 같이 있어야 한다
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.here = "윤슬"
	JourneyState.announce_ready = true
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(24, 12)
	p = await _open("res://scenes/journey/interiors/ShopInterior.tscn")
	await _wait(6)
	JourneyState.mark_quest("윤슬:가게")
	await _wait(14)
	await _shot("shop-entered")

	# ⑨ 가게 안 — 마을마다 달라야 한다
	for v in [["Yunseul", "윤슬"], ["Soleunjae", "솔은재"], ["Kkonnunbeol", "꽃눈벌"]]:
		JourneyState.exit_scene = "res://scenes/journey/%s.tscn" % v[0]
		JourneyState.exit_tile = Vector2i(4, 4)
		p = await _open("res://scenes/journey/interiors/ShopInterior.tscn")
		await _wait(20)
		await _shot("shop-%s" % v[0])
		if v[0] == "Yunseul":
			# 위쪽 벽 얼굴(갓돌·벽면·밑선)이 보이는 자리에서 한 장 더.
			p.walker.global_position = Vector2(17.5 * 16, 5 * 16)
			await _wait(30)
			await _shot("shop-wall")

	# ⑨-2 마을 선반 — 값이 없는 가게. 세 판을 다 찍어 둔다. 잠긴 것이
	# 흐리게만 보이는지, 이름이 판 밖으로 안 넘치는지 눈으로 본다.
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(24, 12)
	p = await _open("res://scenes/journey/interiors/ShopInterior.tscn")
	JourneyState.pick("p-shell")
	JourneyState.pick("p-seaglass")
	await _wait(16)
	for kind: String in [ShelfPanel.KIND_FOOD, ShelfPanel.KIND_KEEP,
			ShelfPanel.KIND_SHOW]:
		var sp := ShelfPanel.open(p, "윤슬", kind)
		await _wait(10)
		await _shot("shelf-%s" % kind)
		if sp != null:
			sp._close()
		await _wait(4)

	# ⑩ 샛길 — 셋이 서로 달라야 한다
	for v2 in ["Gubinaru", "Soleunjae", "Kkonnunbeol"]:
		JourneyState.exit_scene = "res://scenes/journey/%s.tscn" % v2
		JourneyState.exit_tile = Vector2i(4, 4)
		p = await _open("res://scenes/journey/interiors/SidePathInterior.tscn")
		await _wait(20)
		await _shot("side-%s" % v2)
		p.minimap.toggle()
		await _wait(28)
		await _shot("side-%s-map" % v2)

	# ⑪ 시각별 하늘빛 — 17시에 갑자기 어두워지지 않는지, 노을 구간이
	# 실제로 붉은지, 가로등이 19시엔 다 켜져 있는지, 소품 그림자와
	# 물 흔들림이 보이는지. UI(시계·달력)는 CanvasLayer 라 안 물들어야 한다.
	for hh in [6.0, 12.0, 17.0, 18.0, 18.75, 19.5, 21.0, 23.9]:
		JourneyState.minutes = hh * 60.0
		p = await _open("res://scenes/journey/Yunseul.tscn")
		await _wait(24)
		await _shot("sky-%02d%02d" % [int(hh), int(fmod(hh, 1.0) * 60.0)])

	# ⑫ 마을 바닥 — 길이 굽어 보이는지 본다. 2배 줌이면 41x23칸이
	# 거의 다 한 화면에 든다. 정오·인연 있는 그대로.
	JourneyState.minutes = 12.0 * 60.0
	for v3 in [["Yunseul", "윤슬"], ["Kkonnunbeol", "꽃눈벌"],
			["Hanuiseom", "하늬섬"]]:
		p = await _open("res://scenes/journey/%s.tscn" % v3[0])
		var sz: Vector2i = p.tile_size()
		p.walker.global_position = Vector2(sz.x * 8.0, sz.y * 8.0)
		await _wait(30)
		await _shot("floor-%s" % v3[0])

	# ⑬ 폰에서 겪은 그 상황 — 아침 윤슬. 가게 할머니가 나무에 안 가리고,
	# 목표 화살표가 이름표를 안 덮어야 한다.
	JourneyState.reset()
	JourneyState.minutes = 6.0 * 60.0 + 13.0
	SaveManager.set_flag(Guide.FLAG, true)
	p = await _open("res://scenes/journey/Yunseul.tscn")
	p.walker.global_position = Vector2(13 * 16 + 8, 13 * 16)
	await _wait(40)
	await _shot("morning-granny")

	# ⑭ 얻은 것 카드와 축하가 **차례로** 떠야 한다 (겹치면 글자가 뭉갠다)
	p.hud.show_got("map")
	p.hud._celebrate("다 했어요!", "가게 할머니와 인사하고 지도 받기")
	await _wait(30)
	await _shot("center-1-got")      # 얻은 것 카드만 (축하는 줄 서서 기다린다)
	p.hud._got_queue.clear()
	p.hud._got_busy = false
	p.hud._cele_queue.clear()
	p.hud._celebrate("다 했어요!", "가게 할머니와 인사하고 지도 받기")
	await _wait(24)
	await _shot("center-2-cele")     # 그다음 축하만

	# ⑮ 화면 보는 법 — 처음 한 번 뜨는 안내판. 네 귀퉁이에 고리가
	# 실제 그 자리에 놓이는지, 글자가 화면 밖으로 안 나가는지 본다.
	p = await _open("res://scenes/journey/Yunseul.tscn")
	await _wait(10)
	var card := HowToPlay.open(get_tree())
	await _wait(20)
	await _shot("how-to-play")

	# ⑭ 대사창 - 긴 말과 짧은 말. 한글이 낱말 한가운데서 안 갈리는지,
	#    접힌 줄만큼 창이 높아지는지 본다 (`Wrap` / `JourneySay._fit`).
	JourneyState.reset()
	JourneyState.here = "윤슬"
	p = await _open("res://scenes/journey/Yunseul.tscn")
	await _wait(16)
	p.say.say("가게 할머니", [
		"여기 오래 살았는데, 저녁마다 등대 불이 켜지는 걸 보면 아직도 좋아.",
	])
	await _wait(90)
	await _shot("say-long")
	p.say.say("갈매기 소년", ["응."])
	await _wait(40)
	await _shot("say-short")

	# ⑮ 화면 밖 할 일 - 가장자리 화살표. 4배로 당겨 놓고 찍는다.
	#    굽이나루는 마을에 들어선 자리에서 할 일 여섯이 다 화면 밖이다.
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.here = "굽이나루"
	p = await _open("res://scenes/journey/Gubinaru.tscn")
	await _wait(20)
	await _shot("edge-far")
	if p.cam != null:
		p.cam.zoom = Vector2.ONE * 4.0
	await _wait(20)
	await _shot("edge-zoomed")

	# ⑯ 가게 안에서 나가는 문 짚기. 안에 볼 것을 다 보면 화살표가
	#    문을 가리켜야 한다 (`Place.open_goals` 의 exit).
	JourneyState.reset()
	JourneyState.here = "윤슬"
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(24, 12)
	p = await _open("res://scenes/journey/interiors/ShopInterior.tscn")
	if p.walker != null:
		p.walker.global_position = p.world_of(Vector2i(12, 6))
	await _wait(24)
	await _shot("shop-exit-arrow")

	# ⑰ 채집터 - 갯바위. 물웅덩이와 미역·소라가 자리에 보이는지.
	JourneyState.reset()
	JourneyState.here = "윤슬"
	JourneyState.exit_scene = "res://scenes/journey/Yunseul.tscn"
	JourneyState.exit_tile = Vector2i(20, 9)
	p = await _open("res://scenes/journey/interiors/GatherGround.tscn")
	await _wait(20)
	await _shot("gather-ground")
	# 문 앞 - 윤슬 백사장에서 갯바위 어귀가 보이는지.
	JourneyState.reset()
	JourneyState.here = "윤슬"
	p = await _open("res://scenes/journey/Yunseul.tscn")
	if p.walker != null:
		p.walker.global_position = p.world_of(Vector2i(20, 8))
	await _wait(30)
	await _shot("yunseul-gather-door")

	# ⑱ 채집터 - 갈밭 속. 물길과 갈댓잎·갈꽃이 자리에 보이는지.
	JourneyState.reset()
	JourneyState.here = "갈밭머리"
	JourneyState.exit_scene = "res://scenes/journey/Galbatmeori.tscn"
	JourneyState.exit_tile = Vector2i(11, 9)
	p = await _open("res://scenes/journey/interiors/GatherGround.tscn")
	await _wait(20)
	await _shot("gather-galbat")

	# ⑲ 그늘 자리 - 연밭 그늘. 저녁 대사가 실제로 나오는지.
	JourneyState.reset()
	JourneyState.here = "방울못"
	JourneyState.exit_scene = "res://scenes/journey/Bangulmot.tscn"
	JourneyState.exit_tile = Vector2i(4, 19)
	JourneyState.minutes = 19 * 60
	p = await _open("res://scenes/journey/interiors/ShadeSpot.tscn")
	await _wait(20)
	await _shot("shade-bangulmot")
	p.walker.global_position = p.world_of(Vector2i(11, 6))
	p.talk_to_near()
	await _wait(20)
	await _shot("shade-say")

	# ⑳ 채집터 - 귤밭 뒤뜰. 귤나무와 귤·귤잎이 자리에 보이는지.
	JourneyState.reset()
	JourneyState.here = "하늬섬"
	JourneyState.exit_scene = "res://scenes/journey/Hanuiseom.tscn"
	JourneyState.exit_tile = Vector2i(29, 12)
	p = await _open("res://scenes/journey/interiors/GatherGround.tscn")
	await _wait(20)
	await _shot("gather-hanui")

	# ㉑ 채집터 - 감나무 밭. 감나무와 감·감잎이 자리에 보이는지.
	JourneyState.reset()
	JourneyState.here = "볕뉘"
	JourneyState.exit_scene = "res://scenes/journey/Byeotnwi.tscn"
	JourneyState.exit_tile = Vector2i(18, 17)
	p = await _open("res://scenes/journey/interiors/GatherGround.tscn")
	await _wait(20)
	await _shot("gather-byeotnwi")

	# ㉒ 채집터 - 솔밭 그늘. 소나무와 버섯·솔잎이 자리에 보이는지.
	JourneyState.reset()
	JourneyState.here = "솔은재"
	JourneyState.exit_scene = "res://scenes/journey/Soleunjae.tscn"
	JourneyState.exit_tile = Vector2i(6, 12)
	p = await _open("res://scenes/journey/interiors/GatherGround.tscn")
	await _wait(20)
	await _shot("gather-soleunjae")

	# ㉓ 그늘 자리 - 뒷개. 그물 걸이와 부표가 자리에 보이는지.
	JourneyState.reset()
	JourneyState.here = "가풀재"
	JourneyState.exit_scene = "res://scenes/journey/Gapuljae.tscn"
	JourneyState.exit_tile = Vector2i(1, 18)
	p = await _open("res://scenes/journey/interiors/ShadeSpot.tscn")
	await _wait(20)
	await _shot("shade-gapuljae")

	# ㉔ 말 전하기 - 가풀재 국수집 아저씨가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("san_seal")
	p = await _open("res://scenes/journey/Gapuljae.tscn")
	var seal: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "san_seal":
			seal = f
	if seal != null and p.walker != null:
		p.walker.global_position = seal.global_position + Vector2(0, 20)
		p._near = seal
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-give")

	# ㉕ 말 전하기 - 굽이나루 나루 가게 아저씨가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("cap_guinaru")
	p = await _open("res://scenes/journey/Gubinaru.tscn")
	var cap: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "cap_guinaru":
			cap = f
	if cap != null and p.walker != null:
		p.walker.global_position = cap.global_position + Vector2(0, 20)
		p._near = cap
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-guinaru")

	# ㉖ 말 전하기 - 꽃눈벌 까치가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("kk_magpie")
	p = await _open("res://scenes/journey/Kkonnunbeol.tscn")
	var mag: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "kk_magpie":
			mag = f
	if mag != null and p.walker != null:
		p.walker.global_position = mag.global_position + Vector2(0, 20)
		p._near = mag
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-magpie")

	# ㉗ 말 전하기 - 갈밭머리 전망대 갈매기가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("ga_gull")
	p = await _open("res://scenes/journey/Galbatmeori.tscn")
	var gull: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "ga_gull":
			gull = f
	if gull != null and p.walker != null:
		p.walker.global_position = gull.global_position + Vector2(0, 20)
		p._near = gull
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-gagull")

	# ㉘ 말 전하기 - 하늬섬 귤 파는 할머니가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("do_seal")
	p = await _open("res://scenes/journey/Hanuiseom.tscn")
	var seal2: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "do_seal":
			seal2 = f
	if seal2 != null and p.walker != null:
		p.walker.global_position = seal2.global_position + Vector2(0, 20)
		p._near = seal2
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-doseal")

	# ㉙ 말 전하기 - 솔은재 다람쥐가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("so_squirrel")
	p = await _open("res://scenes/journey/Soleunjae.tscn")
	var sq: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "so_squirrel":
			sq = f
	if sq != null and p.walker != null:
		p.walker.global_position = sq.global_position + Vector2(0, 20)
		p._near = sq
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-squirrel")

	# ㉚ 말 전하기 - 갈밭머리 쉼터 할머니가 말을 맡기는 장면.
	JourneyState.reset()
	for i in JourneyState.HEART_MAX:
		JourneyState.warm("cap_galbat")
	p = await _open("res://scenes/journey/Galbatmeori.tscn")
	var gh: Folk = null
	for f in p._folk:
		if is_instance_valid(f) and f.folk_id == "cap_galbat":
			gh = f
	if gh != null and p.walker != null:
		p.walker.global_position = gh.global_position + Vector2(0, 20)
		p._near = gh
		p.talk_to_near()
	await _wait(20)
	await _shot("relay-galbat")
	if card != null:
		card.queue_free()

	# ㉛ 매듭 화살표 - 할머니와 인사했으면(지도를 받았으면) 소년을
	# 가리켜야 한다. 여태 늘 할머니만 가리켜서 다음이 안 보였다.
	JourneyState.reset()
	JourneyState.pick("map")
	p = await _open("res://scenes/journey/Yunseul.tscn")
	if p.walker != null:
		p.walker.global_position = p.world_of(Vector2i(17, 12))
	await _wait(20)
	await _shot("knot-arrow-seagull")

	# ㉜ 기다리기 - 등대곶에서 저녁까지 서서 기다리게 했더니 무리라는
	# 말을 들었다. 그 자리에 서면 곧장 저녁으로 건너뛸 수 있다.
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")
	JourneyState.minutes = 9 * 60
	p = await _open("res://scenes/journey/Yunseul.tscn")
	if p.walker != null:
		# 등대곶 자리 안쪽이되, 등대 문(31,6)이나 숨은 자취(반짝이는
		# 자리)와는 떨어뜨린다 - 가까우면 "등대 들어가기"·"보기" 가
		# 먼저 뜬다.
		p.walker.global_position = p.world_of(Vector2i(32, 3))
	await _wait(20)
	await _shot("wait-button")
	p._do_wait()
	await _wait(20)
	await _shot("wait-evening")

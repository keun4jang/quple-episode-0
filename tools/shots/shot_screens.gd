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

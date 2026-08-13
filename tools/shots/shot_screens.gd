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

	# ① 프롤로그 — 길잡이 첫 줄과 배낭 고리가 같이 보여야 한다
	var p := await _open("res://scenes/journey/Jaenmaru.tscn")
	await _wait(90)                       # 길잡이는 1.2초 뒤에 뜬다
	await _shot("prologue-guide")

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

	# ⑨ 가게 안 — 마을마다 달라야 한다
	for v in [["Yunseul", "윤슬"], ["Soleunjae", "솔은재"], ["Kkonnunbeol", "꽃눈벌"]]:
		JourneyState.exit_scene = "res://scenes/journey/%s.tscn" % v[0]
		JourneyState.exit_tile = Vector2i(4, 4)
		p = await _open("res://scenes/journey/interiors/ShopInterior.tscn")
		await _wait(20)
		await _shot("shop-%s" % v[0])

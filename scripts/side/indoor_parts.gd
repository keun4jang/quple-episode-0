extends RefCounted
class_name IndoorParts
## 옆에서 본 실내 배경. 사무실·로비·복도.
##
## 여행지는 그려 둔 그림이 있지만 회사 안은 없다. 그래서 코드로 그린다 —
## 밤 도시가 비치는 창, 천장등, 파티션, 책상. 그림만큼 곱지는 않아도
## 지금의 3D 사무실보다는 낫고, 무엇보다 **옆에서 보는 화면과 화풍이
## 어긋나지 않는다.** 나중에 그림이 생기면 이 자리에 걸면 된다.

const NIGHT_SKY := Color("#16203A")
const BUILDING := Color("#1E2A46")
const WINDOW_LIT := Color("#FAE29A")
const WALL := Color("#46557A")
const WALL_DARK := Color("#36415C")
const TRIM := Color("#5A6C90")
const FLOOR_TOP := Color("#65799E")
const FLOOR_BODY := Color("#404E6C")
const GLASS := Color("#3E6278")
const LAMP := Color("#FFD76D")


## 그려 받은 배경이 있으면 그것을 걸고 true 를 돌려준다.
##
## `tools/side/import-indoor-bg.py` 가 넣어 준 파일을 찾는다. 없으면 false 를
## 돌려주고, 부르는 쪽은 코드로 그린 배경으로 넘어간다. 그림이 생겨도
## 코드 쪽을 지우지 않는 이유는 **되돌릴 수 있어야 하기 때문**이다 —
## 그림이 마음에 안 들면 파일만 지우면 어제 상태로 돌아간다.
##
## factor 는 배경이 카메라를 따라 흐르는 정도다. 실내는 벽이 가까우니
## 바깥 풍경보다 크게 잡는다 — 너무 작으면 벽이 따라오지 않아 방이
## 미끄러지는 것처럼 보인다.
const BACKDROP_FACTOR := 0.40
## 맵마다 다른 값. 회사 앞의 밤도시는 아득히 멀어서 거의 안 움직여야 한다.
## `tools/side/import-indoor-bg.py` 의 PARALLAX 와 같은 값이어야 한다 —
## 한쪽만 고치면 그림 폭이 모자라 맵 끝에서 검은 띠가 생긴다.
const BACKDROP_FACTORS := {"front": 0.12}

static func backdrop_factor(map_name: String) -> float:
	return float(BACKDROP_FACTORS.get(map_name, BACKDROP_FACTOR))

static func backdrop(parent: Node, map_name: String) -> TextureRect:
	var path := "res://assets/side/%s-room.png" % map_name
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.name = "Backdrop"
	tr.texture = tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.z_index = -45
	parent.add_child(tr)
	return tr


static func _box(parent: Node, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## 밤 도시. 제일 뒤에 깔린다.
##
## 창밖이 새까맣기만 하면 실내가 상자로 보인다. 불 켜진 창이 몇 개
## 있어야 "다들 아직 저기 있구나" 가 되고, 그게 0편이 하려는 말이다.
static func skyline(parent: Node, w: float, floor_y: float, seed_n := 7) -> Node2D:
	var n := Node2D.new()
	n.name = "Skyline"
	n.z_index = -40
	parent.add_child(n)
	_box(n, Vector2(0, -400), Vector2(w, floor_y + 400), NIGHT_SKY)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var x := -100.0
	while x < w:
		var bw := rng.randf_range(90, 210)
		var bh := rng.randf_range(180, 620)
		_box(n, Vector2(x, floor_y - bh), Vector2(bw, bh), BUILDING)
		var wy := floor_y - bh + 26
		while wy < floor_y - 40:
			var wx := x + 14
			while wx < x + bw - 22:
				if rng.randf() < 0.34:
					_box(n, Vector2(wx, wy), Vector2(13, 19), WINDOW_LIT)
				wx += 30
			wy += 38
		x += bw + rng.randf_range(10, 50)
	return n


## 실내 벽. 창틀이 도시를 잘라 주어야 밖이 아니라 안이 된다.
static func room(parent: Node, w: float, floor_y: float,
		win_top := 190.0, win_bottom := 600.0, pier := 470.0) -> Node2D:
	var n := Node2D.new()
	n.name = "Room"
	n.z_index = -30
	parent.add_child(n)
	# 천장과 허리 아래 벽
	_box(n, Vector2(-200, -400), Vector2(w + 400, 400 + win_top), WALL)
	_box(n, Vector2(-200, win_bottom), Vector2(w + 400, floor_y - win_bottom), WALL)
	# 창틀 기둥
	var x := -100.0
	while x < w + 100:
		_box(n, Vector2(x, win_top), Vector2(46, win_bottom - win_top), WALL)
		x += pier
	# 창틀 위아래 테두리
	_box(n, Vector2(-200, win_top - 22), Vector2(w + 400, 24), TRIM)
	_box(n, Vector2(-200, win_bottom - 2), Vector2(w + 400, 24), TRIM)
	return n


## 천장등. 불 켜진 자리가 몇 개인지가 그 층의 분위기를 정한다.
static func ceiling_lights(parent: Node, w: float, y := 60.0, gap := 620.0) -> void:
	var n := Node2D.new()
	n.name = "CeilingLights"
	n.z_index = -28
	parent.add_child(n)
	var x := 240.0
	while x < w:
		_box(n, Vector2(x - 150, y), Vector2(300, 30), Color("#E8ECF4"))
		var glow := _box(n, Vector2(x - 340, y + 26), Vector2(680, 420),
			Color(1, 0.97, 0.86, 0.06))
		glow.z_index = -27
		x += gap


## 바닥에 깔리는 빛 웅덩이. 실내가 판판해 보이는 건 대개 빛이 없어서다.
static func floor_pools(parent: Node, w: float, floor_y: float, gap := 620.0) -> void:
	var n := Node2D.new()
	n.name = "FloorPools"
	n.z_index = -5
	parent.add_child(n)
	var x := 240.0
	while x < w:
		_box(n, Vector2(x - 300, floor_y - 22), Vector2(600, 26), Color(1, 0.95, 0.80, 0.10))
		_box(n, Vector2(x - 190, floor_y - 16), Vector2(380, 18), Color(1, 0.95, 0.80, 0.10))
		x += gap


## 그림 위에 놓을 때 쓰는 금속색. 청회색 금속은 나무·크림 그림 위에서
## 혼자 다른 게임에서 온 것처럼 보인다.
const WARM_METAL := Color("#9A8270")
const WARM_METAL_HI := Color("#B49B86")
const WARM_METAL_DK := Color("#6E5A4C")

## 바닥. 옆에서 보는 실내는 바닥선 하나로 층이 정해진다.
##
## painted 면 그리지 않고 딛는 자리만 남긴다 — 바닥은 그림에 이미 있다.
static func floor_slab(parent: Node, x: float, y: float, w: float, h := 320.0,
		painted := false) -> StaticBody2D:
	return SideParts.platform(parent, x, y, w, h, false, FLOOR_TOP, FLOOR_BODY, not painted)


## 그려 받은 배경 위에 놓을 때 쓰는 색.
##
## 코드로 그린 방은 푸른 회색이었다. 그림이 걸리면 그 색 그대로 둔 가구가
## 따로 논다 — 실제로 사무실 그림을 넣자마자 책상만 파랗게 떠 보였다.
## 그림에서 뽑은 나무·천 색으로 갈아입힌다.
const WARM_TOP := Color("#B99C82")
const WARM_LEG := Color("#8E7461")
const WARM_MON := Color("#5A4A44")

## 책상. 위에 물건을 올릴 수 있게 윗면 높이를 돌려준다.
##
## warm 은 그려 받은 배경 위에 놓는가다. 배경이 코드로 그린 것이면
## 원래의 푸른 회색이 맞고, 그림이면 나무색이 맞다.
static func desk(parent: Node, x: float, floor_y: float, w := 300.0, lit := false,
		warm := false) -> float:
	var n := Node2D.new()
	n.name = "Desk"
	parent.add_child(n)
	var h := 150.0
	var top := floor_y - h
	var c_top := WARM_TOP if warm else Color("#4E627E")
	var c_leg := WARM_LEG if warm else Color("#3A4A63")
	var c_mon := WARM_MON if warm else Color("#222E44")
	_box(n, Vector2(x, top), Vector2(w, 18), c_top)
	_box(n, Vector2(x + 14, top + 18), Vector2(18, h - 18), c_leg)
	_box(n, Vector2(x + w - 32, top + 18), Vector2(18, h - 18), c_leg)
	# 모니터
	var mx := x + w * 0.5
	_box(n, Vector2(mx - 8, top - 26), Vector2(16, 26), c_leg)
	_box(n, Vector2(mx - 62, top - 108), Vector2(124, 84), c_mon)
	var c_off := Color("#3A2E2B") if warm else Color("#2C3A52")
	_box(n, Vector2(mx - 54, top - 100), Vector2(108, 68),
		Color("#8FD0E4") if lit else c_off)
	if lit:
		# 켜진 모니터는 이 화면에서 **가장 밝은 것**이어야 한다. 밤 사무실에
		# 홀로 남은 불빛이 이야기의 전부인데, 0.07 은 창밖 도시 불빛에도
		# 졌다. 빛무리를 세 겹으로 겹쳐 책상과 바닥까지 닿게 한다.
		for spec in [[440.0, 400.0, 0.10], [260.0, 250.0, 0.10], [150.0, 150.0, 0.10]]:
			var gw: float = spec[0]
			var gh: float = spec[1]
			var g := _box(n, Vector2(mx - gw * 0.5, top - gh * 0.62), Vector2(gw, gh),
				Color(0.56, 0.82, 0.9, spec[2]))
			g.z_index = -1
	return top


## 문. 지나갈 수 있는 자리. 실제 판정은 SideParts.door 가 만든다.
## 그림 위에 놓는 문의 판. 유리 청록(GLASS)을 그대로 두면 따뜻한 벽에
## 청록 사각형 하나가 박혀 **화면에 뚫린 구멍**처럼 보인다 — 복도처럼
## 어두운 맵에서는 그 구멍이 문틈 빛보다 밝아서, 가장 밝아야 할 것이
## 가장 밝지 않게 된다.
const WARM_GLASS := Color("#7A6558")

static func door_frame(parent: Node, x: float, floor_y: float, tint := GLASS,
		warm := false) -> void:
	var n := Node2D.new()
	parent.add_child(n)
	var panel := tint
	if warm and tint == GLASS:
		panel = WARM_GLASS         # 부르는 쪽이 색을 고르지 않았을 때만 갈아입는다
	_box(n, Vector2(x - 92, floor_y - 268), Vector2(184, 268),
		WARM_LEG if warm else Color("#243147"))
	_box(n, Vector2(x - 74, floor_y - 248), Vector2(148, 248), panel)
	_box(n, Vector2(x - 60, floor_y - 232), Vector2(120, 120), Color(1, 1, 1, 0.10))

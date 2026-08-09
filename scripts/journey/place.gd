class_name Place
extends Node2D
## 여행지 한 곳. 지도를 글자로 적고, 물건을 좌표로 놓는다.
##
## 지도를 에디터에서 손으로 찍지 않고 **글자 격자**로 적는다. 파일 하나만
## 보면 그곳이 어떻게 생겼는지 알 수 있고, 고치기도 쉽다.
##
##     const GROUND := "
##     ggggggg
##     gddddg
##     "
##
## 물건은 발 닿는 칸으로 놓는다. Y 정렬이 있으므로 아래에 있는 것이 앞에
## 그려진다 — 나무 뒤로 걸어 들어가면 가려진다.

const TILE := 16

## 글자 → 바닥 그림. 하위 클래스가 채운다.
var legend: Dictionary = {}
## 지나갈 수 없는 바닥 글자
var solid_tiles: Array[String] = []

var walker: QuoWalker
var cam: JourneyCamera
var touch: JourneyTouch

var _ground: Node2D
var _props: Node2D
var _size := Vector2i.ZERO
var _grid: Array = []            # 행 문자열
var _tiles: Dictionary = {}      # 이름 → Texture2D


# ── 하위 클래스가 채우는 것 ───────────────────────────────────────────

func place_name() -> String:
	return "어딘가"

## 글자 격자
func ground_map() -> String:
	return ""

## [(타일x, 타일y, 스프라이트이름, 막는가)]
func props() -> Array:
	return []

## 주인공이 처음 서는 칸
func spawn_tile() -> Vector2i:
	return Vector2i(2, 2)

## 지도가 다 깔린 뒤. 인연을 세우거나 사건을 붙인다.
func on_built() -> void:
	pass


# ── 짓기 ──────────────────────────────────────────────────────────────

func _ready() -> void:
	y_sort_enabled = true
	_read_map()
	_build_ground()
	_build_props()
	_build_walls()
	_build_walker()
	_build_camera()
	on_built()


func _read_map() -> void:
	_grid = []
	for line in ground_map().split("\n"):
		var t := line.strip_edges(false, true)   # 오른쪽 공백만 자른다
		if t.strip_edges() == "":
			continue
		_grid.append(t)
	var w := 0
	for row in _grid:
		w = maxi(w, (row as String).length())
	_size = Vector2i(w, _grid.size())


func tile_texture(name: String) -> Texture2D:
	if not _tiles.has(name):
		_tiles[name] = load("res://assets/tiles/%s.png" % name) as Texture2D
	return _tiles[name]


func _build_ground() -> void:
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.y_sort_enabled = false
	add_child(_ground)

	# 타일마다 Sprite2D 를 만들면 작은 지도에서도 수천 개가 된다.
	# 같은 그림끼리 묶어 MultiMesh 하나로 그린다 — 드로우콜이 그림 수만큼만.
	var by_tex: Dictionary = {}
	for y in _grid.size():
		var row: String = _grid[y]
		for x in row.length():
			var ch := row[x]
			if not legend.has(ch):
				continue
			var name: String = legend[ch]
			if not by_tex.has(name):
				by_tex[name] = []
			by_tex[name].append(Vector2(x * TILE, y * TILE))

	for name in by_tex:
		var tex := tile_texture(name)
		if tex == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		var quad := QuadMesh.new()
		quad.size = Vector2(TILE, TILE)
		mm.mesh = quad
		var spots: Array = by_tex[name]
		mm.instance_count = spots.size()
		for i in spots.size():
			var at: Vector2 = spots[i]
			# 칸마다 뒤집고 돌린다.
			#
			# 이음매는 지웠는데도 바둑판 무늬가 그대로 보였다. 16px 로
			# 줄이면 무늬 하나가 칸 하나를 차지해서, 같은 점이 규칙적으로
			# 반복되는 게 눈에 띈다. 여덟 가지로 돌려 놓으면 규칙이 깨진다.
			#
			# 무작위를 쓰면 켤 때마다 마당이 달라진다. 칸 좌표로 정해진
			# 값을 만든다.
			var v := _variant(at)
			var t := Transform2D(
				(v & 4) * (PI * 0.5),                       # 0 또는 90도
				Vector2(1.0 if (v & 1) == 0 else -1.0,
						1.0 if (v & 2) == 0 else -1.0),
				0.0,
				at + Vector2(TILE, TILE) * 0.5)
			mm.set_instance_transform_2d(i, t)
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture = tex
		mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ground.add_child(mmi)


## 칸 좌표로 0~7 을 만든다. 늘 같은 값이 나와야 한다.
func _variant(at: Vector2) -> int:
	var x := int(at.x) / TILE
	var y := int(at.y) / TILE
	var h := (x * 73856093) ^ (y * 19349663)
	return absi(h) % 8


func _build_props() -> void:
	_props = Node2D.new()
	_props.name = "Props"
	_props.y_sort_enabled = true
	add_child(_props)

	for p in props():
		var tx: int = p[0]
		var ty: int = p[1]
		var name: String = p[2]
		var blocks: bool = p[3] if p.size() > 3 else true
		var tex := load("res://assets/sprites/%s.png" % name) as Texture2D
		if tex == null:
			push_warning("스프라이트가 없다: %s" % name)
			continue

		var s := Sprite2D.new()
		s.name = name
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 발 닿는 칸의 **아래 가운데**가 기준. 그래야 Y 정렬이 맞는다.
		s.position = Vector2(tx * TILE + TILE * 0.5, (ty + 1) * TILE)
		s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		_props.add_child(s)

		if blocks:
			# 밑동만 막는다. 나무 꼭대기까지 막으면 뒤로 못 지나간다.
			var body := StaticBody2D.new()
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			var w: float = maxf(TILE, tex.get_width() * 0.7)
			r.size = Vector2(w, 8.0)
			cs.shape = r
			cs.position = s.position + Vector2(0, -4.0)
			body.add_child(cs)
			add_child(body)


## 지도 밖으로 못 나가게 벽을 두른다.
func _build_walls() -> void:
	var w := float(_size.x * TILE)
	var h := float(_size.y * TILE)
	var th := 16.0
	for spec in [
		[Vector2(w * 0.5, -th * 0.5), Vector2(w, th)],
		[Vector2(w * 0.5, h + th * 0.5), Vector2(w, th)],
		[Vector2(-th * 0.5, h * 0.5), Vector2(th, h)],
		[Vector2(w + th * 0.5, h * 0.5), Vector2(th, h)],
	]:
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = spec[1]
		cs.shape = r
		cs.position = spec[0]
		body.add_child(cs)
		add_child(body)


func _build_walker() -> void:
	walker = QuoWalker.new()
	walker.name = "Walker"
	var t := spawn_tile()
	walker.position = Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE)
	add_child(walker)


func _build_camera() -> void:
	cam = JourneyCamera.new()
	cam.name = "Camera"
	cam.target = walker
	walker.add_sibling(cam)
	cam.global_position = walker.global_position
	cam.set_bounds(Rect2(Vector2.ZERO, Vector2(_size) * TILE))
	cam.make_current()

	touch = JourneyTouch.new()
	touch.name = "Touch"
	var layer := CanvasLayer.new()
	layer.name = "TouchLayer"
	layer.add_child(touch)
	add_child(layer)


func _process(_delta: float) -> void:
	if walker != null and touch != null:
		walker.set_input(touch.direction_with_keys())


# ── 도우미 ────────────────────────────────────────────────────────────

func tile_size() -> Vector2i:
	return _size


func world_of(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE)


## 인연을 세운다. 걷지 않고 서 있기만 한다.
func put_folk(t: Vector2i, sheet: String, facing := Vector2.DOWN) -> QuoWalker:
	var f := QuoWalker.new()
	f.sheet = "res://assets/sprites/%s-walk.png" % sheet
	f.position = world_of(t)
	add_child(f)
	f.face(facing)
	return f

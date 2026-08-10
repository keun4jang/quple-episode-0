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

signal picked_up(item: String)
signal talked(folk_id: String)
signal slept(day: int)

const TILE := 16
## 이만큼 가까우면 줍는다. 한 칸 조금 안쪽.
const PICK_RANGE := 12.0
## 이만큼 가까우면 말을 걸 수 있다. 줍기보다 넉넉하게.
## 말을 걸 수 있는 거리. 두 칸이다.
##
## 한동안 26px(1.6칸)이었는데, 그러면 인연 바로 옆 칸이 그 사람 몸에
## 막혀 있을 때 설 자리가 1.4칸 밖이 되고, 걸어가 서면 27px — **1px
## 차이로 말을 못 걸었다.** 폰에서 손가락으로 하는 게임에 그런 여유는
## 없다. 두 칸으로 넉넉히 잡는다.
const TALK_RANGE := 32.0
## 실제 1초에 게임 시간이 얼마나 흐르나. 하루(18시간)가 약 9분.
const MINUTES_PER_SECOND := 2.0

## 글자 → 바닥 그림. 하위 클래스가 채운다.
var legend: Dictionary = {}
## 지나갈 수 없는 바닥 글자
## 걸어 들어갈 수 없는 바닥. 타일 **이름**으로 적는다 ("water" 등).
##
## 한동안 이 목록이 선언만 되고 아무도 안 봤다. 그래서 바다가 그림일
## 뿐이었고, 윤슬에서 위로 계속 걸으면 백사장을 지나 바다 한복판까지
## 걸어 들어갔다. 기본값을 여기 둔다 — 물은 어디서나 물이다.
var solid_tiles: Array[String] = ["water"]

var walker: QuoWalker
var cam: JourneyCamera
var touch: JourneyTouch

var _ground: Node2D
var _props: Node2D
var _size := Vector2i.ZERO
var _grid: Array = []            # 행 문자열
var _tiles: Dictionary = {}      # 이름 → Texture2D
var _loose: Array[Node2D] = []   # 아직 안 주운 것
var _folk: Array[Folk] = []
var _near: Folk = null
var _mark: Label                     # 말 걸 수 있는 사람 위에 뜨는 표시
var _prev_near: Folk
var minimap: MiniMap
var guide: Guide
## 소품이 막고 있는 칸. 길찾기가 본다.
var _blocked: Dictionary = {}
var _night: CanvasModulate
var _sleep_at := Vector2.ZERO
var _has_bed := false
var _fade: ColorRect
var _sleeping := false
var _depart_at := Vector2.ZERO
var _has_stop := false
var board: TravelBoard
var say: JourneySay
var hud: JourneyHud


# ── 하위 클래스가 채우는 것 ───────────────────────────────────────────

func place_name() -> String:
	return "어딘가"

## 글자 격자
func ground_map() -> String:
	return ""

## [(타일x, 타일y, 스프라이트이름, 막는가)]
func props() -> Array:
	return []

## 주울 것. [(타일x, 타일y, 아이템이름)]
##
## 한 번 주우면 다시 안 생긴다. 같은 자리를 왔다 갔다 하며 퍼 담는 게임이
## 아니다 — 여행지마다 몇 개씩만 두고, 다음에 오면 다른 게 있게 한다.
func pickups() -> Array:
	return []

## 주인공이 처음 서는 칸
func spawn_tile() -> Vector2i:
	return Vector2i(2, 2)

## 잘 수 있는 자리 (숙소 문, 집 문). 없으면 (-1, -1).
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)

## 떠나는 자리 (정류장, 나루). 없으면 (-1, -1).
func depart_tile() -> Vector2i:
	return Vector2i(-1, -1)

## 여행자가 여기 있을 때 서는 칸
func wanderer_tile() -> Vector2i:
	return Vector2i(-1, -1)

## 지도가 다 깔린 뒤. 인연을 세우거나 사건을 붙인다.
func on_built() -> void:
	pass


# ── 짓기 ──────────────────────────────────────────────────────────────

func _ready() -> void:
	y_sort_enabled = true
	JourneyState.arrive()
	_read_map()
	_build_ground()
	_build_fringes()
	_build_props()
	_build_pickups()
	_build_walls()
	_build_astar()
	_build_walker()
	_build_camera()
	_build_ui()
	_start_sound()
	on_built()
	_block_folk_tiles()
	if place_name() == "고향":
		JourneyState.came_home()
	else:
		JourneyState.maybe_letter()


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
			var name: String = _tile_for(String(legend[ch]), x, y)
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


# ── 넘침 가장자리 ──────────────────────────────────────────────────────
#
# 바닥 두 종이 만나는 경계가 칸 모양 그대로 뚝 끊긴다 — 마을이 아니라
# 모눈종이로 보인다. 우선순위가 높은 바닥이 이웃 칸으로 두세 픽셀
# 넘쳐 들어가게 얹는다. 풀이 흙 위로 삐져나오고 모래가 물속으로 스민다.
#
# **자연이 인공물 위로** 넘치는 것만 자연스럽다. 반대는 이상하다.
const FRINGE_PRIO := {
	"grass": 6, "dry-grass": 5, "clay-earth": 4, "dirt": 3,
	"sand": 2, "basalt": 2,
	# 아래는 안 넘친다. 받기만 한다.
	"water": 0, "cobble": 1, "stone-slab": 1, "deck": 1, "wood-floor": 1,
	"tilled-soil": 1, "slate-path": 1, "granite-step": 1,
	"office-carpet": 1, "lobby-marble": 1,
}


func _build_fringes() -> void:
	var by_tex: Dictionary = {}          # "이름-fr-방향" → 자리들
	for y in _grid.size():
		var row: String = _grid[y]
		for x in row.length():
			if not legend.has(row[x]):
				continue
			var me := String(legend[row[x]])
			var pm: int = FRINGE_PRIO.get(me, 1)
			for d in [[Vector2i(0, -1), "s"], [Vector2i(0, 1), "n"],
					[Vector2i(-1, 0), "e"], [Vector2i(1, 0), "w"]]:
				var nt: Vector2i = Vector2i(x, y) + (d[0] as Vector2i)
				if nt.y < 0 or nt.y >= _grid.size():
					continue
				var nrow: String = _grid[nt.y]
				if nt.x < 0 or nt.x >= nrow.length() or not legend.has(nrow[nt.x]):
					continue
				var other := String(legend[nrow[nt.x]])
				if other == me:
					continue
				# 이웃이 나보다 세면 **이웃이 내 쪽으로** 넘친다
				if FRINGE_PRIO.get(other, 1) <= pm:
					continue
				var key := "%s-fr-%s" % [other, d[1]]
				if not by_tex.has(key):
					by_tex[key] = []
				by_tex[key].append(Vector2(x * TILE, y * TILE))

	for key in by_tex:
		var path := "res://assets/tiles/%s.png" % key
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		var quad := QuadMesh.new()
		quad.size = Vector2(TILE, TILE)
		mm.mesh = quad
		var spots: Array = by_tex[key]
		mm.instance_count = spots.size()
		for i in spots.size():
			mm.set_instance_transform_2d(i,
				Transform2D(0.0, (spots[i] as Vector2) + Vector2(TILE, TILE) * 0.5))
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture = tex
		mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ground.add_child(mmi)


# ── 형제 타일 ─────────────────────────────────────────────────────────
#
# 바닥 한 장을 지도 전체에 깔면, 이음매를 아무리 지워도 **같은 그림이
# 수백 번 반복되는 것**은 못 감춘다. 마을이 바닥재 견본처럼 보인다.
#
# `tools/pixel/make-tile-variants.py` 가 바닥마다 형제를 두세 장 만들어
# 둔다 — 꽃 핀 풀, 금 간 돌, 이끼 낀 돌담, 비질 자국이 난 마당.
# **열에 하나쯤만** 형제를 깐다. 자주 나오면 그게 다시 무늬가 된다.
const VARIANT_RATE := 0.17

var _variant_cache: Dictionary = {}

func _tile_for(base: String, x: int, y: int) -> String:
	if not _variant_cache.has(base):
		var found: Array = []
		for n in range(2, 5):
			var path := "res://assets/tiles/%s-%d.png" % [base, n]
			if ResourceLoader.exists(path):
				found.append("%s-%d" % [base, n])
		_variant_cache[base] = found
	var kinds: Array = _variant_cache[base]
	if kinds.is_empty():
		return base
	# 칸 좌표로 정해진 값. 켤 때마다 마당이 달라지면 안 된다.
	var h := (x * 374761393 + y * 668265263) ^ 0x27d4eb2d
	h = (h ^ (h >> 13)) * 1274126177
	var r := float(absi(h) % 1000) / 1000.0
	if r >= VARIANT_RATE:
		return base
	return String(kinds[absi(h >> 7) % kinds.size()])


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
		# 같은 이름이 겹치면 Godot 이 "@Sprite2D@105" 로 바꿔 버린다.
		# 사진이 노드 이름으로 소품을 찾다가 **같은 소품 둘째부터 전부
		# "풍경"** 이 됐다 (윤슬 62개 중 45개). 이름은 메타에 따로 담는다.
		s.set_meta("prop", name)
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 발 닿는 칸의 **아래 가운데**가 기준. 그래야 Y 정렬이 맞는다.
		s.position = Vector2(tx * TILE + TILE * 0.5, (ty + 1) * TILE)
		if name == "street-lamp":
			_add_lamp(s.position)
		s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		_props.add_child(s)

		if blocks:
			# 밑동만 막는다. 나무 꼭대기까지 막으면 뒤로 못 지나간다.
			var half: int = int(ceil(maxf(TILE, tex.get_width() * 0.7) * 0.5 / TILE))
			for bx in range(tx - half + 1, tx + half):
				_blocked[Vector2i(bx, ty)] = true
			var body := StaticBody2D.new()
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			var w: float = maxf(TILE, tex.get_width() * 0.7)
			r.size = Vector2(w, 8.0)
			cs.shape = r
			cs.position = s.position + Vector2(0, -4.0)
			body.add_child(cs)
			add_child(body)


## 주울 것을 뿌린다. 밟으면 주워진다 — 버튼을 안 누른다.
##
## 탑다운에서 작은 물건을 줍는 데 버튼을 요구하면, 지나갈 때마다 "여기
## 뭐 있었나" 하고 되돌아가게 된다. 밟으면 줍는 게 편하고, 벌이 없으니
## 실수로 주워도 손해가 없다.
func _build_pickups() -> void:
	var place := place_name()
	for entry in pickups():
		var t := Vector2i(entry[0], entry[1])
		var item: String = entry[2]
		if JourneyState.is_taken(place, t):
			continue
		var tex := load("res://assets/sprites/%s.png" % item) as Texture2D
		if tex == null:
			push_warning("주울 그림이 없다: %s" % item)
			continue

		var a := Area2D.new()
		a.name = "pick_%d_%d" % [t.x, t.y]
		a.position = world_of(t)
		a.monitoring = false          # 주인공 쪽에서 훑는다
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE, TILE)
		cs.shape = r
		cs.position = Vector2(0, -TILE * 0.5)
		a.add_child(cs)

		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		a.add_child(s)

		a.set_meta("item", item)
		a.set_meta("tile", t)
		_props.add_child(a)
		_loose.append(a)


## 발밑에 있는 것을 줍는다.
func _check_pickups() -> void:
	if walker == null or _loose.is_empty():
		return
	var here := walker.global_position
	for a in _loose.duplicate():
		if not is_instance_valid(a):
			_loose.erase(a)
			continue
		if here.distance_squared_to(a.global_position) > PICK_RANGE * PICK_RANGE:
			continue
		_loose.erase(a)
		var item: String = a.get_meta("item")
		var t: Vector2i = a.get_meta("tile")
		JourneyState.pick(item)
		AudioManager.pickup()
		JourneyState.mark_taken(place_name(), t)
		picked_up.emit(item)
		_pop(a)


## 주운 것이 위로 톡 떠올랐다 사라진다. 이게 없으면 그냥 없어진 것 같다.
func _pop(a: Node2D) -> void:
	for c in a.get_children():
		if c is CollisionShape2D:
			c.queue_free()
	var tw := create_tween()
	tw.tween_property(a, "position:y", a.position.y - 10.0, 0.28) \
		.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(a, "modulate:a", 0.0, 0.28)
	tw.tween_callback(a.queue_free)


## 지도 밖으로 못 나가게 벽을 두른다.
## 지도 바깥 테두리 + 걸을 수 없는 바닥.
##
## 물 칸은 하나씩 몸을 세우지 않고 **가로줄로 이어 붙인다.** 윤슬 바다가
## 200칸이 넘는데 칸마다 StaticBody2D 를 만들면 그것만으로 저사양 폰에
## 부담이 된다. 이어 붙이면 줄 수만큼(보통 10~20개)이면 된다.
func _build_walls() -> void:
	_build_solid_floor()
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


func _build_solid_floor() -> void:
	if solid_tiles.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "SolidFloor"
	add_child(body)
	for y in _grid.size():
		var row: String = _grid[y]
		var run := -1
		for x in range(row.length() + 1):
			var solid := false
			if x < row.length():
				var ch := row[x]
				solid = legend.has(ch) and solid_tiles.has(String(legend[ch]))
			if solid and run < 0:
				run = x
			elif not solid and run >= 0:
				var cs := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2((x - run) * TILE, TILE)
				cs.shape = r
				cs.position = Vector2((run + (x - run) * 0.5) * TILE,
					(y + 0.5) * TILE)
				body.add_child(cs)
				run = -1


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


func _build_ui() -> void:
	say = JourneySay.new()
	say.name = "Say"
	add_child(say)

	hud = JourneyHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.shutter.connect(_take_photo)
	hud.acted.connect(_on_action)
	hud.bag_toggled.connect(func(open: bool): if open: _did("bag"))

	# 말 걸 수 있는 사람 위에 뜨는 표시. 글자로 "말 걸기"라고 쓰지 않는다 —
	# 가까이 가면 뜨고 멀어지면 사라지는 것만으로 뜻이 통한다.
	# 표시 글자는 **굵은 한글 폰트에 있는 것만** 쓴다.
	# 처음엔 ❢ 🌙 🚏 를 썼는데 Jua 에 없어서 흰 네모나 이상한 모양이 떴다.
	_mark = Label.new()
	_mark.text = "!"
	_mark.add_theme_font_size_override("font_size", 14)
	_mark.add_theme_color_override("font_color", Color("#FFF2C8"))
	_mark.add_theme_color_override("font_outline_color", Color("#3A2C2C"))
	_mark.add_theme_constant_override("outline_size", 4)
	_mark.visible = false
	_mark.z_index = 50
	add_child(_mark)

	# 밤이 오면 화면이 어두워진다. 그림을 다시 그리지 않고 색만 덮는다.
	_night = CanvasModulate.new()
	_night.color = Color.WHITE
	add_child(_night)

	board = TravelBoard.new()
	board.name = "Board"
	add_child(board)

	# 처음 잡은 사람을 위한 안내. 다 해 보면 두 번 다시 안 나온다.
	guide = Guide.new()
	guide.name = "Guide"
	add_child(guide)

	# 미니맵. 설정 버튼 아래, 오른쪽 위.
	var mm_layer := CanvasLayer.new()
	# 설정(5)보다 **아래**. 위에 두면 설정을 열어 화면이 어두워져도
	# 미니맵만 밝게 떠서 깜빡이고, 그 위 누름이 설정을 뚫고 들어갔다.
	mm_layer.layer = 4
	add_child(mm_layer)
	var mm_root := Control.new()
	mm_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mm_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_layer.add_child(mm_root)
	JourneyHud.inset_safe(mm_root)
	get_viewport().size_changed.connect(func(): JourneyHud.inset_safe(mm_root))
	minimap = MiniMap.new()
	minimap.name = "MiniMap"
	minimap.place = self
	mm_root.add_child(minimap)

	# 설정. 여행 중에도 소리를 줄이고 메인화면으로 나갈 수 있어야 한다.
	#
	# 지금까지 설정은 메인화면 씬에만 붙어 있었다. 여행에 들어가면
	# 볼륨·기록 초기화·업데이트 확인이 전부 사라지고, 나가는 길도 없어서
	# 앱을 죽이는 것 말고는 메인화면으로 돌아갈 방법이 없었다.
	# `settings_ui.gd` 의 "메인화면으로" 버튼은 그동안 아무도 못 여는
	# 기능이었다 — 여행 씬에 설정이 없었으니까.
	_add_settings()

	var stop := depart_tile()
	_has_stop = stop.x >= 0
	if _has_stop:
		_depart_at = world_of(stop)

	var bed := sleep_tile()
	_has_bed = bed.x >= 0
	if _has_bed:
		_sleep_at = world_of(bed)

	# 잘 때 화면을 덮는 검은 막. CanvasLayer 에 둬야 카메라를 따라다닌다.
	var fl := CanvasLayer.new()
	fl.layer = 20
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)


# ── 소리 ──────────────────────────────────────────────────────────────
#
# 소리 만드는 코드는 처음부터 잘 짜여 있었는데 **부르는 쪽이 없었다.**
# 옛 게임을 지울 때 호출부만 같이 날아간 것으로 보인다. 걸어 다니는 게
# 전부인 게임에 발소리가 없었고, 환경음은 한 번도 난 적이 없는데
# 설정창의 슬라이더는 그 크기를 조절하고 있었다.

## 이 여행지에 깔리는 곡. 여행지 파일에서 덮어쓸 수 있다.
func bgm_track() -> String:
	match place_name():
		"잿마루": return "room"
		"고향": return "gohyang"
		"볕뉘": return "gaeguri"
		_:      return "doraji"


## 배경에 계속 나는 소리.
func ambient_kind() -> String:
	match place_name():
		"잿마루": return "room"
		"볕뉘": return "wind"
		"고향": return "wind"
		_:      return "wave"


func _start_sound() -> void:
	AudioManager.play_bgm(bgm_track())
	AudioManager.play_ambient(ambient_kind())


## 발소리. 걸음 사이 간격만큼 띄워서 낸다 — 매 프레임 내면 잡음이 된다.
## 걷기 그림 4프레임이 0.64초 한 바퀴, 그 사이 발이 두 번 닿는다.
## 그래서 0.32 다 — 0.34 로 두면 2.7초쯤 걸었을 때 소리와 발이 정반대가 된다.
const STEP_GAP := 0.32
var _step_t := 0.0

func _tick_footsteps(delta: float) -> void:
	# **실제로 나아갈 때만** 낸다. 벽에 막혀 제자리걸음이면 소리도 안 난다.
	if walker == null or not walker.is_moving():
		_step_t = STEP_GAP           # 멈춰 있으면 다음 걸음은 바로 난다
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = STEP_GAP
		AudioManager.footstep()


const SETTINGS_SCENE := "res://scenes/ui/SettingsUI.tscn"

func _add_settings() -> void:
	if get_tree().get_first_node_in_group("settings_ui") != null:
		return
	if not ResourceLoader.exists(SETTINGS_SCENE):
		return
	var sv = load(SETTINGS_SCENE).instantiate()
	add_child(sv)

	# 여는 버튼. 오른쪽 위 — 엄지가 잘 안 닿는 자리가 맞다.
	# 여행 중에 자주 누를 것이 아니고, 아래 두 모서리는 배낭과 사진이 쓴다.
	var cl := CanvasLayer.new()
	cl.layer = 6
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	# 이 버튼은 HUD 와 다른 층에 산다. HUD 의 안전영역 보정이 여기까지
	# 오지 않아서, 가로 모드에서 펀치홀이 오는 바로 그 자리에 맨살로
	# 붙어 있었다. 같은 계산을 여기서도 한다.
	JourneyHud.inset_safe(root)
	get_viewport().size_changed.connect(func(): JourneyHud.inset_safe(root))
	var b := Button.new()
	b.name = "SettingsBtn"
	b.text = "설정"
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(96, 72)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -128
	b.offset_top = 24
	b.offset_right = -32
	b.offset_bottom = 96
	b.modulate.a = 0.72
	b.pressed.connect(func() -> void:
		var sv2 = get_tree().get_first_node_in_group("settings_ui")
		if sv2 != null and sv2.has_method("open"):
			sv2.open())
	root.add_child(b)


## 시간이 흐른다. 대화 중이거나 배낭을 열어 두면 멈춘다 —
## 읽는 동안 해가 지면 급해진다.
func _tick_clock(delta: float) -> void:
	# 시계만 멈춘다. 색은 늘 따라간다 — 처음엔 둘을 같이 멈췄더니
	# 대화 중에 시간을 건너뛰면 화면이 낮인 채로 굳었다.
	var paused := (say != null and say.is_busy()) \
		or (hud != null and hud.bag_open())
	if not paused:
		JourneyState.advance_time(delta * MINUTES_PER_SECOND)
	if _night != null:
		_night.color = sky_tint(JourneyState.minutes)
	_tick_lamps()


## 밟고 선 바닥이 어두운지 본다.
##
## 캐릭터를 배경에서 떼어 놓는 건 사실상 테두리 하나인데, 그 테두리가
## 어두운 색이라 현무암·밭고랑 위에서는 같이 묻혔다 (1.6:1).
var _dark_floor := false
const DARK_TILES := ["basalt", "tilled-soil"]

func _tick_outline() -> void:
	if walker == null:
		return
	var w := walker.global_position
	var t := Vector2i(int(floor(w.x / TILE)), int(floor((w.y - 1.0) / TILE)))
	var dark := false
	if t.y >= 0 and t.y < _grid.size():
		var row: String = _grid[t.y]
		if t.x >= 0 and t.x < row.length():
			var ch := row[t.x]
			dark = legend.has(ch) and DARK_TILES.has(String(legend[ch]))
	if dark != _dark_floor:
		_dark_floor = dark
		walker.set_on_dark_ground(dark)


# ── 하늘빛 ────────────────────────────────────────────────────────────
#
# 예전엔 흰색에서 남색으로 곧장 섞었다. 그러면 **따뜻한 구간이 한
# 프레임도 없다** — 재 보니 R−B 가 첫 순간부터 계속 음수였다. 해가 지는
# 게 아니라 화면이 파래지기만 했다.
#
# 노을은 파래지기 **전에** 한 번 붉어진다. 그 구간이 이 게임에서 제일
# 예쁠 자리인데 통째로 없었다. 시각별로 색을 찍어 두고 사이를 잇는다.
const SKY := [
	# 아침. 예전엔 표가 16시부터 시작이라 7시가 정오와 똑같은 순백이었다 —
	# 하루의 절반에 무드가 없었다. 푸른 새벽에서 살구빛으로 풀린다.
	[6.0, Color(0.78, 0.82, 0.96)],    # 푸른 새벽
	[7.2, Color(1.00, 0.93, 0.84)],    # 살구빛 아침
	[9.0, Color(1.00, 1.00, 1.00)],    # 낮
	[16.0, Color(1.00, 1.00, 1.00)],   # 아직 낮
	[17.0, Color(1.00, 0.96, 0.88)],   # 볕이 노래진다
	[18.0, Color(1.00, 0.87, 0.72)],   # 금빛. 가장 따뜻한 지점
	[18.7, Color(1.00, 0.78, 0.70)],   # 노을 산호빛
	[19.4, Color(0.82, 0.68, 0.76)],   # 보랏빛 박명
	[20.0, Color(0.60, 0.58, 0.78)],   # 남빛으로 넘어간다
	[21.0, Color(0.40, 0.44, 0.66)],   # 밤 도착점
]


func sky_tint(mins: float) -> Color:
	var h := mins / 60.0
	if h <= float(SKY[0][0]):
		return SKY[0][1]
	for i in range(1, SKY.size()):
		var t1: float = SKY[i][0]
		if h <= t1:
			var t0: float = SKY[i - 1][0]
			var k: float = (h - t0) / maxf(t1 - t0, 0.0001)
			return (SKY[i - 1][1] as Color).lerp(SKY[i][1], k)
	return SKY[SKY.size() - 1][1]


# ── 가로등 ────────────────────────────────────────────────────────────
#
# 전구가 그림에 이미 그려져 있는데 `CanvasModulate` 가 그것까지 곱한다.
# 재 보니 **낮보다 밤에 5.7배 어두웠다** — 켜져야 할 때 가장 어두웠다.
# 빛을 더해서(ADD) 눌린 밝기를 되살린다. 낮에는 세기가 0 이라 꺼져 보인다.
var _lamps: Array = []

func _add_lamp(at: Vector2) -> void:
	var l := PointLight2D.new()
	l.texture = _lamp_glow()
	# 처음엔 지름 24칸 · 세기 1.15 로 뒀더니 등 네 개가 합쳐져 **한낮보다
	# 밝은 흰 덩어리**가 마을 절반을 덮었다. 가로등은 제 발치나 비추면
	# 된다 — 눈에 띄면 과한 것이다.
	l.texture_scale = 1.4
	l.color = Color(1.0, 0.86, 0.58)
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.position = at + Vector2(0, -22)
	l.energy = 0.0
	add_child(l)
	_lamps.append(l)


static var _glow_tex: Texture2D

func _lamp_glow() -> Texture2D:
	if _glow_tex != null:
		return _glow_tex
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex


func _tick_lamps() -> void:
	if _lamps.is_empty():
		return
	var e: float = smoothstep(0.15, 0.75, JourneyState.night_amount()) * 0.55
	for l in _lamps:
		if is_instance_valid(l):
			l.energy = e


## 사진을 찍는다.
##
## 화면을 그림으로 저장하지 않는다. 남는 건 결국 **어디서 언제 무엇을
## 봤는지** 한 줄이고, 픽셀 화면을 통째로 담으면 용량만 분다.
## 지금 눈앞에 뭐가 있는지를 대신 적는다.
func _take_photo() -> void:
	if walker == null:
		return
	var subject := _what_is_near()
	JourneyState.take_photo(place_name(), subject)
	AudioManager.shutter()
	if hud != null:
		hud.flash()
	SaveManager.save_now()


func _what_is_near() -> String:
	# 사람이 가까이 있으면 사람을, 없으면 눈에 띄는 물건을 적는다.
	if _near != null and is_instance_valid(_near):
		return _near.who
	# **이름이 있는 것 중에서** 가장 가까운 것을 고른다. 예전엔 무조건
	# 가장 가까운 스프라이트를 집고 이름이 없으면 "풍경"으로 덮어서,
	# 좌판 셋 한가운데서 찍어도 "풍경"이 나왔다.
	var best := ""
	var gap := 90.0 * 90.0
	if _props != null:
		for c in _props.get_children():
			if not (c is Sprite2D) or not c.has_meta("prop"):
				continue
			var pn := String(PHOTO_NAMES.get(String(c.get_meta("prop")), ""))
			if pn == "":
				continue
			var d := walker.global_position.distance_squared_to(c.global_position)
			if d < gap:
				gap = d
				best = pn
	return best if best != "" else "풍경"


## 사진에 적을 이름. 없는 건 "풍경"으로 뭉뚱그린다.
const PHOTO_NAMES := {
	"lighthouse": "등대", "guesthouse": "쿼스텔", "shop": "가게",
	"stall": "좌판", "home-house": "집", "home-persimmon": "감나무",
	"home-deck": "평상", "home-garden": "밭", "jars": "장독대",
	"clothesline": "빨랫줄", "pump": "펌프", "parasol": "파라솔",
	"mailbox": "우체통", "bench": "벤치", "pine": "소나무", "tree": "나무",
	"boulder": "바위", "net": "그물", "buoy": "부표", "dock": "부두",
	"street-lamp": "가로등", "signpost": "표지판", "firewood": "장작",
	"flower-pots": "화분", "fence": "울타리", "shrub": "덤불",
	"pebbles": "조약돌", "beach-grass": "갯풀", "tools": "연장",
	"washtub": "빨래통", "icebox": "아이스박스", "desk": "책상",
	"cabinet": "캐비닛", "reception": "접수대", "return-box": "반납함",
	"office-chair": "의자", "office-window": "창",
	"asphalt": "찻길", "burial-mound": "능", "stone-wall": "돌담",
	"retaining-wall": "축대",
}


## 가장 가까운 인연을 찾아 표시를 띄운다.
func _update_near() -> void:
	_near = null
	if walker == null:
		return
	# **한 번 잡으면 조금 더 붙들고 있는다.**
	#
	# 26px 딱 자르고 되돌림이 없으면, 인연 둘이 네 칸 안에 서 있을 때
	# 그 사이가 깜빡임이 된다 — 마을길을 한 번 걷는 8초 동안 선택
	# 버튼이 다섯 번 켜졌다 꺼졌다. 놓는 거리를 조금 넉넉히 둔다.
	var keep := _prev_near
	var best := TALK_RANGE * TALK_RANGE
	for f in _folk:
		if not is_instance_valid(f):
			continue
		var d := walker.global_position.distance_squared_to(f.global_position)
		if d < best:
			best = d
			_near = f
	if _near == null and keep != null and is_instance_valid(keep):
		var far := TALK_RANGE * 1.45
		if walker.global_position.distance_squared_to(keep.global_position) < far * far:
			_near = keep
	_prev_near = _near
	if _mark == null:
		return
	var busy := say != null and say.is_busy()
	if _near != null and not busy:
		_mark.visible = true
		_mark.text = "!"
		_mark.global_position = _near.global_position + Vector2(-3, -40)
	elif _can_sleep() and not busy:
		_mark.visible = true
		_mark.text = "잠"
		_mark.global_position = _sleep_at + Vector2(-26, -40)
	elif _can_depart() and not busy:
		_mark.visible = true
		_mark.text = "출발"
		_mark.global_position = _depart_at + Vector2(-26, -40)
	else:
		_mark.visible = false


## 잘 자리에 서 있나. **밤이 아니어도 잘 수 있다** — 낮잠도 여행이다.
func _can_sleep() -> bool:
	if not _has_bed or walker == null:
		return false
	return walker.global_position.distance_squared_to(_sleep_at) \
		< TALK_RANGE * TALK_RANGE


func _can_depart() -> bool:
	if not _has_stop or walker == null or board == null or board.visible:
		return false
	return walker.global_position.distance_squared_to(_depart_at) \
		< TALK_RANGE * TALK_RANGE


## 자고 다음 날. 하루가 끝나는 유일한 방법이다 —
## 밤을 새워도 벌이 없고, 그냥 밤 풍경을 계속 본다.
func go_to_sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	walker.stop()
	stop_walk_to()
	_did("sleep")
	AudioManager.sit_rustle()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		JourneyState.sleep()
		for f in _folk:
			if is_instance_valid(f):
				f.reset_day()
		walker.global_position = world_of(spawn_tile())
		# 화면이 깜깜한 지금이 자리를 옮길 때다. 아침 자리로.
		_relocate_folk(true))
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 0.0, 0.7)
	tw.tween_callback(func():
		_sleeping = false
		slept.emit(JourneyState.day))


func talk_to_near() -> void:
	if _near == null or say == null or say.is_busy():
		return
	var f := _near
	# 서로 마주 본다. 등을 보고 말하면 이상하다.
	var dir := (walker.global_position - f.global_position).normalized()
	f.face(dir)
	walker.face(-dir)
	walker.stop()
	# **대사를 먼저 고르고** 마음을 올린다. 순서를 바꾸면 처음 만난
	# 사람이 두 칸째 대사를 하고, 첫인사를 영영 못 듣는다.
	var what := f.lines()
	f.on_talked()
	# 마음을 다 채우면 엽서를 준다. 떠난 뒤에도 편지가 온다는 뜻이다.
	if f.heart() >= JourneyState.HEART_MAX:
		JourneyState.give_postcard(f.folk_id, f.who)
	say.say(f.who, what)
	_did("talk")
	talked.emit(f.folk_id)


func _unhandled_input(e: InputEvent) -> void:
	if say != null and say.is_busy():
		return
	# 설정이 떠 있으면 세계는 아무것도 안 받는다. 이게 없으면 설정 위를
	# 누른 것이 창을 닫으면서 **동시에** 그 밑 미니맵까지 펼쳤다.
	var sv := get_tree().get_first_node_in_group("settings_ui")
	if sv != null and sv.visible:
		return
	if _sleeping or (board != null and board.visible):
		return
	# 확대하려고 댄 두 번째 손가락이 대화를 열어 버리곤 했다.
	if touch != null and touch.has_method("is_multi") and touch.is_multi():
		return
	# 손가락 하나가 터치와 흉내낸 마우스로 **두 번** 온다. 하나만 받는다.
	if JourneyHud.is_echo(e):
		return
	# e 는 InputEvent 라 e.pressed 가 Variant 다. 타입을 적어 준다 —
	# 안 적으면 추론이 안 돼 파일 전체가 컴파일에 실패한다.
	var tap: bool = (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed
			and e.button_index == MOUSE_BUTTON_LEFT) \
		or e.is_action_pressed("ui_accept")
	if not tap:
		return

	# 미니맵이 먼저다. 누르면 켜지고 꺼진다 (펼친 채 바깥을 눌러도 닫힌다).
	#
	# **`tap` 판정 뒤에 둔다.** 누를 때와 뗄 때가 둘 다 오는데 앞에 두면
	# 눌러서 켜고 떼면서 다시 꺼서, 폰에서 아무 일도 안 일어나 보인다.
	var scr := _touch_screen(e)
	if minimap != null and scr != Vector2.INF and minimap.try_touch(scr):
		_did("map")
		get_viewport().set_input_as_handled()
		return
	# 배낭을 열어 놓고 딴 데를 누르면 닫는다. 거의 반사에 가까운 동작이라
	# 아무 일도 안 일어나면 잠긴 것처럼 느껴진다.
	if hud != null and hud.bag_open():
		hud.close_bag()
		get_viewport().set_input_as_handled()
		return

	var at := _touch_world(e)
	# ① 누른 자리에 인연이 서 있으면 말을 건다.
	#
	# 예전엔 **가까이 있기만 하면** 화면 아무 데나 눌러도 대화가 열렸다.
	# 그래서 인연 옆을 지나가려고 땅을 눌렀는데 말이 걸리곤 했다.
	# 이제는 **그 사람을 직접 눌러야** 한다.
	var who := _folk_at(at)
	if who != null:
		# **앞에 가서** 눌러야 말이 걸린다. 멀리서 누르면 그 앞까지
		# 걸어간다 — 가서 한 번 더 누르면 그때 말이 걸린다.
		# 저절로 말이 시작되게 하지 않는다. 다가가는 것과 말을 거는 것은
		# 다른 마음이고, 그 사이를 사람이 정하는 편이 이 게임에 맞는다.
		if walker.global_position.distance_to(who.global_position) <= TALK_RANGE:
			stop_walk_to()
			_near = who
			talk_to_near()
		else:
			walk_to(_beside(who))
		get_viewport().set_input_as_handled()
		return
	# ② 잠자리·정류장은 **그 자리를 눌렀을 때만.**
	#
	# 예전엔 서 있기만 하면 화면 아무 데나 눌러도 자거나 여행판이 떴다.
	# "가고 싶은 곳을 톡 누르세요" 라고 가르쳐 놓고 그 두 칸 위에서만
	# 딴 짓을 하는 셈이었고, 숙소 앞에서 걸어가려다 **하루가 통째로
	# 넘어가** 되돌릴 수도 없었다. 멀리 누르면 그냥 걸어간다.
	if _can_sleep() and _near_tile(at, sleep_tile()):
		go_to_sleep()
		get_viewport().set_input_as_handled()
		return
	if _can_depart() and _near_tile(at, depart_tile()):
		walker.stop()
		stop_walk_to()
		board.open(place_name())
		_did("go")
		get_viewport().set_input_as_handled()
		return
	# ③ 그 밖에는 **누른 자리로 걸어간다.**
	if at != Vector2.INF:
		walk_to(at)
		if is_walking_to():
			_did("walk")
		get_viewport().set_input_as_handled()


## 누른 자리가 그 칸 언저리인가. 손가락 크기만큼 넉넉히 잡는다.
func _near_tile(at: Vector2, t: Vector2i) -> bool:
	if t.x < 0 or at == Vector2.INF:
		return true            # 키보드로 눌렀으면 서 있는 것만으로 친다
	return world_of(t).distance_to(at) <= TILE * 1.6


## 누른 화면 좌표. 키보드로 눌렀으면 INF.
func _touch_screen(e: InputEvent) -> Vector2:
	if e is InputEventScreenTouch:
		return (e as InputEventScreenTouch).position
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).position
	return Vector2.INF


## 화면에서 누른 자리를 세계 좌표로. 못 구하면 INF.
##
## **엔진이 실제로 쓰는 변환을 그대로 뒤집는다.** 예전엔 카메라 위치와
## 줌으로 직접 계산했는데, 그러면 **카메라가 지도 끝에서 멈출 때** 어긋난다.
## `limit_*` 로 막히면 화면에 그려지는 자리는 멈추지만 `global_position`
## 은 목표를 따라 계속 움직이기 때문이다. 마을 가장자리로 갈수록 누른
## 데가 아니라 엉뚱한 데로 걸어갔다 — 폰에서 바로 티가 나는 사고다.
##
## `get_canvas_transform()` 은 카메라 한계·줌·화면 늘이기까지 이미 다
## 반영된 값이라, 이걸 뒤집으면 언제나 맞는다.
func _touch_world(e: InputEvent) -> Vector2:
	var pos := _touch_screen(e)
	if pos == Vector2.INF or get_viewport() == null:
		return Vector2.INF
	return get_viewport().get_canvas_transform().affine_inverse() * pos


# ── 누른 자리 표시 ────────────────────────────────────────────────────
#
# 먼 데를 누르면 그리로 걸어가는데, **진짜 그리로 가는 중인지 알 방법이
# 걸어가는 것 말고 없었다.** 눌린 자리에 동그라미를 잠깐 남긴다.
var _tap_mark: Node2D
var _tap_t := 0.0

func _mark_tap(at: Vector2) -> void:
	if _tap_mark == null:
		_tap_mark = Node2D.new()
		_tap_mark.z_index = 40
		_tap_mark.draw.connect(func() -> void:
			var k: float = clampf(_tap_t / TAP_MARK_TIME, 0.0, 1.0)
			var a: float = k * 0.7
			_tap_mark.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			_tap_mark.draw_arc(Vector2.ZERO, 5.0 + (1.0 - k) * 7.0, 0.0, TAU, 20,
				Color(1.0, 0.96, 0.86, a), 1.6, true))
		add_child(_tap_mark)
	_tap_mark.position = at
	_tap_t = TAP_MARK_TIME
	_tap_mark.visible = true


const TAP_MARK_TIME := 0.45

func _tick_tap_mark(delta: float) -> void:
	if _tap_mark == null or not _tap_mark.visible:
		return
	_tap_t -= delta
	if _tap_t <= 0.0:
		_tap_mark.visible = false
	_tap_mark.queue_redraw()


# ── 인연 시간표 ──────────────────────────────────────────────────────
#
# 아침에는 마당을 쓸고, 낮에는 가게 앞에 서고, 저녁에는 벤치에 앉는다 —
# 자리만 바뀌어도 마을이 산다. 걷게 하지 않는다 (길찾기·충돌까지
# 딸려 와서 값이 크다). 대신 **보고 있지 않을 때만** 옮긴다.
# 화면 안에서 순간이동하면 유령이 된다.

## 지금이 하루 중 언제인가.
func day_part() -> String:
	var h := JourneyState.minutes / 60.0
	if h < 11.0:
		return "아침"
	if h < 17.0:
		return "낮"
	return "저녁"


var _sched_t := 0.0

func _tick_schedule(delta: float) -> void:
	_sched_t += delta
	if _sched_t < 1.0:
		return
	_sched_t = 0.0
	_relocate_folk(false)


## 시간표 자리로 옮긴다. force 면 보이든 말든 옮긴다 — **화면이 깜깜할 때**
## (잘 때) 부른다. 고향처럼 작은 지도는 가족이 늘 화면 안이라, 안 보일
## 때를 기다리면 하루 종일 아침 자리에 서 있게 된다.
func _relocate_folk(force: bool) -> void:
	var part := day_part()
	var moved := false
	for f in _folk:
		if not is_instance_valid(f) or f.is_spot or f.schedule.is_empty():
			continue
		var want: Vector2i = f.schedule.get(part, Vector2i(-1, -1))
		if want.x < 0 or tile_of(f.global_position) == want:
			continue
		if not force:
			if f == _near or (say != null and say.is_busy()):
				continue                   # 말 섞는 중엔 안 움직인다
			if _on_screen(f.global_position) or _on_screen(world_of(want)):
				continue                   # 보고 있으면 다음 기회에
		f.global_position = world_of(want)
		f.face(Vector2.DOWN)
		moved = true
	if moved:
		_block_folk_tiles()                # 길찾기의 막힌 칸도 따라간다


func _on_screen(w: Vector2) -> bool:
	if cam == null:
		return false
	var half := get_viewport().get_visible_rect().size / (2.0 * cam.zoom.x)
	var d := w - cam.global_position
	return absf(d.x) <= half.x + 24.0 and absf(d.y) <= half.y + 24.0


# ── 같이 노을 보기 ────────────────────────────────────────────────────
#
# 마음을 채우는 길이 "말 걸기 → 자기" 반복 하나뿐이었다. 그런데 4칸
# 대사에 "같이 노을 볼래요?" 가 네 마을 전부 들어 있으면서 **실제로는
# 아무 일도 일어나지 않았다** — 말로만 하는 약속이었다.
#
# 노을 질 무렵(17~19시) 인연 옆에 **가만히** 서 있으면, 30초 뒤에
# 마음이 한 칸 는다. 버튼도 알림도 없다. 둘이 같은 쪽을 보고 서 있는
# 것으로만 안다. 아무것도 안 하는 시간이 이 게임에서는 하는 일이다.
var _dusk_t := 0.0

func _tick_dusk(delta: float) -> void:
	if _near == null or _near.is_spot or _near._dusk_warmed:
		_dusk_t = 0.0
		return
	var h := JourneyState.minutes / 60.0
	if h < 17.0 or h > 19.0:
		_dusk_t = 0.0
		return
	if (walker != null and walker.is_moving()) \
			or (say != null and say.is_busy()) \
			or (hud != null and hud.bag_open()):
		_dusk_t = 0.0
		return
	_dusk_t += delta
	if _dusk_t >= 30.0:
		_dusk_t = 0.0
		_near._dusk_warmed = true
		JourneyState.warm(_near.folk_id)
		# 그 사람이 나와 같은 쪽 — 노을 쪽을 본다. 그게 답이다.
		_near.face(Vector2.LEFT)
		if walker != null:
			walker.face(Vector2.LEFT)


## 안내가 기다리던 일을 해냈다고 알린다.
func _did(what: String) -> void:
	if guide != null and is_instance_valid(guide):
		guide.done(what)


# ── 선택 버튼 ─────────────────────────────────────────────────────────
#
# 오른쪽 아래 버튼 하나가 지금 할 수 있는 일을 맡는다. 화면을 눌러서도
# 다 되지만, 누를 곳을 찾는 것과 누를 것이 거기 있는 것은 다르다.

func _refresh_action() -> void:
	if hud == null:
		return
	if say != null and say.is_busy():
		hud.set_action("next", "다음")
		return
	if hud.bag_open() or (board != null and board.visible) or _sleeping \
			or (minimap != null and minimap.is_big()):
		hud.set_action("", "")
		return
	if _near != null:
		hud.set_action("talk", "보기" if _near.is_spot else "말 걸기")
		return
	if _can_sleep():
		hud.set_action("sleep", "자기")
		return
	if _can_depart():
		hud.set_action("depart", "떠나기")
		return
	hud.set_action("", "")


func _on_action() -> void:
	_did("act")
	match hud.action_kind():
		"next":
			if say != null:
				say.advance()
		"talk":
			stop_walk_to()
			talk_to_near()
		"sleep":
			go_to_sleep()
		"depart":
			walker.stop()
			stop_walk_to()
			board.open(place_name())
			_did("go")


## 그 사람 **옆에** 설 자리. 몸 위로 걸어 들어가면 밀려난다.
##
## 인연은 제가 선 칸과 그 아랫칸을 막는다. 그래서 단순히 "나 쪽으로
## 조금" 만 잡으면 **그 막힌 칸이 나올 때가 있고**, 그러면 길찾기가
## 빈 배열을 돌려줘 다가가기 자체가 실패한다. 걸을 수 있는 칸이 나올
## 때까지 조금씩 물러나며 찾는다.
func _beside(f: Folk) -> Vector2:
	var from := walker.global_position
	var d := (from - f.global_position)
	if d.length() < 1.0:
		d = Vector2.RIGHT
	d = d.normalized()
	# **말 걸 수 있는 거리 안**을 먼저 찾는다. 멀리 세워 두면 다가가긴
	# 하는데 도착해서 말을 못 건다 — 그게 더 답답하다.
	#
	# 거리를 `TALK_RANGE` 의 비율로 잡으면 안 된다. 그러면 말 걸 수 있는
	# 거리를 넓힐 때 서는 자리도 같이 멀어져서 **영원히 1px 모자란다.**
	# 도착 여유(`ARRIVE`)까지 빼고 남는 만큼을 픽셀로 못 박는다.
	var near: float = TALK_RANGE - ARRIVE - 2.0
	var tries: Array = [d * 14.0, d * minf(20.0, near), d * near]
	for a in range(8):
		tries.append(Vector2.RIGHT.rotated(TAU * a / 8.0) * minf(20.0, near))
	# 그래도 없으면 조금 물러선다. 못 가는 것보다는 낫다.
	tries.append(d * (TALK_RANGE + 8.0))
	tries.append(d * (TALK_RANGE + 20.0))
	for v in tries:
		var at: Vector2 = f.global_position + (v as Vector2)
		if _walkable(tile_of(at)):
			return at
	return f.global_position + d * (TALK_RANGE * 0.6)


## 그 자리에 서 있는 인연. 눌러야 할 만큼 가까우면 돌려준다.
##
## 화면에 그려진 크기가 아니라 **손가락 크기**를 기준으로 잡는다.
## 24px 짜리 쿼카를 정확히 눌러야 한다면 아무도 못 누른다.
const TOUCH_SLACK := 14.0

func _folk_at(at: Vector2) -> Folk:
	if at == Vector2.INF:
		return null
	var best := INF
	var found: Folk = null
	for f in _folk:
		if not is_instance_valid(f):
			continue
		# 발끝이 원점이라 몸통은 그 위에 있다.
		var body := f.global_position + Vector2(0, -12)
		var d := body.distance_to(at)
		if d < TOUCH_SLACK + 8.0 and d < best:
			best = d
			found = f
	return found


# ── 눌러서 걷기 ────────────────────────────────────────────────────────
#
# 톡 누르면 그 자리로 **알아서 간다.** 손가락으로 미는 조작도 그대로
# 남아 있다 — 밀면 그쪽이 우선이고, 가던 길은 접는다.
#
# 처음엔 직선으로만 갔다. 마을이 트여 있으니 대개 닿긴 했는데,
# **벤치 모서리 하나에 걸려 제자리에 서 버렸다.** 옆으로 한 발 돌아 보게
# 해도 집 뒤로 돌아가야 하는 자리는 못 갔다. 누른 사람에게는 그냥
# 고장으로 보인다. 그래서 **길을 찾는다.**
#
# 지도가 44x20 칸이라 A* 를 매번 돌려도 싸다. 미리 만들어 둘 것도 없다.
var _path: Array[Vector2] = []
const REACH := 5.0            # 길목에 이만큼 닿으면 다음 길목으로
const ARRIVE := 4.0           # 마지막 자리에 이만큼 닿으면 도착


func walk_to(at: Vector2) -> void:
	_path.clear()
	if walker == null:
		return
	var from := tile_of(walker.global_position)
	var to := tile_of(at)
	if not _walkable(to):
		to = _nearest_walkable(to)
		if to.x < 0:
			return
	var tiles := _find_path(from, to)
	if tiles.is_empty():
		return
	for t in tiles:
		_path.append(world_of(t) - Vector2(0, TILE * 0.5))
	# 마지막은 누른 자리 그대로. 칸 가운데로 끌려가면 어긋나 보인다.
	if _walkable(tile_of(at)):
		_path[_path.size() - 1] = at
	_mark_tap(_path[_path.size() - 1])


func stop_walk_to() -> void:
	_path.clear()


func is_walking_to() -> bool:
	return not _path.is_empty()


func tile_of(w: Vector2) -> Vector2i:
	return Vector2i(int(floor(w.x / TILE)), int(floor((w.y - 1.0) / TILE)))


func _walkable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.y >= _grid.size():
		return false
	var row: String = _grid[t.y]
	if t.x >= row.length():
		return false
	var ch := row[t.x]
	if not legend.has(ch):
		return false
	if solid_tiles.has(String(legend[ch])):
		return false
	return not _blocked.has(t)


## 누른 곳이 물이나 소품 위면 **가장 가까운 걸을 수 있는 칸**으로 보낸다.
## 못 가는 곳을 눌렀다고 아무 반응이 없으면 고장으로 읽힌다.
##
## 링을 훑다 처음 걸리는 것을 쓰면 안 된다 — 그건 링 안에서 **위쪽·왼쪽**
## 칸이라 바다를 눌렀을 때 바로 아래 백사장이 아니라 옆으로 여섯 칸
## 비켜난 데로 갔다 (실측 최대 98px). 링을 다 훑어 **진짜 가까운 것**을 쓴다.
func _nearest_walkable(t: Vector2i) -> Vector2i:
	for r in range(1, 7):
		var best := Vector2i(-1, -1)
		var gap := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := t + Vector2i(dx, dy)
				if not _walkable(c):
					continue
				var d := Vector2(dx, dy).length_squared()
				if d < gap:
					gap = d
					best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## 인연이 선 칸을 길찾기가 피해 가게 한다.
##
## A* 는 소품만 알고 인연(Folk)을 몰랐다. 그래서 톡 눌러 걷기가 인연을
## 뚫고 직진하다 몸에 박혀 **초당 2px 로 인연을 밀며 기어갔다** — 볕뉘
## 검사에서 자고 일어나 정류장 가는 길이 매일 막히는 걸 실측으로 잡았다.
## 인연은 제자리에 서 있으니, 그 칸을 막힌 칸으로 등록하면 끝이다.
## `_blocked` 에도 넣어야 곧게 펴기(`_clear_line`)가 그 사람을 안 뚫는다.
var _folk_blocked: Array = []

func _block_folk_tiles() -> void:
	# 인연이 시간표 따라 옮겨 다니므로, 먼저 지난 자리를 푼다.
	for bt in _folk_blocked:
		_blocked.erase(bt)
		if _astar != null and _astar.region.has_point(bt):
			_astar.set_point_solid(bt, false)
	_folk_blocked.clear()
	for f in _folk:
		if not is_instance_valid(f) or f.is_spot:
			continue
		var t := tile_of(f.global_position)
		# **바로 아랫칸도 막는다.** 둘 다 발밑에 콜라이더가 있어서, 그 사람
		# 아랫칸을 스치는 직선은 몸이 8px 겹친다 — 칸만 막았더니 여전히
		# 그 사람 발치에 박혀 기어갔다. 사람을 한 칸 돌아가는 게 보기에도
		# 자연스럽다.
		for bt in [t, t + Vector2i(0, 1)]:
			_folk_blocked.append(bt)
			_blocked[bt] = true
			if _astar != null and _astar.region.has_point(bt):
				_astar.set_point_solid(bt, true)


# ── 길찾기 ────────────────────────────────────────────────────────────
#
# 손으로 짠 A* 를 쓰다 `AStarGrid2D` 로 바꿨다. 손으로 짠 쪽은 열린 목록이
# 그냥 배열이라 매번 전체를 훑었다 — O(n²). 데스크톱에서 재 보니 고향에서
# **최악 19~27ms**, 잿마루 41ms 로 이미 한 프레임을 넘었고, 폰은 그보다
# 서너 배 느리다. 누른 바로 그 순간 멈칫하는 자리다.
#
# `AStarGrid2D` 는 엔진 안(C++)에서 돌고 격자를 미리 물고 있는다.
var _astar: AStarGrid2D


func _build_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _size.x, _size.y)
	_astar.cell_size = Vector2(TILE, TILE)
	# 모서리를 뚫고 지나가지 않는다. 그림상 벽을 통과한 것처럼 보인다.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in _size.y:
		for x in _size.x:
			_astar.set_point_solid(Vector2i(x, y), not _walkable(Vector2i(x, y)))


func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if _astar == null or from == to or not _walkable(to):
		return []
	if not _walkable(from):
		from = _nearest_walkable(from)
		if from.x < 0:
			return []
	var pts := _astar.get_id_path(from, to)
	if pts.size() < 2:
		return []
	pts.remove_at(0)                       # 서 있는 칸은 뺀다
	return _smooth(pts)


## 곧게 갈 수 있으면 사이 길목을 버린다 (line of sight).
##
## 예전에는 **방향이 똑같은 연속 칸만** 합쳤다. A* 가 만드는 계단은
## 직선 한 칸 → 대각 한 칸 → 직선 한 칸이라 방향이 매 칸 바뀌어서
## 하나도 안 합쳐졌고, 길 하나에 꺾임이 여섯 개씩 남아 걸음이 잔물결처럼
## 흔들렸다 (구간의 55~62% 가 한 칸 반도 안 됐다).
func _smooth(tiles: Array) -> Array:
	if tiles.size() < 3:
		return tiles
	var out: Array = []
	var anchor: Vector2i = tile_of(walker.global_position) if walker != null \
		else tiles[0]
	var i := 0
	while i < tiles.size():
		var far := i
		for j in range(tiles.size() - 1, i - 1, -1):
			if _clear_line(anchor, tiles[j]):
				far = j
				break
		out.append(tiles[far])
		anchor = tiles[far]
		i = far + 1
	return out


## 두 칸 사이가 다 트여 있나. 칸을 하나씩 밟아 본다.
func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var steps: int = maxi(absi(d.x), absi(d.y))
	if steps == 0:
		return true
	for k in range(1, steps + 1):
		var t := Vector2i(
			a.x + int(round(float(d.x) * k / steps)),
			a.y + int(round(float(d.y) * k / steps)))
		if not _walkable(t):
			return false
		# 대각선으로 스칠 때 양옆도 본다 — 모서리를 뚫으면 안 된다.
		if not _walkable(Vector2i(t.x, a.y + int(round(float(d.y) * (k - 1) / steps)))) \
				and not _walkable(Vector2i(a.x + int(round(float(d.x) * (k - 1) / steps)), t.y)):
			return false
	return true


var _goto_stuck := 0.0

func _tick_goto(delta: float) -> Vector2:
	if _path.is_empty() or walker == null:
		return Vector2.ZERO
	var here := walker.global_position
	var goal: Vector2 = _path[0]
	var to := goal - here
	var near: float = ARRIVE if _path.size() == 1 else REACH
	if to.length() <= near:
		_path.remove_at(0)
		_goto_stuck = 0.0
		if _path.is_empty():
			return Vector2.ZERO
		to = _path[0] - here
	# 곧게 편 길이 소품 콜라이더 모서리를 스칠 때가 있다. 벽에 대고
	# 비비고 있으면 그 길목을 버리고 다음 길목으로 — 그래도 안 되면
	# 길을 처음부터 다시 찾는다. 화면에서는 어깨를 트는 정도로 보인다.
	if walker.is_moving():
		_goto_stuck = 0.0
	else:
		_goto_stuck += delta
		if _goto_stuck > 0.4:
			_goto_stuck = 0.0
			if _path.size() > 1:
				_path.remove_at(0)
				to = _path[0] - here
			else:
				var again: Vector2 = _path[0]
				stop_walk_to()
				walk_to(again)
				return Vector2.ZERO
	# **살살 선다.** 예전엔 `to.limit_length(1.0)` 를 썼는데 그건 길이를
	# 1 이하로 자르는 것이라, 1px 만 넘으면 결과가 늘 정확히 1.0 이었다 —
	# `normalized()` 와 똑같아서 감속이 아무 일도 안 했다.
	var k: float = clampf(to.length() / 22.0, 0.28, 1.0)
	return to.normalized() * k


func _process(delta: float) -> void:
	var blocked := (say != null and say.is_busy()) \
		or (hud != null and hud.bag_open()) or _sleeping \
		or (board != null and board.visible) \
		or (minimap != null and minimap.is_big())
	if walker != null and touch != null:
		if blocked:
			stop_walk_to()
			walker.set_input(Vector2.ZERO)
		else:
			# 손가락을 밀고 있으면 그쪽이 우선이다. 누르러 가던 길은 접는다.
			var stick := touch.direction_with_keys()
			if stick.length_squared() > 0.001:
				stop_walk_to()
				walker.set_input(stick)
			else:
				walker.set_input(_tick_goto(delta))
	_check_pickups()
	_update_near()
	_tick_outline()
	_tick_tap_mark(delta)
	_tick_dusk(delta)
	_tick_schedule(delta)
	_refresh_action()
	_tick_clock(delta)
	if not blocked:
		_tick_footsteps(delta)


# ── 도우미 ────────────────────────────────────────────────────────────

func tile_size() -> Vector2i:
	return _size


func world_of(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE)


## 여행자를 세운다. **지금 여기 있을 때만.**
##
## 재회일 때는 대사가 통째로 달라진다. 마음 칸을 따라가지 않고
## "어? 너 여기 웬일이야?"가 먼저 나온다 — 그게 이 게임의 한 순간이다.
## 다시 만났을 때 주고받는 말.
##
## 여행지마다 같은 네 줄을 복사해 뒀었다. 네 곳에서 똑같이 놀라고
## 똑같이 같은 문구를 세 번 들으면, 이 게임의 심장이 그냥 반복되는
## 대사가 된다. **제목과 만나는 말은 딱 한 번, 마지막 재회에만 나온다.**
## 설명하지 않는다 — 한 번 쓰고 만다 (`docs/world-quo.md` 1절).
##
## 그래서 몇 번째 재회인지에 따라 다르게 말한다. 마지막에만 그 말이 나온다.
const REUNION := [
	[["그", "어? 여기서 또 봐요?"], ["나", "…아니 진짜로 또 만났네요."]],
	[["그", "또 만났네요."], ["나", "이쯤 되면 우연이 아닌 것 같은데요."]],
	# 셋째 재회에서만 말이 놓인다. 말투가 바뀌는 것이 곧 친해졌다는 뜻이다
	# — 이 게임은 마음 칸을 숫자로 안 보여 주고 말투로만 알린다.
	[["그", "…또 만났네."], ["나", "저도 방금 놀랐어요."],
		["그", "나는 이런 게 진짜 행복인 것 같아."]],
]

## 넷째부터. 제목이 나오는 셋째 줄을 **되풀이하면 안 된다** — 그 말은
## 게임 전체에서 두 번뿐이다. 넷째부터는 놀람이 아니라 익숙함이다.
const REUNION_LATER := [
	[["그", "오늘도 만났네."], ["나", "네. 어쩐지 그럴 것 같았어요."]],
	[["그", "이제 놀랍지도 않지?"], ["나", "…네. 그게 좋아요."]],
]


func put_wanderer(sheet: String, who: String, folk_id: String,
		lines: Array, flavour: Array) -> Folk:
	var t := wanderer_tile()
	if t.x < 0 or not JourneyState.wanderer_here(place_name()):
		return null
	var f := put_folk(t, sheet, who, folk_id, lines, Vector2.DOWN, true)
	if JourneyState.is_reunion(place_name()):
		JourneyState.reunions += 1
		JourneyState.since_reunion = 0
		var nth: int = JourneyState.reunions - 1
		var script: Array
		if nth < REUNION.size():
			script = REUNION[nth]
		else:
			script = REUNION_LATER[(nth - REUNION.size()) % REUNION_LATER.size()]
		var once: Array = []
		for pair in script:
			once.append([who if String(pair[0]) == "그" else "나", pair[1]])
		# 그 자리에서만 할 수 있는 말 한 줄. 여기가 어딘지가 드러난다.
		for l in flavour:
			once.append([who, l])
		f.once = once
		# 다시 만난 것 자체가 사건이다. 말을 안 걸어도 한 칸 는다.
		JourneyState.warm(folk_id)
	JourneyState.meet_wanderer(place_name())
	return f


## 사람이 아닌 것에도 말을 붙인다 (창밖, 반납함, 바다).
##
## 눈에 안 보이는 Folk 를 세워 두는 것뿐이다. 표시도 대사도 같은 길을
## 타므로 따로 만들 게 없다.
func put_spot(t: Vector2i, what: String, lines: Array) -> Folk:
	var f := Folk.new()
	f.who = what
	f.is_spot = true
	f.folk_id = ""            # 마음이 안 는다 — 물건이니까
	f.lines_by_heart = [lines]
	f.position = world_of(t)
	add_child(f)
	f.hide_body()
	_folk.append(f)
	return f


## 인연을 세운다. 걷지 않고 서 있기만 한다.
func put_folk(t: Vector2i, sheet: String, who: String, folk_id: String,
		lines: Array, facing := Vector2.DOWN, wanderer := false,
		schedule: Dictionary = {}) -> Folk:
	var f := Folk.new()
	f.sheet = "res://assets/sprites/%s-walk.png" % sheet
	f.who = who
	f.folk_id = folk_id
	f.wanderer = wanderer
	f.lines_by_heart = lines
	f.schedule = schedule
	# 시간표가 있으면 지금 시간대의 자리에서 시작한다.
	var at := t
	if not schedule.is_empty():
		at = schedule.get(day_part(), t)
	f.position = world_of(at)
	add_child(f)
	f.face(facing)
	_folk.append(f)
	return f

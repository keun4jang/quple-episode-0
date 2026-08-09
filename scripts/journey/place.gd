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
const TALK_RANGE := 26.0
## 실제 1초에 게임 시간이 얼마나 흐르나. 하루(18시간)가 약 9분.
const MINUTES_PER_SECOND := 2.0

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
var _loose: Array[Node2D] = []   # 아직 안 주운 것
var _folk: Array[Folk] = []
var _near: Folk = null
var _mark: Label                 # 말 걸 수 있는 사람 위에 뜨는 표시
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
	_read_map()
	_build_ground()
	_build_props()
	_build_pickups()
	_build_walls()
	_build_walker()
	_build_camera()
	_build_ui()
	on_built()
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


func _build_ui() -> void:
	say = JourneySay.new()
	say.name = "Say"
	add_child(say)

	hud = JourneyHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.shutter.connect(_take_photo)

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
		var n := JourneyState.night_amount()
		_night.color = Color(1, 1, 1).lerp(Color(0.40, 0.44, 0.66), n)


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
	if hud != null:
		hud.flash()
	SaveManager.save_now()


func _what_is_near() -> String:
	# 사람이 가까이 있으면 사람을, 없으면 눈에 띄는 물건을 적는다.
	if _near != null and is_instance_valid(_near):
		return _near.who
	var best := ""
	var gap := 90.0 * 90.0
	if _props != null:
		for c in _props.get_children():
			if not (c is Sprite2D):
				continue
			var d := walker.global_position.distance_squared_to(c.global_position)
			if d < gap:
				gap = d
				best = PHOTO_NAMES.get(c.name, "")
	return best if best != "" else "풍경"


## 사진에 적을 이름. 없는 건 "풍경"으로 뭉뚱그린다.
const PHOTO_NAMES := {
	"lighthouse": "등대", "guesthouse": "쿼스텔", "shop": "가게",
	"stall": "좌판", "home-house": "집", "home-persimmon": "감나무",
	"home-deck": "평상", "home-garden": "밭", "jars": "장독대",
	"clothesline": "빨랫줄", "pump": "펌프", "parasol": "파라솔",
	"mailbox": "우체통", "bench": "벤치", "pine": "소나무", "tree": "나무",
	"boulder": "바위", "net": "그물", "buoy": "부표", "dock": "부두",
	"street-lamp": "가로등",
}


## 가장 가까운 인연을 찾아 표시를 띄운다.
func _update_near() -> void:
	_near = null
	if walker == null:
		return
	var best := TALK_RANGE * TALK_RANGE
	for f in _folk:
		if not is_instance_valid(f):
			continue
		var d := walker.global_position.distance_squared_to(f.global_position)
		if d < best:
			best = d
			_near = f
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
		_mark.global_position = _sleep_at + Vector2(-7, -34)
	elif _can_depart() and not busy:
		_mark.visible = true
		_mark.text = "출발"
		_mark.global_position = _depart_at + Vector2(-14, -34)
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
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		JourneyState.sleep()
		for f in _folk:
			if is_instance_valid(f):
				f.reset_day()
		walker.global_position = world_of(spawn_tile()))
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
	talked.emit(f.folk_id)


func _unhandled_input(e: InputEvent) -> void:
	if say != null and say.is_busy():
		return
	# e 는 InputEvent 라 e.pressed 가 Variant 다. 타입을 적어 준다 —
	# 안 적으면 추론이 안 돼 파일 전체가 컴파일에 실패한다.
	var tap: bool = (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed
			and e.button_index == MOUSE_BUTTON_LEFT) \
		or e.is_action_pressed("ui_accept")
	if not tap:
		return
	if _near != null:
		talk_to_near()
		get_viewport().set_input_as_handled()
	elif _can_sleep():
		go_to_sleep()
		get_viewport().set_input_as_handled()
	elif _can_depart():
		walker.stop()
		board.open(place_name())
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var blocked := (say != null and say.is_busy()) \
		or (hud != null and hud.bag_open()) or _sleeping \
		or (board != null and board.visible)
	if walker != null and touch != null:
		walker.set_input(Vector2.ZERO if blocked else touch.direction_with_keys())
	_check_pickups()
	_update_near()
	_tick_clock(delta)


# ── 도우미 ────────────────────────────────────────────────────────────

func tile_size() -> Vector2i:
	return _size


func world_of(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE)


## 여행자를 세운다. **지금 여기 있을 때만.**
##
## 재회일 때는 대사가 통째로 달라진다. 마음 칸을 따라가지 않고
## "어? 너 여기 웬일이야?"가 먼저 나온다 — 그게 이 게임의 한 순간이다.
func put_wanderer(sheet: String, who: String, folk_id: String,
		lines: Array, reunion: Array) -> Folk:
	var t := wanderer_tile()
	if t.x < 0 or not JourneyState.wanderer_here(place_name()):
		return null
	var f := put_folk(t, sheet, who, folk_id, lines, Vector2.DOWN, true)
	if JourneyState.is_reunion(place_name()):
		f.once = reunion
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
	f.sprite.visible = false
	_folk.append(f)
	return f


## 인연을 세운다. 걷지 않고 서 있기만 한다.
func put_folk(t: Vector2i, sheet: String, who: String, folk_id: String,
		lines: Array, facing := Vector2.DOWN, wanderer := false) -> Folk:
	var f := Folk.new()
	f.sheet = "res://assets/sprites/%s-walk.png" % sheet
	f.who = who
	f.folk_id = folk_id
	f.wanderer = wanderer
	f.lines_by_heart = lines
	f.position = world_of(t)
	add_child(f)
	f.face(facing)
	_folk.append(f)
	return f

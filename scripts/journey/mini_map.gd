class_name MiniMap
extends Control
## 오른쪽 위에 뜨는 작은 지도. 누르면 커지고, 다시 누르면 작아진다.
##
## 그림을 따로 안 만든다. 바닥 글자판(`ground_map()`)을 그대로 읽어
## 칸마다 점을 찍는다 — 지도를 고치면 미니맵도 저절로 따라온다.
##
## **길을 알려 주는 물건이 아니다.** 화살표도 목적지 표시도 안 넣는다.
## 지금 이 마을이 어떻게 생겼고 내가 어디쯤 있는지, 그거 하나다.

## 접었을 때 / 펼쳤을 때 화면에서 차지하는 최대 크기
const SMALL := Vector2(148.0, 100.0)
const BIG_PART := 0.62         # 펼치면 화면의 이만큼까지
const GROW_TIME := 0.22

var place: Node = null          # Place
var _big := false
var _tw: Tween
var _dot_t := 0.0

## 바닥 이름 → 미니맵 색. 없는 것은 기본색으로 찍는다.
const COLORS := {
	"water": Color("#6FA8A0"), "sand": Color("#E7D3AE"),
	"grass": Color("#8FA070"), "dry-grass": Color("#C0A87F"),
	"dirt": Color("#B08A66"), "cobble": Color("#A89684"),
	"stone-slab": Color("#9E8E7C"), "deck": Color("#C09268"),
	"wood-floor": Color("#C09268"), "tilled-soil": Color("#7A5C48"),
	"basalt": Color("#6B5A57"), "clay-earth": Color("#CDA282"),
	"granite-step": Color("#B0A7A9"), "slate-path": Color("#BFA69F"),
	"office-carpet": Color("#AFA8B6"), "lobby-marble": Color("#A9BDB2"),
	"asphalt": Color("#4A4C52"),
}
const UNKNOWN := Color("#9A8E80")


func _ready() -> void:
	add_to_group("mini_map")
	# **입력을 안 먹는다.** `MOUSE_FILTER_STOP` 으로 뒀더니 손가락 탭이
	# 여기서 삼켜지는데 `gui_input` 은 안 왔다 — 마우스로는 오고 손가락
	# 으로는 안 오는 자리다. 그래서 폰에서는 눌러도 아무 일도 안 났다.
	# 이제 아무것도 안 먹고, `Place` 가 `try_touch()` 로 직접 물어본다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_place_small()
	set_process(true)


## 손가락을 직접 받는다.
##
## `gui_input` 은 **마우스로는 오는데 손가락으로는 안 왔다.** 터치를
## 마우스로 흉내내는 건 첫 번째 손가락 하나뿐이고, 그 손가락은 걷기가
## 쓰고 있다. 배낭·사진 버튼이 같은 병으로 안 눌렸었다
## (`journey_hud.gd` 의 `try_touch`). 여기도 같은 길을 낸다.
func try_touch(pos: Vector2) -> bool:
	if not visible:
		return false
	if get_global_rect().has_point(pos):
		toggle()
		return true
	# 펼쳐 놓았으면 **바깥을 눌러도 닫힌다.** 지도를 열어 놓고 딴 데를
	# 누르는 건 거의 반사다.
	if _big:
		toggle()
		return true
	return false


func toggle() -> void:
	_big = not _big
	AudioManager.touch_tap()
	var want := _big_rect() if _big else _small_rect()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "offset_left", want.position.x, GROW_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw.tween_property(self, "offset_top", want.position.y, GROW_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw.tween_property(self, "offset_right", want.end.x, GROW_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw.tween_property(self, "offset_bottom", want.end.y, GROW_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func is_big() -> bool:
	return _big


## 지도 비율을 지키면서 상자 안에 맞춘 크기
func _fit(limit: Vector2) -> Vector2:
	if place == null or not place.has_method("tile_size"):
		return limit
	var t: Vector2i = place.tile_size()
	if t.x <= 0 or t.y <= 0:
		return limit
	var k: float = minf(limit.x / float(t.x), limit.y / float(t.y))
	return Vector2(t.x * k, t.y * k)


## 접었을 때 — 오른쪽 위, 설정 버튼 **아래**.
func _small_rect() -> Rect2:
	var sz := _fit(SMALL)
	var right := -32.0
	var top := 116.0
	return Rect2(Vector2(right - sz.x, top), sz)


## 펼쳤을 때 — 화면 가운데.
func _big_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var sz := _fit(vp * BIG_PART)
	var c := vp * 0.5
	return Rect2(Vector2(c.x - sz.x * 0.5 - vp.x, c.y - sz.y * 0.5), sz)


func _place_small() -> void:
	var r := _small_rect()
	offset_left = r.position.x
	offset_top = r.position.y
	offset_right = r.end.x
	offset_bottom = r.end.y


func _process(delta: float) -> void:
	# 내 자리 점이 천천히 깜빡인다. 지도가 멈춰 있으면 죽은 그림 같다.
	_dot_t += delta
	queue_redraw()


func _draw() -> void:
	if place == null or not place.has_method("tile_size"):
		return
	var t: Vector2i = place.tile_size()
	if t.x <= 0 or t.y <= 0:
		return

	# 펼쳤을 때는 뒤 세계를 살짝 눌러 준다. 여행판·설정은 다 이렇게
	# 하는데 여기만 안 하고 있었다 — 같은 무게의 화면인데 혼자 규칙이
	# 달랐다.
	if _big:
		var g := get_global_rect()
		draw_rect(Rect2(-g.position, get_viewport_rect().size),
			Color(0.10, 0.09, 0.12, 0.45))

	# 바탕과 테두리
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.16, 0.13, 0.18, 0.55 if _big else 0.42))

	var cw := size.x / float(t.x)
	var ch := size.y / float(t.y)
	var grid: Array = place.get("_grid")
	var legend: Dictionary = place.get("legend")
	if grid != null and legend != null:
		for y in mini(grid.size(), t.y):
			var row: String = grid[y]
			for x in mini(row.length(), t.x):
				var ch2 := row[x]
				if not legend.has(ch2):
					continue
				var col: Color = COLORS.get(String(legend[ch2]), UNKNOWN)
				draw_rect(Rect2(x * cw, y * ch, cw + 0.6, ch + 0.6), col)

	# 인연은 작은 점으로. 이름은 안 쓴다 — 지도가 목록이 되면 안 된다.
	var folk: Array = place.get("_folk")
	if folk != null:
		for f in folk:
			if not is_instance_valid(f) or f.is_spot:
				continue
			var p := _to_map(f.global_position, cw, ch)
			draw_circle(p, maxf(1.6, cw * 0.30), Color(1.0, 0.94, 0.78, 0.9))

	# 나. 천천히 숨쉰다.
	var w = place.get("walker")
	if w != null and is_instance_valid(w):
		var me := _to_map(w.global_position, cw, ch)
		var k: float = 1.0 + sin(_dot_t * 3.0) * 0.18
		draw_circle(me, maxf(2.6, cw * 0.52) * k, Color(0.16, 0.13, 0.18, 0.8))
		draw_circle(me, maxf(1.8, cw * 0.36) * k, Color("#E4785F"))

	# 테두리는 마지막에 — 점이 밖으로 새 보이지 않게
	draw_rect(r, Color(1.0, 0.99, 0.94, 0.55), false, 2.0)


func _to_map(world: Vector2, cw: float, ch: float) -> Vector2:
	var tile: float = 16.0
	if place != null and "TILE" in place:
		tile = float(place.TILE)
	return Vector2(world.x / tile * cw, world.y / tile * ch)

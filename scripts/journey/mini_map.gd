class_name MiniMap
extends Control
## 오른쪽 위에 뜨는 작은 지도. 누르면 커지고, 다시 누르면 작아진다.
##
## 그림을 따로 안 만든다. 바닥 글자판(`ground_map()`)을 그대로 읽어
## 칸마다 점을 찍는다 — 지도를 고치면 미니맵도 저절로 따라온다.
##
## **길을 알려 주는 물건은 아니다.** 화살표도 "여기로 가세요" 도 없다.
## 다만 할 일이 **글자로만** 있어서, 읽어도 지도 위 어디인지 알 수가
## 없었다 — 목록과 지도가 서로 남이었다. 그래서 조용히 자리만 짚어 준다.
##
## 지키는 선:
##
## - **접었을 때는 하나만.** 지금 보고 있는 할 일 한 자리뿐이다
## - **펼쳤을 때만 남은 것들.** 그것도 아직 안 한 것만 — 다 한 것은 지운다
## - **줍기는 다 안 찍는다.** 가장 가까운 하나만 (`Place.goal_world`)
## - 글자를 안 쓴다. 폰트에 없는 기호는 폰에서 네모 상자가 된다
##   (`CLAUDE.md`). 모양은 전부 직접 그린다

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

	# 막힌 칸을 살짝 어둡게. 바닥 글자판만 그리면 **소품이 막는 자리가
	# 안 보인다** — 솔그늘 샛길은 소나무가 길 양옆을 빈틈없이 메워 폭
	# 서너 칸짜리 외길인데, 미니맵에서는 온통 풀밭으로 보였다. 지도와
	# 실제로 갈 수 있는 데가 어긋나면 지도를 안 믿게 된다.
	var blocked: Dictionary = place.get("_blocked")
	if blocked != null:
		for bt in blocked:
			if bt.x < 0 or bt.y < 0 or bt.x >= t.x or bt.y >= t.y:
				continue
			draw_rect(Rect2(bt.x * cw, bt.y * ch, cw + 0.6, ch + 0.6),
				Color(0.16, 0.13, 0.18, 0.30))

	# 말 걸 수 있는 것은 다 찍는다. 이름은 안 쓴다 — 지도가 목록이 되면
	# 안 된다.
	#
	# **소품 자리(`is_spot`)를 빼먹고 있었다.** 평상·창밖·반납함·진열대처럼
	# 대화창이 열리는 것들이 지도에 아예 없어서, 마을에 그런 게 있는 줄도
	# 몰랐다. 인연은 찬 점, 소품 자리는 속 빈 고리로 갈라 그린다 —
	# 사람인지 물건인지는 알아야 한다.
	var folk: Array = place.get("_folk")
	if folk != null:
		for f in folk:
			if not is_instance_valid(f):
				continue
			var p := _to_map(f.global_position, cw, ch)
			var rr: float = maxf(1.6, cw * 0.30)
			if f.is_spot:
				draw_arc(p, rr, 0.0, TAU, 12, Color(1.0, 0.88, 0.62, 0.85),
					maxf(1.0, cw * 0.16), true)
			else:
				draw_circle(p, rr, Color(1.0, 0.94, 0.78, 0.9))

	_draw_goals(cw, ch)

	# 나. 천천히 숨쉰다.
	var w = place.get("walker")
	if w != null and is_instance_valid(w):
		var me := _to_map(w.global_position, cw, ch)
		var k: float = 1.0 + sin(_dot_t * 3.0) * 0.18
		draw_circle(me, maxf(2.6, cw * 0.52) * k, Color(0.16, 0.13, 0.18, 0.8))
		draw_circle(me, maxf(1.8, cw * 0.36) * k, Color("#E4785F"))

	# 테두리는 마지막에 — 점이 밖으로 새 보이지 않게
	draw_rect(r, Color(1.0, 0.99, 0.94, 0.55), false, 2.0)


# ── 할 일 표시 ────────────────────────────────────────────────────────

const GOAL := Color(1.0, 0.97, 0.88, 0.85)        # 남은 할 일
const GOAL_NOW := Color(0.66, 0.80, 0.60, 0.95)   # 지금 보고 있는 것

## 접었으면 지금 것 하나, 펼쳤으면 남은 것 전부.
func _draw_goals(cw: float, ch: float) -> void:
	if not place.has_method("current_goal"):
		return
	var now: Dictionary = place.current_goal()
	var items: Array = place.open_goals() if _big else \
		([now] if not now.is_empty() else [])
	# **접었을 때가 문제다.** 칸 하나가 4px 남짓이라 칸에 비례해 그리면
	# 점보다 작아져 보이지도 않았다 — 가리키라고 넣은 표시가 안 보이면
	# 없는 것과 같다. 바닥값을 둬서 작은 지도에서도 읽히게 한다.
	var r: float = maxf(4.2, cw * 0.42)
	for it in items:
		var at: Vector2 = place.goal_world(it)
		if at == Vector2.INF:
			continue
		var p := _to_map(at, cw, ch)
		var mine: bool = not now.is_empty() and it == now
		_goal_shape(p, r, String(it.get("kind", "")),
			bool(it.get("photo", false)), GOAL_NOW if mine else GOAL)
		if mine:
			# 지금 보고 있는 것에는 고리를 하나 더. 숨쉬듯 커졌다 작아진다.
			var k: float = 1.0 + sin(_dot_t * 2.4) * 0.16
			draw_arc(p, r * 1.9 * k, 0.0, TAU, 20, GOAL_NOW,
				maxf(1.6, cw * 0.10), true)


## 종류마다 다른 모양. 글자를 안 쓰고 직접 그린다.
func _goal_shape(p: Vector2, r: float, kind: String, photo: bool, col: Color) -> void:
	var w: float = maxf(1.6, r * 0.34)
	match kind:
		"door":
			# 문 · 가게 · 등대 · 능 입구 — 작은 네모
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2.0, r * 2.0)),
				col, false, w)
		"visit":
			# 가 볼 자리 — 빈 동그라미. 사진이 필요하면 바깥에 모서리 넷
			draw_arc(p, r, 0.0, TAU, 18, col, w, true)
			if photo:
				var d: float = r * 1.7
				for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
					draw_line(p + s * d, p + s * (d - r * 0.6), col, w * 0.8, true)
		"exit":
			# 나가는 문 - 네모 위로 나가는 화살. 들어가는 문(빈 네모)과
			# 갈라 둔다. 실내에서 볼 것을 다 봤을 때 이것이 뜬다.
			draw_rect(Rect2(p - Vector2(r, r * 0.2),
				Vector2(r * 2.0, r * 1.2)), col, false, w)
			draw_line(p + Vector2(0, r * 0.4), p + Vector2(0, -r * 1.6), col, w, true)
			for sx: float in [-1.0, 1.0]:
				draw_line(p + Vector2(0, -r * 1.6),
					p + Vector2(sx * r * 0.7, -r * 0.9), col, w, true)
		"sleep":
			# 잠자리 — 반달
			draw_arc(p, r, PI * 0.15, PI * 0.85, 14, col, w, true)
			draw_arc(p + Vector2(0, -r * 0.5), r * 0.9, PI * 0.2, PI * 0.8,
				12, col, w * 0.8, true)
		"depart":
			# 정류장 — 표지판. 기둥 하나에 판 하나
			draw_line(p, p + Vector2(0, -r * 1.8), col, w, true)
			draw_rect(Rect2(p + Vector2(-r * 0.9, -r * 2.4),
				Vector2(r * 1.8, r * 0.9)), col, false, w * 0.9)
		"trace":
			# 숨은 자취 — 대각선 네 갈래 반짝임. 줍기(십자)와 갈라 둔다
			for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(p + v * (r * 0.3), p + v * (r * 1.0), col, w * 0.9, true)
		"pickup":
			# 줍기 — 작은 반짝임 (네 갈래)
			for v in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
				draw_line(p + v * (r * 0.35), p + v * (r * 1.25), col, w * 0.9, true)
		_:
			# 인연·소품 — 이미 크림색 점이 찍혀 있으니 테두리만 살짝
			draw_arc(p, r * 1.15, 0.0, TAU, 16, col, w * 0.9, true)


func _to_map(world: Vector2, cw: float, ch: float) -> Vector2:
	var tile: float = 16.0
	if place != null and "TILE" in place:
		tile = float(place.TILE)
	return Vector2(world.x / tile * cw, world.y / tile * ch)

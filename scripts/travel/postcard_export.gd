class_name PostcardExport
extends RefCounted

# 엽서(기념품 사진 + 일기)를 PNG 로 내보낸다.
#
# [텍스트에 대한 결정]
# Image 에는 폰트를 그릴 방법이 없고(한글은 더더욱), 전역 테마의 Jua 폰트를
# 픽셀로 흉내 내면 오히려 글씨가 깨져 보인다. 그래서 여기서는
# **사진 + 폴라로이드 프레임만 그리고, 글자 자리는 비워 둔다.**
# 제목/일기를 얹고 싶은 호출자는 title_rect() / diary_rect() 가 돌려주는
# 좌표에 Label 을 올리면 된다(그 Label 은 전역 테마를 그대로 쓰므로
# 굵기가 유지된다). 저장본에 글씨까지 넣으려면 호출자가 SubViewport 로
# 합성하는 쪽이 결과가 훨씬 깨끗하다.

const CARD_W := 480
const CARD_H := 600

# 폴라로이드 사진 영역 (위쪽). 아래 여백이 넓은 것이 폴라로이드의 인상.
const PHOTO_X := 30
const PHOTO_Y := 30
const PHOTO_W := 420
const PHOTO_H := 380

# 크림색 액자. 순백이면 사진과 대비가 세서 눈이 아프다.
const FRAME_COLOR := Color(0.97, 0.95, 0.90)
const FRAME_EDGE := Color(0.86, 0.83, 0.76)

const SUMMARY_W := 480
const SUMMARY_H := 640


# --- 그리기 헬퍼 (전부 set_pixel 기반, 외부 이미지 없음) ---

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	# 이미지 밖 좌표를 넘기면 Godot 이 에러를 뱉으므로 먼저 잘라 낸다.
	var x0: int = maxi(0, x)
	var y0: int = maxi(0, y)
	var x1: int = mini(img.get_width(), x + w)
	var y1: int = mini(img.get_height(), y + h)
	for py in range(y0, y1):
		for px in range(x0, x1):
			img.set_pixel(px, py, c)


static func _blend_rect(img: Image, x: int, y: int, w: int, h: int, c: Color, a: float) -> void:
	# 반투명 겹치기. 실루엣 위에 빛/안개를 얹을 때 쓴다.
	var x0: int = maxi(0, x)
	var y0: int = maxi(0, y)
	var x1: int = mini(img.get_width(), x + w)
	var y1: int = mini(img.get_height(), y + h)
	for py in range(y0, y1):
		for px in range(x0, x1):
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(c, clampf(a, 0.0, 1.0)))


static func _fill_circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	if r <= 0:
		return
	var rr := r * r
	for py in range(maxi(0, cy - r), mini(img.get_height(), cy + r + 1)):
		for px in range(maxi(0, cx - r), mini(img.get_width(), cx + r + 1)):
			var dx := px - cx
			var dy := py - cy
			if dx * dx + dy * dy <= rr:
				img.set_pixel(px, py, c)


static func _fill_triangle(img: Image, ax: int, ay: int, bx: int, by: int, cx: int, cy: int, c: Color) -> void:
	# 산·나무 실루엣용. 무게중심 좌표 대신 외적 부호로 안팎을 판정한다.
	var min_x: int = maxi(0, mini(ax, mini(bx, cx)))
	var max_x: int = mini(img.get_width() - 1, maxi(ax, maxi(bx, cx)))
	var min_y: int = maxi(0, mini(ay, mini(by, cy)))
	var max_y: int = mini(img.get_height() - 1, maxi(ay, maxi(by, cy)))
	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			var d1 := (px - bx) * (ay - by) - (ax - bx) * (py - by)
			var d2 := (px - cx) * (by - cy) - (bx - cx) * (py - cy)
			var d3 := (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
			var has_neg := d1 < 0 or d2 < 0 or d3 < 0
			var has_pos := d1 > 0 or d2 > 0 or d3 > 0
			if not (has_neg and has_pos):
				img.set_pixel(px, py, c)


static func _v_gradient(img: Image, x: int, y: int, w: int, h: int, top: Color, bottom: Color) -> void:
	if h <= 0:
		return
	for i in range(h):
		var t := float(i) / float(maxi(1, h - 1))
		_fill_rect(img, x, y + i, w, 1, top.lerp(bottom, t))


# --- 텍스트 자리 (호출자가 Label 을 얹을 좌표) ---

static func title_rect() -> Rect2i:
	return Rect2i(PHOTO_X, PHOTO_Y + PHOTO_H + 18, PHOTO_W, 44)


static func diary_rect() -> Rect2i:
	return Rect2i(PHOTO_X, PHOTO_Y + PHOTO_H + 66, PHOTO_W, 74)


# --- 기념품 엽서 ---

## 기념품 하나를 폴라로이드 카드 이미지로 그린다.
## sv: travel_state 의 souvenir 딕셔너리, dest: 여행지 딕셔너리.
static func render_souvenir(sv: Dictionary, dest: Dictionary) -> Image:
	var img := Image.create(CARD_W, CARD_H, false, Image.FORMAT_RGBA8)
	var pal := TravelPalette.for_destination(dest)

	# 액자
	img.fill(FRAME_COLOR)
	_fill_rect(img, 0, 0, CARD_W, 3, FRAME_EDGE)
	_fill_rect(img, 0, CARD_H - 3, CARD_W, 3, FRAME_EDGE)
	_fill_rect(img, 0, 0, 3, CARD_H, FRAME_EDGE)
	_fill_rect(img, CARD_W - 3, 0, 3, CARD_H, FRAME_EDGE)

	_draw_scene(img, PHOTO_X, PHOTO_Y, PHOTO_W, PHOTO_H, pal, sv, dest)

	# 사진 테두리(살짝 어두운 선) — 사진과 크림색 여백을 분리해 준다
	_fill_rect(img, PHOTO_X - 2, PHOTO_Y - 2, PHOTO_W + 4, 2, FRAME_EDGE)
	_fill_rect(img, PHOTO_X - 2, PHOTO_Y + PHOTO_H, PHOTO_W + 4, 2, FRAME_EDGE)
	_fill_rect(img, PHOTO_X - 2, PHOTO_Y - 2, 2, PHOTO_H + 4, FRAME_EDGE)
	_fill_rect(img, PHOTO_X + PHOTO_W, PHOTO_Y - 2, 2, PHOTO_H + 4, FRAME_EDGE)

	# 글자 자리는 비워 두되, 일기 줄 자리를 아주 옅은 선으로 암시한다
	var dr := diary_rect()
	for i in range(3):
		_blend_rect(img, dr.position.x, dr.position.y + 8 + i * 24, dr.size.x, 1, FRAME_EDGE, 0.55)

	_draw_watermark(img, CARD_W - 96, CARD_H - 42, pal)
	return img


## 사진 영역: 하늘 그러데이션 + 땅 + 실루엣 + 쿼카 커플 점 두 개.
static func _draw_scene(img: Image, x: int, y: int, w: int, h: int,
		pal: Dictionary, sv: Dictionary, dest: Dictionary) -> void:
	var sky_top: Color = pal.get("sky_top", Color(0.5, 0.6, 0.8))
	var sky_bottom: Color = pal.get("sky_bottom", Color(0.8, 0.85, 0.9))
	var ground: Color = pal.get("ground", Color(0.4, 0.5, 0.4))
	var accent: Color = pal.get("accent", Color(0.6, 0.7, 0.8))
	var fog: Color = pal.get("fog_color", sky_bottom)

	var horizon := int(h * 0.66)
	_v_gradient(img, x, y, w, horizon, sky_top, sky_bottom)
	_v_gradient(img, x, y + horizon, w, h - horizon, ground.lightened(0.12), ground.darkened(0.18))

	# 여행지 id 로 실루엣 모양을 정한다. 같은 곳은 늘 같은 그림이어야
	# "그곳의 사진"으로 느껴진다.
	var seed_str := str(dest.get("id", "")) + str(sv.get("title", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(seed_str))

	# 해/달 — 조용한 날은 낮게 걸린 작은 빛으로
	var quiet := bool(sv.get("quiet", false))
	var sun_r := 18 if quiet else 26
	_fill_circle(img, x + int(w * rng.randf_range(0.18, 0.82)),
		y + int(horizon * rng.randf_range(0.22, 0.5)), sun_r,
		pal.get("light_color", Color(1, 0.97, 0.9)))

	# 먼 산 (안개색으로 흐리게) → 가까운 산 (accent) 순서로 깊이를 만든다
	for layer in range(2):
		var col: Color = fog.lerp(accent, 0.35 + 0.5 * layer)
		var count := 3 + layer
		for i in range(count):
			var bx := x + int(w * (float(i) / float(count)) + rng.randf_range(-30.0, 30.0))
			var peak := int(horizon * rng.randf_range(0.32, 0.62)) * (1 + layer)
			var half := int(w * rng.randf_range(0.14, 0.26))
			var base_y := y + horizon + layer * 10
			_fill_triangle(img, bx, base_y, bx - half, base_y, bx - half / 2, base_y - peak, col)

	# 지평선 안개 — 하늘과 땅의 경계를 부드럽게
	_blend_rect(img, x, y + horizon - 10, w, 20, fog, 0.35)

	# 쿼카 커플: 실루엣 두 개 + 스카프 한 점.
	# 스카프색(산호)은 배경에 없으므로 여기서 시선이 잡힌다.
	var cx := x + int(w * 0.5)
	var cy := y + horizon + int((h - horizon) * 0.42)
	var body: Color = ground.darkened(0.45)
	_fill_circle(img, cx - 16, cy, 13, body)
	_fill_circle(img, cx + 16, cy - 2, 13, body)
	_fill_circle(img, cx - 16, cy - 14, 8, body)
	_fill_circle(img, cx + 16, cy - 16, 8, body)
	_fill_rect(img, cx - 23, cy - 6, 14, 4, TravelPalette.SCARF_CORAL)
	_fill_rect(img, cx + 9, cy - 8, 14, 4, TravelPalette.SCARF_CORAL)

	# 사진 네 귀퉁이 비네팅 — 인화된 느낌
	for i in range(24):
		var a := 0.30 * (1.0 - float(i) / 24.0)
		_blend_rect(img, x, y + i, w, 1, Color(0, 0, 0), a * 0.5)
		_blend_rect(img, x, y + h - 1 - i, w, 1, Color(0, 0, 0), a)


## 하단 워터마크 자리(쿼플 로고). 도형만으로 표시한다.
static func _draw_watermark(img: Image, x: int, y: int, pal: Dictionary) -> void:
	var c: Color = pal.get("accent", Color(0.6, 0.7, 0.8)).darkened(0.25)
	_fill_rect(img, x, y, 66, 22, FRAME_EDGE)
	_blend_rect(img, x + 2, y + 2, 62, 18, c, 0.55)
	# 쿼카 얼굴 자리를 동그라미 하나로
	_fill_circle(img, x + 14, y + 11, 6, FRAME_COLOR)
	_fill_rect(img, x + 26, y + 8, 30, 6, FRAME_COLOR)


## 엽서를 PNG 로 저장한다. path 는 user:// 기준으로 강제한다
## (내보내기 후에도 실행 환경에 상관없이 쓰기 가능한 곳이어야 하므로).
static func save_souvenir(sv: Dictionary, dest: Dictionary, path: String) -> bool:
	var img := render_souvenir(sv, dest)
	return _save(img, path)


static func save_trip_summary(collection: Array, chapters: Array, path: String) -> bool:
	var img := render_trip_summary(collection, chapters)
	return _save(img, path)


static func _save(img: Image, path: String) -> bool:
	var full := _user_path(path)
	var dir := full.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return img.save_png(full) == OK


static func _user_path(path: String) -> String:
	if path.begins_with("user://"):
		return path
	if path.begins_with("res://"):
		# res:// 는 내보낸 게임에서 쓰기가 막히므로 파일명만 살려 user:// 로 옮긴다
		return "user://" + path.get_file()
	return "user://" + path.trim_prefix("/")


# --- 여행 통계 카드 ---

## 다녀온 곳 수와 막별 내역을 막대그래프로 그린다.
## collection: 기념품 배열(각 항목에 dest_id), chapters: 막 정의 배열.
static func render_trip_summary(collection: Array, chapters: Array) -> Image:
	var img := Image.create(SUMMARY_W, SUMMARY_H, false, Image.FORMAT_RGBA8)
	img.fill(FRAME_COLOR)
	_fill_rect(img, 0, 0, SUMMARY_W, 3, FRAME_EDGE)
	_fill_rect(img, 0, SUMMARY_H - 3, SUMMARY_W, 3, FRAME_EDGE)
	_fill_rect(img, 0, 0, 3, SUMMARY_H, FRAME_EDGE)
	_fill_rect(img, SUMMARY_W - 3, 0, 3, SUMMARY_H, FRAME_EDGE)

	# 막별 개수 집계. dest_id 만으로 막을 모르면 souvenir 안의 chapter 를 본다.
	var per_chapter := {}
	for ch in chapters:
		if ch is Dictionary:
			per_chapter[str((ch as Dictionary).get("id", ""))] = 0
	var total := 0
	var uniq := {}
	for sv in collection:
		if not (sv is Dictionary):
			continue
		total += 1
		var d: Dictionary = sv
		uniq[str(d.get("dest_id", ""))] = true
		var cid := str(d.get("chapter", ""))
		if cid == "" or not per_chapter.has(cid):
			# 막을 모르면 첫 막에 넣는다(빈 그래프보다 낫다)
			cid = str(per_chapter.keys()[0]) if per_chapter.size() > 0 else ""
		if per_chapter.has(cid):
			per_chapter[cid] = int(per_chapter[cid]) + 1

	# 상단 띠: 다녀온 곳 수를 점으로 (한 점 = 한 곳)
	var band_top := 40
	_v_gradient(img, 20, band_top, SUMMARY_W - 40, 120,
		Color(0.55, 0.70, 0.86), Color(0.78, 0.86, 0.92))
	var dots: int = mini(uniq.size(), 60)
	for i in range(dots):
		var col := i % 12
		var row := i / 12
		_fill_circle(img, 44 + col * 34, band_top + 24 + row * 24, 8, FRAME_COLOR)

	# 막별 막대그래프
	var max_v := 1
	for k in per_chapter:
		max_v = maxi(max_v, int(per_chapter[k]))
	var bar_top := band_top + 160
	var bar_h := 300
	var idx := 0
	var n: int = maxi(1, per_chapter.size())
	var slot: int = int((SUMMARY_W - 80) / n)
	for k in per_chapter:
		var v := int(per_chapter[k])
		var hgt := int(bar_h * float(v) / float(max_v))
		var pal: Dictionary = TravelPalette.CHAPTER_PALETTES.get(k, {})
		var col2: Color = pal.get("accent", Color(0.6, 0.7, 0.8))
		var bx := 40 + idx * slot + 10
		var bw: int = maxi(12, slot - 24)
		_fill_rect(img, bx, bar_top + bar_h - hgt, bw, hgt, col2)
		_fill_rect(img, bx, bar_top + bar_h, bw, 4, FRAME_EDGE)
		idx += 1

	# 총 개수를 하단에 눈금으로 (텍스트 대신 도형)
	var ticks: int = mini(total, 40)
	for i in range(ticks):
		_fill_rect(img, 40 + i * 10, SUMMARY_H - 60, 6, 14, Color(0.45, 0.50, 0.55))

	_draw_watermark(img, SUMMARY_W - 96, SUMMARY_H - 42, {"accent": Color(0.6, 0.7, 0.8)})
	return img

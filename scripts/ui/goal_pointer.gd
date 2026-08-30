class_name GoalPointer
extends CanvasLayer
## 화면 밖 할 일을 화면 가장자리에서 가리킨다.
##
## 여태 할 일 화살표(`Place._tick_goal_arrow`)는 **세계 좌표**에 떠
## 있었다. 그래서 목표가 화면에 들어와 있을 때만 보였다. 실제로 재
## 보니 그게 드문 일이 아니었다 - 마을 아홉 곳의 남은 할 일을 마을에
## 들어선 자리에서 재 봤더니:
##
##   굽이나루  : 여섯 중 여섯이 화면 밖 (기본 배율에서도)
##   갈밭머리  : 여섯 중 다섯이 화면 밖
##   솔은재    : 어느 배율로도 안 보이는 것 둘
##
## 두 손가락으로 당겨 보고 있으면(3배·4배) 거의 다 화면 밖이다.
## 그때 화면에는 **아무 표시도 없었다.** 위쪽 띠가 "부두 끝을 아침에도
## 저녁에도 보기" 라고 적어 줘도, 부두가 어느 쪽인지는 알 수 없었다.
##
## 그래서 목표가 화면을 벗어나면 **가장자리에 화살표를 세운다.**
## 어느 쪽인지와 얼마나 먼지, 둘만 말한다.
##
## 지키는 선:
## - **대신 걸어 주지 않는다.** 방향만 알려 준다
## - 화면에 목표가 들어오면 조용히 사라진다 - 세계 화살표가 이어받는다
## - 모서리 버튼(배낭·사진·설정·미니맵)을 안 가린다
## - 폰트에 없는 글자를 안 쓴다. 세모는 직접 그린다 (`CLAUDE.md`)

## 모서리 버튼을 피해 안쪽으로 물러나는 정도. 배낭 버튼이 96px 이고
## 미니맵이 그만하다.
const EDGE := 118.0

## 남은 거리를 적는 글자. 방향만으로는 "저 산 너머인지 코앞인지" 를
## 모른다 - 스무 걸음인지 두 걸음인지는 갈지 말지를 가른다.
const FONT_SIZE := 20

## 화살촉 모양. [코, 왼날개, 파낸 뒷허리, 오른날개] - +x 를 가리킨다.
##
## **세모 하나로는 안 된다.** 세 번 틀리고 알았다 -
##
##   밑변 22 · 길이 22 : 거의 정삼각형. 앞뒤가 없다
##   밑변 18 · 길이 26 : 옆면이 길고 곧아서 그쪽이 뒤로 읽혔다
##   밑변 26 · 길이 22 : 밑변을 늘려도 옆면과 길이가 비슷해진다
##
## 좌표는 세 번 다 맞았다. 오른쪽 아래를 가리키는 세모를 눈이 왼쪽으로
## 읽었을 뿐이다. 이등변삼각형은 **밑변 모서리가 무게중심에서 제일
## 멀어서**, 기울여 놓으면 그 모서리가 앞으로 보인다. 늘 아래만
## 가리키는 세계 화살표(`Place._tick_goal_arrow`)는 안 겪던 일이다.
##
## 그래서 뒤를 파내고, **코를 날개보다 확실히 길게** 잡는다
## (코 20 · 날개 13.5). 그러면 무게중심에서 제일 먼 꼭짓점이 코가 된다 -
## 눈이 앞을 찾는 방식이 그것이다. 검사가 이 성질을 지킨다.
const HEAD := [
	Vector2(20, 0),      # 코
	Vector2(-9, -10),    # 왼날개
	Vector2(-2, 0),      # 파낸 뒷허리
	Vector2(-9, 10),     # 오른날개
]


## 화살촉이 실제로 가리키는 쪽. 무게중심에서 제일 먼 꼭짓점이다 -
## 눈이 앞을 찾는 방식 그대로 잰다. 검사가 이걸 쓴다.
static func head_aims() -> Vector2:
	var mid := Vector2.ZERO
	for pt: Vector2 in HEAD:
		mid += pt
	mid /= float(HEAD.size())
	var far := HEAD[0] as Vector2
	for pt: Vector2 in HEAD:
		if (pt - mid).length_squared() > (far - mid).length_squared():
			far = pt
	return (far - mid).normalized()


var _at := Vector2.INF        # 목표의 세계 좌표
var _from := Vector2.INF      # 주인공의 세계 좌표
var _clock := 0.0
var _draw: Node2D
var _tag: Label


func _ready() -> void:
	# HUD(layer 10) 아래. 배낭을 열면 그 위를 덮지 않는다.
	layer = 9
	_draw = Node2D.new()
	_draw.draw.connect(_on_draw)
	add_child(_draw)

	_tag = Label.new()
	_tag.add_theme_font_size_override("font_size", FONT_SIZE)
	_tag.add_theme_color_override("font_color", Color(1.0, 0.89, 0.60))
	_tag.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	_tag.add_theme_constant_override("outline_size", 7)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	visible = false


## 매 프레임 어디를 가리킬지 알려 준다. 목표가 없으면 `Vector2.INF`.
func aim(at: Vector2, from: Vector2, delta: float) -> void:
	_at = at
	_from = from
	_clock += delta
	visible = _off_screen()
	if visible:
		_draw.queue_redraw()


## 목표가 화면 밖인가. 여기 하나에서만 판단한다 - 검사도 이걸 부른다.
##
## **진짜 화면 전체로 잰다.** `_safe_rect()` 는 모서리 버튼을 피해
## 118px 안으로 물러난 "화살표가 설 수 있는 자리" 지, "보이는 자리"
## 가 아니다. 이걸로 화면 밖 여부까지 판단했더니, 화면 안에 멀쩡히
## 보이는 목표 - 심지어 발밑 목표에도 - 가장자리 화살표가 떴다.
func _off_screen() -> bool:
	if _at == Vector2.INF:
		return false
	var s := screen_of(_at)
	if s == Vector2.INF:
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	return not vp.get_visible_rect().has_point(s)


## 세계 좌표를 화면 좌표로. 카메라의 확대·이동이 다 들어 있다.
func screen_of(w: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.INF
	return vp.get_canvas_transform() * w


## 화살표가 설 수 있는 자리. 모서리 버튼을 피해 안쪽으로 물러난다.
func _safe_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var size := vp.get_visible_rect().size
	var pad := JourneyHud.safe_insets(vp)
	return Rect2(Vector2(EDGE + pad.x, EDGE + pad.y),
		size - Vector2(EDGE * 2.0 + pad.x + pad.z, EDGE * 2.0 + pad.y + pad.w))


func _on_draw() -> void:
	var r := _safe_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var mid := r.position + r.size * 0.5
	var to := screen_of(_at)
	var dir := to - mid
	if dir.length_squared() < 1.0:
		return
	dir = dir.normalized()

	# 가운데에서 목표 쪽으로 쏜 선이 테두리와 만나는 자리.
	var half := r.size * 0.5
	var tx: float = half.x / absf(dir.x) if absf(dir.x) > 0.0001 else INF
	var ty: float = half.y / absf(dir.y) if absf(dir.y) > 0.0001 else INF
	var edge := mid + dir * minf(tx, ty)

	# 숨쉬듯 오르내린다. 멈춰 있으면 화면에 붙은 얼룩으로 읽힌다.
	edge += dir * (sin(_clock * 3.6) * 4.0)

	# 둥근 바닥을 먼저 깐다. 풀밭이든 모래든 그 위에서 읽히게.
	_draw.draw_circle(edge, 23.0, Color(0.16, 0.13, 0.18, 0.66))

	# 화살촉을 그린다. 오목한 도형이라 삼각형 둘로 나눠 그린다 -
	# `draw_colored_polygon` 은 볼록한 것만 제대로 채운다.
	var ang := dir.angle()
	var tip := edge + dir * 2.0
	for tri: Array in [[HEAD[0], HEAD[1], HEAD[2]],
		[HEAD[0], HEAD[2], HEAD[3]]]:
		var poly := PackedVector2Array()
		for pt: Vector2 in tri:
			poly.append(tip + pt.rotated(ang))
		_draw.draw_colored_polygon(poly, Color(1.0, 0.83, 0.35))

	# 남은 거리. 걸음으로 센다 - 픽셀이나 칸은 사람 말이 아니다.
	#
	# **화살표 안쪽에 놓는다.** 바깥에 놓으면 화면 끝에 눌려서
	# 화살표 위로 겹쳐 앉는다 - 처음에 그렇게 만들었다가 세모가
	# 글자에 가렸다.
	var steps := int(round(_from.distance_to(_at) / 16.0))
	_tag.text = "%d걸음" % maxi(steps, 1)
	_tag.reset_size()
	_tag.position = edge - _tag.size * 0.5 - dir * 42.0

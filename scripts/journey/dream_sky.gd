class_name DreamSky
extends CanvasLayer
## 꿈이 금 가는 하늘 (`docs/redesign-dream.md` 2절 "전·결").
##
## 이야기의 전환부를 **하늘로** 보여 준다. 그림 파일 없이 코드로 그린다:
##
##   1단계 - 솔은재 보스 뒤   현실이 새어 든다. 하늘 위쪽이 잿빛 보라로 물들고,
##                            결재 서류가 드문드문 떨어지고, 가끔 알람 소리와
##                            회사 메시지가 하늘에 번쩍 떴다 사라진다
##   2단계 - 꽃눈벌 보스 뒤   **하늘에 금이 간다.** 금 사이로 빛이 새고
##                            서류가 비처럼 내린다. 꿈속 잿마루 타워는 더 거세다
##   끝     - 야근 대마왕 뒤   아침빛으로 걷힌다 (`dawn`) - 그 뒤로는 다시 맑다
##
## 금이 가는 순간(보스를 처음 쓰러뜨린 그때)은 따로 크게 보여 준다
## (`break_open`) - 쩍 소리, 화면 흔들림, 금이 위에서 아래로 뻗고 서류가 쏟아진다.
##
## 입력은 하나도 안 받는다 - 전부 `MOUSE_FILTER_IGNORE`. 몬스터·인연보다
## 위, HUD(5)보다 아래 층에 그린다.

## 떨어지는 서류 수 - 단계별 (0, 1, 2), 타워는 더 많다.
const PAPERS := [0, 7, 16]
const PAPERS_TOWER := 24
## 하늘에 뜨는 현실의 말.
const LEAKS := [
	"결재 부탁드립니다",
	"내일 아침까지 부탁해요",
	"회의 10분 전입니다",
	"읽지 않은 메시지 12개",
	"알람 오전 6:00",
	"보고서 수정본 올려 주세요",
	"야근 신청이 승인되었습니다",
]

var stage := 0
var strong := false

var _canvas: Control
var _papers: Array = []
var _cracks: Array = []        # [PackedVector2Array]
var _reveal := 1.0             # 금이 얼마나 뻗었나 (0~1)
var _crack_a := 1.0            # 금의 진하기 (새벽에 옅어진다)
var _haze_a := 1.0
var _t := 0.0
var _leak_t := 8.0
var _dawn: ColorRect
var _rng := RandomNumberGenerator.new()


## 지금 이야기가 몇 단계인가. 대마왕을 쓰러뜨렸으면 다시 0 - 아침이다.
static func stage_now() -> int:
	if JourneyState.quest_done("엔딩:대마왕"):
		return 0
	if Battle.boss_down("꽃눈벌"):
		return 2
	if Battle.boss_down("솔은재"):
		return 1
	return 0


## 이 장소의 하늘을 새로 달거나 이미 단 것을 돌려준다.
static func attach(place: Node, st: int, tower := false) -> DreamSky:
	var old := place.get_node_or_null("DreamSky") as DreamSky
	if old != null:
		old.set_stage(st)
		return old
	var s := DreamSky.new()
	s.name = "DreamSky"
	s.stage = st
	s.strong = tower
	place.add_child(s)
	return s


func _ready() -> void:
	layer = 3
	_rng.seed = hash("sky|%d" % JourneyState.day)
	_canvas = Control.new()
	_canvas.name = "SkyCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_sky)
	add_child(_canvas)
	_make_cracks()
	_fill_papers()


func set_stage(st: int) -> void:
	stage = st
	_fill_papers()


func _size() -> Vector2:
	return _canvas.size if _canvas != null and _canvas.size.x > 1.0 else Vector2(1280, 720)


func _want_papers() -> int:
	if stage <= 0:
		return 0
	return PAPERS_TOWER if strong else int(PAPERS[mini(stage, 2)])


func _fill_papers() -> void:
	var want := _want_papers()
	while _papers.size() < want:
		_papers.append(_new_paper(true))
	while _papers.size() > want:
		_papers.pop_back()


func _new_paper(anywhere: bool) -> Dictionary:
	var sz := _size()
	return {
		"p": Vector2(_rng.randf_range(0, sz.x),
			_rng.randf_range(-sz.y, sz.y) if anywhere else _rng.randf_range(-80, -20)),
		"v": _rng.randf_range(38, 70),
		"rot": _rng.randf_range(-0.6, 0.6),
		"spin": _rng.randf_range(-1.2, 1.2),
		"sway": _rng.randf_range(0, TAU),
		"s": _rng.randf_range(1.3, 1.9),
		"stamp": _rng.randf() < 0.35,
	}


## 금 - 위쪽 가장자리에서 아래로 지그재그로 뻗는 줄 셋, 곁가지 몇.
func _make_cracks() -> void:
	_cracks.clear()
	var sz := _size()
	var r := RandomNumberGenerator.new()
	r.seed = 7331
	for i in 3:
		var x := sz.x * (0.2 + 0.3 * float(i)) + r.randf_range(-60, 60)
		var pts := PackedVector2Array([Vector2(x, -4)])
		var p := Vector2(x, -4)
		var steps := r.randi_range(6, 9)
		for j in steps:
			p += Vector2(r.randf_range(-34, 34), r.randf_range(18, 34))
			pts.append(p)
			if j == steps / 2:
				# 곁가지
				var b := PackedVector2Array([p])
				var q := p
				for k in 3:
					q += Vector2(r.randf_range(10, 30) * (1 if i % 2 == 0 else -1), r.randf_range(8, 20))
					b.append(q)
				_cracks.append(b)
		_cracks.append(pts)


func _process(delta: float) -> void:
	_t += delta
	var sz := _size()
	for pp in _papers:
		pp["p"] += Vector2(sin(_t * 1.3 + float(pp["sway"])) * 22.0, float(pp["v"])) * delta
		pp["rot"] = float(pp["rot"]) + float(pp["spin"]) * delta
		if (pp["p"] as Vector2).y > sz.y + 30.0:
			var np := _new_paper(false)
			pp.merge(np, true)
	if stage >= 1 and _dawn == null:
		_leak_t -= delta
		if _leak_t <= 0.0:
			_leak_t = _rng.randf_range(16.0, 28.0) / (1.6 if strong else 1.0)
			leak()
	_canvas.queue_redraw()


func _draw_sky() -> void:
	if stage <= 0 and _dawn == null and _papers.is_empty():
		return
	var sz := _size()
	# 하늘 위쪽이 잿빛 보라로 물든다 - 위가 진하고 아래로 옅어진다.
	var haze := (0.2 if stage == 1 else 0.32) * (1.35 if strong else 1.0) * _haze_a
	if stage > 0:
		var bands := 12
		for i in bands:
			var k := 1.0 - float(i) / float(bands)
			_canvas.draw_rect(Rect2(0, sz.y * 0.4 * float(i) / bands, sz.x, sz.y * 0.4 / bands + 1),
				Color(0.30, 0.24, 0.42, haze * k * k))
	# 금 - 2단계부터. 빛이 새는 넓은 줄 위에 가는 흰 줄.
	if stage >= 2 or _reveal < 1.0:
		var pulse := 0.75 + 0.25 * sin(_t * 2.2)
		for c in _cracks:
			var pts: PackedVector2Array = c
			var n := maxi(2, int(ceil(pts.size() * _reveal)))
			var shown := pts.slice(0, mini(n, pts.size()))
			if shown.size() < 2:
				continue
			_canvas.draw_polyline(shown, Color(0.78, 0.66, 1.0, 0.25 * pulse * _crack_a), 14.0)
			_canvas.draw_polyline(shown, Color(0.95, 0.9, 1.0, 0.6 * pulse * _crack_a), 6.0)
			_canvas.draw_polyline(shown, Color(1, 1, 1, 0.95 * _crack_a), 2.4)
	# 결재 서류 - 흰 종이에 회색 줄 셋, 가끔 붉은 도장.
	for pp in _papers:
		var s := float(pp["s"])
		_canvas.draw_set_transform(pp["p"], float(pp["rot"]), Vector2(s, s))
		var a := 0.85 * _haze_a
		_canvas.draw_rect(Rect2(-9, -12, 18, 24), Color(0.2, 0.18, 0.24, 0.35 * a))
		_canvas.draw_rect(Rect2(-8, -11, 16, 22), Color(0.97, 0.96, 0.92, a))
		for j in 3:
			_canvas.draw_rect(Rect2(-5, -6 + j * 5, 10 - (j % 2) * 3, 1.5), Color(0.55, 0.55, 0.6, a))
		if bool(pp["stamp"]):
			_canvas.draw_circle(Vector2(4, 7), 2.6, Color(0.88, 0.2, 0.22, a))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 현실의 말 한 줄이 하늘에 번쩍 떴다가 흔들리며 사라진다. 알람도 한 번.
func leak(text := "") -> void:
	if text == "":
		text = String(LEAKS[_rng.randi_range(0, LEAKS.size() - 1)])
	var sz := _size()
	var at := Vector2(_rng.randf_range(sz.x * 0.25, sz.x * 0.62), _rng.randf_range(90, 170))
	# 빨강·파랑으로 살짝 어긋난 두 벌 + 흰 글자 - 화면이 튀는 것처럼.
	var layers := [[Vector2(-2, 0), Color(1.0, 0.35, 0.4, 0.7)],
		[Vector2(2, 0), Color(0.35, 0.7, 1.0, 0.7)], [Vector2.ZERO, Color(1, 1, 1, 0.95)]]
	for L in layers:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", L[1])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.position = at + (L[0] as Vector2)
		l.modulate.a = 0.0
		add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.12)
		tw.tween_interval(1.4)
		tw.tween_property(l, "position:x", l.position.x + (L[0] as Vector2).x * 6.0, 0.5)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
		tw.tween_callback(l.queue_free)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("alarm"):
		am.alarm()


## **금이 가는 순간.** 쩍 소리, 흰 번쩍임, 금이 위에서 아래로 뻗고 서류가 쏟아진다.
func break_open(to_stage: int) -> void:
	set_stage(to_stage)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("sky_crack"):
		am.sky_crack()
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.75)
	add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.6)
	ft.tween_callback(flash.queue_free)
	# 금은 2단계에서만 남지만, 1단계로 넘어가는 순간에도 한 번 뻗었다 사라진다.
	_reveal = 0.0
	_crack_a = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_reveal", 1.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if to_stage < 2:
		tw.tween_interval(0.8)
		tw.tween_property(self, "_crack_a", 0.0, 0.8)
		tw.tween_callback(func() -> void:
			_reveal = 1.0
			_crack_a = 1.0)
	# 한꺼번에 쏟아지는 서류 - 몇 초 뒤 제 수로 돌아간다.
	for i in 26:
		var pp := _new_paper(false)
		pp["p"] = Vector2(_rng.randf_range(0, _size().x), _rng.randf_range(-260, -10))
		pp["v"] = _rng.randf_range(120, 200)
		_papers.append(pp)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_fill_papers())
	leak("알람 오전 6:00")


## **아침이 온다.** 금빛이 번지고 금·서류·잿빛이 걷힌다 (`Place._wake_up`).
func dawn() -> void:
	if _dawn != null:
		return
	_dawn = ColorRect.new()
	_dawn.name = "Dawn"
	_dawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dawn.color = Color(1.0, 0.84, 0.58, 0.0)
	add_child(_dawn)
	var tw := create_tween()
	tw.tween_property(_dawn, "color:a", 0.42, 2.4)
	tw.parallel().tween_property(self, "_crack_a", 0.0, 2.0)
	tw.parallel().tween_property(self, "_haze_a", 0.0, 2.4)
	tw.tween_callback(func() -> void:
		_papers.clear()
		stage = 0)

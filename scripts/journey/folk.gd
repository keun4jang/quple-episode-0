class_name Folk
extends QuoWalker
## 여행지에서 만나는 이. 붙박이와 여행자 둘 다 이걸 쓴다.
##
## 마음 다섯 칸(`docs/redesign-journey.md` 5절)은 숫자로 안 보여 준다.
## **말투가 바뀌는 것**으로 안다. 그래서 대사를 칸별로 나눠 들고 있는다.

## 화면에 뜨는 이름
@export var who := "누군가"
## 이 사람을 알아보는 열쇠 (재회 판정에 쓴다)
@export var folk_id := ""
## 여행자인가 (다른 여행지에서 다시 만날 수 있다)
@export var wanderer := false
## 사람이 아니라 **자리**인가 (창밖·반납함·평상).
## 말은 걸리지만 인연으로 세지 않고 마음도 안 는다.
@export var is_spot := false
## 자리 표시가 남기는 열쇠. 비어 있으면 `who` 를 쓴다 — 같은 이름의
## 자리가 여럿일 때(반짝이는 자리 셋) 서로 다른 표시를 남기려는 것이다.
var spot_key := ""

## 마음 칸별 대사. [칸0줄들, 칸1줄들, ...] — 없는 칸은 마지막 것을 쓴다.
var lines_by_heart: Array = []
## 하루 시간표. "아침"/"낮"/"저녁" → 서 있는 칸. 비어 있으면 안 움직인다.
##
## 하늘빛은 일곱 단계로 넘어가는데 마을은 아침 6시와 밤 11시가 픽셀
## 하나 안 다르다 — 다섯 갈래 조사가 전부 이걸 지목했다. 걷게 하지는
## 않는다. 자리만 시간대별로 다르다. 옮기는 건 `Place` 가 한다.
var schedule: Dictionary = {}

## 처음 말을 걸면 주는 여행 물품 ("map"/"camera"). 없으면 "".
##
## 윤슬의 가게 할머니·갈매기 소년만 쓴다 — 여행 물품은 "첫 여행지에서
## 여행자가 된다"는 통과의례라 다른 마을엔 안 늘린다 (`docs/quest-journey.md`
## 3.5절).
@export var gives_item := ""

## 한 번만 하는 말 (첫 만남·재회). 있으면 먼저 쓰고 비운다.
##
## 타입을 `Array[String]` 으로 뒀더니 여행지 파일에서 넘겨주는 평범한
## 배열이 대입되지 않고 조용히 실패했다 — **재회 대사가 통째로 안 붙었다.**
## 오류는 로그에만 남고 화면에서는 그냥 평소 인사를 했다.
var once: Array = []

var _talked := false
## 오늘 노을을 같이 봤나. 하루에 한 번이다.
var _dusk_warmed := false

var _talk_outline_on := false

func _ready() -> void:
	super._ready()
	# 말 걸 수 있는 것은 **멀리서도 옅게 빛난다.** 몸을 감춘 소품 자리
	# (`is_spot`)는 제 테두리가 안 보이니 짝지은 소품이 대신 한다
	# (`Place._outline_sprite`).
	if not is_spot:
		outline_color = QuoWalker.talk_pulse()
		_sync_outline()
		set_process(true)
		_build_name_tag()
		_ready_bob_seed()


## 머리 위에 이름을 단다.
##
## 누구인지 말을 걸어 봐야 알았다. 탑다운에서 8px 짜리 얼굴로는 서로
## 구별이 안 되니, 이름이 곧 그 사람이다. 몸을 감춘 자리 표시
## (`is_spot`)에는 안 단다 — 거기는 사람이 아니라 물건이다.
func _build_name_tag() -> void:
	if who == "":
		return
	var l := Label.new()
	l.name = "NameTag"
	l.text = who
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.18))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 40
	# 발밑이 원점이라 키만큼 올린 뒤 한 뼘 더. 폭은 넉넉히 잡고 가운데 정렬.
	var tall: float = sprite.size().y if sprite != null else 24.0
	l.size = Vector2(120, 16)
	l.position = Vector2(-60, -tall - 17.0)
	l.modulate.a = 0.0     # 가까이 와야 보인다 (`Place.TAG_RANGE`)
	add_child(l)
	_tag = l


## 숨 고르기. 몇 초에 한 번, 아주 잠깐 몸이 1px 들썩인다.
## 크기를 흔들면 픽셀이 뭉개지니 **정수 px 위치만** 움직이고, 발밑
## 그림자와 이름표는 그대로 둔다 — 몸만 숨을 쉰다.
var _bob_clock := 0.0
var _bob_gap := 3.2

## 이름표. 가까이 온 이의 것만 스르르 보인다 — 화면의 이름이 죄다
## 떠 있으면 서로 겹치고 지도가 글자밭이 된다 (`Place._update_near`).
var _tag: Label
var _tag_on := false

func set_tag_near(on: bool) -> void:
	_tag_on = on

func _ready_bob_seed() -> void:
	# 같은 화면의 인연들이 한 박자로 들썩이면 기계 같다. 이름으로
	# 박자를 흩는다.
	_bob_gap = 2.8 + float(absi(hash(folk_id)) % 170) / 100.0
	_bob_clock = fmod(float(absi(hash(who))) / 97.0, _bob_gap)


## 멀리 있는 동안만 깜빡인다. 가까이 오면 `set_talk_near(true)` 가
## 진한 금색으로 멎게 한다.
func _process(delta: float) -> void:
	if is_spot:
		return
	_bob_clock += delta
	if _bob_clock >= _bob_gap + 0.24:
		_bob_clock = 0.0
	if sprite != null:
		sprite.position.y = -1.0 if _bob_clock >= _bob_gap else 0.0
	if _tag != null:
		# **위가 없으면 아래에 단다.** 지도 맨 윗줄에 선 인연은 이름이
		# 위쪽 시계·안내줄·설정 버튼 밑으로 들어가 안 읽혔다. 지도
		# 좌표가 아니라 **화면 좌표**로 본다 — 카메라가 어디를 보고
		# 있느냐에 달린 문제라서, 지도 위쪽만 따지면 못 잡는다.
		var above: float = -(sprite.size().y if sprite != null else 24.0) - 17.0
		var on_screen: float = (get_viewport_transform()
			* (global_position + Vector2(0, above))).y
		_tag.position.y = 4.0 if on_screen < 64.0 else above
		_tag.modulate.a = move_toward(_tag.modulate.a,
			0.95 if _tag_on else 0.0, delta * 4.0)
	if _talk_outline_on:
		return
	outline_color = QuoWalker.talk_pulse()
	_sync_outline()


## 말 걸 수 있다는 표시를 **두 단계**로 켠다.
##
## 한동안 가까이 왔을 때만 켰다. 신호가 둘(느낌표+테두리)이면 흐려진다고
## 봐서 하나로 줄인 것까지는 맞았는데, **아예 꺼 두니 옆에 설 때까지
## 말 걸 수 있는 줄을 몰랐다.** 그래서 끄지 않고 옅게 남긴다 —
## 멀리서는 "저기 뭔가 있다", 가까이서는 "지금 말 걸 수 있다".
func set_talk_near(on: bool) -> void:
	if is_spot or _talk_outline_on == on:
		return
	_talk_outline_on = on
	outline_color = OUTLINE_TALK if on else QuoWalker.talk_pulse()
	_sync_outline()


func heart() -> int:
	return JourneyState.heart(folk_id)


## 지금 할 말
func lines() -> Array:
	if not once.is_empty():
		var l := once.duplicate()
		once.clear()
		return l
	if lines_by_heart.is_empty():
		return ["…"]
	var i := clampi(heart(), 0, lines_by_heart.size() - 1)
	return lines_by_heart[i]


## 말을 걸었다. 하루에 한 번만 마음이 는다 —
## 같은 사람에게 말만 반복해서 친해지는 건 지루하다.
func on_talked() -> void:
	if _talked:
		return
	_talked = true
	JourneyState.warm(folk_id)
	# **딱 한 번만.** `_talked` 는 하루마다 풀리므로 (`reset_day()`),
	# 이걸로만 막으면 다음 날 다시 말을 걸 때 지도를 또 받는다. 배낭에
	# 이미 있는지로 진짜 처음인지를 가린다.
	if gives_item != "" and JourneyState.count(gives_item) <= 0:
		JourneyState.pick(gives_item)


func reset_day() -> void:
	_talked = false
	_dusk_warmed = false

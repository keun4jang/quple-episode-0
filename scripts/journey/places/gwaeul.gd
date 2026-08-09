extends Place
## 🏢 쿼울 — 쿼카컴퍼니. 프롤로그.
##
## `docs/story-journey.md` 3절. 밤 11시, 사무실에서 걸어 나온다.
##
## **회사를 악당으로 만들지 않는다.** 나쁜 상사도 소리 지르는 장면도 없다.
## 그냥 여기가 내 자리가 아니었을 뿐이다. 회사에 나쁜 사람이 없어야
## 박차고 나온 것이 더 무겁다.
##
## 컷신을 안 쓴다. 직접 걸어 나오면서 걷기·말 걸기·사진을 다 배운다.

const DONE_FLAG := "prologue_done"

func place_name() -> String:
	return "쿼울"


func _init() -> void:
	legend = {
		"o": "stone-slab",   # 사무실 바닥
		"l": "cobble",       # 로비
		"c": "cobble",
		".": "dirt",         # 회사 앞 새벽 거리
		"g": "grass",
	}


## 위가 사무실, 가운데가 로비, 아래가 회사 앞. 걸어 내려오면 나간다.
func ground_map() -> String:
	return """
oooooooooooooooooooooooooooooooooooooooooooo
oooooooooooooooooooooooooooooooooooooooooooo
oooooooooooooooooooooooooooooooooooooooooooo
oooooooooooooooooooooooooooooooooooooooooooo
oooooooooooooooooooooooooooooooooooooooooooo
oooooooooooooooooooooooooooooooooooooooooooo
oooooooooooooooooooooooooooooooooooooooooooo
llllllllllllllllllllllllllllllllllllllllllll
llllllllllllllllllllllllllllllllllllllllllll
llllllllllllllllllllllllllllllllllllllllllll
llllllllllllllllllllllllllllllllllllllllllll
llllllllllllllllllllllllllllllllllllllllllll
............................................
............................................
............................................
............................................
gggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg
"""


func props() -> Array:
	return [
		# 사무실. 창밖으로 도시 불빛
		[6, 1, "office-window", false],
		[16, 1, "office-window", false],
		[26, 1, "office-window", false],
		[36, 1, "office-window", false],
		[8, 4, "desk", true],
		[8, 5, "office-chair", true],
		[15, 4, "desk", true],
		[22, 4, "desk", true],
		[29, 4, "desk", true],
		[36, 4, "cabinet", true],
		[3, 4, "cabinet", true],

		# 로비
		[20, 10, "reception", true],
		[34, 9, "return-box", true],
		[8, 10, "flower-pots", true],

		# 회사 앞
		[6, 15, "street-lamp", true],
		[36, 15, "street-lamp", true],
		[14, 15, "bench", true],
		[28, 14, "mailbox", true],
		[3, 16, "tree", true],
		[40, 16, "tree", true],
	]


## 프롤로그에서는 아무것도 안 줍는다. 챙길 건 세 개뿐이었다.
func pickups() -> Array:
	return []


## 자리에 앉은 채로 시작한다.
func spawn_tile() -> Vector2i:
	return Vector2i(8, 6)


## 여기서는 못 잔다. 오늘은 집에 가는 날이 아니다.
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)


## 회사 앞. 여기서 처음으로 어디 갈지 고른다.
func depart_tile() -> Vector2i:
	return Vector2i(21, 16)


func on_built() -> void:
	JourneyState.here = place_name()
	# 밤 11시에서 시작한다
	JourneyState.minutes = 23 * 60

	put_folk(Vector2i(22, 5), "seagull", "옆자리 동료", "coworker", [
		["아직 안 갔어요?", "…나도 이제 가려고."],
		["오늘도 막차겠네요."],
	], Vector2.DOWN)

	put_folk(Vector2i(18, 11), "seal", "경비 아저씨", "guard", [
		["오늘도 늦었네."],
		["…그래. 조심히 가."],
	], Vector2.RIGHT)

	# 창밖. 확대해야 보인다 — 그 한 순간이 프롤로그의 전부다
	put_spot(Vector2i(26, 3), "창밖", [
		"도시 불빛이 멀리까지 이어져 있다.",
		"저 끝에 비행기 한 대가 내려앉는다.",
		"…어디로 가는 걸까.",
	])

	# 반납함. 되돌릴 수 없다
	put_spot(Vector2i(34, 10), "반납함", [
		"사원증을 넣었다.",
		"덜컹, 하고 떨어지는 소리가 났다.",
	])

	put_spot(Vector2i(21, 15), "회사 앞", [
		"오늘은 퇴근이 아니라 출발이었다.",
	])

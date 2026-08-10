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

## 마음 칸별 대사. [칸0줄들, 칸1줄들, ...] — 없는 칸은 마지막 것을 쓴다.
var lines_by_heart: Array = []
## 한 번만 하는 말 (첫 만남·재회). 있으면 먼저 쓰고 비운다.
##
## 타입을 `Array[String]` 으로 뒀더니 여행지 파일에서 넘겨주는 평범한
## 배열이 대입되지 않고 조용히 실패했다 — **재회 대사가 통째로 안 붙었다.**
## 오류는 로그에만 남고 화면에서는 그냥 평소 인사를 했다.
var once: Array = []

var _talked := false
## 오늘 노을을 같이 봤나. 하루에 한 번이다.
var _dusk_warmed := false


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


func reset_day() -> void:
	_talked = false
	_dusk_warmed = false

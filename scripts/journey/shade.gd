class_name Shade
extends Folk
## 마을에 서서 기다리는 그늘. 누르면 마음 겨루기가 열린다.
##
## **`Folk` 를 그대로 물려받는다.** 눌러서 다가가 만나는 일이라는 점이
## 인연과 똑같아서, 탭 판정(`Place._folk_at`)·이름표·테두리·다가가기
## 예약(`_pending_talk`)을 새로 쓸 까닭이 없다. 다른 건 닿았을 때
## 대화 대신 전투가 열린다는 것뿐이다 (`Place.talk_to_near`).
##
## **눈에 보이게 세워 두는 것이 핵심이다.** 걷다가 저절로 튀어나오면
## 쉬러 온 사람이 방해받는다 — 이건 여행 게임이고, 싸울지 말지는
## 매번 사람이 고른다.

## 어느 그늘인가 (`Battle.ENEMIES` 의 열쇠).
var shade_kind := ""

## 인연의 금색과 갈라야 한다. 멀리서 봤을 때 "말 걸 사람" 과
## "붙어 볼 그늘" 이 같은 색으로 깜빡이면 고르고 말고가 없다.
const SHADE_TALK := Color(0.88, 0.44, 0.50, 0.92)


func pulse_color() -> Color:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var k: float = 0.5 + 0.5 * sin(t * TAU / QuoWalker.TALK_PULSE_SECS)
	return QuoWalker.OUTLINE_DARK.lerp(SHADE_TALK, k)


func near_color() -> Color:
	return SHADE_TALK


## 걷어냈다. 스르르 옅어지며 사라진다 — 터지거나 쓰러지지 않는다.
func dissolve() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(self, "scale", Vector2(1.15, 0.85), 0.5)
	tw.tween_callback(queue_free)

class_name MainQuest
extends RefCounted
## **이 게임의 줄기** - 한 줄로 말하면 "꿈속 액션 RPG: 아홉 구역의 우두머리를
## 차례로 쓰러뜨리고, 야근 대마왕을 물리쳐 꿈에서 깨어난다".
##
## "RPG 인가 스토리 게임인가 모르겠다" 는 말을 들었다. 마을 할 일(인사·줍기·
## 사진)이 화면 위 안내줄을 차지하고 있어서, 싸움은 곁가지처럼 보였던 것이다.
## 그래서 **줄기를 따로 늘 보여 준다** (`JourneyHud` 왼쪽 메뉴 아래) -
## 지금 몇 장이고, 이번 장에서 쓰러뜨릴 우두머리가 누구인지. 마을 이야기는
## 보상이 붙는 곁가지로 둔다.
##
##   프롤로그  꿈속 사무실 → 정류장
##   1~9장     구역마다 우두머리 (`Battle.REGION_BOSS`)
##   10장      꿈속 잿마루 타워 → 야근 계단길 → 야근 대마왕의 방 (다른 장과 같은 세 단계)
##   끝        깨어난 뒤 - 꿈의 탑

const TOTAL := 10
## 우두머리보다 이만큼 넘게 낮으면 "레벨이 모자라요" 로 알린다.
const LOW_GAP := 2


## 메인 퀘스트 칸 둘째 줄 끝에 붙일 한 마디 - 레벨이 모자라면 무엇을 하면 되는지.
static func level_note(m: Dictionary) -> String:
	if not m.has("boss_lv"):
		return ""
	if bool(m.get("low", false)):
		return "내 LV %d · 몬스터를 더 잡아 레벨을 올려요" % Battle.level
	return "내 LV %d · 도전할 만해요" % Battle.level


## `{chapter, head, goal, village}` - head 는 "3장 / 10" 같은 머리글.
static func now() -> Dictionary:
	if JourneyState.quest_done("엔딩:대마왕"):
		return {"chapter": TOTAL + 1, "head": "꿈에서 깼어요",
			"goal": "꿈의 탑 최고 %d층 - 더 높이" % Loop.tower_best, "village": ""}
	if not JourneyState.quest_done("잿마루:정류장"):
		return {"chapter": 0, "head": "프롤로그",
			"goal": "꿈속 사무실을 나가 정류장에서 첫 구역으로", "village": "잿마루"}
	for i in Quests.ORDER.size():
		var v := String(Quests.ORDER[i])
		var b := Battle.boss_of(v)
		if b == "" or Battle.boss_down(v):
			continue
		var blv := Battle.boss_lv(v)
		return {"chapter": i + 1, "head": "%d장 / %d  ·  %s" % [i + 1, TOTAL, v],
			"goal": "우두머리 %s 쓰러뜨리기  (LV %d)" % [String(Battle.ENEMIES[b]["name"]), blv],
			"village": v, "boss_lv": blv, "low": Battle.level < blv - LOW_GAP}
	var flv := Battle.boss_lv("잿마루")
	return {"chapter": TOTAL, "head": "%d장 / %d  ·  잿마루 타워" % [TOTAL, TOTAL],
		"goal": "야근 계단길 끝의 야근 대마왕 쓰러뜨리기  (LV %d)" % flv, "village": "잿마루",
		"boss_lv": flv, "low": Battle.level < flv - LOW_GAP}

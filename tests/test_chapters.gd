extends Node
## 4막 구조: 국내 → 해외 → 우주 → 다른 차원(엔딩)

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func travel(dest: String) -> bool:
	if not TravelState.start_trip(dest): return false
	TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	return not TravelState.collect_arrival().is_empty()

func _ready() -> void:
	print("=== 쿼플 4막 구조 테스트 ===")
	SaveManager.clear_save(); TravelState.reset()
	Episode0State.has_camera = true
	Episode0State.has_notebook = true
	Episode0State.has_travel_bag = true

	print("\n[1] 여행지 구성")
	ck("여행지 12곳", TravelState.DESTINATIONS.size() == 12, "%d곳" % TravelState.DESTINATIONS.size())
	ck("막 4개", TravelState.CHAPTERS.size() == 4)
	var per := {}
	for d in TravelState.DESTINATIONS:
		per[d.chapter] = int(per.get(d.chapter, 0)) + 1
	ck("국내 4 / 해외 4 / 우주 3 / 차원 1",
		per.get("korea",0)==4 and per.get("world",0)==4 and per.get("space",0)==3 and per.get("beyond",0)==1,
		str(per))
	# 모든 여행지에 기념품과 소식이 있는가
	var miss := []
	for d in TravelState.DESTINATIONS:
		if not TravelState.SOUVENIRS.has(d.id) or not TravelState.MID_MESSAGES.has(d.id):
			miss.append(d.id)
	ck("모든 곳에 기념품·소식", miss.is_empty(), str(miss))

	print("\n[2] 처음엔 국내만 열림")
	ck("서울 열림", TravelState.is_unlocked("seoul"))
	ck("강릉 열림", TravelState.is_unlocked("gangneung"))
	ck("교토 잠김", not TravelState.is_unlocked("kyoto"))
	ck("달 잠김", not TravelState.is_unlocked("moon"))
	ck("다른 차원 잠김", not TravelState.is_unlocked("rift"))
	ck("해금 안내", TravelState.unlock_hint("kyoto").contains("국내"), TravelState.unlock_hint("kyoto"))

	print("\n[3] 국내 3곳 → 해외 열림")
	ck("서울", travel("seoul"))
	ck("부산", travel("busan"))
	ck("아직 해외 잠김", not TravelState.is_unlocked("paris"), "국내 %d곳" % TravelState.chapter_cleared("korea"))
	ck("제주", travel("jeju"))
	ck("해외 열림", TravelState.is_unlocked("paris"), "국내 %d곳" % TravelState.chapter_cleared("korea"))
	ck("우주는 아직 잠김", not TravelState.is_unlocked("moon"))
	ck("같은 곳 재방문은 안 세짐", TravelState.chapter_cleared("korea") == 3)
	ck("서울 재방문", travel("seoul"))
	ck("여전히 국내 3곳", TravelState.chapter_cleared("korea") == 3)

	print("\n[4] 해외 3곳 → 우주 열림")
	ck("교토", travel("kyoto"))
	ck("파리", travel("paris"))
	ck("뉴욕", travel("newyork"))
	ck("우주 열림", TravelState.is_unlocked("moon"), "해외 %d곳" % TravelState.chapter_cleared("world"))
	ck("다른 차원 잠김", not TravelState.is_unlocked("rift"))

	print("\n[5] 우주 3곳 → 다른 차원 열림")
	ck("달", travel("moon"))
	ck("화성", travel("mars"))
	ck("토성", travel("saturn"))
	ck("다른 차원 열림", TravelState.is_unlocked("rift"), "우주 %d곳" % TravelState.chapter_cleared("space"))

	print("\n[6] 엔딩 — 한 번만, 돌아오지 않는다")
	ck("엔딩 전", not TravelState.ending_reached())
	ck("다른 차원 여행", travel("rift"))
	ck("엔딩 도달", TravelState.ending_reached())
	ck("다시 갈 수 없음", not TravelState.is_unlocked("rift"))
	ck("안내 문구", TravelState.unlock_hint("rift") == "이미 다녀왔어요", TravelState.unlock_hint("rift"))
	ck("앨범에 전부 기록", TravelState.collection.size() == 11, "%d개 (여행 11회)" % TravelState.collection.size())

	print("\n[7] 저장 / 복원")
	SaveManager.save_game()
	TravelState.reset()
	ck("리셋됨", not TravelState.ending_reached())
	ck("복원", SaveManager.load_game())
	ck("엔딩 상태 유지", TravelState.ending_reached())
	ck("막 진행도 유지", TravelState.chapter_cleared("space") == 3)

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

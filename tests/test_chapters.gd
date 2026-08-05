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
	var per := {}
	for d in TravelState.DESTINATIONS:
		per[d.chapter] = int(per.get(d.chapter, 0)) + 1
	ck("여행지 200곳 이상", TravelState.DESTINATIONS.size() >= 200, "%d곳" % TravelState.DESTINATIONS.size())
	ck("막 4개", TravelState.CHAPTERS.size() == 4)
	ck("국내 10곳 이상", int(per.get("korea", 0)) >= 10, "%d곳" % per.get("korea", 0))
	ck("해외 190곳 이상", int(per.get("world", 0)) >= 190, "%d곳" % per.get("world", 0))
	ck("우주 10곳 (해왕성~태양)", int(per.get("space", 0)) >= 10, "%d곳" % per.get("space", 0))
	ck("다른 차원 1곳", int(per.get("beyond", 0)) == 1)

	# id 중복 없는가
	var ids := {}
	var dup := []
	for d in TravelState.DESTINATIONS:
		if ids.has(d.id): dup.append(d.id)
		ids[d.id] = true
	ck("id 중복 없음", dup.is_empty(), str(dup))

	# 225곳 전부 기념품과 소식이 만들어지는가 (손으로 쓴 것 + 자동 생성)
	var bad_sv := []
	var bad_msg := []
	for d in TravelState.DESTINATIONS:
		var sv: Dictionary = TravelState._auto_souvenir(d, 0) if not TravelState.SOUVENIRS.has(d.id) else TravelState.SOUVENIRS[d.id][0]
		if str(sv.get("title", "")) == "" or str(sv.get("diary", "")) == "":
			bad_sv.append(d.id)
		var ms: Array = TravelState._auto_messages(d) if not TravelState.MID_MESSAGES.has(d.id) else TravelState.MID_MESSAGES[d.id]
		if ms.size() < 2:
			bad_msg.append(d.id)
	ck("모든 곳에 기념품", bad_sv.is_empty(), "%d곳 문제" % bad_sv.size())
	ck("모든 곳에 소식 2개", bad_msg.is_empty(), "%d곳 문제" % bad_msg.size())

	# 우주는 해왕성에서 태양 순서인가
	var space_ids := []
	for d in TravelState.DESTINATIONS:
		if d.chapter == "space": space_ids.append(d.id)
	ck("우주는 해왕성부터", space_ids[0] == "neptune", str(space_ids[0]))
	ck("우주는 태양에서 끝", space_ids[space_ids.size()-1] == "sun", str(space_ids[space_ids.size()-1]))

	print("\n[2] 처음엔 국내만 열림")
	ck("서울 열림", TravelState.is_unlocked("seoul"))
	ck("제주 열림", TravelState.is_unlocked("jeju"))
	ck("교토 잠김", not TravelState.is_unlocked("kyoto"))
	ck("달 잠김", not TravelState.is_unlocked("moon"))
	ck("다른 차원 잠김", not TravelState.is_unlocked("rift"))
	ck("해금 안내", TravelState.unlock_hint("japan").contains("국내"), TravelState.unlock_hint("japan"))

	print("\n[3] 국내 5곳 → 해외 열림")
	var korea5 = ["seoul", "busan", "incheon", "daegu", "gwangju"]
	for i in range(korea5.size()):
		ck(korea5[i], travel(korea5[i]))
		if i < korea5.size() - 1:
			ck("  아직 해외 잠김", not TravelState.is_unlocked("france"))
	ck("해외 열림", TravelState.is_unlocked("france"), "국내 %d곳" % TravelState.chapter_cleared("korea"))
	ck("우주는 아직 잠김", not TravelState.is_unlocked("moon"))
	ck("서울 재방문", travel("seoul"))
	ck("재방문은 안 세짐", TravelState.chapter_cleared("korea") == 5)

	print("\n[4] 해외 15곳 → 우주 열림")
	var world15 = ["japan", "france", "usa", "australia", "italy", "spain", "egypt",
		"brazil", "canada", "india", "thailand", "germany", "kenya", "peru", "iceland"]
	for i in range(world15.size()):
		if not travel(world15[i]):
			ck("여행 실패: " + world15[i], false)
	ck("해외 15곳", TravelState.chapter_cleared("world") == 15, "%d곳" % TravelState.chapter_cleared("world"))
	ck("우주 열림", TravelState.is_unlocked("neptune"))
	ck("다른 차원 잠김", not TravelState.is_unlocked("rift"))

	print("\n[5] 우주 8곳 → 다른 차원 열림")
	var space8 = ["neptune", "uranus", "saturn", "jupiter", "asteroid", "mars", "moon", "venus"]
	for s2 in space8:
		if not travel(s2):
			ck("여행 실패: " + s2, false)
	ck("우주 8곳", TravelState.chapter_cleared("space") == 8, "%d곳" % TravelState.chapter_cleared("space"))
	ck("다른 차원 열림", TravelState.is_unlocked("rift"))

	print("\n[6] 엔딩 — 한 번만, 돌아오지 않는다")
	ck("엔딩 전", not TravelState.ending_reached())
	ck("다른 차원 여행", travel("rift"))
	ck("엔딩 도달", TravelState.ending_reached())
	ck("다시 갈 수 없음", not TravelState.is_unlocked("rift"))
	ck("안내 문구", TravelState.unlock_hint("rift") == "이미 다녀왔어요", TravelState.unlock_hint("rift"))
	ck("앨범 기록", TravelState.collection.size() >= 28, "%d개" % TravelState.collection.size())

	print("\n[7] 저장 / 복원")
	SaveManager.save_game()
	TravelState.reset()
	ck("리셋됨", not TravelState.ending_reached())
	ck("복원", SaveManager.load_game())
	ck("엔딩 상태 유지", TravelState.ending_reached())
	ck("막 진행도 유지", TravelState.chapter_cleared("space") == 8)

	print("\n[8] 엔딩 화면")
	var es := load("res://scenes/ui/EndingScreen.tscn") as PackedScene
	ck("엔딩 씬 로드", es != null)
	if es:
		var inst = es.instantiate()
		add_child(inst)
		await get_tree().process_frame
		ck("엔딩 그룹 등록", inst.is_in_group("ending_screen"))
		var stats_label: Label = inst.get_node_or_null("Root/Center/Body/StatsLabel")
		ck("여행 통계 표시", stats_label != null and stats_label.text.contains("다녀온 곳"),
			stats_label.text.split("\n")[0] if stats_label else "없음")
		inst.queue_free()
		await get_tree().process_frame

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

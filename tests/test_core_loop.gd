extends Node
## 코어 루프 자동 테스트: 여행 → (오프라인 경과) → 도착 → 수집 → 저장/복원

var pass_n := 0
var fail_n := 0

func ck(name: String, cond: bool, extra := "") -> void:
	if cond: pass_n += 1; print("  ✔ ", name, ("  " + extra) if extra else "")
	else:    fail_n += 1; print("  ✘ ", name, "  ", extra)

func _ready() -> void:
	print("=== 쿼플 코어 루프 테스트 ===")
	SaveManager.clear_save()

	print("\n[1] 초기 상태")
	ck("여행 중 아님", not TravelState.is_traveling())
	ck("도착 아님", not TravelState.has_arrived())
	ck("앨범 비어있음", TravelState.collection.is_empty())
	ck("여행지 3곳", TravelState.DESTINATIONS.size() == 3,
		str(TravelState.DESTINATIONS.map(func(d): return d.name)))

	print("\n[2] 여행 보내기")
	ck("서울행 출발 성공", TravelState.start_trip("seoul"))
	ck("여행 중 상태", TravelState.is_traveling())
	ck("아직 도착 안 함", not TravelState.has_arrived())
	ck("남은 시간 > 0", TravelState.seconds_left() > 0, TravelState.format_time_left())
	ck("중복 출발 차단", not TravelState.start_trip("paris"))
	ck("없는 목적지 차단", not TravelState.start_trip("mars"))

	print("\n[3] 오프라인 시간 경과 (앱 종료 시뮬레이션)")
	var before := TravelState.progress()
	# 도착 시각을 과거로 당겨 '앱을 끈 채 시간이 흐른' 상황을 만든다
	TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	ck("도착 판정됨", TravelState.has_arrived())
	ck("여행 중 아님", not TravelState.is_traveling())
	ck("진행률 100%", is_equal_approx(TravelState.progress(), 1.0),
		"before=%.2f after=%.2f" % [before, TravelState.progress()])

	print("\n[4] 사진·일기 수집")
	var s := TravelState.collect_arrival()
	ck("기념품 받음", not s.is_empty())
	ck("제목 있음", s.has("title") and s.title != "", str(s.get("title","")))
	ck("일기 있음", s.has("diary") and s.diary != "")
	ck("사진 있음", s.has("photo") and s.photo != "")
	ck("목적지 기록됨", s.get("dest_id","") == "seoul")
	ck("앨범에 1개", TravelState.collection.size() == 1)
	ck("여행 초기화됨", TravelState.trip.is_empty())
	ck("중복 수집 방지", TravelState.collect_arrival().is_empty())
	ck("서울 방문 1회", TravelState.visit_count("seoul") == 1)

	print("\n[5] 저장 / 복원")
	SaveManager.save_game()
	var saved := TravelState.collection.size()
	TravelState.reset()
	ck("리셋 후 비어있음", TravelState.collection.is_empty())
	ck("불러오기 성공", SaveManager.load_game())
	ck("앨범 복원됨", TravelState.collection.size() == saved, "%d개" % TravelState.collection.size())
	ck("복원된 일기 유지", str(TravelState.collection[0].get("diary","")) != "")

	print("\n[6] 재방문 시 다른 사진")
	TravelState.start_trip("seoul")
	TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	var s2 := TravelState.collect_arrival()
	ck("두 번째 사진은 다른 것", s2.get("title","") != s.get("title",""),
		"%s vs %s" % [s.get("title",""), s2.get("title","")])
	ck("서울 방문 2회", TravelState.visit_count("seoul") == 2)

	print("\n[7] 진행 중 저장 후 복원 (앱 강제 종료 시나리오)")
	TravelState.start_trip("moon")
	var arrive_at: int = TravelState.trip.get("arrive_at", 0)
	SaveManager.save_game()
	TravelState.reset()
	SaveManager.load_game()
	ck("여행이 복원됨", TravelState.is_traveling())
	ck("도착 시각 보존", int(TravelState.trip.get("arrive_at", 0)) == arrive_at)
	ck("목적지 보존", TravelState.trip.get("dest_id","") == "moon")

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

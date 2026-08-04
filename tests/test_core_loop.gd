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
	# 0편을 마친 플레이어를 가정한다 (여행 물품 3개 보유)
	Episode0State.has_camera = true
	Episode0State.has_notebook = true
	Episode0State.has_travel_bag = true

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
	TravelState.start_trip("seoul")
	var arrive_at: int = TravelState.trip.get("arrive_at", 0)
	SaveManager.save_game()
	TravelState.reset()
	SaveManager.load_game()
	ck("여행이 복원됨", TravelState.is_traveling())
	ck("도착 시각 보존", int(TravelState.trip.get("arrive_at", 0)) == arrive_at)
	ck("목적지 보존", TravelState.trip.get("dest_id","") == "seoul")

	print("\n[8] 여행지 해금")
	SaveManager.clear_save(); TravelState.reset()
	Episode0State.has_camera = true
	Episode0State.has_notebook = true
	Episode0State.has_travel_bag = true
	ck("서울은 처음부터 열림", TravelState.is_unlocked("seoul"))
	ck("파리는 잠김", not TravelState.is_unlocked("paris"))
	ck("달도 잠김", not TravelState.is_unlocked("moon"))
	ck("잠긴 곳은 출발 불가", not TravelState.start_trip("paris"))
	ck("해금 안내 문구", TravelState.unlock_hint("paris").contains("서울"),
		TravelState.unlock_hint("paris"))
	# 서울 3번 다녀오기
	for i in range(3):
		TravelState.start_trip("seoul")
		TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
		TravelState.collect_arrival()
	ck("서울 3회 → 파리 해금", TravelState.is_unlocked("paris"), "서울 %d회" % TravelState.visit_count("seoul"))
	ck("달은 아직 잠김", not TravelState.is_unlocked("moon"))
	# 파리 2번
	for i in range(2):
		TravelState.start_trip("paris")
		TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
		TravelState.collect_arrival()
	ck("파리 2회 → 달 해금", TravelState.is_unlocked("moon"))

	print("\n[9] 0편 물품이 여행 기록에 반영")
	SaveManager.clear_save(); TravelState.reset()
	Episode0State.has_camera = false
	Episode0State.has_notebook = false
	Episode0State.has_travel_bag = false
	TravelState.start_trip("seoul")
	TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	var poor := TravelState.collect_arrival()
	ck("카메라 없으면 사진 없음", str(poor.get("title","")).contains("사진 없음"), str(poor.get("title","")))
	ck("수첩 없으면 일기 대체", str(poor.get("diary","")).contains("수첩이 없어서"))
	# 물품을 갖추면 정상 기록 (clear_save 가 0편 상태도 초기화하므로 그 뒤에 설정)
	SaveManager.clear_save(); TravelState.reset()
	Episode0State.has_camera = true
	Episode0State.has_notebook = true
	TravelState.start_trip("seoul")
	TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	var rich := TravelState.collect_arrival()
	ck("물품 있으면 정상 기록", not str(rich.get("title","")).contains("사진 없음"), str(rich.get("title","")))

	print("\n[10] 개발용 빠른 여행 전환")
	var seoul := TravelState.get_destination("seoul")
	var secs := TravelState.duration_of(seoul)
	ck("소요 시간이 설정됨", secs > 0, "%d초" % secs)

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

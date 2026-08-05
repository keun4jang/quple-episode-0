extends Node
## 저장 안전성: 손상되어도 기록이 날아가지 않는가

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func travel(d: String) -> void:
	if TravelState.start_trip(d):
		TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
		TravelState.collect_arrival()

func _ready() -> void:
	print("=== 저장 안전성 테스트 ===")
	SaveManager.clear_save()
	Episode0State.has_camera = true
	Episode0State.has_notebook = true
	Episode0State.has_travel_bag = true

	print("\n[1] 기본 저장/복원")
	travel("seoul"); travel("busan")
	SaveManager.save_game()
	ck("저장 파일 생성", FileAccess.file_exists(SaveManager.SAVE_PATH))
	ck("임시 파일은 안 남음", not FileAccess.file_exists(SaveManager.TEMP_PATH))
	var n0 := TravelState.collection.size()
	TravelState.reset()
	ck("불러오기", SaveManager.load_game())
	ck("기록 복원", TravelState.collection.size() == n0, "%d개" % TravelState.collection.size())

	print("\n[2] 두 번째 저장 → 백업 생성")
	travel("jeju")
	SaveManager.save_game()
	ck("백업 생성됨", SaveManager.has_backup())
	var n1 := TravelState.collection.size()
	ck("기록 늘어남", n1 == n0 + 1, "%d개" % n1)

	print("\n[3] 저장본이 깨져도 백업으로 복구")
	# 저장 파일을 일부러 망가뜨린다
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("[game]\nversion=2\n이건 깨진 파일입니다 @#$%^&*(")
	f.close()
	TravelState.reset()
	Episode0State.reset()
	ck("깨진 파일 감지", not SaveManager._is_valid(SaveManager.SAVE_PATH))
	ck("백업에서 복구", SaveManager.load_game())
	ck("기록이 날아가지 않음", TravelState.collection.size() > 0,
		"%d개 복구" % TravelState.collection.size())
	ck("복구 후 저장본 정상화", SaveManager._is_valid(SaveManager.SAVE_PATH))
	ck("백업도 온전히 유지", SaveManager.has_backup(),
		"복구가 백업을 덮어쓰지 않아야 한다")
	# 한 번 더 깨뜨려도 또 복구되는가
	var f2 := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f2.store_string("또 깨짐 !!!")
	f2.close()
	TravelState.reset()
	ck("두 번째 손상도 복구", SaveManager.load_game() and TravelState.collection.size() > 0,
		"%d개" % TravelState.collection.size())

	print("\n[4] 저장본도 백업도 없으면")
	SaveManager.clear_save()
	ck("불러오기 실패 처리", not SaveManager.load_game())
	ck("백업 없음", not SaveManager.has_backup())

	print("\n[5] 저장 중 중단되어도 기존 기록은 안전")
	travel("seoul")
	SaveManager.save_game()
	var before := TravelState.collection.size()
	# 임시 파일만 깨진 채 남은 상황을 흉내
	var t := FileAccess.open(SaveManager.TEMP_PATH, FileAccess.WRITE)
	t.store_string("깨진 임시 파일")
	t.close()
	TravelState.reset()
	ck("정상 저장본으로 불러옴", SaveManager.load_game())
	ck("기록 그대로", TravelState.collection.size() == before, "%d개" % TravelState.collection.size())

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

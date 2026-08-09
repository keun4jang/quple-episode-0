extends Node
## 저장·복원. **깨진 저장본이 사람을 가두지 않는 것**이 이 파일의 목적이다.

var pass_n := 0
var fail_n := 0

func ck(n: String, c: bool, e := "") -> void:
	if c:
		pass_n += 1
		print("  ✔ ", n, ("  " + e) if e else "")
	else:
		fail_n += 1
		print("  ✘ ", n, "  ", e)


func _ready() -> void:
	print("=== 저장 테스트 ===")

	print("\n[1] 저장하고 불러오면 그대로다")
	SaveManager.clear_save()
	JourneyState.pick("p-shell", 3)
	JourneyState.warm("raccoon", 2)
	JourneyState.visit("쿼릉")
	JourneyState.take_photo("쿼릉", "등대")
	JourneyState.day = 4
	SaveManager.save_game("res://scenes/journey/Gwaeleung.tscn")

	JourneyState.reset()
	ck("초기화하면 빈다", JourneyState.total() == 0)
	ck("불러오기 성공", SaveManager.load_game())
	ck("배낭이 돌아온다", JourneyState.count("p-shell") == 3)
	ck("마음이 돌아온다", JourneyState.heart("raccoon") == 2)
	ck("다녀온 곳이 돌아온다", JourneyState.places_visited() == 1)
	ck("사진이 돌아온다", JourneyState.photos.size() == 1)
	ck("며칠째인지 돌아온다", JourneyState.day == 4)
	ck("자리가 돌아온다",
		SaveManager.get_current_scene() == "res://scenes/journey/Gwaeleung.tscn")

	print("\n[2] 반쯤 쓰인 파일을 진짜 저장본으로 만들지 않는다")
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("[game]\nversion=2\n")     # journey 칸이 없다
	f.close()
	ck("알맹이 없는 파일은 안 읽는다", not SaveManager._is_valid(SaveManager.SAVE_PATH))

	print("\n[3] 저장본이 깨지면 백업에서 살린다")
	SaveManager.clear_save()
	JourneyState.pick("p-acorn", 1)
	SaveManager.save_game("res://scenes/journey/Home.tscn")   # ①
	JourneyState.pick("p-acorn", 1)
	SaveManager.save_game("res://scenes/journey/Home.tscn")   # ② (①이 백업으로)
	ck("백업이 생겼다", SaveManager.has_backup())

	var bad := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	bad.store_string("깨진 파일")
	bad.close()
	JourneyState.reset()
	ck("깨져도 불러와진다", SaveManager.load_game())
	ck("백업 시점으로 돌아온다", JourneyState.count("p-acorn") >= 1)
	ck("살린 뒤 저장본이 온전하다", SaveManager._is_valid(SaveManager.SAVE_PATH))

	print("\n[4] 저장이 아예 없어도 안 죽는다")
	SaveManager.clear_save()
	ck("불러오기 실패를 알려 준다", not SaveManager.load_game())
	ck("갈 자리는 있다", SaveManager.get_current_scene() == SaveManager.HUB)

	print("\n[5] 기록 초기화")
	JourneyState.pick("p-flower", 1)
	SaveManager.save_game()
	SaveManager.clear_save()
	ck("파일이 지워진다", not SaveManager.has_save())
	ck("들고 있던 것도 비워진다", JourneyState.total() == 0)

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)

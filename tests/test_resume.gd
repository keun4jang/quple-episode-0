extends Node
## "이어하기" 는 어디로 가는가.
##
## 예전 규칙은 "0편을 깼으면 여행 허브로" 였다. 게임이 탑다운 여행으로
## 바뀌면서 옛 맵들(횡스크롤 0편·3D 맵·옛 여행 화면)이 전부 게임 밖으로
## 나갔고, 규칙도 하나로 단순해졌다 —
##
##   **옛 맵을 가리키는 저장은 무시하고 여행으로 보낸다.**
##
## 이 테스트가 지키는 것은 여전히 같다. 예전에 저장해 둔 사람이 **할 일이
## 하나도 없는 화면에 갇히지 않는 것.** 갱신만 받으면 풀려나야 한다.

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
	print("=== 이어하기 복귀 테스트 ===")
	var hub := SaveManager.HUB

	print("\n[1] 여행 중이면 그 자리로 돌아간다")
	SaveManager.clear_save()
	SaveManager.autosave("res://scenes/journey/Gwaeleung.tscn")
	ck("쿼릉으로 이어진다",
		SaveManager.get_current_scene() == "res://scenes/journey/Gwaeleung.tscn",
		SaveManager.get_current_scene())

	SaveManager.autosave("res://scenes/journey/Home.tscn")
	ck("고향도 그 자리로",
		SaveManager.get_current_scene() == "res://scenes/journey/Home.tscn",
		SaveManager.get_current_scene())

	print("\n[2] 옛 맵을 가리키는 저장은 여행으로 보낸다")
	for old in [
		"res://scenes/side/Office.tscn",              # 옛 횡스크롤 0편
		"res://scenes/side/Front.tscn",
		"res://scenes/maps/CompanyFront3D.tscn",      # 옛 3D 맵
		"res://scenes/travel/TravelHub.tscn",         # 옛 여행 허브
		"res://scenes/travel/SouvenirRoom3D.tscn",    # 옛 기념품 방
	]:
		SaveManager.autosave(old)
		ck("%s → 여행" % old.get_file(),
			SaveManager.get_current_scene() == hub,
			SaveManager.get_current_scene())

	print("\n[3] 저장이 아예 없으면 처음부터")
	SaveManager.clear_save()
	ck("저장이 없으면 프롤로그로", SaveManager.get_current_scene() == hub,
		SaveManager.get_current_scene())
	ck("기본 자리가 쿼카컴퍼니다", hub.contains("Gwaeul"), hub)

	print("\n[4] 0편을 깬 기록이 있어도 규칙은 같다")
	# 예전엔 이 값이 이어하기를 좌우했다. 지금은 안 본다.
	Episode0State.episode0_cleared = true
	SaveManager.autosave("res://scenes/journey/Gwaedo.tscn")
	ck("깬 기록과 상관없이 그 자리로",
		SaveManager.get_current_scene() == "res://scenes/journey/Gwaedo.tscn",
		SaveManager.get_current_scene())
	Episode0State.episode0_cleared = false

	print("\n[5] 갈 수 있는 곳만 가리킨다")
	# 이어하기가 없는 씬을 가리키면 켜자마자 죽는다
	SaveManager.autosave("res://scenes/journey/Gwaesan.tscn")
	var target := SaveManager.get_current_scene()
	ck("가리키는 씬이 실제로 있다", ResourceLoader.exists(target), target)

	SaveManager.clear_save()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)

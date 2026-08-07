extends Node
## 0편을 깬 뒤 "이어하기" 는 어디로 가는가.
##
## 한 번 깬 사람이 이어하기를 누를 때마다 할 일 없는 밤 11시 회사 앞으로
## 돌아오던 문제가 있었다. 나가는 길이 설정→메인화면뿐인데 그 버튼이
## 같은 자리를 다시 저장해서 영영 빠져나올 수 없었다.

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

const HUB := "res://scenes/travel/TravelHub.tscn"

func _ready() -> void:
	print("=== 이어하기 복귀 테스트 ===")

	print("\n[1] 0편 진행 중이면 그 자리로 돌아간다")
	SaveManager.clear_save()
	Episode0State.reset()
	Episode0State.advance_to(Episode0State.State.FIND_PARTNER)
	SaveManager.autosave("res://scenes/side/Office.tscn")
	ck("사무실로 이어진다", SaveManager.get_current_scene() == "res://scenes/side/Office.tscn",
		SaveManager.get_current_scene())

	print("\n[2] 0편을 깼으면 여행 허브로 간다")
	Episode0State.episode0_cleared = true
	ck("옆맵 저장을 무시하고 허브로", SaveManager.get_current_scene() == HUB,
		SaveManager.get_current_scene())
	SaveManager.autosave("res://scenes/maps/CompanyFront3D.tscn")
	ck("옛 3D 경로도 허브로", SaveManager.get_current_scene() == HUB,
		SaveManager.get_current_scene())

	print("\n[3] 깬 뒤 여행 화면은 그대로 이어진다")
	SaveManager.autosave("res://scenes/travel/SouvenirRoom3D.tscn")
	ck("기념품 방은 그 자리로",
		SaveManager.get_current_scene() == "res://scenes/travel/SouvenirRoom3D.tscn",
		SaveManager.get_current_scene())

	print("\n[4] 이미 갇힌 저장 파일도 풀려난다")
	# 갱신 전에 회사 앞이 저장된 채 클리어된 사람
	SaveManager.clear_save()
	Episode0State.reset()
	Episode0State.episode0_cleared = true
	SaveManager.autosave("res://scenes/side/Front.tscn")
	ck("갇힌 저장도 허브로 나온다", SaveManager.get_current_scene() == HUB,
		SaveManager.get_current_scene())

	SaveManager.clear_save()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)

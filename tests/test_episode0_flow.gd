extends Node
## 0편 스토리 흐름 자동 검증: START → CLEAR

var pass_n := 0
var fail_n := 0
func ck(name: String, cond: bool, extra := "") -> void:
	if cond: pass_n += 1; print("  ✔ ", name, ("  " + extra) if extra else "")
	else: fail_n += 1; print("  ✘ ", name, "  ", extra)

func _ready() -> void:
	print("=== 쿼플 0편 흐름 테스트 ===")
	SaveManager.clear_save()
	var S = Episode0State.State

	print("\n[1] 상태 순서가 스펙과 일치")
	var order = [S.START, S.ENTER_COMPANY, S.FIND_PARTNER, S.TALK_PARTNER, S.CHOICE_WAIT,
		S.EAVESDROP_BOSS, S.RETURN_TO_PARTNER, S.COLLECT_TRAVEL_ITEMS, S.RETURN_BADGE,
		S.PARTNER_JOINED, S.FIRST_PHOTO, S.ALBUM_CREATED, S.CLEAR]
	var ok := true
	for i in range(order.size()):
		if order[i] != i: ok = false
	ck("13단계 순서 정확", ok, "START=%d ... CLEAR=%d" % [S.START, S.CLEAR])

	print("\n[2] 진행은 되돌아가지 않는다")
	Episode0State.reset()
	Episode0State.advance_to(S.FIND_PARTNER)
	Episode0State.advance_to(S.ENTER_COMPANY)
	ck("역행 차단", Episode0State.current_state == S.FIND_PARTNER)

	print("\n[3] 목표(바람 노트)가 상태마다 바뀐다")
	Episode0State.reset()
	ck("시작 목표", Episode0State.get_objective() == "쿼카전자 안으로 들어가기",
		Episode0State.get_objective())
	Episode0State.advance_to(S.COLLECT_TRAVEL_ITEMS)
	ck("물품 수집 목표", Episode0State.get_objective() == "여행 물품 3가지 챙기기",
		Episode0State.get_objective())

	print("\n[4] 여행 물품 3가지")
	Episode0State.reset()
	ck("처음엔 미완", not Episode0State.all_items_collected())
	Episode0State.has_camera = true
	Episode0State.has_notebook = true
	ck("2개로는 미완", not Episode0State.all_items_collected())
	Episode0State.has_travel_bag = true
	ck("3개 모두 → 완료", Episode0State.all_items_collected())

	print("\n[5] 사진 → 앨범 → 클리어 플래그")
	Episode0State.advance_to(S.FIRST_PHOTO)
	# FIRST_PHOTO 는 "이제 찍어야 한다"는 단계 — 아직 찍은 게 아니다
	ck("FIRST_PHOTO 단계에선 아직 안 찍음", not Episode0State.first_photo_taken,
		"※ 이게 참이면 사진 지점(노란 원)이 안 뜬다")
	Episode0State.advance_to(S.ALBUM_CREATED)
	ck("사진 찍음 처리", Episode0State.first_photo_taken)
	ck("album_created", Episode0State.album_created)
	Episode0State.advance_to(S.CLEAR)
	ck("episode0_cleared", Episode0State.episode0_cleared)

	print("\n[6] 자동 저장 / 복원")
	Episode0State.badge_returned = true
	Episode0State.partner_joined = true
	SaveManager.autosave("res://scenes/maps/CompanyFront3D.tscn", Vector3(1, 2, 3))
	var saved_state = Episode0State.current_state
	Episode0State.reset()
	ck("리셋됨", Episode0State.current_state == S.START)
	ck("불러오기 성공", SaveManager.load_game())
	ck("상태 복원", Episode0State.current_state == saved_state)
	ck("물품 복원", Episode0State.all_items_collected())
	ck("사원증 복원", Episode0State.badge_returned)
	ck("씬 경로 복원", SaveManager.get_current_scene().ends_with("CompanyFront3D.tscn"))
	ck("위치 복원", SaveManager.get_player_position() == Vector3(1, 2, 3))

	print("\n[7] 앨범 해금 (min_state 7 / 11)")
	Episode0State.reset()
	Episode0State.advance_to(S.COLLECT_TRAVEL_ITEMS)
	ck("물품 단계에 첫 사진 해금", Episode0State.current_state >= 7)
	Episode0State.advance_to(S.ALBUM_CREATED)
	ck("앨범 단계에 두번째 해금", Episode0State.current_state >= 11)

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

extends Node
## 0편 전체 플레이스루 시뮬레이션. 두 선택지 경로를 모두 끝까지 통과시킨다.

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _ready() -> void:
	print("=== 0편 플레이스루 시뮬레이션 ===")
	var S = Episode0State.State
	for path in [0, 1]:
		print("\n--- 선택지 %d 경로 ---" % path)
		SaveManager.clear_save()
		Episode0State.reset()

		# 1. 회사 앞 오프닝
		Episode0State.advance_to(S.ENTER_COMPANY)
		ck("오프닝 → ENTER_COMPANY", Episode0State.current_state == S.ENTER_COMPANY)

		# 2. 로비 진입 → 애인 찾기
		Episode0State.advance_to(S.FIND_PARTNER)
		ck("로비 → FIND_PARTNER", Episode0State.current_state == S.FIND_PARTNER)

		# 3. 애인과 대화
		Episode0State.advance_to(S.TALK_PARTNER)
		ck("대화 → TALK_PARTNER", Episode0State.current_state == S.TALK_PARTNER)

		# 4. 선택지
		if path == 0:
			Episode0State.advance_to(S.CHOICE_WAIT)
		else:
			Episode0State.advance_to(S.CHOICE_WAIT)
		ck("선택지 → CHOICE_WAIT", Episode0State.current_state == S.CHOICE_WAIT)

		# 5. 엿듣기 (스펙 필수 장면)
		Episode0State.advance_to(S.EAVESDROP_BOSS)
		ck("대표실 → EAVESDROP_BOSS", Episode0State.current_state == S.EAVESDROP_BOSS,
			"※ 선택지 0에서도 반드시 도달해야 함")

		# 6. 애인에게 복귀
		Episode0State.advance_to(S.RETURN_TO_PARTNER)
		Episode0State.advance_to(S.COLLECT_TRAVEL_ITEMS)
		ck("복귀 → COLLECT_TRAVEL_ITEMS", Episode0State.current_state == S.COLLECT_TRAVEL_ITEMS)

		# 7. 여행 물품 3개
		Episode0State.has_camera = true
		Episode0State.has_notebook = true
		Episode0State.has_travel_bag = true
		ck("물품 3개 수집", Episode0State.all_items_collected())
		Episode0State.advance_to(S.RETURN_BADGE)

		# 8. 사원증 반납
		Episode0State.badge_returned = true
		Episode0State.partner_joined = true
		Episode0State.advance_to(S.PARTNER_JOINED)
		ck("사원증 반납 → PARTNER_JOINED", Episode0State.current_state == S.PARTNER_JOINED)

		# 9. 회사 앞 복귀 → 사진
		Episode0State.advance_to(S.FIRST_PHOTO)
		ck("회사 앞 → FIRST_PHOTO", Episode0State.current_state == S.FIRST_PHOTO)

		# 10. 앨범 + 클리어
		Episode0State.advance_to(S.ALBUM_CREATED)
		Episode0State.advance_to(S.CLEAR)
		ck("클리어 도달", Episode0State.current_state == S.CLEAR)
		ck("클리어 플래그", Episode0State.episode0_cleared and Episode0State.album_created
			and Episode0State.first_photo_taken)

	print("\n--- 재진입 안정성 ---")
	Episode0State.reset()
	Episode0State.advance_to(S.FIRST_PHOTO)
	Episode0State.partner_joined = true
	ck("사진 단계 재진입 시 애인 동행 조건",
		Episode0State.current_state >= S.PARTNER_JOINED and not Episode0State.first_photo_taken,
		"※ 회사 앞을 다시 방문해도 애인이 있어야 함")

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)

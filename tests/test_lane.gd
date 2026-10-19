extends Node
## 쿼카 군단 규칙 (LaneData / LaneState / LaneBattle).
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
	print("=== 쿼카 군단 테스트 ===")
	print("\n[1] 표")
	ck("1번은 풀밭 1-1", LaneData.stage_label(1) == "풀밭 1-1")
	ck("100번은 악몽 하수구 우두머리", bool(LaneData.stage_info(100)["boss"]) and LaneData.stage_label(100) == "악몽 하수구 10-10")
	var last: Dictionary = LaneData.ZONES[9]
	ck("마지막 우두머리는 바퀴벌레 대왕", String(last["boss"]) == "roach_king" and LaneData.BUGS["roach_king"]["name"] == "바퀴벌레 대왕")
	ck("우두머리 판에는 우두머리가 나온다", LaneData.spawns(10).any(func(s): return bool(s.get("boss", false))))
	ck("보통 판에는 안 나온다", not LaneData.spawns(9).any(func(s): return bool(s.get("boss", false))))
	ck("갈수록 벌레가 세다", LaneData.magnification(80) > LaneData.magnification(5))
	ck("처음 깨면 더 받는다", int(LaneData.reward(5, true)["xp"]) > int(LaneData.reward(5, false)["xp"]))
	ck("레벨이 오를수록 비싸다", LaneData.level_cost("tiny", 10) > LaneData.level_cost("tiny", 2))
	var all_sprites := true
	for k in LaneData.BUGS.keys():
		if not ResourceLoader.exists("res://assets/sprites/bug-%s.png" % k):
			all_sprites = false
			print("    그림 없음: ", k)
	ck("벌레 그림이 전부 있다", all_sprites)
	for z in LaneData.ZONES:
		for b in z["bugs"]:
			if not LaneData.BUGS.has(b):
				ck("구역 벌레가 표에 있다 (%s)" % b, false)

	print("\n[2] 성장·편성")
	LaneState.reset()
	ck("처음엔 꼬마·방패", LaneState.has_unit("tiny") and LaneState.has_unit("shield") and not LaneState.has_unit("spear"))
	var r := LaneState.on_win(1)
	ck("1번을 깨면 꿈조각·꿈별", int(r["xp"]) > 0 and int(r["stars"]) > 0 and bool(r["first"]) and LaneState.cleared == 1)
	r = LaneState.on_win(2)
	ck("2번을 깨면 창 쿼카 합류", (r["new_units"] as Array).has("spear") and LaneState.lineup.has("spear"))
	var r2 := LaneState.on_win(1)
	ck("깬 판을 또 깨면 처음 보상은 없다", not bool(r2["first"]) and int(r2["stars"]) == 0 and LaneState.cleared == 2)
	LaneState.xp = 0
	ck("꿈조각이 없으면 레벨업 못 한다", not LaneState.level_up("tiny"))
	LaneState.xp = 999999
	var hp1 := float(LaneState.unit_stats("tiny")["hp"])
	ck("레벨업", LaneState.level_up("tiny") and LaneState.level_of("tiny") == 2)
	ck("레벨이 오르면 20% 세진다", is_equal_approx(float(LaneState.unit_stats("tiny")["hp"]), hp1 * 1.2))
	ck("편성에서 뺀다", LaneState.toggle_lineup("spear") and not LaneState.lineup.has("spear"))
	ck("다시 넣는다", LaneState.toggle_lineup("spear") and LaneState.lineup.has("spear"))
	ck("없는 쿼카는 못 넣는다", not LaneState.toggle_lineup("giant"))
	LaneState.lineup = ["tiny"]
	ck("마지막 한 마리는 못 뺀다", not LaneState.toggle_lineup("tiny"))

	print("\n[3] 한 판")
	LaneState.reset()
	var b := LaneBattle.new()
	b.start(1, 5)
	ck("처음엔 꿈빛 0", b.wallet == 0.0 and not b.can_summon("tiny"))
	b.tick(2.0)
	ck("꿈빛이 저절로 찬다", b.wallet > 50.0, str(b.wallet))
	ck("소환", b.summon("tiny") and b.ents.size() >= 1)
	ck("곧바로 또 못 낸다 (대기시간)", not b.summon("tiny"))
	var w0 := b.worker
	b.wallet = 1000.0
	ck("수입 올리기", b.upgrade_worker() and b.worker == w0 + 1)
	ck("수입을 올리면 한도도 커진다", b.wallet_cap() > int(LaneData.WALLET_CAP[0]))
	ck("대포는 처음엔 못 쏜다", not b.fire_cannon())
	b.cannon = LaneData.CANNON_CHARGE
	ck("다 차면 쏜다", b.fire_cannon() and b.cannon == 0.0)
	# 끝까지: 레벨을 많이 올리면 1번은 저절로 이긴다
	LaneState.reset()
	LaneState.units["tiny"] = 10
	LaneState.units["shield"] = 10
	var w := LaneBattle.new()
	w.start(1, 2)
	w.auto = true
	var tt := 0.0
	var kinds := {}
	while not w.done and tt < 600.0:
		for e in w.tick(0.25):
			kinds[e["k"]] = true
		tt += 0.25
	ck("자동 소환으로 1번을 이긴다", w.result == "win", "%s %.0f초" % [w.result, tt])
	ck("넉백이 일어난다", kinds.has("kb"))
	ck("벌레를 잡는다", kinds.has("die"))
	ck("둥지를 친다", kinds.has("base_hit"))
	# 아무것도 안 내면 진다
	LaneState.reset()
	var l := LaneBattle.new()
	l.start(1, 2)
	var tl := 0.0
	while not l.done and tl < 900.0:
		l.tick(0.5)
		tl += 0.5
	ck("가만히 있으면 진다", l.result == "lose", "%s %.0f초" % [l.result, tl])
	# 우두머리 충격파
	LaneState.reset()
	LaneState.cleared = 9
	LaneState.unlock_by_stage()
	var bb := LaneBattle.new()
	bb.start(10, 1)
	bb.wallet = 5000.0
	for id in bb.lineup:
		bb.cds[id] = 0.0
		bb.summon(String(id))
	var shock := false
	var tb := 0.0
	while tb < 20.0 and not shock:
		for e in bb.tick(0.25):
			if e["k"] == "shock":
				shock = true
		tb += 0.25
	ck("우두머리가 나오면 충격파", shock)

	print("\n[4] 저장")
	LaneState.reset()
	LaneState.xp = 4321
	LaneState.stars = 77
	LaneState.cleared = 15
	LaneState.unlock_by_stage()
	LaneState.units["spear"] = 7
	LaneState.auto_summon = true
	LaneState.save(999)
	LaneState.reset()
	ck("불러온다", LaneState.load_save())
	ck("전부 돌아온다", LaneState.xp == 4321 and LaneState.stars == 77 and LaneState.cleared == 15
		and LaneState.level_of("spear") == 7 and LaneState.auto_summon and LaneState.last_seen == 999)
	LaneState.from_dict({"cleared": 999, "units": {"tiny": 99, "nope": 3}, "lineup": ["nope", "tiny", "tiny"]})
	ck("망가진 값은 범위 안으로", LaneState.cleared == LaneData.STAGE_MAX and LaneState.level_of("tiny") == LaneData.UNIT_LV_MAX
		and not LaneState.units.has("nope") and LaneState.lineup.count("tiny") == 1)
	LaneState.clear_save()
	ck("지우면 없다", not LaneState.has_save())
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)

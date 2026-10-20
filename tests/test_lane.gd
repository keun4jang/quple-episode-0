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
	ck("깬 판을 또 깨면 처음 보상은 없다", not bool(r2["first"]) and int(r2["stars"]) == 1 and LaneState.cleared == 2)
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
	_test_gacha()
	_test_extras()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)


func _test_gacha() -> void:
	print("\n[뽑기·매일 선물·특성]")
	LaneState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	ck("처음엔 선물 티켓 1장", LaneState.tickets == 1 and LaneState.can_pull(1))
	var r := LaneState.pull(1, rng)
	ck("첫 뽑기는 새 친구", r.size() == 1 and bool(r[0]["new"]))
	ck("티켓을 썼고 꿈별은 그대로", LaneState.tickets == 0 and LaneState.stars == 0)
	ck("뽑은 친구가 편성에 들어간다", LaneState.lineup.has(String(r[0]["id"])))
	ck("꿈별이 없으면 못 뽑는다", not LaneState.can_pull(1) and LaneState.pull(1, rng).is_empty())
	LaneState.stars = LaneData.GACHA10_COST
	var r10 := LaneState.pull(10, rng)
	var best := 0
	for x in r10:
		best = maxi(best, int(LaneData.RARITY_STARS[String(x["rarity"])]))
	ck("10번 뽑기 = 10마리, 특급 이상 하나", r10.size() == 10 and best >= 2 and LaneState.stars == 0)
	# 중복은 레벨 +1, 최고 레벨이면 꿈조각
	LaneState.units["chick"] = LaneData.UNIT_LV_MAX
	var xp0 := LaneState.xp
	var g := LaneState._grant("chick")
	ck("최고 레벨 중복은 꿈조각", int(g["xp"]) > 0 and LaneState.xp == xp0 + int(g["xp"]))
	LaneState.units["frog"] = 3
	g = LaneState._grant("frog")
	ck("중복은 레벨 +1", LaneState.level_of("frog") == 4 and not bool(g["new"]))
	# 천장: 전설 없이 PITY-1 번 뽑았으면 다음은 전설
	LaneState.pity = LaneData.PITY_LEGEND - 1
	ck("천장이면 전설", LaneData.rarity(LaneState.roll(rng)) == "legend" and LaneState.pity == 0)
	# 확률이 대충 맞나 (2000번)
	var cnt := {"rare": 0, "super": 0, "legend": 0}
	for i in 2000:
		LaneState.pity = 0
		cnt[LaneData.rarity(LaneState.roll(rng))] += 1
	ck("확률이 대충 맞다", absf(float(cnt["rare"]) / 2000.0 - 0.72) < 0.04 and absf(float(cnt["legend"]) / 2000.0 - 0.04) < 0.02,
		str(cnt))
	# 매일 선물
	var day := 86400 * 20000
	var d1 := LaneState.claim_daily(day + 100)
	ck("매일 선물 받는다", not d1.is_empty() and int(d1["streak"]) == 1)
	ck("같은 날엔 또 못 받는다", LaneState.claim_daily(day + 5000).is_empty())
	var d2 := LaneState.claim_daily(day + 86400 + 10)
	ck("다음 날 이어진다", int(d2["streak"]) == 2)
	var d3 := LaneState.claim_daily(day + 86400 * 4)
	ck("하루 빠지면 처음부터", int(d3["streak"]) == 1)
	# 저장
	LaneState.tickets = 4
	LaneState.pity = 9
	var dd := LaneState.to_dict()
	LaneState.reset()
	LaneState.from_dict(dd)
	ck("뽑기 상태 저장", LaneState.tickets == 4 and LaneState.pity == 9 and LaneState.has_unit("frog"))
	# 특성: 개구리는 날벌레에 1.5배, 고슴도치는 기어다니는 벌레에게 반만 맞는다
	LaneState.reset()
	LaneState.units["frog"] = 1
	LaneState.units["hedgehog"] = 1
	LaneState.lineup = ["frog", "hedgehog"]
	var b := LaneBattle.new()
	b.start(1, 3)
	var frog := b._make(LaneState.unit_stats("frog"), "q", 100.0)
	var mos := b._make(LaneData.BUGS["mosquito"].merged({"id": "mosquito"}), "b", 200.0)
	var ant := b._make(LaneData.BUGS["ant"].merged({"id": "ant"}), "b", 200.0)
	var hog := b._make(LaneState.unit_stats("hedgehog"), "q", 100.0)
	var h0 := float(mos["hp"])
	b._strike(frog, mos, 10.0)
	ck("강함: 1.5배로 때린다", is_equal_approx(h0 - float(mos["hp"]), 15.0))
	var hh := float(hog["hp"])
	b._strike(ant, hog, 10.0)
	ck("강함: 반만 맞는다", is_equal_approx(hh - float(hog["hp"]), 5.0))
	LaneState.units["owl"] = 1
	var owl := b._make(LaneState.unit_stats("owl"), "q", 100.0)
	var mos2 := b._make(LaneData.BUGS["mosquito"].merged({"id": "mosquito"}), "b", 200.0)
	var m0 := float(mos2["hp"])
	b._strike(owl, mos2, 10.0)
	ck("굉장히 강함: 2.5배", is_equal_approx(m0 - float(mos2["hp"]), 25.0))
	ck("벽 판정", LaneData.is_wall("turtle") and not LaneData.is_wall("owl"))
	var all_ok := true
	for id in LaneData.ALL_ORDER:
		if not ResourceLoader.exists(LaneData.sheet_path(String(id), 1)) or not ResourceLoader.exists(LaneData.sheet_path(String(id), 10)):
			all_ok = false
	ck("모든 친구 그림이 있다 (진화 포함)", all_ok)
	LaneState.reset()


func _test_extras() -> void:
	print("\n[보물·장신구·콤보·옛 저장]")
	LaneState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var firsts := 0
	for i in 200:
		LaneState.reset()
		if not (LaneState.on_win(1, rng)["treasure"] as Dictionary).is_empty():
			firsts += 1
	ck("처음 깨면 보물이 자주 나온다 (60%)", absf(float(firsts) / 200.0 - LaneData.TREASURE_FIRST) < 0.1, str(firsts))
	var got := 0
	for i in 300:
		var rr := LaneState.on_win(1, rng)
		if not (rr["treasure"] as Dictionary).is_empty():
			got += 1
	ck("다시 깨면 가끔 나온다", got > 0 and got < 300, str(got))
	ck("많이 돌면 구역 보물을 다 모은다", LaneState.treasure_count(0) == 9)
	var tb := LaneState.treasure_bonus()
	ck("보물 효과가 합쳐진다", is_equal_approx(float(tb["atk"]), 1.5) and is_equal_approx(float(tb["wallet"]), 45.0))
	var b := LaneBattle.new()
	b.start(1, 1)
	ck("시작 꿈빛 보너스", is_equal_approx(b.wallet, 45.0))
	ck("공격 보너스가 판에 들어간다", is_equal_approx(float(b.stats["tiny"]["atk"]), float(LaneState.unit_stats("tiny")["atk"]) * 1.015))
	# 장신구: 우두머리를 처음 잡으면
	LaneState.cleared = 9
	var rb := LaneState.on_win(10, rng)
	ck("우두머리 첫 클리어 = 장신구", String(rb["acc"]) == "feather_hat" and LaneState.accs.has("feather_hat"))
	var sp0 := float(LaneState.unit_stats("tiny")["speed"])
	ck("장신구 달기", LaneState.equip("tiny", "feather_hat") and LaneState.wearer("feather_hat") == "tiny")
	ck("달면 그 유닛만 세진다", is_equal_approx(float(LaneState.unit_stats("tiny")["speed"]), sp0 * 1.15)
		and is_equal_approx(float(LaneState.unit_stats("shield")["speed"]), float(LaneData.UNITS["shield"]["speed"])))
	LaneState.equip("shield", "feather_hat")
	ck("다른 유닛에 달면 옮겨 간다", LaneState.wearer("feather_hat") == "shield" and not LaneState.acc_on.has("tiny"))
	LaneState.xp = 999999
	ck("장신구 강화", LaneState.level_acc("feather_hat") and int(LaneState.accs["feather_hat"]) == 2)
	LaneState.accs["mirror_shield"] = 1
	LaneState.equip("tiny", "mirror_shield")
	ck("받는 피해 줄이기", is_equal_approx(float(LaneState.unit_stats("tiny")["guard"]), 0.92))
	# 콤보
	LaneState.units["spear"] = 1
	LaneState.lineup = ["tiny", "shield", "spear"]
	var cs := LaneState.active_combos()
	ck("쿼카 삼총사 콤보", cs.size() == 1 and String(cs[0]["name"]) == "쿼카 삼총사")
	ck("콤보가 보너스에 들어간다", float(LaneState.bonuses()["hp"]) > float(LaneState.treasure_bonus()["hp"]))
	# 저장
	var d := LaneState.to_dict()
	LaneState.reset()
	LaneState.from_dict(d)
	ck("보물·장신구 저장", LaneState.treasure_count(0) == 9 and int(LaneState.accs["feather_hat"]) == 2
		and LaneState.wearer("mirror_shield") == "tiny")
	# 옛 저장 → 선물 (한 번만)
	var had := IdleState.has_save()
	if not had:
		IdleState.reset()
		IdleState.best = 30
		IdleState.level = 12
		IdleState.save(1)
		LaneState.reset()
		var g := LaneState.migrate_from_idle()
		ck("옛 저장이 선물이 된다", int(g.get("stars", 0)) == 180 and LaneState.tickets == 1 + int(g["tickets"]))
		ck("선물은 한 번만", LaneState.migrate_from_idle().is_empty())
		IdleState.clear_save()
	LaneState.reset()
	ck("옛 저장이 없으면 선물 없음", IdleState.has_save() == had and (had or LaneState.migrate_from_idle().is_empty()))
	LaneState.reset()

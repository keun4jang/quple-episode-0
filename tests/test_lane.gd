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
	LaneState.save_path = LaneState.TEST_SAVE_PATH  # 진짜 저장(user://lane.cfg)을 건드리지 않는다
	print("=== 쿼카 군단 테스트 ===")
	print("\n[1] 표")
	ck("1번은 초원 1-1", LaneData.stage_label(1) == "초원 1-1")
	ck("100번은 악몽 하수구 우두머리", bool(LaneData.stage_info(100)["boss"]) and LaneData.stage_label(100) == "악몽 하수구 10-10")
	# 2장
	var c2: Dictionary = LaneData.stage_info(101)
	ck("101번은 2장 초원 1-1", LaneData.stage_label(101) == "2장 초원 1-1" and int(c2["chapter"]) == 1 and int(c2["zone"]) == 0)
	ck("200번은 2장 마지막 우두머리", LaneData.stage_label(200) == "2장 악몽 하수구 10-10" and bool(LaneData.stage_info(200)["boss"]))
	ck("2장 첫 판은 1장 마지막 판보다 세다", float(c2["mag"]) > float(LaneData.stage_info(100)["mag"]))
	ck("2장은 처음부터 벌레가 다 섞인다", LaneData.spawns(101).size() > LaneData.spawns(1).size())
	ck("2장 우두머리는 티켓 2장", int(LaneData.reward(110, true)["tickets"]) == 2 and int(LaneData.reward(10, true)["tickets"]) == 1)
	ck("판 번호 계산", LaneData.stage_no(1, 3, 5) == 135 and LaneData.chapter_of(100) == 0 and LaneData.chapter_of(101) == 1)
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
	# 글 사이 기호는 테마의 기호 폰트(QuokkaSymbols)가 그린다 - 기기 폰트에 기대면 폰에서 네모가 뜬다
	var tf := (load("res://assets/themes/quple_bold.tres") as Theme).default_font
	ck("테마 폰트에 ★ ✦ ▶ ✓ ● 가 있다", [0x2605, 0x2726, 0x25B6, 0x2713, 0x25CF].all(func(c): return tf.has_char(c)))
	ck("작은 벌레는 3배, 우두머리는 2배로 그린다", LaneData.sheet_px("res://assets/sprites/lane-bug-ant.png", 29.0) == 3.0
		and LaneData.sheet_px("res://assets/sprites/lane-bug-queen_ant.png", 93.0) == 2.0
		and LaneData.sheet_px("res://assets/sprites/lane-bug-hornet.png", 78.0) == 2.0)
	for z in LaneData.ZONES:
		for b in z["bugs"]:
			if not LaneData.BUGS.has(b):
				ck("구역 벌레가 표에 있다 (%s)" % b, false)

	print("\n[2] 성장·편성")
	LaneState.reset()
	ck("처음엔 꼬마·방패", LaneState.has_unit("tiny") and LaneState.has_unit("shield") and not LaneState.has_unit("spear"))
	var r := LaneState.on_win(1)
	ck("1번을 깨면 행복 조각·행운별", int(r["xp"]) > 0 and int(r["stars"]) > 0 and bool(r["first"]) and LaneState.cleared == 1)
	r = LaneState.on_win(2)
	ck("2번을 깨면 창 쿼카 합류", (r["new_units"] as Array).has("spear") and LaneState.lineup.has("spear"))
	var r2 := LaneState.on_win(1)
	ck("깬 판을 또 깨면 처음 보상은 없다", not bool(r2["first"]) and int(r2["stars"]) == 1 and LaneState.cleared == 2)
	LaneState.xp = 0
	ck("행복 조각이 없으면 레벨업 못 한다", not LaneState.level_up("tiny"))
	LaneState.xp = 999999
	var hp1 := float(LaneState.unit_stats("tiny")["hp"])
	ck("레벨업", LaneState.level_up("tiny") and LaneState.level_of("tiny") == 2)
	ck("레벨이 오르면 20% 세진다", is_equal_approx(float(LaneState.unit_stats("tiny")["hp"]), hp1 * 1.2))
	ck("편성에서 뺀다", LaneState.toggle_lineup("spear") and not LaneState.lineup.has("spear"))
	ck("다시 넣는다", LaneState.toggle_lineup("spear") and LaneState.lineup.has("spear"))
	ck("편성은 도감 순서 (뺐다 넣어도)", LaneState.lineup.find("spear") > LaneState.lineup.find("tiny")
		and LaneState.lineup.find("spear") < LaneState.lineup.size() and LaneState.lineup == LaneState.lineup.duplicate())
	var lsorted := LaneState.lineup.duplicate()
	lsorted.sort_custom(func(a, b) -> bool: return LaneData.ALL_ORDER.find(a) < LaneData.ALL_ORDER.find(b))
	ck("편성 순서 = 도감 순서", LaneState.lineup == lsorted)
	ck("없는 쿼카는 못 넣는다", not LaneState.toggle_lineup("giant"))
	LaneState.lineup = ["tiny"]
	ck("마지막 한 마리는 못 뺀다", not LaneState.toggle_lineup("tiny"))

	print("\n[3] 한 판")
	LaneState.reset()
	var b := LaneBattle.new()
	b.start(1, 5)
	ck("처음엔 웃음 0", b.wallet == 0.0 and not b.can_summon("tiny"))
	b.tick(2.0)
	ck("웃음이 저절로 찬다", b.wallet > 50.0, str(b.wallet))
	ck("소환", b.summon("tiny") and b.ents.size() >= 1)
	ck("곧바로 또 못 낸다 (대기시간)", not b.summon("tiny"))
	var w0 := b.worker
	b.wallet = 1000.0
	ck("수입 올리기", b.upgrade_worker() and b.worker == w0 + 1)
	ck("수입을 올리면 한도도 커진다", b.wallet_cap() > int(LaneData.WALLET_CAP[0]))
	ck("대포는 처음엔 못 쏜다", not b.fire_cannon())
	b.cannon = b.cannon_max
	var nest0 := b.nest_hp
	ck("다 차면 쏜다", b.fire_cannon() and b.cannon == 0.0)
	ck("바주카포는 둥지까지 깎는다", is_equal_approx(b.nest_hp, nest0 - b.nest_max * LaneData.CANNON_NEST))
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

	print("\n[스킬]")
	var all_sk := true
	for id in LaneData.ALL_ORDER:
		if not LaneData.SKILLS.has(id) or LaneData.skill_text(String(id)) == "":
			all_sk = false
	ck("친구마다 스킬이 하나씩", all_sk and LaneData.SKILLS.size() == LaneData.ALL_ORDER.size())
	LaneState.reset()
	for id in LaneData.ALL_ORDER:
		LaneState.units[id] = 10
	LaneState.lineup = ["tiny", "shield", "spear", "hammer", "duck", "chick", "owl", "penguin", "rabbit", "turtle"]
	# 판이 빨리 끝나면 스킬이 다 나오기 전에 이긴다 - 이 검사는 예전 세기(빠르기·둥지·벌레 1)로
	LaneData.pace = 1.0
	LaneData.nest_mult = 1.0
	LaneData.bug_mult = 1.0
	var sb := LaneBattle.new()
	sb.start(25, 3)
	sb.auto = true
	var sk_kinds := {}
	var skill_dmg := 0
	var healed := 0
	for i in 400:
		for ev in sb.tick(0.25):
			if ev["k"] == "skill":
				sk_kinds[String(ev["kind"])] = true
			elif ev["k"] == "hit" and String(ev.get("eff", "")) == "skill":
				skill_dmg += int(ev["dmg"])
			elif ev["k"] == "heal":
				healed += int(ev["amt"])
		if sb.done:
			break
	ck("싸우면 스킬이 저절로 나간다", sk_kinds.size() >= 5, str(sk_kinds.keys()))
	LaneData.pace = LaneData.PACE
	LaneData.nest_mult = LaneData.NEST_MULT
	LaneData.bug_mult = LaneData.CH1_BUG
	ck("스킬이 벌레에게 피해를 준다", skill_dmg > 0, str(skill_dmg))
	# 버프: 방어 스킬을 받으면 덜 아프다
	var gb := LaneBattle.new()
	gb.start(5, 1)
	var sq := gb._make(gb.stats["shield"], "q", 100.0)
	var sbug := gb._make(LaneData.BUGS["ant"].merged({"id": "ant"}), "b", 150.0)
	gb.ents = [sq, sbug]
	var shp0 := float(sq["hp"])
	gb._strike(sbug, sq, 100.0)
	var splain := shp0 - float(sq["hp"])
	sq["hp"] = shp0
	sq["b_guard"] = 0.5
	sq["b_guard_t"] = 3.0
	gb._strike(sbug, sq, 100.0)
	ck("방어 스킬은 받는 피해를 줄인다", is_equal_approx(shp0 - float(sq["hp"]), splain * 0.5), "%s / %s" % [splain, shp0 - float(sq["hp"])])
	sq["sk"] = "duck"
	sq["hp"] = shp0 * 0.3
	ck("치유 스킬은 다친 친구를 고친다", gb._try_skill(sq, [], false) and float(sq["hp"]) > shp0 * 0.3)
	LaneState.reset()

	print("\n[진화]")
	LaneState.reset()
	LaneState.units["spear"] = LaneData.EVOLVE_LV
	LaneState.xp = 99999999
	ck("진화 전엔 레벨 10 에서 멈춘다", not LaneState.can_level("spear") and LaneState.evolve_ready("spear"))
	var pre: Dictionary = LaneState.unit_stats("spear")
	ck("진화 전 그림·이름", not LaneData.sheet_path("spear", 10).ends_with("-2.png") and LaneData.unit_name("spear", 10) == "창 쿼카")
	var xp_before := LaneState.xp
	ck("진화", LaneState.evolve("spear") and LaneState.is_evolved("spear")
		and LaneState.xp == xp_before - LaneData.evolve_cost("spear"))
	var post: Dictionary = LaneState.unit_stats("spear")
	ck("진화하면 체력·공격 ×1.2", is_equal_approx(float(post["atk"]), float(pre["atk"]) * LaneData.EVOLVE_ATK)
		and is_equal_approx(float(post["hp"]), float(pre["hp"]) * LaneData.EVOLVE_HP))
	ck("진화 뒤 그림·이름", LaneData.sheet_path("spear", 10).ends_with("-2.png") and LaneData.unit_name("spear", 10) == "번개창 쿼카")
	ck("진화하면 다시 레벨업", LaneState.can_level("spear") and not LaneState.evolve("spear"))
	var eb := LaneBattle.new()
	LaneState.lineup = ["spear"]
	eb.start(3, 1)
	var es := eb._make(eb.stats["spear"], "q", 0.0)
	ck("진화하면 스킬이 더 자주", is_equal_approx(float(es["sk_cd"]), float(LaneData.SKILLS["spear"]["cd"]) * LaneData.EVOLVE_SKILL_CD))
	var ed := LaneState.to_dict()
	LaneState.reset()
	LaneState.from_dict(ed)
	ck("진화 저장", LaneState.is_evolved("spear"))
	LaneState.from_dict({"units": {"tiny": 14, "shield": 6}})
	ck("옛 저장: 레벨 10 넘은 친구는 진화한 채로", LaneState.is_evolved("tiny") and LaneState.level_of("tiny") == 14
		and not LaneState.is_evolved("shield"))
	LaneState.from_dict({"units": {"tiny": 14}, "evolved": []})
	ck("진화 안 한 친구는 레벨 10 까지만", LaneState.level_of("tiny") == LaneData.EVOLVE_LV)
	LaneState.from_dict({"speed2": true})
	ck("옛 저장의 빨리 감기(켜짐)는 3배로", LaneState.speed_lv == 1)
	ck("배속은 1배·3배·20배(시험용)", LaneData.SPEEDS == [1.0, 3.0, 20.0])
	LaneState.speed_lv = 1
	var sd := LaneState.to_dict()
	LaneState.reset()
	LaneState.from_dict(sd)
	ck("3배 저장", LaneState.speed_lv == 1)
	LaneState.from_dict({"speed_lv": 2})
	ck("셋째 단계(옛 10배)는 20배로", LaneState.speed_lv == 2)
	LaneState.from_dict({"speed_lv": 0})
	ck("1배 저장", LaneState.speed_lv == 0)
	ck("배속 버튼은 1배 → 3배 → 20배 → 1배", (1 + 1) % LaneData.SPEEDS.size() == 2 and (2 + 1) % LaneData.SPEEDS.size() == 0)
	LaneState.reset()
	ck("바주카포는 Lv1 부터, 행복 조각이 없으면 못 올린다", LaneState.bazooka_lv == 1 and not LaneState.level_bazooka())
	LaneState.xp = 1000000
	while LaneState.level_bazooka():
		pass
	ck("바주카포는 Lv10 까지", LaneState.bazooka_lv == LaneData.BAZOOKA_LV_MAX)
	ck("강화하면 세지고 빨리 찬다", LaneData.bazooka_dmg_mult(10) > LaneData.bazooka_dmg_mult(1)
		and LaneData.bazooka_charge(10) < LaneData.bazooka_charge(1) and LaneData.bazooka_nest(10) > LaneData.bazooka_nest(1))
	var bs := LaneState.to_dict()
	LaneState.reset()
	LaneState.from_dict(bs)
	ck("바주카포 단계 저장", LaneState.bazooka_lv == LaneData.BAZOOKA_LV_MAX)
	var bzb := LaneBattle.new()
	bzb.start(5, 1)
	LaneState.fort_lv = 4
	var fb := LaneBattle.new()
	fb.start(5, 1)
	ck("우리 성 강화하면 성 체력이 는다", is_equal_approx(fb.our_max, LaneData.OUR_BASE_HP * 1.45) and fb.our_hp == fb.our_max)
	LaneState.xp = 1000000
	while LaneState.level_fort():
		pass
	var fs2 := LaneState.to_dict()
	LaneState.reset()
	LaneState.from_dict(fs2)
	ck("우리 성은 Lv10 까지, 저장된다", LaneState.fort_lv == LaneData.FORT_LV_MAX and is_equal_approx(LaneData.fort_hp(10), 7050.0))
	ck("판은 강화 단계의 충전량을 쓴다", is_equal_approx(bzb.cannon_max, LaneData.bazooka_charge(LaneData.BAZOOKA_LV_MAX)))
	LaneState.reset()
	LaneState.reset()

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
	_test_tally()
	_test_flowers()
	_test_missions()
	_test_daily()
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
	ck("티켓을 썼고 행운별은 그대로", LaneState.tickets == 0 and LaneState.stars == 0)
	ck("뽑은 친구가 편성에 들어간다", LaneState.lineup.has(String(r[0]["id"])))
	ck("행운별이 없으면 못 뽑는다", not LaneState.can_pull(1) and LaneState.pull(1, rng).is_empty())
	LaneState.stars = LaneData.GACHA10_COST
	var r10 := LaneState.pull(10, rng)
	var best := 0
	for x in r10:
		best = maxi(best, int(LaneData.RARITY_STARS[String(x["rarity"])]))
	ck("10번 뽑기 = 10마리, 특급 이상 하나", r10.size() == 10 and best >= 2 and LaneState.stars == 0)
	LaneState.tickets = 13
	var tk_p0 := LaneState.pulls
	var ra := LaneState.pull_tickets(rng)
	ck("티켓 모두 뽑기 = 티켓 수만큼, 티켓 0장", ra.size() == 13 and LaneState.tickets == 0 and LaneState.pulls == tk_p0 + 13)
	ck("티켓이 없으면 모두 뽑기는 빈손", LaneState.pull_tickets(rng).is_empty())
	# 중복은 레벨 +1, 최고 레벨이면 행복 조각
	LaneState.units["chick"] = LaneData.UNIT_LV_MAX
	var xp0 := LaneState.xp
	var g := LaneState._grant("chick")
	ck("최고 레벨 중복은 행복 조각", int(g["xp"]) > 0 and LaneState.xp == xp0 + int(g["xp"]))
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
	# 선물 달력 (28칸, 끊겨도 이어진다)
	LaneState.cal_day = 0
	var tk0 := LaneState.tickets
	var d1 := LaneState.claim_daily(day + 100, rng)
	ck("선물 달력 1칸째를 받는다", not d1.is_empty() and int(d1["day"]) == 1 and LaneState.cal_day == 1
		and LaneState.tickets == tk0 + 1 and (d1["unit"] as Dictionary).is_empty())
	ck("같은 날 두 번 부르면 빈 것", LaneState.claim_daily(day + 5000, rng).is_empty() and LaneState.cal_day == 1)
	var d2 := LaneState.claim_daily(day + 86400 + 10, rng)
	ck("다음 날 2칸째", int(d2["day"]) == 2)
	var d3 := LaneState.claim_daily(day + 86400 * 4, rng)
	ck("하루 건너 들어와도 칸은 +1 (되돌아가지 않는다)", int(d3["day"]) == 3 and LaneState.cal_day == 3)
	ck("달력 보상: 보통 날 · 7일째 · 14일째", LaneData.calendar_gift(3) == {"tickets": 1, "stars": 30, "capsule": false}
		and int(LaneData.calendar_gift(21)["tickets"]) == 3 and bool(LaneData.calendar_gift(28)["capsule"]))
	LaneState.cal_day = 13
	var pulls0 := LaneState.pulls
	var d14 := LaneState.claim_daily(day + 86400 * 5, rng)
	var u14: Dictionary = d14["unit"]
	ck("14일째는 특급 이상 캡슐", int(d14["day"]) == 14 and not u14.is_empty()
		and String(u14["rarity"]) != "rare" and LaneState.units.has(String(u14["id"])) and LaneState.pulls == pulls0 + 1, str(u14))
	LaneState.cal_day = 28
	var d29 := LaneState.claim_daily(day + 86400 * 6, rng)
	ck("28칸 다음은 1칸", int(d29["day"]) == 1 and LaneState.cal_day == 1)
	var od := LaneState.to_dict()
	od.erase("cal_day")
	od["daily_streak"] = 9
	LaneState.from_dict(od)
	ck("옛 저장 daily_streak 9 → 달력 9칸", LaneState.cal_day == 9)
	LaneState.cal_day = 17
	LaneState.from_dict(LaneState.to_dict())
	ck("달력 칸 저장", LaneState.cal_day == 17 and not LaneState.to_dict().has("daily_streak"))
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
	ck("시작 웃음 보너스", is_equal_approx(b.wallet, 45.0))
	ck("공격 보너스가 판에 들어간다", is_equal_approx(float(b.stats["tiny"]["atk"]), float(LaneState.unit_stats("tiny")["atk"]) * 1.015))
	# 장신구: 우두머리를 처음 잡으면
	LaneState.cleared = 9
	var rb := LaneState.on_win(10, rng)
	ck("우두머리 첫 클리어 = 장신구", String(rb["acc"]) == "feather_hat" and LaneState.accs.has("feather_hat"))
	# 2장 판: 보물은 그 구역 것이 나오고, 장신구는 안 준다
	var save_cl := LaneState.cleared
	LaneState.cleared = 134
	var r2c := LaneState.on_win(135, rng)
	ck("2장 판을 깨면 다음 판이 열린다", LaneState.cleared == 135 and bool(r2c["first"]))
	var zones_ok := true
	for i in 60:
		var t2: Dictionary = LaneState.on_win(135, rng)["treasure"]
		if not t2.is_empty() and int(t2["zone"]) != 3:
			zones_ok = false
	ck("2장 4구역 판의 보물은 4구역 보물", zones_ok)
	LaneState.cleared = 109
	ck("2장 우두머리는 장신구를 안 준다", String(LaneState.on_win(110, rng)["acc"]) == "")
	LaneState.cleared = save_cl
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


## 판 기록 + 손맛 보너스 (여럿 맞히기 · 떼 막기)
func _test_tally() -> void:
	print("\n[판 기록 · 손맛]")
	LaneState.reset()
	# ① 손으로 쏜 바주카가 5마리를 맞히면 웃음 +100, 충전 25% 돌려받기
	var b := LaneBattle.new()
	b.start(1, 3)
	b._spawns = []
	b.ents = []
	for i in 5:
		b._spawn_bug("ant")
	for e in b.ents:
		e["hp"] = 1.0e9
		e["max"] = 1.0e9
		e["pos"] = 1000.0
	b.wallet = 0.0
	b.cannon = b.cannon_max
	var ok := b.fire_cannon()
	var ev := b.tick(0.0)
	ck("여럿 맞히기: 웃음 +100", ok and is_equal_approx(b.wallet, 100.0), str(b.wallet))
	ck("여럿 맞히기: 충전 25% 돌려받기", is_equal_approx(b.cannon, b.cannon_max * LaneData.MULTI_REFUND), str(b.cannon))
	ck("여럿 맞히기 기록", int(b.tally["multi5"]) == 1 and int(b.tally["best_hit"]) == 5 and int(b.tally["shots"]) == 1)
	ck("여럿 맞히기 사건", ev.any(func(x): return x["k"] == "multi" and int(x["gain"]) == 100))
	# ② 자동이 쏘면 보너스 없음
	var a := LaneBattle.new()
	a.start(1, 3)
	a._spawns = []
	a.ents = []
	for i in 5:
		a._spawn_bug("ant")
	for e in a.ents:
		e["hp"] = 1.0e9
		e["max"] = 1.0e9
		e["pos"] = 500.0
	a.auto = true
	a.wallet = 0.0
	a.cannon = a.cannon_max
	a._auto_play()
	ck("자동 바주카는 보너스가 없다", a.cannon == 0.0 and a.wallet == 0.0 and int(a.tally["multi5"]) == 0
		and int(a.tally["shots"]) == 0, "%s %s" % [a.cannon, a.wallet])
	# ③ 떼 막기 - 진짜 떼 줄(_queue)로 내보낸다
	ck("떼를 다 길 가운데 너머에서 잡으면 떼 막기", _hold_case(false) == 1)
	ck("하나라도 가운데 아래로 오면 떼 막기 아님", _hold_case(true) == 0)
	# ④ 자동 소환은 세지 않는다
	var s := LaneBattle.new()
	s.start(1, 3)
	s.wallet = 500.0
	ck("자동 소환은 세지 않는다", s.summon("tiny", false) and int(s.tally["summons"]) == 0 and (s.tally["kinds"] as Dictionary).is_empty())
	s.cds["shield"] = 0.0
	ck("손 소환은 센다", s.summon("shield") and int(s.tally["summons"]) == 1 and s.tally["kinds"].has("shield"))
	s.auto = true
	s.tick(0.1)
	ck("자동을 켜면 기록에 남는다", bool(s.tally["auto_used"]))


func _hold_case(cross: bool) -> int:
	var b := LaneBattle.new()
	b.start(1, 4)
	b.ents = []
	b._spawns = [{"kind": "ant", "burst": 3, "t": 0.01, "every": 999.0, "max": 1, "count": 0, "first": 0.01}]
	b.tick(1.5)
	var bugs: Array = b.ents.filter(func(e): return e.has("wave"))
	if bugs.size() != 3:
		print("    떼 벌레 수: ", bugs.size())
		return -1
	for e in bugs:
		e["hp"] = 1.0e9
		e["pos"] = 2000.0
	if cross:
		bugs[0]["pos"] = 1400.0
	b.tick(0.05)
	for e in bugs:
		b._damage(e, 2.0e9, false)
	return int(b.tally["holds"])


func _test_flowers() -> void:
	print("
[꽃 세 송이 · 구역 꽃다발]")
	LaneState.reset()
	var t3 := LaneData.flower_task(3)
	ck("3번 판 과제는 바주카 한 방에 3마리", String(t3["id"]) == "hit" and int(t3["need"]) == 3)
	ck("우두머리 판 과제는 바주카포 마무리", String(LaneData.flower_task(10)["id"]) == "boss_cannon"
		and String(LaneData.flower_task(110)["id"]) == "boss_cannon")
	ck("뒤 구역은 더 많이 맞혀야", int(LaneData.flower_task(99)["need"]) == 6 and String(LaneData.flower_task(4)["id"]) == "spend"
		and String(LaneData.flower_task(5)["id"]) == "hold")
	# ① 판정
	var tl := {"best_hit": 3, "cap_t": 99.0, "holds": 0, "boss_cannon": false, "auto_used": false}
	ck("성 70% + 과제 = 꽃 셋", LaneState.judge_flowers(3, tl, 0.7) == 7)
	ck("성 50% 면 꽃 2 없음", LaneState.judge_flowers(3, tl, 0.5) == 5)
	ck("과제 못 하면 꽃 3 없음", LaneState.judge_flowers(3, {"best_hit": 2, "auto_used": false}, 0.7) == 3)
	ck("기록이 없으면 꽃 1·2만", LaneState.judge_flowers(3, {}, 1.0) == 3)
	ck("웃음 쌓아 두지 않기", LaneState.judge_flowers(4, {"cap_t": 10.0, "auto_used": false}, 0.1) == 5
		and LaneState.judge_flowers(4, {"cap_t": 10.5, "auto_used": false}, 0.1) == 1)
	ck("떼 막기", LaneState.judge_flowers(5, {"holds": 1, "auto_used": false}, 0.1) == 5)
	# ② 자동
	var ta := tl.duplicate()
	ta["auto_used"] = true
	ck("자동을 켠 판은 꽃 3 없음", LaneState.judge_flowers(3, ta, 0.7) == 3)
	# ③ 같은 판 두 번 - 별은 처음만
	var s0 := LaneState.stars
	var r1 := LaneState.on_win(3, null, tl, 0.7)
	var got1 := LaneState.stars - s0 - int(r1["stars"])
	ck("새 꽃 2·3 = 행운별 2 x 2", got1 == 4 and int(r1["flower_stars"]) == 4 and int(r1["new_flowers"]) == 7
		and int(LaneState.flowers[3]) == 7, str(got1))
	var s1 := LaneState.stars
	var r2 := LaneState.on_win(3, null, tl, 0.7)
	ck("두 번째는 꽃 행운별 없음", int(r2["flower_stars"]) == 0 and int(r2["new_flowers"]) == 0
		and LaneState.stars - s1 == int(r2["stars"]))
	# 나눠 받기
	LaneState.on_win(4, null, {"cap_t": 99.0, "auto_used": false}, 0.3)
	ck("꽃 1만", int(LaneState.flowers[4]) == 1)
	var r4 := LaneState.on_win(4, null, {"cap_t": 0.0, "auto_used": false}, 0.3)
	ck("다음 판에 꽃 3 더하기", int(LaneState.flowers[4]) == 5 and int(r4["new_flowers"]) == 4 and int(r4["flower_stars"]) == 2)
	ck("2장은 꽃 하나에 행운별 3", int(LaneState.on_win(101, null, {}, 1.0)["flower_stars"]) == 3)
	# 저장·불러오기
	var d := LaneState.to_dict()
	LaneState.from_dict(d)
	ck("꽃이 저장된다", int(LaneState.flowers.get(3, 0)) == 7 and int(LaneState.flowers.get(4, 0)) == 5)
	# ④ 옛 저장
	LaneState.from_dict({"cleared": 25, "units": {"tiny": 1}})
	var ok := true
	for i in range(1, 26):
		ok = ok and int(LaneState.flowers.get(i, 0)) == 1
	ck("옛 저장은 깬 판마다 꽃 1", ok and not LaneState.flowers.has(26) and LaneState.flowers_in_zone(0) == 10
		and LaneState.flowers_in_zone(2) == 5)
	# ⑤ 구역 꽃다발
	LaneState.reset()
	var full := {"best_hit": 99, "cap_t": 0.0, "holds": 3, "boss_cannon": true, "auto_used": false}
	var bq20 := {}
	for i in range(1, 10):
		var rr := LaneState.on_win(i, null, full, 1.0)
		if not (rr["bouquet"] as Dictionary).is_empty():
			bq20 = rr["bouquet"]
	ck("꽃 20 = 꽃다발 행운별 20", int(bq20.get("stage", 0)) == 1 and int(bq20.get("stars", 0)) == 20
		and LaneState.flowers_in_zone(0) == 27)
	var tk := LaneState.tickets
	var rb := LaneState.on_win(10, null, full, 1.0)
	ck("꽃 30 = 뽑기 티켓 +1", LaneState.flowers_in_zone(0) == 30 and int(rb["bouquet"]["tickets"]) == 1
		and LaneState.tickets - tk == int(rb["tickets"]) + 1, str(LaneState.tickets - tk))
	tk = LaneState.tickets
	var rb2 := LaneState.on_win(10, null, full, 1.0)
	ck("다시 이겨도 꽃다발은 한 번", (rb2["bouquet"] as Dictionary).is_empty() and LaneState.tickets == tk
		and int(LaneState.bouquet[0]) == 2)


func _test_missions() -> void:
	print("
[오늘의 임무 · 이번 주 도장판]")
	LaneState.reset()
	var today := 20401        # 2025-11-09 (일요일)
	ck("안내 전에는 임무가 안 열린다", not LaneState.roll_missions(today) and LaneState.missions.is_empty())
	LaneState.tut = 99
	LaneState.cleared = 3
	ck("세 판을 깨면 열린다", LaneState.missions_open())
	# ① 같은 날은 같은 임무, 다음 날은 새로
	LaneState.roll_missions(today)
	var ids1: Array = LaneState.missions.map(func(m): return String(m["id"]))
	var tiers_ok := true
	for k in 3:
		tiers_ok = tiers_ok and int(LaneData.MISSIONS[ids1[k]]["tier"]) == k
	ck("등급마다 하나씩 셋", ids1.size() == 3 and tiers_ok, str(ids1))
	ck("열리지 않은 임무는 안 나온다", not ids1.has("boss1") and not ids1.has("bosscan"))
	LaneState.missions[0]["prog"] = 2
	ck("같은 날은 다시 굴리지 않는다", not LaneState.roll_missions(today) and int(LaneState.missions[0]["prog"]) == 2)
	var saved := LaneState.missions.duplicate(true)
	LaneState.mission_day = 0
	LaneState.roll_missions(today)
	var ids2: Array = LaneState.missions.map(func(m): return String(m["id"]))
	ck("같은 today 로 굴리면 같은 임무", ids1 == ids2)
	LaneState.missions = saved
	LaneState.mission_day = today
	LaneState.mission_swap = true
	ck("다음 날은 새로 굴리고 비운다", LaneState.roll_missions(today + 1)
		and LaneState.missions.all(func(m): return int(m["prog"]) == 0 and not bool(m["got"]))
		and not LaneState.mission_swap and LaneState.mission_day == today + 1)
	# ② 자동 소환은 call30 에 안 들어간다
	LaneState.missions = [{"id": "call30", "prog": 0, "got": false}, {"id": "kill150", "prog": 0, "got": false},
		{"id": "multi2", "prog": 0, "got": false}]
	var b := LaneBattle.new()
	b.start(1, 3)
	b.wallet = 99999.0
	b.summon("tiny", false)
	b.cds["tiny"] = 0.0
	b.summon("shield", false)
	ck("자동 소환은 판 기록에 안 센다", int(b.tally["summons"]) == 0)
	b.cds["tiny"] = 0.0
	b.summon("tiny")
	LaneState.add_tally(b.tally, false, 0.5, 0, 1)
	ck("손으로 부른 것만 call30 에", int(LaneState.missions[0]["prog"]) == 1, str(LaneState.missions[0]["prog"]))
	# 진 판도 센다, 이긴 판만 세는 것은 안 센다
	var ups := LaneState.add_tally({"summons": 40, "kills": 10, "multi5": 1, "auto_used": false}, false, 1.0, 0, 3)
	ck("져도 그때까지 한 만큼 센다", int(LaneState.missions[0]["prog"]) == 30 and int(LaneState.missions[1]["prog"]) == 10
		and int(LaneState.missions[2]["prog"]) == 1 and ups.size() == 3)
	ck("goal 에서 멈춘다", int(LaneState.missions[0]["prog"]) == 30)
	LaneState.missions = [{"id": "win3", "prog": 0, "got": false}, {"id": "hp70", "prog": 0, "got": false},
		{"id": "flower", "prog": 0, "got": false}]
	LaneState.add_tally({"auto_used": true}, true, 0.9, 7, 4)
	ck("자동을 켠 판은 hp70 에 안 센다", int(LaneState.missions[0]["prog"]) == 1 and int(LaneState.missions[1]["prog"]) == 0
		and int(LaneState.missions[2]["prog"]) == 2)
	LaneState.add_tally({"auto_used": false}, false, 0.9, 0, 4)
	ck("진 판은 wins 에 안 센다", int(LaneState.missions[0]["prog"]) == 1 and int(LaneState.missions[1]["prog"]) == 0)
	# lvup
	LaneState.missions[0] = {"id": "lvup", "prog": 0, "got": false}
	LaneState.xp = 999999
	LaneState.level_up("tiny")
	ck("레벨 올리기가 센다", int(LaneState.missions[0]["prog"]) == 1)
	# 바꾸기 - 하루 한 번, 같은 등급
	LaneState.mission_swap = false
	var was := String(LaneState.missions[1]["id"])
	LaneState.missions[1]["prog"] = 1
	ck("바꾸기", LaneState.swap_mission(1, today + 1) and String(LaneState.missions[1]["id"]) != was
		and int(LaneData.MISSIONS[String(LaneState.missions[1]["id"])]["tier"]) == 2 and int(LaneState.missions[1]["prog"]) == 0)
	ck("바꾸기는 하루 한 번", not LaneState.swap_mission(2, today + 1))
	# ③ 셋 다 받으면 도장 하나, 같은 날 또 안 찍힌다
	LaneState.check_week(today + 1)
	ck("다 하지 않은 임무는 못 받는다", LaneState.claim_mission(1).is_empty())
	for m in LaneState.missions:
		m["prog"] = int(LaneData.MISSIONS[String(m["id"])]["goal"])
		m["got"] = false
	ck("받을 것이 있으면 점", LaneState.missions_ready())
	var s0 := LaneState.stars
	var c0 := LaneState.claim_mission(0)
	var c1 := LaneState.claim_mission(1)
	ck("두 개 받으면 아직 도장 없음", LaneState.stamps == 0 and not bool(c1["stamp"]))
	var c2 := LaneState.claim_mission(2)
	ck("셋 다 받으면 도장 +1", LaneState.stamps == 1 and bool(c2["stamp"]))
	var want := 0
	for m in LaneState.missions:
		want += int(LaneData.MISSION_STARS[int(LaneData.MISSIONS[String(m["id"])]["tier"])])
	ck("임무 행운별은 등급대로 (10·15·20)", LaneState.stars - s0 == want and int(c0["stars"]) == 10 and want == 50,
		str(LaneState.stars - s0))
	ck("받은 것은 또 못 받는다", LaneState.claim_mission(0).is_empty() and not LaneState.missions_ready())
	for m in LaneState.missions:
		m["got"] = false
	LaneState.claim_mission(0)
	LaneState.claim_mission(1)
	LaneState.claim_mission(2)
	ck("같은 날 도장은 하나까지", LaneState.stamps == 1)
	# 저장·불러오기
	var d := LaneState.to_dict()
	LaneState.from_dict(d)
	ck("임무·도장이 저장된다", LaneState.mission_day == today + 1 and LaneState.missions.size() == 3
		and LaneState.stamps == 1 and LaneState.stamp_day == today + 1 and LaneState.week_no == (today + 1 + 3) / 7)
	# ④ 다음 월요일이면 도장판이 새로
	var monday := today + 1     # 20402 = 월요일
	ck("20402 는 월요일 (주가 바뀐다)", (monday + 3) / 7 != (today + 3) / 7 and (monday + 3) / 7 == (monday + 6 + 3) / 7)
	LaneState.check_week(monday + 6)
	ck("같은 주 일요일은 그대로", LaneState.stamps == 1)
	LaneState.check_week(monday + 7)
	ck("다음 월요일엔 도장 0", LaneState.stamps == 0 and LaneState.week_got == [false, false, false])
	# 칸 보상
	LaneState.stamps = 7
	var tk := LaneState.tickets
	var st := LaneState.stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var w0 := LaneState.claim_week(0, rng)
	var w1 := LaneState.claim_week(1, rng)
	ck("3칸 티켓 1 · 5칸 티켓 1 + 행운별 50", int(w0["tickets"]) == 1 and int(w1["tickets"]) == 1 and int(w1["stars"]) == 50
		and LaneState.tickets - tk == 2 and LaneState.stars - st == 50)
	ck("칸 보상은 한 번", LaneState.claim_week(0, rng).is_empty())
	# ⑤ 7칸 캡슐은 특급 이상
	var p0 := LaneState.pulls
	var w2 := LaneState.claim_week(2, rng)
	ck("7칸은 행복 캡슐 한 번 (천장에 센다)", not (w2["capsule"] as Dictionary).is_empty() and LaneState.pulls == p0 + 1)
	var no_rare := true
	for i in 300:
		var id := LaneState.roll(rng, "super")
		no_rare = no_rare and LaneData.rarity(id) != "rare"
	ck("특급 캡슐은 희귀가 안 나온다", no_rare and String(w2["capsule"]["rarity"]) != "rare")
	ck("다 받으면 점 없음", not LaneState.missions_ready())
	LaneState.stamps = 2
	LaneState.week_got = [false, false, false]
	ck("3칸 전에는 칸 보상 없음", not LaneState.week_ready(0) and LaneState.claim_week(0, rng).is_empty())
	# 열림 조건
	LaneState.cleared = 10
	ck("10판을 깨면 우두머리 임무도", LaneState._mission_pool(1).has("boss1") and LaneState._mission_pool(2).has("bosscan"))
	LaneState.lineup = ["tiny"]
	ck("편성이 다섯이 안 되면 다섯 종 임무 없음", not LaneState._mission_pool(2).has("kinds5"))
	ck("임무 글", LaneData.mission_text("hp70") == "성을 70% 넘게 지키고 이기기 1번"
		and LaneData.mission_text("kinds5") == "한 판에 친구 다섯 종 내보내고 이기기"
		and LaneData.mission_text("win3") == "판 3번 이기기")


func _test_daily() -> void:
	print("
[오늘의 도전]")
	var today := 20401
	# ① 같은 날은 같은 규칙, 다음 날은 다른 규칙
	ck("같은 날은 같은 규칙", LaneData.daily_rule(today) == LaneData.daily_rule(today))
	var differ := true
	for k in 10:
		differ = differ and String(LaneData.daily_rule(today + k)["id"]) != String(LaneData.daily_rule(today + k + 1)["id"])
	ck("이틀 연달아 같은 규칙은 없다", differ)
	ck("규칙은 다섯", LaneData.DAILY_RULES.size() == 5)
	ck("모든 규칙에 벌레 체력 0.9 이하 (느긋한 웃음 0.8)", range(5).all(func(k): return float(LaneData.daily_mods(k)["bug_hp"]) <= 0.9 + 0.0001) and is_equal_approx(float(LaneData.daily_mods(2)["bug_hp"]), 0.8))
	ck("도전 판은 두 판 앞 (이미 깬 판)", LaneData.daily_stage(25) == 23 and LaneData.daily_stage(1) == 1 and LaneData.daily_stage(2) == 1)
	# 열림
	LaneState.reset()
	LaneState.cleared = 9
	LaneState.tut = 99
	ck("10판 전에는 닫혀 있다", not LaneState.daily_open() and not LaneState.dch_ready(today))
	LaneState.cleared = 10
	LaneState.tut = 3
	ck("안내 중에도 닫혀 있다", not LaneState.daily_open())
	LaneState.tut = 99
	ck("10판 + 안내 끝이면 열린다", LaneState.daily_open() and LaneState.dch_ready(today))
	# ② 벽 없이 · 희귀까지만 · 작은 군단
	var nw := LaneData.filter_lineup(["tiny", "shield", "spear", "chick", "frog"], {"no_wall": true})
	ck("벽 없이: 벽 친구가 빠진다", nw == ["spear", "frog"] and not nw.any(func(id): return LaneData.is_wall(String(id))), str(nw))
	ck("벽만 있던 편성은 꼬마 하나", LaneData.filter_lineup(["tiny", "shield", "chick"], {"no_wall": true}) == ["tiny"])
	ck("희귀까지만: 특급·전설이 빠진다", LaneData.filter_lineup(["spear", "chick", "owl", "tiger"], {"max_rarity": "rare"}) == ["spear", "chick"])
	ck("특급·전설만이면 꼬마 하나", LaneData.filter_lineup(["owl", "tiger"], {"max_rarity": "rare"}) == ["tiny"])
	LaneState.units = {"tiny": 1, "shield": 1, "spear": 1, "giant": 1, "mage": 1, "chick": 1, "frog": 1, "owl": 1}
	LaneState.lineup = ["owl", "frog", "tiny", "chick", "spear", "giant", "shield", "mage"]
	var fb := LaneBattle.new()
	fb.start(5, 1, LaneData.daily_mods(1))   # 1 = 작은 군단
	LaneState.sort_lineup()
	ck("작은 군단: 편성 앞 다섯만", fb.lineup == LaneState.lineup.slice(0, 5), str(fb.lineup))
	var wb := LaneBattle.new()
	wb.start(5, 1, LaneData.daily_mods(3))   # 3 = 벽 없이
	ck("벽 없이 판에 벽이 없다", not wb.lineup.is_empty() and not wb.lineup.any(func(id): return LaneData.is_wall(String(id))))
	# ⑤ 느긋한 웃음: 친구 값 0.7배 (반올림) · 수입 0.6배
	var nb := LaneBattle.new()
	nb.start(5, 1)
	var sb := LaneBattle.new()
	sb.start(5, 1, LaneData.daily_mods(2))   # 2 = 느긋한 웃음
	var cost_ok := true
	for id in sb.lineup:
		cost_ok = cost_ok and int(sb.stats[id]["cost"]) == maxi(1, int(round(float(nb.stats[id]["cost"]) * 0.7)))
	ck("느긋한 웃음: 친구 값 0.7배", cost_ok and int(sb.stats["giant"]["cost"]) < int(nb.stats["giant"]["cost"]))
	ck("느긋한 웃음: 수입 0.6배", is_equal_approx(sb.rate_mult, nb.rate_mult * 0.6))
	var cb := LaneBattle.new()
	cb.start(5, 1, LaneData.daily_mods(0))   # 0 = 바주카 잔치
	ck("바주카 잔치: 충전 2.5배 · 수입 0.8배", is_equal_approx(cb.cannon_mult, nb.cannon_mult * 2.5) and is_equal_approx(cb.rate_mult, nb.rate_mult * 0.8))
	ck("보통 판은 규칙 없음", nb.mods.is_empty() and nb.bug_hp_mult == 1.0 and nb.lineup == LaneState.lineup)
	nb._spawn_bug("ant")
	cb._spawn_bug("ant")
	var h0 := float(nb.ents[nb.ents.size() - 1]["hp"])
	var h1 := float(cb.ents[cb.ents.size() - 1]["hp"])
	ck("도전 판 벌레 체력 0.9배", is_equal_approx(h1, h0 * 0.9), "%s / %s" % [h1, h0])
	# ③ ④ 보상은 하루 한 번, 판 기록은 그대로
	LaneState.reset()
	LaneState.cleared = 20
	LaneState.tut = 99
	for i in range(1, 21):
		LaneState.flowers[i] = 1
	var n := LaneData.daily_stage(LaneState.cleared)
	var fl0 := LaneState.flowers.duplicate()
	var x0 := LaneState.xp
	var s0 := LaneState.stars
	var t0 := LaneState.tickets
	var r1 := LaneState.on_daily_win(today, n)
	ck("첫 승리: 행복 조각 x3 · 행운별 30", int(r1["xp"]) == int(LaneData.reward(n, false)["xp"]) * 3 and int(r1["stars"]) == 30
		and LaneState.xp - x0 == int(r1["xp"]) and LaneState.stars - s0 == 30 and not bool(r1["again"]))
	ck("꽃 조건이 없으면 티켓 없음", LaneState.tickets == t0)
	ck("이긴 날은 점이 꺼진다", not LaneState.dch_ready(today) and LaneState.dch_ready(today + 1))
	var r2 := LaneState.on_daily_win(today, n)
	ck("두 번째 승리는 보상 0", bool(r2["again"]) and int(r2["xp"]) == 0 and int(r2["stars"]) == 0 and LaneState.xp - x0 == int(r1["xp"]))
	ck("깬 판·꽃·기록이 그대로", LaneState.cleared == 20 and LaneState.flowers == fl0 and LaneState.clears.is_empty()
		and LaneState.fails.is_empty())
	# 꽃 세 송이 조건까지 하면 티켓 하나
	var tl := {"summons": 5, "kinds": {}, "boss_cannon": true, "best_hit": 99, "holds": 3, "cap_t": 0.0, "auto_used": false}
	var t1 := LaneState.tickets
	var r3 := LaneState.on_daily_win(today + 1, n, null, tl, 1.0)
	ck("꽃 세 송이 조건이면 티켓 +1", int(r3["tickets"]) == 1 and LaneState.tickets == t1 + 1
		and LaneState.judge_flowers(n, tl, 1.0) == 7)
	ck("보물 행복 조각 보너스가 붙는다", LaneState.daily_xp(n) >= int(LaneData.reward(n, false)["xp"]) * 3)
	# 저장
	var d := LaneState.to_dict()
	LaneState.from_dict(d)
	ck("도전한 날이 저장된다", LaneState.dch_day == today + 1)
	LaneState.from_dict({})
	ck("옛 저장은 도전 안 함", LaneState.dch_day == 0)

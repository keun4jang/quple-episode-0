extends Node
## 꿈결 키우기 규칙 (IdleData / IdleState / IdleFight).

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
	print("=== 꿈결 키우기 테스트 ===")
	_data_tests()
	_growth_tests()
	_gear_tests()
	_stage_tests()
	_fight_tests()
	_offline_save_tests()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	IdleState.clear_save()
	get_tree().quit(1 if fail_n > 0 else 0)


func _data_tests() -> void:
	print("\n[1] 표")
	var a := IdleData.stage_info(1)
	ck("1번은 윤슬 1-1", IdleData.stage_label(1) == "윤슬 1-1" and not bool(a["boss"]))
	var b := IdleData.stage_info(10)
	ck("10번은 우두머리 한 마리", bool(b["boss"]) and int(b["count"]) == 1 and b["kind"] == "drop_king")
	ck("11번은 볕뉘 2-1", IdleData.stage_label(11) == "볕뉘 2-1")
	ck("100번은 잿마루 10-10 우두머리", IdleData.stage_label(100) == "잿마루 10-10" and bool(IdleData.stage_info(100)["boss"]))
	ck("101번부터 끝없이", bool(IdleData.stage_info(101)["endless"]) and IdleData.stage_label(101) == "잿마루 · 1")
	ck("0번도 1번으로", int(IdleData.stage_info(0)["stage"]) == 1)
	ck("구역 10개 × 10", IdleData.ZONES.size() == 10 and IdleData.STAGE_MAX == 100)
	ck("몬스터는 갈수록 세다", int(IdleData.monster(50, false)["hp"]) > int(IdleData.monster(5, false)["hp"]))
	ck("우두머리는 졸개보다 세다", int(IdleData.monster(10, true)["hp"]) > int(IdleData.monster(10, false)["hp"]) * 3)
	ck("경험이 갈수록 는다", IdleData.exp_need(30) > IdleData.exp_need(3))
	ck("단계 이름이 구역마다", IdleData.item_name("weapon", 3, "mage") == "바위 지팡이")
	ck("그림이 전부 있다", _sprites_exist())


func _sprites_exist() -> bool:
	for z in IdleData.ZONES:
		var kinds: Array = (z["mobs"] as Array).duplicate()
		kinds.append(z["boss"])
		for k in kinds:
			if not ResourceLoader.exists("res://assets/sprites/s-%s-walk.png" % k):
				print("    없음: ", k)
				return false
			if not IdleData.MOB_NAMES.has(k):
				return false
	return true


func _growth_tests() -> void:
	print("\n[2] 성장")
	IdleState.reset()
	ck("처음은 LV1 꿈나그네", IdleState.level == 1 and IdleState.job == "novice")
	var h0 := IdleState.hero()
	var ups := IdleState.add_exp(IdleData.exp_need(1))
	ck("경험이 차면 한 레벨", ups == 1 and IdleState.level == 2 and IdleState.xp == 0)
	ck("레벨이 오르면 몸이 세진다", float(IdleState.hero()["hp"]) > float(h0["hp"]))
	ups = IdleState.add_exp(999999)
	ck("한 번에 여러 레벨", ups > 3)
	IdleState.add_exp(99999999)
	ck("60이 끝", IdleState.level == IdleData.LEVEL_MAX and IdleState.xp == 0)
	ck("더 못 오른다", IdleState.add_exp(1000) == 0)

	IdleState.reset()
	ck("LV5 전에는 직업 못 고른다", not IdleState.set_job("warrior") and IdleState.job == "novice")
	IdleState.level = 5
	ck("LV5에 고른다", IdleState.set_job("mage") and IdleState.job == "mage")
	ck("공짜로 바꾼다", IdleState.set_job("thief") and IdleState.job == "thief")
	ck("없는 직업은 안 된다", not IdleState.set_job("wizard") and IdleState.job == "thief")
	ck("꿈나그네로는 못 돌아간다", not IdleState.set_job("novice"))
	for j in IdleData.JOB_ORDER:
		IdleState.set_job(j)
		var h := IdleState.hero()
		ck("%s 능력치가 양수" % j, float(h["hp"]) > 0 and float(h["atk"]) > 0 and float(h["every"]) > 0)
		ck("%s 필살기가 있다" % j, not (h["skill"] as Dictionary).is_empty())


func _gear_tests() -> void:
	print("\n[3] 장비")
	IdleState.reset()
	ck("여섯 칸이 1단계 +0", IdleState.gear.size() == 6 and IdleState.gear["weapon"] == [1, 0])
	var atk0 := float(IdleState.hero()["atk"])
	ck("꿈조각이 없으면 못 올린다", not IdleState.can_enhance("weapon") and not IdleState.enhance("weapon"))
	IdleState.coins = 1000
	var cost := IdleState.enhance_cost_of("weapon")
	ck("강화한다", IdleState.enhance("weapon") and int(IdleState.gear["weapon"][1]) == 1)
	ck("값만큼 빠진다", IdleState.coins == 1000 - cost)
	ck("공격이 오른다", float(IdleState.hero()["atk"]) > atk0)
	ck("오를수록 비싸다", IdleState.enhance_cost_of("weapon") > cost)
	IdleState.gear["weapon"] = [1, IdleData.PLUS_MAX]
	IdleState.coins = 99999999
	ck("+30이 끝", not IdleState.can_enhance("weapon"))

	IdleState.gear["hat"] = [1, 7]
	ck("높은 단계로 바뀐다", IdleState.upgrade_tier("hat", 4) and int(IdleState.gear["hat"][0]) == 4)
	ck("강화는 이어진다", int(IdleState.gear["hat"][1]) == 7)
	ck("낮거나 같은 단계는 안 바뀐다", not IdleState.upgrade_tier("hat", 4) and not IdleState.upgrade_tier("hat", 2))
	ck("단계가 오르면 값이 커진다",
		IdleData.slot_value("hat", 2, 0) > IdleData.slot_value("hat", 1, 0) * 1.4)
	# 칸마다 올려 주는 것
	var stats := {}
	for s in IdleData.SLOTS:
		stats[IdleData.SLOT_STAT[s]] = true
	ck("공격·체력·방어를 다 올려 준다", stats.size() == 3)

	# 수련
	IdleState.reset()
	IdleState.coins = 99999999
	ck("수련은 처음엔 닫혀 있다", not IdleState.train_open() and not IdleState.do_train("atk"))
	IdleState.best = IdleData.TRAIN_OPEN
	var a0 := float(IdleState.hero()["atk"])
	var tc := IdleState.train_cost_of("atk")
	ck("50번 우두머리를 깨면 열린다", IdleState.train_open() and IdleState.do_train("atk"))
	ck("수련하면 값만큼 빠지고 공격이 1% 오른다", IdleState.coins == 99999999 - tc
		and is_equal_approx(float(IdleState.hero()["atk"]), a0 * (1.0 + IdleData.TRAIN_STEP)))
	ck("수련은 할수록 비싸다", IdleState.train_cost_of("atk") > tc)
	for i in 30:
		IdleState.do_train("hp")
	ck("수련에는 끝이 없다 (30단계)", int(IdleState.train["hp"]) == 30)
	IdleState.coins = 0
	ck("꿈조각이 없으면 못 한다", not IdleState.do_train("def"))
	var td := IdleState.to_dict()
	IdleState.reset()
	IdleState.from_dict(td)
	ck("수련도 저장된다", int(IdleState.train["atk"]) == 1 and int(IdleState.train["hp"]) == 30)

	# 떨굼
	IdleState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var got := 0
	for i in 2000:
		if not IdleState.roll_drop(rng, 35).is_empty():
			got += 1
	ck("떨굼이 된다 (%d)" % got, got > 0)
	var all4 := true
	for s in IdleData.SLOTS:
		all4 = all4 and int(IdleState.gear[s][0]) <= 4
	ck("그 구역 단계보다 높게는 안 나온다", all4)
	ck("이미 높은 칸은 낮은 걸로 안 바뀐다", IdleState.roll_drop(_always(), 1).is_empty())


func _always() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r


func _stage_tests() -> void:
	print("\n[4] 스테이지")
	IdleState.reset()
	var o := IdleState.on_clear()
	ck("깨면 다음 스테이지", IdleState.stage == 2 and IdleState.best == 2 and bool(o["new_best"]))
	IdleState.go_stage(1)
	o = IdleState.on_clear()
	ck("깬 데를 다시 깨면 새로 열리지 않는다", not bool(o["new_best"]) and IdleState.best == 2)
	ck("안 열린 곳은 못 간다", not IdleState.go_stage(50) and IdleState.stage == 2)
	IdleState.on_defeat()
	ck("지면 한 칸 물러난다", IdleState.stage == 1)
	IdleState.on_defeat()
	ck("1번 밑으로는 안 간다", IdleState.stage == 1)

	IdleState.reset()
	IdleState.best = 15
	IdleState.stage = 11
	IdleState.on_defeat()
	ck("물러난 자리가 우두머리면 한 칸 더 물러난다", IdleState.stage == 9 and not IdleState.boss_failed)

	IdleState.reset()
	IdleState.best = 10
	IdleState.stage = 10
	IdleState.on_defeat()
	ck("우두머리에 지면 [보스 도전]", IdleState.boss_failed and IdleState.stage == 9)
	ck("도전하면 우두머리 스테이지로", IdleState.challenge_boss() and IdleState.stage == 10 and not IdleState.boss_failed)
	ck("졌을 때만 도전 가능", not IdleState.challenge_boss())
	var before := IdleState.gear.duplicate(true)
	var oc := IdleState.on_clear()
	ck("우두머리를 처음 깨면 장비가 오른다", not (oc["reward"] as Array).is_empty() and IdleState.gear != before)
	ck("11번이 열린다", IdleState.best == 11 and IdleState.stage == 11)
	IdleState.go_stage(10)
	oc = IdleState.on_clear()
	ck("두 번째는 보상이 없다", (oc["reward"] as Array).is_empty())

	IdleState.reset()
	IdleState.best = 100
	IdleState.stage = 100
	oc = IdleState.on_clear()
	ck("100번을 깨면 엔딩", bool(oc.get("ending", false)) and IdleState.stage == 101)
	IdleState.ending_seen = true
	IdleState.go_stage(100)
	oc = IdleState.on_clear()
	ck("엔딩은 한 번만", not oc.has("ending"))


func _fight_tests() -> void:
	print("\n[5] 자동 전투")
	# 레벨 5 전에는 손으로 싸운다
	IdleState.reset()
	ck("LV1은 자동사냥이 아니다", not IdleState.auto_active() and not IdleState.can_auto())
	var mf := IdleFight.new()
	mf.start(1, 3)
	var mev: Array = []
	for i in 40:
		mev.append_array(mf.tick(0.25))
	var slow_hits := mev.filter(func(e): return e["k"] == "hero_hit").size()
	ck("LV1은 가만히 있으면 느리게만 때린다 (10초에 %d번)" % slow_hits, slow_hits >= 1 and slow_hits <= 4)
	var te0 := mf.tap()
	ck("LV1은 톡 치면 제대로 한 대", te0.size() >= 1 and te0[0]["k"] == "hero_hit" and not bool(te0[0]["tap"]))
	ck("손으로 칠 때도 간격이 있다", mf.tap().is_empty())
	var tguard := 0
	while not mf.done and tguard < 2000:
		mf.tick(IdleFight.MANUAL_COOLDOWN)
		mf.tap()
		tguard += 1
	ck("톡톡 쳐서 첫 스테이지를 깬다", mf.result == "clear", mf.result)
	IdleState.level = 4
	ck("LV4도 아직", not IdleState.can_auto())
	IdleState.level = 5
	ck("LV5부터 자동사냥", IdleState.auto_active())
	IdleState.auto_on = false
	ck("꺼 두면 자동이 아니다", not IdleState.auto_active())
	IdleState.auto_on = true

	IdleState.reset()
	IdleState.level = 5
	var f := IdleFight.new()
	f.start(1, 3)
	var evs: Array = []
	var guard := 0
	while not f.done and guard < 4000:
		evs.append_array(f.tick(0.5))
		guard += 1
	ck("LV5는 첫 스테이지를 알아서 깬다", f.result == "clear", f.result)
	var kills := 0
	var spawns := 0
	for e in evs:
		if e["k"] == "kill":
			kills += 1
		if e["k"] == "spawn":
			spawns += 1
	ck("5마리를 잡고 5마리가 나온다", kills == 5 and spawns == 5, "%d/%d" % [kills, spawns])
	ck("clear 사건이 한 번", evs.filter(func(e): return e["k"] == "clear").size() == 1)
	ck("경험과 꿈조각이 쌓인다", IdleState.coins > 0 and IdleState.kills == 5)
	IdleState.level = 5
	ck("끝난 뒤 tick은 아무 일도 없다", f.tick(1.0).is_empty())

	# 못 이기는 스테이지는 진다
	IdleState.reset()
	IdleState.level = 5
	f.start(80, 3)
	guard = 0
	while not f.done and guard < 4000:
		f.tick(0.5)
		guard += 1
	ck("LV5가 80번에서는 진다", f.result == "defeat")

	# 같은 씨앗이면 같은 결과
	IdleState.reset()
	IdleState.level = 5
	var f1 := IdleFight.new()
	f1.start(4, 11)
	var t1 := 0.0
	while not f1.done and t1 < 600.0:
		f1.tick(0.25)
		t1 += 0.25
	var xp1 := IdleState.xp + IdleState.level * 1000
	IdleState.reset()
	IdleState.level = 5
	var f2 := IdleFight.new()
	f2.start(4, 11)
	var t2 := 0.0
	while not f2.done and t2 < 600.0:
		f2.tick(0.25)
		t2 += 0.25
	ck("같은 씨앗은 같은 결과", t1 == t2 and xp1 == IdleState.xp + IdleState.level * 1000)

	# 직업 필살기가 나간다
	for j in IdleData.JOB_ORDER:
		IdleState.reset()
		IdleState.level = 40
		IdleState.set_job(j)
		var g := IdleFight.new()
		g.start(30, 2)
		var skills := 0
		var t := 0.0
		while not g.done and t < 120.0:
			for e in g.tick(0.25):
				if e["k"] == "skill":
					skills += 1
			t += 0.25
		ck("%s 필살기가 나간다 (%d)" % [j, skills], skills > 0)
	# 톡 치기 (자동사냥 중)
	IdleState.reset()
	IdleState.level = 5
	var tf := IdleFight.new()
	tf.start(1, 4)
	ck("나타나기 전에는 톡 쳐도 아무 일 없다", tf.tap().is_empty())
	tf.tick(IdleFight.SPAWN_DELAY + 0.01)
	var te := tf.tap()
	ck("싸우는 중엔 톡 치면 한 대", te.size() >= 1 and te[0]["k"] == "hero_hit" and bool(te[0]["tap"]))
	ck("곧바로 또 치면 안 된다 (간격)", tf.tap().is_empty())
	tf.tick(IdleFight.TAP_COOLDOWN + 0.01)
	ck("간격이 지나면 또 된다", not tf.tap().is_empty() or tf.done)
	# 우두머리 스테이지는 한 마리
	IdleState.reset()
	IdleState.level = 30
	var bf := IdleFight.new()
	bf.start(10, 1)
	ck("우두머리 스테이지는 한 마리", bf.total == 1)


func _offline_save_tests() -> void:
	print("\n[6] 자는 동안 · 저장")
	IdleState.reset()
	IdleState.stage = 20
	IdleState.best = 20
	IdleState.last_seen = 1000
	ck("1분은 보상이 없다", IdleState.offline_reward(1060).is_empty())
	ck("처음 켠 것(last_seen 0)도 없다", (func():
		IdleState.last_seen = 0
		var r := IdleState.offline_reward(99999)
		IdleState.last_seen = 1000
		return r.is_empty()).call())
	ck("시계가 거꾸로 가도 없다", IdleState.offline_reward(500).is_empty())
	var r1 := IdleState.offline_reward(1000 + 60 * 60)
	ck("한 시간 보상", int(r1["minutes"]) == 60 and int(r1["coins"]) > 0 and int(r1["exp"]) > 0)
	var r2 := IdleState.offline_reward(1000 + 60 * 60 * 100)
	ck("최대 8시간", int(r2["minutes"]) == 480)
	var c0 := IdleState.coins
	var cl := IdleState.claim_offline(1000 + 3600)
	ck("받으면 쌓이고 시각이 갱신된다",
		IdleState.coins == c0 + int(cl["coins"]) and IdleState.last_seen == 1000 + 3600)
	ck("두 번 받을 수 없다", IdleState.claim_offline(1000 + 3600).is_empty())

	# 저장 왕복
	IdleState.reset()
	IdleState.clear_save()
	ck("저장 없음", not IdleState.has_save())
	IdleState.level = 17
	IdleState.xp = 33
	IdleState.job = "archer"
	IdleState.coins = 4242
	IdleState.stage = 23
	IdleState.best = 31
	IdleState.gear["hat"] = [3, 9]
	IdleState.boss_failed = true
	IdleState.auto_on = false
	IdleState.save(777)
	IdleState.reset()
	ck("초기화하면 빈다", IdleState.level == 1)
	ck("불러온다", IdleState.has_save() and IdleState.load_save())
	ck("전부 돌아온다", IdleState.level == 17 and IdleState.xp == 33 and IdleState.job == "archer"
		and IdleState.coins == 4242 and IdleState.stage == 23 and IdleState.best == 31
		and IdleState.gear["hat"] == [3, 9] and IdleState.boss_failed and IdleState.last_seen == 777
		and not IdleState.auto_on)
	# 망가진 저장
	var d := {"level": 9999, "job": "???", "best": -4, "stage": 500, "gear": {"hat": [99, 99], "weapon": "x"}}
	IdleState.from_dict(d)
	ck("망가진 값은 범위 안으로", IdleState.level == IdleData.LEVEL_MAX and IdleState.job == "novice"
		and IdleState.best == 1 and IdleState.stage == 1)
	ck("망가진 장비는 한계 안으로", IdleState.gear["hat"] == [10, 30] and IdleState.gear["weapon"] == [1, 0])
	var fh := FileAccess.open(IdleState.SAVE_PATH, FileAccess.WRITE)
	fh.store_string("깨진 파일 [[[")
	fh.close()
	IdleState.reset()
	ck("깨진 파일은 불러오기 실패, 상태는 그대로", not IdleState.load_save() and IdleState.level == 1)
	IdleState.clear_save()
	ck("지우면 없다", not IdleState.has_save())

extends Node
## 쿼카 군단 화면 찍기. SHOT_MODE=home|battle|gacha|evolve(SHOT_EVO_ID) (SHOT_PULL=1|10, SHOT_LEGEND=1), SHOT_ANIMALS=id,id (편성), SHOT_TAB=map|units|lineup, SHOT_STAGE, SHOT_LV, SHOT_WAIT, SHOT_SERIES, SHOT_FAST=0|1 (1배·3배), SHOT_MODE=handy (여럿 맞히기·떼 막기 글자), SHOT_TALLY=1 (result 에 판 기록 줄), SHOT_FLOWERS=1|2 (꽃: 1 깬 판마다 섞어서 · 2 깬 판 다 셋 - 꽃다발 보기. 자동은 끈다), SHOT_MODE=missions (오늘의 임무 창 · SHOT_HOMEONLY=1 홈 단추만 · SHOT_STAMPS=n · SHOT_CLAIM=1 받기 누르기) | mresult (결과 창의 임무 줄), SHOT_MODE=calendar (선물 달력 · SHOT_CAL=n 오늘 받을 칸 · SHOT_CALVIEW=1 임무 창에서 보기(받기 없이) · SHOT_TAKE=1 받기 누르기)
func _ready() -> void:
	LaneState.save_path = LaneState.TEST_SAVE_PATH  # 진짜 저장(user://lane.cfg)을 건드리지 않는다
	LaneState.clear_save()
	LaneState.reset()
	var st := int(OS.get_environment("SHOT_STAGE")) if OS.get_environment("SHOT_STAGE") != "" else 12
	var lv := int(OS.get_environment("SHOT_LV")) if OS.get_environment("SHOT_LV") != "" else 6
	LaneState.cleared = st - 1
	LaneState.unlock_by_stage()
	for id in LaneState.units.keys():
		LaneState.units[id] = lv
		if lv >= LaneData.EVOLVE_LV:
			LaneState.evolved[id] = true
	LaneState.xp = 12345
	LaneState.stars = 30
	LaneState.seen_intro = true
	LaneState.daily_day = int(Time.get_unix_time_from_system()) / 86400 + 1   # 시간대가 앞서도 달력이 안 뜨게
	LaneState.migrated = true
	LaneState.tut = 99 if OS.get_environment("SHOT_TUT") == "" else int(OS.get_environment("SHOT_TUT"))
	if OS.get_environment("SHOT_MODE") == "calendar":
		var cn := int(OS.get_environment("SHOT_CAL")) if OS.get_environment("SHOT_CAL") != "" else 9
		if OS.get_environment("SHOT_CALVIEW") == "1":
			LaneState.cal_day = cn
		else:
			# 어제 받은 것으로 - 켜자마자 진짜 길로 오늘 칸을 받는다 (홈에서 달력이 뜬다)
			LaneState.cal_day = cn - 1
			LaneState.daily_day = int(Time.get_unix_time_from_system()) / 86400 - 1
	if OS.get_environment("SHOT_LOOT") == "1":
		# 보물 몇 개 + 장신구 둘 (지도·카드에 보이게)
		LaneState.treasures[0] = [3, 2, 1]
		LaneState.treasures[1] = [1, 0, 2]
		LaneState.accs = {"feather_hat": 2, "star_necklace": 1}
		LaneState.acc_on = {"tiny": "feather_hat"}
	if OS.get_environment("SHOT_ANIMALS") != "":
		LaneState.lineup = []
		for id in OS.get_environment("SHOT_ANIMALS").split(","):
			LaneState.units[id] = lv
			if lv >= LaneData.EVOLVE_LV:
				LaneState.evolved[id] = true
			LaneState.lineup.append(id)
	if OS.get_environment("SHOT_WEAR") == "1":
		# 장신구 10개를 편성 앞쪽부터 하나씩
		LaneState.accs = {}
		LaneState.acc_on = {}
		var k := 0
		for acc in LaneData.ACC_ORDER:
			LaneState.accs[acc] = 1
			if k < LaneState.lineup.size():
				LaneState.acc_on[String(LaneState.lineup[k])] = acc
			k += 1
	# SHOT_BAZ=N 바주카포 강화 단계
	if OS.get_environment("SHOT_BAZ") != "":
		LaneState.bazooka_lv = int(OS.get_environment("SHOT_BAZ"))
	# SHOT_FAST=0|1 빨리 감기 단계 (0 = 1배, 1 = 3배)
	LaneState.speed_lv = clampi(int(OS.get_environment("SHOT_FAST")), 0, LaneData.SPEEDS.size() - 1) if OS.get_environment("SHOT_FAST") != "" else 0
	LaneState.auto_summon = true
	var flw := OS.get_environment("SHOT_FLOWERS")
	if flw != "":
		LaneState.auto_summon = false
		for i in range(1, LaneState.cleared + 1):
			LaneState.flowers[i] = 7 if flw == "2" else [1, 3, 7, 5][i % 4]
	LaneState.save(int(Time.get_unix_time_from_system()))
	var g = load("res://scenes/lane/LaneGame.tscn").instantiate()
	add_child(g)
	var out := OS.get_environment("SHOT_OUT")
	await get_tree().create_timer(1.0).timeout
	if OS.get_environment("SHOT_MODE") == "battle":
		g._start_battle(st)
	elif OS.get_environment("SHOT_MODE") == "gacha":
		LaneState.stars = 2000
		if OS.get_environment("SHOT_LEGEND") == "1":
			LaneState.pity = LaneData.PITY_LEGEND - 1
		g._do_pull(int(OS.get_environment("SHOT_PULL")) if OS.get_environment("SHOT_PULL") != "" else 1)
	elif OS.get_environment("SHOT_MODE") == "result":
		g._start_battle(st)
		await get_tree().create_timer(0.5).timeout
		g.stage_n = st
		if OS.get_environment("SHOT_FLOWERS") != "":
			g.battle.tally.merge({"best_hit": 99, "cap_t": 0.0, "holds": 1, "boss_cannon": true, "auto_used": false}, true)
		if OS.get_environment("SHOT_TALLY") == "1":
			g.battle.tally["multi5"] = 2
			g.battle.tally["holds"] = 1
		g.battle.done = true
		g._end_battle("win")
	elif OS.get_environment("SHOT_MODE") == "handy":
		g._start_battle(st)
		await get_tree().create_timer(4.0).timeout
		g._on_event({"k": "multi", "hit": 7, "gain": 100})
		g._on_event({"k": "wave_hold", "gain": LaneData.WAVE_HOLD})
	elif OS.get_environment("SHOT_MODE") == "wear":
		g._start_battle(st)
	elif OS.get_environment("SHOT_MODE") == "toast":
		g._toast("매일 선물 2일째!  티켓 1장 · 꿈별 30")   # SHOT_TOAST
	elif OS.get_environment("SHOT_MODE") == "settings":
		var sv = get_tree().get_first_node_in_group("settings_ui")
		if sv == null:
			sv = load("res://scenes/ui/SettingsUI.tscn").instantiate()
			add_child(sv)
			await get_tree().process_frame
		sv.open()
	elif OS.get_environment("SHOT_MODE") == "cannon":
		g._start_battle(st)
		await get_tree().create_timer(14.0).timeout
		g.battle.cannon = g.battle.cannon_max
		g._cannon_btn.pressed.emit()
	elif OS.get_environment("SHOT_MODE") == "evolve":
		# SHOT_EVO_ID 를 진화시키는 연출 (SHOT_WAIT 로 어느 순간을 찍을지)
		var eid := OS.get_environment("SHOT_EVO_ID") if OS.get_environment("SHOT_EVO_ID") != "" else "spear"
		LaneState.units[eid] = LaneData.EVOLVE_LV
		LaneState.evolved.erase(eid)
		LaneState.xp = 9999999
		LaneState.evolve(eid)
		g._evolve_show(eid)
	elif OS.get_environment("SHOT_MODE") == "missions":
		_fake_missions(g)
		g._refresh_home_top()
		if OS.get_environment("SHOT_HOMEONLY") != "1":
			g._open_missions()
		if OS.get_environment("SHOT_CLAIM") == "1":
			# 받기 → 도장 보상 받기 (7칸이면 캡슐 연출)
			await get_tree().create_timer(0.3).timeout
			g._claim_mission(0)
			await get_tree().create_timer(0.3).timeout
			g._claim_week_all()
	elif OS.get_environment("SHOT_MODE") == "mresult":
		g._start_battle(st)
		await get_tree().create_timer(0.5).timeout
		_fake_missions(g)
		g.stage_n = st
		g.battle.tally.merge({"holds": 2, "kills": 40, "summons": 12}, true)
		g.battle.done = true
		g._end_battle("win")
	elif OS.get_environment("SHOT_MODE") == "calendar":
		if OS.get_environment("SHOT_CALVIEW") == "1":
			_fake_missions(g)
			g._open_missions()
			await get_tree().create_timer(0.3).timeout
			var cb = g.find_child("CalBtn", true, false)
			if cb != null:
				cb.pressed.emit()
		if OS.get_environment("SHOT_TAKE") == "1":
			await get_tree().create_timer(1.0).timeout
			var tb = g.find_child("Take", true, false)
			if tb != null:
				tb.pressed.emit()
	elif OS.get_environment("SHOT_MODE") == "acc":
		g._open_acc_picker("tiny")
	elif OS.get_environment("SHOT_TAB") != "":
		# 진짜 탭 단추를 누른다 (탭을 옮길 때 하는 일까지 그대로 보이게)
		var tb = g._home.get_node_or_null("TabBar/Tabs/Tab_" + OS.get_environment("SHOT_TAB"))
		if tb != null:
			tb.pressed.emit()
		else:
			g._home_tab = OS.get_environment("SHOT_TAB")
			g._fill_home()
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 2.0
	await get_tree().create_timer(wait).timeout
	var series := int(OS.get_environment("SHOT_SERIES")) if OS.get_environment("SHOT_SERIES") != "" else 0
	if series > 0:
		for i in series:
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % i))
			await get_tree().create_timer(float(OS.get_environment("SHOT_GAP")) if OS.get_environment("SHOT_GAP") != "" else 0.3).timeout
	else:
		get_viewport().get_texture().get_image().save_png(out)
	LaneState.clear_save()
	get_tree().quit()


## 임무 창 사진용: 오늘 날짜로 임무 셋(받기 · 진행 중 · 받음)과 도장 몇 개.
func _fake_missions(g) -> void:
	var today: int = g._local_now() / 86400
	LaneState.check_week(today)
	LaneState.mission_day = today
	LaneState.missions = [{"id": "win3", "prog": 3, "got": false}, {"id": "hold2", "prog": 1, "got": false},
		{"id": "multi2", "prog": 2, "got": true}]
	LaneState.mission_swap = false
	LaneState.stamps = int(OS.get_environment("SHOT_STAMPS")) if OS.get_environment("SHOT_STAMPS") != "" else 5
	LaneState.week_got = [true, false, false]

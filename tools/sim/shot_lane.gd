extends Node
## 쿼카 군단 화면 찍기. SHOT_MODE=home|battle|gacha|evolve(SHOT_EVO_ID) (SHOT_PULL=1|10, SHOT_LEGEND=1), SHOT_ANIMALS=id,id (편성), SHOT_TAB=map|units|lineup, SHOT_STAGE, SHOT_LV, SHOT_WAIT, SHOT_SERIES
func _ready() -> void:
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
	LaneState.daily_day = int(Time.get_unix_time_from_system()) / 86400
	LaneState.migrated = true
	LaneState.tut = 99 if OS.get_environment("SHOT_TUT") == "" else int(OS.get_environment("SHOT_TUT"))
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
	LaneState.speed2 = OS.get_environment("SHOT_FAST") == "1"
	LaneState.auto_summon = true
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
		g.battle.done = true
		g._end_battle("win")
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
		g.battle.cannon = LaneData.CANNON_CHARGE
		g._cannon_btn.pressed.emit()
	elif OS.get_environment("SHOT_MODE") == "evolve":
		# SHOT_EVO_ID 를 진화시키는 연출 (SHOT_WAIT 로 어느 순간을 찍을지)
		var eid := OS.get_environment("SHOT_EVO_ID") if OS.get_environment("SHOT_EVO_ID") != "" else "spear"
		LaneState.units[eid] = LaneData.EVOLVE_LV
		LaneState.evolved.erase(eid)
		LaneState.xp = 9999999
		LaneState.evolve(eid)
		g._evolve_show(eid)
	elif OS.get_environment("SHOT_MODE") == "acc":
		g._open_acc_picker("tiny")
	elif OS.get_environment("SHOT_TAB") != "":
		g._home_tab = OS.get_environment("SHOT_TAB")
		g._fill_home()
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 2.0
	await get_tree().create_timer(wait).timeout
	var series := int(OS.get_environment("SHOT_SERIES")) if OS.get_environment("SHOT_SERIES") != "" else 0
	if series > 0:
		for i in series:
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % i))
			await get_tree().create_timer(0.3).timeout
	else:
		get_viewport().get_texture().get_image().save_png(out)
	LaneState.clear_save()
	get_tree().quit()

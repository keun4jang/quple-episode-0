extends Node
## 한 판을 10초마다 찍는다. TRACE_STAGE, TRACE_LV(모든 쿼카 레벨)
func _ready() -> void:
	var n := int(OS.get_environment("TRACE_STAGE")) if OS.get_environment("TRACE_STAGE") != "" else 40
	var lv := int(OS.get_environment("TRACE_LV")) if OS.get_environment("TRACE_LV") != "" else 6
	LaneState.reset()
	LaneState.cleared = n - 1
	LaneState.unlock_by_stage()
	for id in LaneState.units.keys():
		LaneState.units[id] = lv
	var b := LaneBattle.new()
	b.start(n, 3)
	b.auto = true
	var t := 0.0
	var kills := {"q": 0, "b": 0}
	var bossd := -1.0
	while not b.done and t < 600.0:
		for e in b.tick(0.25):
			if e["k"] == "die":
				kills[e["side"]] += 1
				if bool(e.get("boss", false)):
					bossd = t
		t += 0.25
		if int(t * 4) % 40 == 0:
			var qn := 0
			var bn := 0
			var front := 0.0
			for e in b.ents:
				if float(e["hp"]) <= 0: continue
				if e["side"] == "q":
					qn += 1
					front = maxf(front, float(e["pos"]))
				else:
					bn += 1
			print("%4.0f초 꿈빛 %4.0f 일꾼%d 쿼카%2d 벌레%2d 전선 %4.0f 둥지 %5.0f/%5.0f 성 %4.0f 죽인 벌레 %d 잃은 쿼카 %d" % [t, b.wallet,
				b.worker, qn, bn, front, b.nest_hp, b.nest_max, b.our_hp, kills["b"], kills["q"]])
	print("결과 %s %.0f초 (우두머리 쓰러뜨린 때 %.0f초)" % [b.result, t, bossd])
	get_tree().quit()

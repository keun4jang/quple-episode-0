extends Node
## 화면 점검: 판을 여러 번 이어 하며 "살아 있는 쿼카·벌레는 모두 그려지는가" 를 본다.
## (지난 판 기록이 남아 새 친구가 안 보이던 버그를 다시 잡으려고)
func _ready() -> void:
	LaneState.clear_save()
	LaneState.reset()
	LaneState.tut = 99
	LaneState.migrated = true
	LaneState.cleared = 12
	LaneState.unlock_by_stage()
	for id in LaneState.units.keys():
		LaneState.units[id] = 6
	LaneState.auto_summon = true
	LaneState.speed_lv = 1
	LaneState.daily_day = 999999
	var g = load("res://scenes/lane/LaneGame.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(0.5).timeout
	var bad := 0
	var checks := 0
	for round_i in 4:
		g._start_battle(5 + round_i)
		for k in 14:
			await get_tree().create_timer(0.7).timeout
			if g._ended:
				break
			for e in g.battle.ents:
				if float(e["hp"]) <= 0.0:
					continue
				checks += 1
				var a = g._actor_of.get(int(e["uid"]))
				var off := false
				if a != null and is_instance_valid(a):
					var want: Vector2 = g._field.to_screen(float(e["pos"]), 0.0)
					off = absf(a.position.y - want.y) > 80.0 or a.position.y < -50.0 or a.position.y > g.size.y + 50.0
				if a == null or not is_instance_valid(a) or not a.visible or g._dead.has(int(e["uid"])) or off:
					bad += 1
					print("  ! %d판 %s(%s) uid %d 가 안 그려진다 (pos %.0f)" % [5 + round_i, e["kind"], e["side"], e["uid"], e["pos"]])
		# 이긴 순간 쓰러지던 몸처럼: 지금 번호들을 '녹는 중' 으로 남겨 둔다 - 다음 판이 이걸 비워야 한다
		for e in g.battle.ents:
			g._dead[int(e["uid"])] = true
		for u in range(1, 40):
			g._dead[u] = true
			g._hit_at[u] = 999.0      # 지난 판 늦게 맞은 기록 (판 시간은 새 판에서 0부터)
		g.battle.done = true
		if not g._ended:
			g._end_battle("lose")
		await get_tree().create_timer(0.3).timeout
		if g._world != null:
			g._world.queue_free()
			g._world = null
	print("점검: 살아 있는 몸 %d번 확인 · 안 그려진 것 %d" % [checks, bad])
	LaneState.clear_save()
	get_tree().quit()

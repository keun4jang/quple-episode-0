extends Node
## 쿼카 군단 화면을 오래 돌린다 (그림 없이). 판이 끝나면 '다음 판'/'다시' 를 누르고, 가끔 버튼을 아무거나 누른다.
## SOAK_SECS, SOAK_STAGE, SOAK_LV, SOAK_CHAOS=1
var g
var t := 0.0
var rng := RandomNumberGenerator.new()
var chaos_t := 0.0
var battles := 0
var wins := 0
var last_mode := ""
var maxn := 0

func _ready() -> void:
	rng.seed = 11
	LaneState.clear_save()
	LaneState.reset()
	var st := int(OS.get_environment("SOAK_STAGE")) if OS.get_environment("SOAK_STAGE") != "" else 5
	var lv := int(OS.get_environment("SOAK_LV")) if OS.get_environment("SOAK_LV") != "" else 8
	LaneState.cleared = st - 1
	LaneState.unlock_by_stage()
	for id in LaneState.units.keys():
		LaneState.units[id] = lv
	LaneState.seen_intro = true
	LaneState.auto_summon = true
	LaneState.speed_lv = 1
	LaneState.save(int(Time.get_unix_time_from_system()))
	g = load("res://scenes/lane/LaneGame.tscn").instantiate()
	add_child(g)

func _process(dt: float) -> void:
	t += dt
	if g.mode == "home" and t > 1.0:
		g._start_battle(mini(LaneState.cleared + 1, LaneData.STAGE_MAX))
		battles += 1
	elif g.mode == "battle" and g._ended and g._result != null and is_instance_valid(g._result):
		if g.battle.result == "win":
			wins += 1
		maxn = maxi(maxn, g.stage_n)
		# 결과 창의 '다음 판' 버튼을 찾아 누른다
		for b in g._result.find_children("*", "Button", true, false):
			if String(b.text).begins_with("다음") or String(b.text).begins_with("다시"):
				b.emit_signal("pressed")
				battles += 1
				break
	if OS.get_environment("SOAK_CHAOS") != "" and g.mode == "battle" and not g._ended:
		chaos_t += dt
		if chaos_t > 0.4:
			chaos_t = 0.0
			match rng.randi_range(0, 4):
				0:
					for id in g.battle.lineup:
						g.battle.summon(String(id))
				1:
					g.battle.upgrade_worker()
				2:
					g.battle.fire_cannon()
				3:
					g._speed_btn.emit_signal("pressed")
				4:
					g._auto_btn.emit_signal("pressed")
	var secs := float(OS.get_environment("SOAK_SECS")) if OS.get_environment("SOAK_SECS") != "" else 60.0
	if t >= secs:
		print("판 %d번 · 이김 %d · 가장 먼 곳 %d · 노드 %d · time_scale %.2f" % [battles, wins, maxn,
			get_tree().get_node_count(), Engine.time_scale])
		LaneState.clear_save()
		get_tree().quit()

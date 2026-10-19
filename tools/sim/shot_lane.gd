extends Node
## 쿼카 군단 화면 찍기. SHOT_MODE=home|battle, SHOT_TAB=map|units|lineup, SHOT_STAGE, SHOT_LV, SHOT_WAIT, SHOT_SERIES
func _ready() -> void:
	LaneState.clear_save()
	LaneState.reset()
	var st := int(OS.get_environment("SHOT_STAGE")) if OS.get_environment("SHOT_STAGE") != "" else 12
	var lv := int(OS.get_environment("SHOT_LV")) if OS.get_environment("SHOT_LV") != "" else 6
	LaneState.cleared = st - 1
	LaneState.unlock_by_stage()
	for id in LaneState.units.keys():
		LaneState.units[id] = lv
	LaneState.xp = 12345
	LaneState.stars = 30
	LaneState.seen_intro = true
	LaneState.auto_summon = true
	LaneState.save(int(Time.get_unix_time_from_system()))
	var g = load("res://scenes/lane/LaneGame.tscn").instantiate()
	add_child(g)
	var out := OS.get_environment("SHOT_OUT")
	await get_tree().create_timer(1.0).timeout
	if OS.get_environment("SHOT_MODE") == "battle":
		g._start_battle(st)
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

extends Node
## 전투 화면을 오래 돌려 연출이 남기는 찌꺼기를 본다: 노드 수가 계속 느나, 시간이 느린 채로 멈춰 있나,
## 몬스터가 안 보이는데 싸우고 있나. SOAK_SECS 초, SOAK_JOB, SOAK_STAGE, SOAK_LV, SOAK_TAP=1(초에 세 번 톡).
var g
var t := 0.0
var samples: Array = []
var stuck_slow := 0.0
var ghost := 0.0
var tap_t := 0.0
var chaos_t := 0.0
var rng := RandomNumberGenerator.new()
var last_event_t := 0.0
var last_kills := -1
var last_stage := -1
var stall_max := 0.0
var actions: Dictionary = {}
var problems: Array = []

func _ready() -> void:
	IdleState.clear_save()
	IdleState.reset()
	IdleState.level = int(OS.get_environment("SOAK_LV")) if OS.get_environment("SOAK_LV") != "" else 60
	IdleState.job = OS.get_environment("SOAK_JOB") if OS.get_environment("SOAK_JOB") != "" else "warrior"
	var st := int(OS.get_environment("SOAK_STAGE")) if OS.get_environment("SOAK_STAGE") != "" else 13
	IdleState.stage = st
	IdleState.best = st
	IdleState.seen_intro = true
	rng.seed = 5
	match OS.get_environment("SOAK_SCENARIO"):
		"ending":
			IdleState.stage = 100
			IdleState.best = 100
			for sl in IdleData.SLOTS:
				IdleState.gear[sl] = [10, 30]
		"offline":
			IdleState.coins = 0
	IdleState.coins = maxi(IdleState.coins, 0)
	if OS.get_environment("SOAK_SCENARIO") == "offline":
		IdleState.save(int(Time.get_unix_time_from_system()) - 3 * 3600)
	else:
		IdleState.save(int(Time.get_unix_time_from_system()))
	g = load("res://scenes/idle/IdleGame.tscn").instantiate()
	add_child(g)

func _process(_dt: float) -> void:
	var rdt := _dt / maxf(Engine.time_scale, 0.001)
	t += rdt
	if Engine.time_scale < 0.99:
		stuck_slow += rdt
	else:
		stuck_slow = 0.0
	if stuck_slow > 0.5:
		print("!! 시간이 0.5초 넘게 느린 채로 멈춤 (time_scale=%.2f)" % Engine.time_scale)
		stuck_slow = -999.0
	# 싸우는 중인데 몬스터가 안 보이면 이상하다
	if g.fight.state == "fight" and not g.fight.done and (not g._mon.visible or g._mon.dissolve > 0.0):
		ghost += rdt
	# 멈춤 검사: 처치 수나 스테이지가 바뀌지 않은 채로 얼마나 오래 있었나
	if IdleState.kills != last_kills or IdleState.stage != last_stage or g._blocked:
		last_kills = IdleState.kills
		last_stage = IdleState.stage
		last_event_t = t
	stall_max = maxf(stall_max, t - last_event_t)
	if IdleState.stage < 1 or IdleState.stage > IdleState.best:
		problems.append("스테이지 범위 밖 %d/%d" % [IdleState.stage, IdleState.best])
	if g._say_layer.visible and OS.get_environment("SOAK_SCENARIO") != "":
		if not actions.has("say:" + g._say_lbl.text):
			actions["say:" + g._say_lbl.text] = 1
			print("  [문장] ", g._say_lbl.text, "  (꿈조각 %d · LV %d)" % [IdleState.coins, IdleState.level])
		_click_say()
	if OS.get_environment("SOAK_CHAOS") != "":
		chaos_t += rdt
		if chaos_t > 0.7:
			chaos_t = 0.0
			_chaos()
	if OS.get_environment("SOAK_TAP") != "":
		tap_t += rdt
		if tap_t > 0.33:
			tap_t = 0.0
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			e.position = Vector2(700, 300)
			g._gui_input(e)
	if OS.get_environment("SOAK_TRACE") != "" and int(t * 2.0) != int((t - rdt) * 2.0):
		print("    t=%.1f stage=%d best=%d kills=%d state=%s done=%s result=%s blocked=%s say=%s end_t=%.2f armed=%s ending_seen=%s" % [
			t, IdleState.stage, IdleState.best, IdleState.kills, g.fight.state, g.fight.done, g.fight.result,
			g._blocked, g._say_layer.visible, g._end_t, g._end_armed, IdleState.ending_seen])
	if samples.size() < int(t / 10.0) + 1:
		samples.append([int(t), get_tree().get_node_count(), IdleState.stage, IdleState.best, IdleState.kills, Engine.get_frames_per_second()])
	var secs := float(OS.get_environment("SOAK_SECS")) if OS.get_environment("SOAK_SECS") != "" else 60.0
	if t >= secs:
		for s in samples:
			print("  %3d초 · 노드 %4d · 지금 %d · 최고 %d · 처치 %d · fps %d" % s)
		print("유령 몬스터(싸우는데 안 보임) 누적 %.2f초 · 끝 time_scale %.2f" % [ghost, Engine.time_scale])
		print("가장 오래 아무 진행 없던 시간 %.1f초 · 문제 %d건 %s" % [stall_max, problems.size(), str(problems.slice(0, 3))])
		if not actions.is_empty():
			var keys := actions.keys().filter(func(k): return not String(k).begins_with("say:"))
			print("누른 것: ", ", ".join(keys.map(func(k): return "%s %d" % [k, actions[k]])))
		IdleState.clear_save()
		get_tree().quit()


func _click_say() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	g._say_at = -99.0
	g._input(e)


## 사람처럼 아무 버튼이나 누른다 (창 열기·닫기·강화·직업 바꾸기·스테이지 고르기·보스 도전·자동 켜고 끄기·뒤로가기).
func _chaos() -> void:
	var acts := ["tab_char", "tab_gear", "tab_stage", "close", "enhance_all", "job", "go_stage", "boss", "auto",
		"back", "train", "skill", "skill"]
	var a: String = acts[rng.randi_range(0, acts.size() - 1)]
	actions[a] = int(actions.get(a, 0)) + 1
	match a:
		"tab_char":
			g._open_tab("char")
		"tab_gear":
			g._open_tab("gear")
		"tab_stage":
			g._open_tab("stage")
		"close":
			g._close_tab()
		"enhance_all":
			g._enhance_all()
		"job":
			g._pick_job(IdleData.JOB_ORDER[rng.randi_range(0, 3)])
		"go_stage":
			g._go_stage(rng.randi_range(1, IdleState.best))
		"boss":
			g._on_boss()
		"auto":
			g._on_auto()
		"back":
			g.close_panel()
		"train":
			g._on_train(IdleData.TRAIN_STATS[rng.randi_range(0, 2)])
		"skill":
			if g.has_method("_on_skill_btn"):
				g._on_skill_btn(rng.randi_range(0, 2))

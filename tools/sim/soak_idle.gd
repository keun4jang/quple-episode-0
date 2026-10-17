extends Node
## 전투 화면을 오래 돌려 연출이 남기는 찌꺼기를 본다: 노드 수가 계속 느나, 시간이 느린 채로 멈춰 있나,
## 몬스터가 안 보이는데 싸우고 있나. SOAK_SECS 초, SOAK_JOB, SOAK_STAGE, SOAK_LV, SOAK_TAP=1(초에 세 번 톡).
var g
var t := 0.0
var samples: Array = []
var stuck_slow := 0.0
var ghost := 0.0
var tap_t := 0.0

func _ready() -> void:
	IdleState.clear_save()
	IdleState.reset()
	IdleState.level = int(OS.get_environment("SOAK_LV")) if OS.get_environment("SOAK_LV") != "" else 60
	IdleState.job = OS.get_environment("SOAK_JOB") if OS.get_environment("SOAK_JOB") != "" else "warrior"
	var st := int(OS.get_environment("SOAK_STAGE")) if OS.get_environment("SOAK_STAGE") != "" else 13
	IdleState.stage = st
	IdleState.best = st
	IdleState.seen_intro = true
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
	if OS.get_environment("SOAK_TAP") != "":
		tap_t += rdt
		if tap_t > 0.33:
			tap_t = 0.0
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			e.position = Vector2(700, 300)
			g._gui_input(e)
	if samples.size() < int(t / 10.0) + 1:
		samples.append([int(t), get_tree().get_node_count(), IdleState.stage, IdleState.best, IdleState.kills, Engine.get_frames_per_second()])
	var secs := float(OS.get_environment("SOAK_SECS")) if OS.get_environment("SOAK_SECS") != "" else 60.0
	if t >= secs:
		for s in samples:
			print("  %3d초 · 노드 %4d · 지금 %d · 최고 %d · 처치 %d · fps %d" % s)
		print("유령 몬스터(싸우는데 안 보임) 누적 %.2f초 · 끝 time_scale %.2f" % [ghost, Engine.time_scale])
		IdleState.clear_save()
		get_tree().quit()

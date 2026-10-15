extends Node
## 진짜 행복 화면을 찍는다.
##   SHOT_MODE=intro  - 첫 실행 문장 장을 띄우고, 화면을 누르면 넘어가는지 확인한 뒤 찍는다
##   SHOT_MODE=fight  - 싸우는 장면 (SHOT_JOB, SHOT_STAGE, SHOT_WAIT 초 뒤)
##   SHOT_TAB=char|gear|stage - 창
func _ready() -> void:
	var mode := OS.get_environment("SHOT_MODE")
	IdleState.clear_save()
	IdleState.reset()
	if mode != "intro":
		IdleState.level = int(OS.get_environment("SHOT_LV")) if OS.get_environment("SHOT_LV") != "" else 30
		IdleState.job = OS.get_environment("SHOT_JOB") if OS.get_environment("SHOT_JOB") != "" else "mage"
		IdleState.coins = 3456
		var st := int(OS.get_environment("SHOT_STAGE")) if OS.get_environment("SHOT_STAGE") != "" else 13
		IdleState.stage = st
		IdleState.best = st + 4
		IdleState.seen_intro = true
		IdleState.gear["hat"] = [2, 5]
		IdleState.save(int(Time.get_unix_time_from_system()))
	var g = load("res://scenes/idle/IdleGame.tscn").instantiate()
	add_child(g)
	var out := OS.get_environment("SHOT_OUT")
	if mode == "intro":
		await get_tree().create_timer(1.0).timeout
		var before: String = g._say_lbl.text
		_click(Vector2(640, 360))
		await get_tree().create_timer(0.6).timeout
		var after: String = g._say_lbl.text
		print("SAY_ADVANCE: ", before, " -> ", after, " ok=", before != after)
		get_viewport().get_texture().get_image().save_png(out)
		for i in 6:
			_click(Vector2(640, 360))
			await get_tree().create_timer(0.5).timeout
		print("SAY_DONE: ", not g._say_layer.visible)
		IdleState.clear_save()
		get_tree().quit()
		return
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 4.0
	var tab := OS.get_environment("SHOT_TAB")
	await get_tree().create_timer(wait).timeout
	if OS.get_environment("SHOT_AUTO") != "":
		g._on_auto()
		await get_tree().create_timer(0.3).timeout
	if tab != "":
		g._open_tab(tab)
		await get_tree().create_timer(0.6).timeout
	var series := int(OS.get_environment("SHOT_SERIES")) if OS.get_environment("SHOT_SERIES") != "" else 0
	if series > 0:
		for i in series:
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % i))
			await get_tree().create_timer(0.12).timeout
	else:
		get_viewport().get_texture().get_image().save_png(out)
	IdleState.clear_save()
	get_tree().quit()


func _click(p: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)

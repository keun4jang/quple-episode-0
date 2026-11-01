extends Node
## 처음 안내를 끝까지 따라가 보며 단계마다 화면을 찍는다. 안내가 가리키는 단추를 그대로 누른다.
## TUT_OUT=폴더 (기본 /tmp/shots/tut). headless 에서는 찍지 않고 흐름만 따라간다.


## 화면 그림을 저장한다. 그림이 없으면(headless) 건너뛴다 - 끊기지 않고 끝까지 가게.
func _snap(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)


func _ready() -> void:
	LaneState.save_path = LaneState.TEST_SAVE_PATH  # 진짜 저장(user://lane.cfg)을 건드리지 않는다
	LaneState.clear_save()
	LaneState.reset()
	LaneState.migrated = true
	LaneState.daily_day = int(Time.get_unix_time_from_system()) / 86400 + 1
	LaneState.save()
	var out := OS.get_environment("TUT_OUT") if OS.get_environment("TUT_OUT") != "" else "/tmp/shots/tut"
	var g = load("res://scenes/lane/LaneGame.tscn").instantiate()
	add_child(g)
	var shot := 0
	var guard := 0
	while LaneState.tut != 99 and guard < 120:
		guard += 1
		await get_tree().create_timer(1.0).timeout
		var t = g._tut
		# 캡슐 연출이 떠 있으면 눌러서 넘긴다 (사람처럼)
		var cap = null
		for c in g.get_children():
			if c is LaneGacha:
				cap = c
		if cap != null:
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			cap._gui_input(ev)
			continue
		if t.visible:
			_snap("%s/tut_%02d.png" % [out, shot])
			print("단계 %02d (tut=%d): %s" % [shot, LaneState.tut, t._text.text])
			shot += 1
			if t._tap_any:
				t._advance()
			elif t._target != null and is_instance_valid(t._target) and t._target is BaseButton:
				(t._target as BaseButton).pressed.emit()
			else:
				print("  ! 가리킬 단추가 없다 - 넘김")
				t._advance()
		elif g.mode == "battle" and LaneState.tut == 2 and not g._ended:
			LaneState.speed_lv = 1
			g.battle.auto = true
		elif g._result != null and g.mode == "battle" and LaneState.tut != 2:
			pass
	_snap("%s/tut_end.png" % out)
	print("안내 끝: tut=%d · 단계 %d · 깬 곳 %d · 친구 %d" % [LaneState.tut, shot, LaneState.cleared, LaneState.owned_count()])
	LaneState.clear_save()
	get_tree().quit()

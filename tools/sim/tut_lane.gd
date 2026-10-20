extends Node
## 처음 안내를 끝까지 따라가 보며 단계마다 화면을 찍는다. 안내가 가리키는 단추를 그대로 누른다.
## TUT_OUT=폴더 (기본 /tmp/shots/tut)
func _ready() -> void:
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
			get_viewport().get_texture().get_image().save_png("%s/tut_%02d.png" % [out, shot])
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
			LaneState.speed2 = true
			g.battle.auto = true
		elif g._result != null and g.mode == "battle" and LaneState.tut != 2:
			pass
	get_viewport().get_texture().get_image().save_png("%s/tut_end.png" % out)
	print("안내 끝: tut=%d · 단계 %d · 깬 곳 %d · 친구 %d" % [LaneState.tut, shot, LaneState.cleared, LaneState.owned_count()])
	LaneState.clear_save()
	get_tree().quit()

extends Node
## 화면을 통째로 찍어 둔다. 디자인 리뷰를 부르기 전에 쓴다.
##
##     tools/shots/capture-all.sh
##
## 눈으로 봐야 아는 문제(화풍이 깨진다, 색이 따로 논다, 겹쳐서 안 읽힌다)는
## 코드를 읽어서는 안 나온다. 화면을 실제로 찍어 놓고 봐야 나온다.
## QUPLE_TARGET 으로 무엇을 찍을지, QUPLE_SHOT 으로 어디에 저장할지 고른다.
func _ready() -> void:
	var t := OS.get_environment("QUPLE_TARGET")
	TravelState.reset()
	Episode0State.reset()
	await get_tree().process_frame
	match t:
		"hub", "album", "souvenir":
			# 여행 몇 번 다녀온 상태로 만들어야 화면이 비지 않는다
			# 여행을 다녀온 척 만든다. 시간을 뒤로 당겨 도착시킨 뒤 수거한다.
			for d: String in ["seoul", "busan", "jeju"]:
				if TravelState.start_trip(d):
					TravelState.trip["arrive_at"] = 0
					TravelState.collect_arrival()
			await get_tree().process_frame
	# 여행 중 화면은 실제로 떠나 있어야 나온다. 다녀온 기록을 만든 뒤
	# 한 번 더 보내고 도착 시각을 미래로 둔다.
	if t == "traveling":
		for d: String in ["seoul", "busan"]:
			if TravelState.start_trip(d):
				TravelState.trip["arrive_at"] = 0
				TravelState.collect_arrival()
		if TravelState.start_trip("jeju"):
			TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) + 8000
		print("TRAVELING? ", TravelState.is_traveling(), " ", TravelState.trip.get("dest_id",""))
		await get_tree().process_frame
	# 돌아온 직후 화면. 사진과 일기를 받는 자리라 제일 붐빈다.
	if t == "arrived":
		if TravelState.start_trip("seoul"):
			TravelState.trip["arrive_at"] = 0
		await get_tree().process_frame
	if t == "menu":
		add_child(load("res://scenes/menu/MainMenu3D.tscn").instantiate())
	var path: String = {
		"hub": "res://scenes/travel/TravelHub.tscn",
		"traveling": "res://scenes/travel/TravelHub.tscn",
		"arrived": "res://scenes/travel/TravelHub.tscn",
		"souvenir": "res://scenes/travel/SouvenirRoom3D.tscn",
		"lobby": "res://scenes/maps/CompanyLobby3D.tscn",
		"office": "res://scenes/maps/Office3D.tscn",
		"hallway": "res://scenes/maps/BossDoorHallway3D.tscn",
		"front": "res://scenes/maps/CompanyFront3D.tscn",
	}.get(t, "")
	if path != "":
		add_child(load(path).instantiate())
	# 돌아온 순간에는 연출이 먼저 흐른다. 그게 끝난 화면을 찍어야 한다.
	await get_tree().create_timer(9.0 if t == "arrived" else 2.4).timeout
	if t == "settings":
		add_child(load("res://scenes/maps/Office3D.tscn").instantiate())
		await get_tree().create_timer(1.6).timeout
		var sv: Node = get_tree().get_first_node_in_group("settings_ui")
		if sv == null:
			sv = load("res://scenes/ui/SettingsUI.tscn").instantiate()
			get_tree().current_scene.add_child(sv)
			await get_tree().process_frame
		sv.open()
		await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("QUPLE_SHOT"))
	print("SHOT_SAVED ", t)
	get_tree().quit()

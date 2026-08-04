extends Node
func _ready() -> void:
	SaveManager.clear_save()
	var mode := OS.get_environment("HUB_MODE")
	if mode == "traveling":
		TravelState.start_trip("paris")
	elif mode == "arrived":
		TravelState.start_trip("moon")
		TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	elif mode == "souvenir":
		TravelState.start_trip("seoul")
		TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
	elif mode == "album":
		for d in ["seoul", "paris", "moon"]:
			TravelState.start_trip(d)
			TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
			TravelState.collect_arrival()
	var hub = load("res://scenes/travel/TravelHub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	if mode == "souvenir":
		hub._show_souvenir(TravelState.collect_arrival())
	elif mode == "album":
		hub._show_album()
	await get_tree().create_timer(0.9).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	print("SHOT_SAVED ", mode)
	get_tree().quit()

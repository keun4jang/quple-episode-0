extends Node
## 0편 옆맵을 실제로 걸어서 진행시켜 본다.
var shots := 0
var map: Node

func _ready() -> void:
	Episode0State.reset()
	TravelState.reset()
	await get_tree().process_frame
	for step in [
		{"scene": "res://scenes/side/Front.tscn", "name": "회사앞", "walk": 2.6},
		{"scene": "res://scenes/side/Lobby.tscn", "name": "로비", "walk": 2.0},
		{"scene": "res://scenes/side/Office.tscn", "name": "사무실", "walk": 2.4},
		{"scene": "res://scenes/side/Hallway.tscn", "name": "복도", "walk": 3.0},
	]:
		if map: map.queue_free(); await get_tree().process_frame
		map = load(step["scene"]).instantiate()
		add_child(map)
		await get_tree().create_timer(1.4).timeout
		await shot(step["name"] + "_들어섬")
		Input.action_press("move_right")
		await get_tree().create_timer(float(step["walk"])).timeout
		Input.action_release("move_right")
		await get_tree().create_timer(0.5).timeout
		await shot(step["name"] + "_걸어감")
		print("  %s  x=%.0f  안내='%s'" % [step["name"], map.walker.global_position.x, map._prompt.text])
	get_tree().quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/side0/%d-%s.png" % [shots, name])
	shots += 1

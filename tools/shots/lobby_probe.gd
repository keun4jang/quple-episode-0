extends Node
## 로비를 걸어서 엘리베이터까지 타 본다. 2층이 그림 안에 제대로 앉는지 본다.
var map: Node
var n := 0
func _ready() -> void:
	Episode0State.reset(); await get_tree().process_frame
	map = load("res://scenes/side/Lobby.tscn").instantiate()
	add_child(map)
	await get_tree().create_timer(1.4).timeout
	await shot("1층")
	map.walker.global_position = Vector2(1500, 840)
	await get_tree().create_timer(0.6).timeout
	await shot("반납함")
	# 엘리베이터로 2층
	map.walker.global_position = Vector2(2260, 840)
	await get_tree().create_timer(0.8).timeout
	Input.action_press("move_up")
	await get_tree().create_timer(3.0).timeout
	Input.action_release("move_up")
	await get_tree().create_timer(0.6).timeout
	print("  2층 y=%.0f" % map.walker.global_position.y)
	await shot("2층")
	get_tree().quit()
func shot(s: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/side0/L%d-%s.png" % [n, s]); n += 1

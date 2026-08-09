extends Node
const OUT := "/tmp/claude-0/-home-user-quple-episode-0/ae13eff1-cbd8-51c3-a13c-d76fdf4ec1ec/scratchpad/shot/"
var place: Node

func _ready() -> void:
	place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(place)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _snap("h1-처음.png")
	# 위로 걸어 집 앞까지
	await _walk(Vector2(0, -1), 2.2)
	await _snap("h2-집앞.png")
	# 왼쪽 감나무 뒤로
	await _walk(Vector2(-1, 0.4), 1.8)
	await _snap("h3-감나무.png")
	# 확대해 보기
	place.cam._nudge(1)
	await get_tree().create_timer(0.5).timeout
	await _snap("h4-확대.png")
	place.cam._nudge(-1); place.cam._nudge(-1)
	await get_tree().create_timer(0.5).timeout
	await _snap("h5-축소.png")
	get_tree().quit()

func _walk(dir: Vector2, secs: float) -> void:
	var t := 0.0
	while t < secs:
		place.walker.set_input(dir)
		await get_tree().process_frame
		t += get_process_delta_time()
	place.walker.set_input(Vector2.ZERO)
	await get_tree().create_timer(0.3).timeout

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name)

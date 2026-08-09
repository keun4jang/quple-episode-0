extends Node
const OUT := "/tmp/claude-0/-home-user-quple-episode-0/ae13eff1-cbd8-51c3-a13c-d76fdf4ec1ec/scratchpad/shot/"
var place: Node
func _ready() -> void:
	JourneyState.reset()
	place = preload("res://scenes/journey/Gwaeleung.tscn").instantiate()
	add_child(place)
	await get_tree().create_timer(0.5).timeout
	place.cam._nudge(-1)
	await get_tree().create_timer(0.5).timeout
	await _snap("g1-마을.png")
	await _walk(Vector2(0,-1), 2.4)
	await _snap("g2-바다.png")
	# 갈매기에게 말 걸기
	place.walker.global_position = place.world_of(Vector2i(20, 8))
	await get_tree().create_timer(0.4).timeout
	place.talk_to_near()
	await get_tree().create_timer(1.4).timeout
	await _snap("g3-대화.png")
	place.say.advance(); place.say.advance(); place.say.advance()
	await get_tree().create_timer(0.4).timeout
	# 배낭
	place.hud.toggle_bag()
	await get_tree().create_timer(0.4).timeout
	await _snap("g4-배낭.png")
	place.hud.toggle_bag()
	# 밤
	JourneyState.minutes = 20*60
	place.walker.global_position = place.world_of(Vector2i(20, 13))
	await get_tree().create_timer(0.8).timeout
	await _snap("g5-밤.png")
	get_tree().quit()
func _walk(dir: Vector2, secs: float) -> void:
	var t := 0.0
	while t < secs:
		place.walker.set_input(dir); await get_tree().process_frame
		t += get_process_delta_time()
	place.walker.set_input(Vector2.ZERO)
	await get_tree().create_timer(0.3).timeout
func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n)

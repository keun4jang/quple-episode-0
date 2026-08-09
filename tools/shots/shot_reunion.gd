extends Node
const OUT := "/tmp/claude-0/-home-user-quple-episode-0/ae13eff1-cbd8-51c3-a13c-d76fdf4ec1ec/scratchpad/shot/"
var place: Node

func _ready() -> void:
	JourneyState.reset()
	# ① 쿼릉에서 처음 만난다
	await _load("res://scenes/journey/Gwaeleung.tscn")
	place.walker.global_position = place.world_of(Vector2i(28, 14))
	await get_tree().create_timer(0.4).timeout
	place.talk_to_near()
	await get_tree().create_timer(1.6).timeout
	await _snap("r1-첫만남.png")
	while place.say.is_busy(): place.say.advance(); await get_tree().process_frame

	# ② 정류장에서 떠난다
	place.walker.global_position = place.world_of(Vector2i(40, 13))
	await get_tree().create_timer(0.5).timeout
	place.board.open(place.place_name())
	await get_tree().create_timer(0.5).timeout
	await _snap("r2-떠나기.png")
	place.board.close()
	JourneyState.move_wanderer()
	place.queue_free(); await get_tree().process_frame

	# ③ 쿼주에서 다시 만난다
	await _load("res://scenes/journey/Gwaeju.tscn")
	place.cam._nudge(-1)
	await get_tree().create_timer(0.4).timeout
	await _snap("r3-쿼주.png")
	place.cam._nudge(1)
	place.walker.global_position = place.world_of(Vector2i(26, 13))
	await get_tree().create_timer(0.5).timeout
	place.talk_to_near()
	await get_tree().create_timer(1.5).timeout
	await _snap("r4-재회.png")
	get_tree().quit()

func _load(path: String) -> void:
	place = load(path).instantiate()
	add_child(place)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n)

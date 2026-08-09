extends Node
const OUT := "/tmp/claude-0/-home-user-quple-episode-0/ae13eff1-cbd8-51c3-a13c-d76fdf4ec1ec/scratchpad/shot/"
var place: Node
func _ready() -> void:
	JourneyState.reset()
	place = preload("res://scenes/journey/Gwaeul.tscn").instantiate()
	add_child(place)
	await get_tree().create_timer(0.6).timeout
	place.cam._nudge(-1)
	await get_tree().create_timer(0.5).timeout
	await _snap("e1-쿼카컴퍼니.png")
	place.cam._nudge(1)
	place.walker.global_position = place.world_of(Vector2i(26, 4))
	await get_tree().create_timer(0.5).timeout
	place.talk_to_near()
	await get_tree().create_timer(1.8).timeout
	await _snap("e2-창밖.png")
	while place.say.is_busy(): place.say.advance(); await get_tree().process_frame
	place.queue_free(); await get_tree().process_frame

	# 평상
	JourneyState.give_postcard("seal", "가게 할머니")
	JourneyState.give_postcard("raccoon", "배낭 멘 너구리")
	JourneyState.give_postcard("seagull", "갈매기 소년")
	place = preload("res://scenes/journey/Home.tscn").instantiate()
	add_child(place)
	await get_tree().create_timer(0.5).timeout
	place.walker.global_position = place.world_of(Vector2i(31, 16))
	JourneyState.minutes = 19*60
	await get_tree().create_timer(0.5).timeout
	place.talk_to_near()
	for i in 5:
		await get_tree().create_timer(0.9).timeout
		place.say.advance()
	await get_tree().create_timer(0.6).timeout
	await _snap("e3-평상.png")
	# 배낭 - 쿼플첩
	place.hud.toggle_bag(); place.hud._pick_tab(3)
	await get_tree().create_timer(0.5).timeout
	await _snap("e4-쿼플첩.png")
	get_tree().quit()
func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n)

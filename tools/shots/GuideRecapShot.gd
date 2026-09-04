extends Node

const SHOT_DIR := "SHOT_DIR"

var _out := "/tmp/shots"
var _n := 0


func _ready() -> void:
	if OS.has_environment(SHOT_DIR):
		_out = OS.get_environment(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(_out)
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("  x %s -- no image" % name)
		return
	_n += 1
	var path := "%s/%02d-%s.png" % [_out, _n, name]
	img.save_png(path)
	print("  ok %s  %dx%d" % [path, img.get_width(), img.get_height()])
	# also print the canvas-space visible rect for correlation
	print("  visible_rect=", get_viewport().get_visible_rect().size)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	JourneyState.reset()
	# in-progress tutorial: not finished, partway through STEPS
	SaveManager.set_flag(Guide.FLAG, false)
	SaveManager.set_flag(Guide.STEP_FLAG, 2)
	SaveManager.set_flag(HowToPlay.FLAG, true)
	JourneyState.pick("map")
	JourneyState.pick("camera")

	var p: Place = load("res://scenes/journey/Yunseul.tscn").instantiate()
	add_child(p)
	await _wait(30)
	p.hud._open_guide_recap()
	await _wait(10)
	await _shot("guide-recap-inprogress")

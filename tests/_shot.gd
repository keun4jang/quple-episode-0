extends Node
func _ready() -> void:
	var scn := OS.get_environment("SCN")
	var ps := load(scn) as PackedScene
	if ps == null: print("LOAD FAIL ", scn); get_tree().quit(); return
	add_child(ps.instantiate())
	await get_tree().process_frame
	await get_tree().create_timer(float(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 1.2).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	print("SHOT_SAVED")
	get_tree().quit()

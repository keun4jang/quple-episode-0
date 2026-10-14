extends Node
func _ready() -> void:
	var m = load("res://scenes/menu/MainMenu3D.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()

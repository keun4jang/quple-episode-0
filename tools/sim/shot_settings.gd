extends Node
## 메인 메뉴의 설정 창을 열어 찍는다.
func _ready() -> void:
	var m = load("res://scenes/menu/MainMenu3D.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(2.5).timeout
	var sv = get_tree().get_first_node_in_group("settings_ui")
	if sv:
		sv.open()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()

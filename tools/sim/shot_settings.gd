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
	# SHOT_HINT=new|ok|fail|busy - 업데이트 안내 글자를 그 상태로 띄워 찍는다
	var h := OS.get_environment("SHOT_HINT")
	if sv and h != "":
		match h:
			"new": sv._on_update_ready("0.1.999")
			"ok": sv._on_up_to_date("0.1.999")
			"fail": sv._set_update_state(false, "받지 못했어요
인터넷 연결을 확인해 주세요", sv.HINT_FAIL)
			"busy": sv._on_check_started()
		await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()

extends Node
## 메인 화면을 찍는다. SHOT_SAVE=1 이면 저장이 있는 상태(이어서 하기 + 처음부터 하기), SHOT_CONFIRM=1 이면 처음부터 확인창.
func _ready() -> void:
	if OS.get_environment("SHOT_SAVE") != "":
		IdleState.reset()
		IdleState.level = 19
		IdleState.job = "archer"
		IdleState.stage = 15
		IdleState.best = 16
		IdleState.save()
	var m = load("res://scenes/menu/MainMenu3D.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(3.0).timeout
	if OS.get_environment("SHOT_CONFIRM") != "":
		m._confirm_new_game()
		await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	if OS.get_environment("SHOT_SAVE") != "":
		IdleState.clear_save()
	get_tree().quit()

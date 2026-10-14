extends Node
## 꿈결 키우기 화면을 찍는다. SHOT_TAB=char|gear|stage, SHOT_OUT=경로.
func _ready() -> void:
	IdleState.reset()
	IdleState.level = 12
	IdleState.job = "mage"
	IdleState.coins = 3456
	IdleState.stage = 13
	IdleState.best = 24
	IdleState.seen_intro = true
	IdleState.gear["hat"] = [2, 5]
	IdleState.save(int(Time.get_unix_time_from_system()))
	var g = load("res://scenes/idle/IdleGame.tscn").instantiate()
	add_child(g)
	var tab := OS.get_environment("SHOT_TAB")
	await get_tree().create_timer(4.0).timeout
	if tab != "":
		g._open_tab(tab)
		await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	IdleState.clear_save()
	get_tree().quit()

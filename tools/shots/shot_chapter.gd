extends Node
const OUT := "/tmp/claude-0/-home-user-quple-episode-0/ae13eff1-cbd8-51c3-a13c-d76fdf4ec1ec/scratchpad/shot/"

func _ready() -> void:
	WordDex.reset()
	WordDex.tier = WordData.Tier.TREE
	for id in ["burning_bush", "river"]:
		var sc := preload("res://scenes/word/WordScene.tscn").instantiate()
		sc.scene_id = id
		add_child(sc)
		await get_tree().create_timer(5.4).timeout
		await _snap("c-%s-막힘.png" % id)
		for i in WordData.blank_slots(String(sc.data["word"]), WordData.Tier.TREE):
			var k := _find(sc.spell, String(sc.data["word"])[i].to_upper())
			if k: k.pressed.emit()
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(1.1).timeout
		await _snap("c-%s-풀림.png" % id)
		await get_tree().create_timer(1.0).timeout
		sc.queue_free()
		await get_tree().process_frame
	# 미니게임
	var mg := preload("res://scenes/word/Minigame.tscn").instantiate()
	add_child(mg)
	await get_tree().create_timer(6.0).timeout
	await _snap("c-미니게임.png")
	get_tree().quit()

func _find(n: Node, ch: String) -> Button:
	for c in n.get_children():
		if c is Button and c.text == ch and c.visible and not c.disabled: return c
		var r := _find(c, ch)
		if r: return r
	return null

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name)

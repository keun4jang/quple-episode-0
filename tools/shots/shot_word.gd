extends Node
const OUT := "/tmp/claude-0/-home-user-quple-episode-0/ae13eff1-cbd8-51c3-a13c-d76fdf4ec1ec/scratchpad/shot/"
func _ready() -> void:
	WordDex.reset()
	WordDex.tier = WordData.Tier.TREE
	var sc := preload("res://scenes/word/WordScene.tscn").instantiate()
	add_child(sc)
	await get_tree().create_timer(1.0).timeout
	await _snap("1-대사.png")
	await get_tree().create_timer(4.4).timeout
	await _snap("2-철자놓기.png")
	# 정답을 하나씩 누른다
	for ch in ["F","I","R","E"]:
		var k := _find(sc.spell, ch)
		if k: k.pressed.emit()
		await get_tree().create_timer(0.25).timeout
	await _snap("3-발동.png")
	await get_tree().create_timer(1.2).timeout
	await _snap("4-도감.png")
	await get_tree().create_timer(2.0).timeout
	await _snap("5-끝.png")
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

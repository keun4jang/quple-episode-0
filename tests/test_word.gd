extends Node
## 마법영자문 첫 장면 테스트.
##
## 한 단어 한 장면이 처음부터 끝까지 도는지, 난이도 넷이 모두 풀리는지,
## 배운 단어가 저장에 남는지를 본다.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	_data_tests()
	await _scene_tests()
	_save_tests()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func ok(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("  ✔ %s" % name)
	else:
		_fail += 1
		print("  ✘ %s" % name)


# ── 데이터 ────────────────────────────────────────────────────────────

func _data_tests() -> void:
	print("\n[데이터]")
	var s := WordData.scene_by_id("ice_wall")
	ok(not s.is_empty(), "얼음 벽 장면이 있다")
	ok(s["word"] == "fire", "단어는 fire")
	ok(s.get("before", []).size() > 0 and s.get("after", []).size() > 0,
		"앞뒤 대사가 있다")

	# 표정은 face_cut 이 아는 것만 써야 한다
	var known := true
	for arr in [s.get("before", []), s.get("after", [])]:
		for l in arr:
			if not FaceCut.MOODS.has(String(l[1])):
				known = false
	ok(known, "대사에 쓴 표정이 모두 정의돼 있다")

	# 빈칸
	ok(WordData.blank_slots("fire", WordData.Tier.SEED).size() == 4,
		"씨앗: 자리 전체")
	ok(WordData.blank_slots("fire", WordData.Tier.SPROUT) == [2, 3],
		"새싹: 뒤 절반만 묻는다")
	ok(WordData.blank_slots("fire", WordData.Tier.TREE).size() == 4,
		"나무: 철자 전부")

	# 철자 풀에 정답이 다 있어야 한다
	for t in [WordData.Tier.SPROUT, WordData.Tier.TREE, WordData.Tier.MOUNTAIN]:
		var pool := WordData.letter_pool("fire", t, s.get("extra", []))
		var need := WordData.blank_slots("fire", t)
		var have := true
		for i in need:
			if not pool.has("fire"[i].to_upper()):
				have = false
		ok(have, "%s: 필요한 철자가 풀에 있다" % WordData.TIER_NAMES[t])

	ok(WordData.letter_pool("fire", WordData.Tier.MOUNTAIN, s["extra"]).size()
		> WordData.letter_pool("fire", WordData.Tier.TREE, s["extra"]).size(),
		"산이 나무보다 방해 철자가 많다")

	# 섞기는 늘 같은 순서여야 한다 (아이가 다시 풀 때 자리가 바뀌면 안 된다)
	ok(WordData.letter_pool("fire", WordData.Tier.TREE, s["extra"])
		== WordData.letter_pool("fire", WordData.Tier.TREE, s["extra"]),
		"철자 순서가 매번 같다")


# ── 장면 ──────────────────────────────────────────────────────────────

func _scene_tests() -> void:
	print("\n[장면]")
	for tier in range(WordData.TIER_NAMES.size()):
		WordDex.reset()
		WordDex.tier = tier
		var sc := preload("res://scenes/word/WordScene.tscn").instantiate()
		sc.instant = true
		add_child(sc)
		await get_tree().process_frame
		await get_tree().process_frame

		ok(sc.spell != null and sc.spell.visible,
			"%s: 마법 칸이 떴다" % WordData.TIER_NAMES[tier])
		_solve(sc.spell, tier)
		await get_tree().process_frame

		ok(WordDex.knows("fire"), "%s: 도감에 fire 등록" % WordData.TIER_NAMES[tier])
		ok(WordDex.is_cleared("ice_wall"), "%s: 장면 클리어" % WordData.TIER_NAMES[tier])
		sc.queue_free()
		await get_tree().process_frame

	# 틀린 철자를 눌러도 진행되지 않는다 (벌은 없지만 통과도 없다)
	WordDex.reset()
	WordDex.tier = WordData.Tier.TREE
	var sc2 := preload("res://scenes/word/WordScene.tscn").instantiate()
	sc2.instant = true
	add_child(sc2)
	await get_tree().process_frame
	await get_tree().process_frame
	var wrong := _find_key(sc2.spell, "A")
	if wrong == null:
		wrong = _find_key(sc2.spell, "S")
	if wrong != null:
		wrong.pressed.emit()
	await get_tree().process_frame
	ok(not WordDex.knows("fire"), "틀린 철자로는 안 열린다")
	_solve(sc2.spell, WordData.Tier.TREE)
	await get_tree().process_frame
	ok(WordDex.knows("fire"), "틀린 뒤에도 이어서 풀 수 있다")
	sc2.queue_free()
	await get_tree().process_frame


## 단계에 맞게 정답을 눌러 준다
func _solve(bar: SpellBar, tier: int) -> void:
	if tier == WordData.Tier.SEED:
		for b in _all_buttons(bar):
			if b.text.contains("불"):
				b.pressed.emit()
				return
		return
	for i in WordData.blank_slots("fire", tier):
		var ch := "fire"[i].to_upper()
		var k := _find_key(bar, ch)
		if k != null:
			k.pressed.emit()


func _find_key(bar: SpellBar, ch: String) -> Button:
	for b in _all_buttons(bar):
		if b.text == ch and b.visible and not b.disabled:
			return b
	return null


func _all_buttons(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out


# ── 저장 ──────────────────────────────────────────────────────────────

func _save_tests() -> void:
	print("\n[저장]")
	WordDex.reset()
	WordDex.learn("fire", {"ko": "불", "pron": "파이어", "emoji": "🔥"}, "얼음 벽")
	WordDex.mark_cleared("ice_wall")
	WordDex.set_tier(WordData.Tier.SPROUT)

	var d := WordDex.to_dict()
	WordDex.reset()
	ok(not WordDex.knows("fire"), "초기화하면 비어 있다")
	ok(WordDex.tier == WordData.Tier.TREE, "초기화하면 난이도는 나무")

	WordDex.from_dict(d)
	ok(WordDex.knows("fire"), "복원하면 단어가 돌아온다")
	ok(WordDex.is_cleared("ice_wall"), "복원하면 클리어 기록도 돌아온다")
	ok(WordDex.tier == WordData.Tier.SPROUT, "복원하면 난이도도 돌아온다")
	ok(WordDex.learned["fire"]["note"] == "얼음 벽", "어디서 썼는지 남는다")

	# 같은 단어를 다시 써도 칸이 늘지 않고 횟수만 는다
	WordDex.learn("fire", {"ko": "불"}, "다른 곳")
	ok(WordDex.count() == 1, "같은 단어는 한 칸")
	ok(int(WordDex.learned["fire"]["count"]) == 2, "쓴 횟수는 는다")

	# 예전 저장본(단어 칸이 없는)을 읽어도 죽지 않아야 한다
	WordDex.from_dict({})
	ok(WordDex.count() == 0 and WordDex.tier == WordData.Tier.TREE,
		"예전 저장본도 읽힌다")

	# 실제 파일에 오가는지
	WordDex.learn("fire", {"ko": "불"}, "얼음 벽")
	SaveManager.save_game("res://scenes/word/WordScene.tscn")
	WordDex.reset()
	SaveManager.load_game()
	ok(WordDex.knows("fire"), "저장 파일에 남았다가 돌아온다")

	SaveManager.clear_save()
	ok(WordDex.count() == 0, "기록 초기화가 도감도 지운다")

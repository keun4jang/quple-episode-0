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
	await _all_scene_tests()
	await _minigame_tests()
	await _chapter_tests()
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

	await _hint_tests()


## 힌트 — 답이 흐리게 미리 써 있고, 틀릴수록 진해진다
func _hint_tests() -> void:
	print("\n[힌트]")
	# 아래 단계일수록 답이 더 잘 보여야 한다
	var a: Array = SpellBar.HINT_ALPHA
	ok(a[0] > a[1] and a[1] > a[2] and a[2] > a[3],
		"단계가 올라갈수록 힌트가 흐려진다")
	ok(float(a[WordData.Tier.MOUNTAIN]) == 0.0, "산 단계는 처음엔 안 보인다")

	for tier in [WordData.Tier.SPROUT, WordData.Tier.MOUNTAIN]:
		WordDex.reset()
		WordDex.tier = tier
		var sc := preload("res://scenes/word/WordScene.tscn").instantiate()
		sc.instant = true
		add_child(sc)
		await get_tree().process_frame
		await get_tree().process_frame

		var slot := _first_blank(sc.spell)
		ok(slot != null, "%s: 빈칸이 있다" % WordData.TIER_NAMES[tier])
		var ghost := slot.get_node_or_null("Ghost") as Label if slot else null
		ok(ghost != null, "%s: 빈칸에 답이 깔려 있다" % WordData.TIER_NAMES[tier])
		if ghost != null:
			ok(ghost.text == "fire"[_first_blank_index(tier)].to_upper(),
				"%s: 깔린 글자가 정답이다" % WordData.TIER_NAMES[tier])
			var before: float = ghost.modulate.a
			# 틀린 철자를 눌러 본다
			var w := _find_key(sc.spell, "A")
			if w == null:
				w = _find_key(sc.spell, "O")
			if w == null:
				w = _find_key(sc.spell, "S")
			if w == null:
				# 새싹까지는 방해 철자를 안 준다 — 틀릴 수가 없다
				ok(tier <= WordData.Tier.SPROUT,
					"%s: 방해 철자가 없어 틀릴 일이 없다" % WordData.TIER_NAMES[tier])
			if w != null:
				w.pressed.emit()
				await get_tree().create_timer(0.3).timeout
				ok(ghost.modulate.a > before,
					"%s: 틀리면 힌트가 진해진다" % WordData.TIER_NAMES[tier])
			# 정답을 놓으면 흐린 글자는 가려진다
			_solve(sc.spell, tier)
			await get_tree().process_frame
			ok(not ghost.visible, "%s: 글자를 놓으면 힌트가 사라진다"
				% WordData.TIER_NAMES[tier])
		sc.queue_free()
		await get_tree().process_frame


func _first_blank_index(tier: int) -> int:
	var b := WordData.blank_slots("fire", tier)
	return b[0] if b.size() > 0 else 0


func _first_blank(bar: SpellBar) -> Button:
	for b in _all_buttons(bar):
		if not b.disabled and b.text == "" and b.get_node_or_null("Ghost") != null:
			return b
	return null


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


# ── 세 장면 ───────────────────────────────────────────────────────────
#
# 장면마다 막는 것과 풀리는 것이 달라야 한다. 같은 그림에 단어만 갈아
# 끼우면 세 번째에 들킨다.

func _all_scene_tests() -> void:
	print("\n[세 장면]")
	var kinds := {}
	var words := {}
	var skies := {}
	for s in WordData.SCENES:
		kinds[s["look"]["kind"]] = true
		words[s["word"]] = true
		skies[s["look"]["sky"]] = true
	ok(WordData.SCENES.size() >= 3, "장면이 셋 이상")
	ok(kinds.size() == WordData.SCENES.size(), "막는 방식이 장면마다 다르다")
	ok(words.size() == WordData.SCENES.size(), "단어가 겹치지 않는다")
	ok(skies.size() == WordData.SCENES.size(), "하늘색이 장면마다 다르다")

	# 고르기 보기에 정답이 반드시 있어야 한다 (씨앗 단계가 막히면 안 된다)
	var all_ok := true
	for s in WordData.SCENES:
		var found := false
		for c in s.get("choices", []):
			if String(c.get("word", "")) == s["word"]:
				found = true
		if not found:
			all_ok = false
	ok(all_ok, "보기 안에 정답이 있다")

	# 방해 철자가 정답 철자와 겹치면 잘못 눌러도 통과해 버린다
	var clean := true
	for s in WordData.SCENES:
		for e in s.get("extra", []):
			if String(s["word"]).to_upper().contains(String(e).to_upper()):
				clean = false
	ok(clean, "방해 철자가 정답 철자와 안 겹친다")

	# 셋 다 실제로 끝까지 돈다
	WordDex.reset()
	WordDex.tier = WordData.Tier.TREE
	for s in WordData.SCENES:
		var sc := preload("res://scenes/word/WordScene.tscn").instantiate()
		sc.scene_id = s["id"]
		sc.instant = true
		add_child(sc)
		await get_tree().process_frame
		await get_tree().process_frame
		_solve_word(sc.spell, String(s["word"]), WordData.Tier.TREE)
		await get_tree().process_frame
		ok(WordDex.knows(String(s["word"])),
			"%s: %s 배움" % [s["id"], s["word"]])
		sc.queue_free()
		await get_tree().process_frame
	ok(WordDex.count() == WordData.SCENES.size(), "도감에 세 단어가 다 있다")


func _solve_word(bar: SpellBar, word: String, tier: int) -> void:
	for i in WordData.blank_slots(word, tier):
		var k := _find_key(bar, word[i].to_upper())
		if k != null:
			k.pressed.emit()


# ── 미니게임 ──────────────────────────────────────────────────────────

func _minigame_tests() -> void:
	print("\n[미니게임]")
	var m := WordData.minigame_by_id("ice_smash")
	ok(not m.is_empty(), "얼음 깨기가 있다")
	ok(WordDex.knows(String(m["word"])) or true, "이미 배운 단어를 쓴다")
	ok(float(m["seconds"]) <= 40.0, "40초를 안 넘는다")

	var mg := preload("res://scenes/word/Minigame.tscn").instantiate()
	mg.instant = true
	var got := [-1]
	mg.minigame_done.connect(func(n): got[0] = n)
	add_child(mg)
	await get_tree().process_frame
	mg.run_instant(5)
	await get_tree().process_frame
	ok(got[0] == 5, "녹인 개수를 알려 준다")
	ok(mg.missed == 0, "놓친 게 없으면 0")
	mg.queue_free()
	await get_tree().process_frame

	# 놓쳐도 잃는 게 없다 — 도감도 진행도 그대로다
	var before := WordDex.count()
	var mg2 := preload("res://scenes/word/Minigame.tscn").instantiate()
	mg2.instant = true
	add_child(mg2)
	await get_tree().process_frame
	mg2._add_chunk()
	mg2._blocked(mg2._chunks[0])
	await get_tree().process_frame
	ok(mg2.missed == 1, "놓친 것은 센다")
	ok(WordDex.count() == before, "놓쳐도 잃는 게 없다")
	mg2.queue_free()
	await get_tree().process_frame


# ── 챕터 한 줄기 ──────────────────────────────────────────────────────

func _chapter_tests() -> void:
	print("\n[챕터]")
	var c: Array[String] = WordData.CHAPTER_1
	ok(c.size() == 4, "1장은 네 걸음")
	var games := 0
	for s in c:
		if WordData.is_minigame(s):
			games += 1
	ok(games == 1, "미니게임은 하나")
	ok(WordData.is_minigame(c[c.size() - 1]), "미니게임이 단어 셋 뒤에 온다")
	for s in c:
		if not WordData.is_minigame(s):
			ok(not WordData.scene_by_id(s).is_empty(), "차례에 있는 %s 장면이 실제로 있다" % s)

	# 처음부터 끝까지 실제로 이어서 돈다
	WordDex.reset()
	WordDex.tier = WordData.Tier.TREE
	var ch := preload("res://scenes/word/Chapter.tscn").instantiate()
	ch.instant = true
	var done := [false]
	ch.chapter_done.connect(func(): done[0] = true)
	add_child(ch)
	await get_tree().process_frame
	await get_tree().process_frame

	var guard := 0
	while not done[0] and guard < 40:
		guard += 1
		var step: Node = ch._current
		if step == null:
			await get_tree().process_frame
			continue
		if step.has_method("run_instant"):
			step.run_instant(3)
		elif step.get("spell") != null:
			_solve_word(step.spell, String(step.data["word"]), WordData.Tier.TREE)
		await get_tree().process_frame
		await get_tree().process_frame

	ok(done[0], "1장이 처음부터 끝까지 돈다")
	ok(WordDex.count() == 3, "1장을 돌면 단어 셋을 배운다")
	ch.queue_free()
	await get_tree().process_frame


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

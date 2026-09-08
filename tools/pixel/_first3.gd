extends Node
## 처음 켜서 3분. **화면에 뜨는 것을 순서대로 그대로 받아 적는다.**
##
## 판단하지 않는다. 몇 초에 무엇이 떴는지만 남긴다 - 조작 설명이 몇
## 초를 먹는지, 왜 떠나는지가 언제 나오는지, 처음 마음이 움직일 만한
## 것이 몇 초에 오는지를 눈이 아니라 숫자로 보려는 것이다.

var _t := 0.0
var _seen := {}
var _log: Array = []

func note(kind: String, text: String) -> void:
	var key := "%s|%s" % [kind, text]
	if _seen.has(key) or text.strip_edges() == "":
		return
	_seen[key] = true
	_log.append([_t, kind, text])
	print("  %6.1f초  [%s] %s" % [_t, kind, text.replace("\n", " / ")])


func _find(cls: String) -> Node:
	return _first(get_tree().root, cls)

func _first(n: Node, cls: String) -> Node:
	if n.get_class() == cls or (n.get_script() != null \
			and String(n.get_script().resource_path).get_file().get_basename() == cls):
		return n
	for c in n.get_children():
		var r := _first(c, cls)
		if r != null:
			return r
	return null


## 화면에 실제로 보이는 Label 을 다 훑는다.
func _labels(n: Node, out: Array) -> void:
	if n is Label:
		var l := n as Label
		if l.is_visible_in_tree() and l.modulate.a > 0.05 \
				and l.text.strip_edges() != "":
			out.append(l.text)
	elif n is Button:
		var b := n as Button
		if b.is_visible_in_tree() and b.modulate.a > 0.05 \
				and b.text.strip_edges() != "":
			out.append("[버튼] " + b.text)
	for c in n.get_children():
		_labels(c, out)


func _ready() -> void:
	SaveManager.clear_save()
	JourneyState.reset()
	print("=== 처음 3분 - 화면에 뜨는 것 그대로 ===\n")

	# ── 1) 인트로 (메인화면에서 "새 여행" 을 누른 다음) ──────────────
	var intro = load("res://scenes/menu/IntroSlides.tscn").instantiate()
	add_child(intro)
	var taps := 0
	while taps < 4 and _t < 60.0:
		await get_tree().process_frame
		_t += get_process_delta_time()
		_sweep()
		# 한 장에 3.5초씩 읽고 넘긴다 (사람 속도)
		if _t > 3.5 * float(taps + 1):
			taps += 1
			if taps < 4:
				intro.call("_next")
	note("장면", "-- 인트로 끝, 회사(잿마루)로 --")
	intro.queue_free()
	await get_tree().process_frame

	# ── 2) 프롤로그 ────────────────────────────────────────────────
	JourneyState.here = "잿마루"
	var p: Place = load("res://scenes/journey/Jaenmaru.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	var last_goal := ""
	var card_at := -1.0
	while _t < 600.0:
		await get_tree().process_frame
		_t += get_process_delta_time()
		_sweep()
		var g: Dictionary = p.current_goal()
		var gl := String(g.get("label", ""))
		if gl != last_goal:
			last_goal = gl
			note("할 일", gl)
			if String(g.get("kind", "")) == "depart":
				note("장면", "-- 여기서 첫 여행지를 고른다 --")
				break
		# 화면 보는 법 판은 4초 보고 닫는다
		var card = get_tree().get_first_node_in_group("how_to_play")
		if card != null:
			if card_at < 0.0:
				card_at = _t
			elif _t - card_at > 4.0 and card.has_method("close"):
				card.call("close")
			continue
		# 대사가 흐르는 중이면 읽고 넘긴다
		if p.say != null and p.say.is_busy():
			if fmod(_t, 1.2) < 0.02:
				p.say.advance()
			continue
		# 화살표대로 간다
		if gl != "" and String(g.get("kind", "")) != "depart":
			var at: Vector2 = p.goal_world(g)
			if at != Vector2.INF and not p.is_walking_to() \
					and p.walker.global_position.distance_to(at) > Place.TALK_RANGE:
				p.walk_to(at)
		var k: String = p.hud.action_kind() if p.hud != null else ""
		if k != "" and k != "enter" and k != "depart" and not p.is_walking_to():
			p._on_action()

	print("\n=== %.0f초 만에 회사를 나선다 · 뜬 것 %d줄 ===" % [_t, _log.size()])
	get_tree().quit()


func _sweep() -> void:
	var out: Array = []
	_labels(get_tree().root, out)
	for s in out:
		note("글", String(s))

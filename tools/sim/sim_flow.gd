extends Node
## **진행 흐름 시뮬레이션** - 한 판을 처음부터 끝까지 장(章) 순서대로 따라가며
## "다음에 뭘 하지?" 가 막히는 곳이 있나 본다. 실제 씬을 띄운다.
##
##     xvfb-run -a godot --headless --path . res://tools/sim/SimFlow.tscn
##
## 장마다:
##   - 메인 퀘스트가 이 구역을 가리키나, 이 구역이 열려 있나
##   - 마을: 붉은 틈(우두머리의 길)이 있고 걸어서 닿나, 화살표가 무엇을 짚나
##   - 우두머리의 길: 방 문이 졸개 전엔 잠기고 다 잡으면 열리나, 화살표가 따라가나
##   - 우두머리 방: 우두머리가 서 있고 화살표가 그것을 짚나, 쓰러뜨리면 승리 판이 뜨나
##   - 승리 판의 "다음 구역" 이 실제 씬인가
## 끝: 잿마루 타워의 대마왕.

const VILLAGE_SCENE := {
	"윤슬": "Yunseul", "볕뉘": "Byeotnwi", "가풀재": "Gapuljae", "하늬섬": "Hanuiseom",
	"굽이나루": "Gubinaru", "방울못": "Bangulmot", "갈밭머리": "Galbatmeori",
	"솔은재": "Soleunjae", "꽃눈벌": "Kkonnunbeol",
}
var issues: Array = []


func _ready() -> void:
	SaveManager.set_flag(Guide.FLAG, true)
	SaveManager.set_flag(HowToPlay.FLAG, true)
	Loop.welcome_on = false
	JourneyState.reset()
	Loop.reset()
	Battle.reset()
	Field.reset()
	await _prologue()
	JourneyState.mark_quest("잿마루:정류장")
	for i in Quests.ORDER.size():
		var v := String(Quests.ORDER[i])
		if Battle.boss_of(v) == "":
			continue
		await _chapter(i, v)
		if i == 0:
			await _tower_cap_check()
	await _final()
	await _after_ending()
	print("\n==== 문제 %d개 ====" % issues.size())
	for s in issues:
		print("  - ", s)
	get_tree().quit()


func _bad(s: String) -> void:
	issues.append(s)
	print("   [문제] ", s)


func _chapter(i: int, v: String) -> void:
	Battle.level = Battle.boss_lv(v)
	Battle.hp = Battle.hp_max()
	# 시계는 아침에 맞춘다 - 자정은 아래에서 따로 본다.
	JourneyState.minutes = JourneyState.DAY_START
	var m := MainQuest.now()
	print("\n[%d장 %s] 메인: %s / %s" % [i + 1, v, m["head"], m["goal"]])
	if String(m.get("village", "")) != v:
		_bad("%s: 메인 퀘스트가 %s 를 가리킨다" % [v, m.get("village", "")])
	if not Quests.is_unlocked(v):
		_bad("%s: 앞 우두머리를 잡았는데 안 열려 있다" % v)
	var vpath := "res://scenes/journey/%s.tscn" % VILLAGE_SCENE[v]
	JourneyState.here = v
	JourneyState.visited[v] = true
	# ── 마을
	var p: Place = await _open(vpath)
	var gate := {}
	var tgate := {}
	for d in p._gates:
		if String(d.get("gate", "")) == "boss":
			gate = d
		elif String(d.get("gate", "")) == "tower":
			tgate = d
	if gate.is_empty():
		_bad("%s: 붉은 틈(우두머리의 길)이 없다" % v)
	else:
		var s := _secs(p, p.spawn_tile(), Vector2i(gate["tile"]))
		print("   마을: 도착 ~ 붉은 틈 %.1f초" % s)
		if s < 0.0:
			_bad("%s: 도착 자리에서 붉은 틈까지 길이 없다" % v)
	if Loop.tower_open() and tgate.is_empty():
		_bad("%s: 탑이 열렸는데 푸른 틈이 없다" % v)
	if not tgate.is_empty():
		print("   탑: %s · 지금 열린 데 %d층" % [tgate.get("label", ""), Loop.tower_cap()])
		if int(tgate["tower_floor"]) > Loop.tower_cap():
			_bad("%s: 탑 틈이 열린 층(%d) 위로 보낸다 (%d)" % [v, Loop.tower_cap(), int(tgate["tower_floor"])])
	var og := p.open_goals()
	var has_boss_row := false
	for q in og:
		if String(q.get("key", "")) == "우두머리길":
			has_boss_row = true
	if not has_boss_row:
		_bad("%s: 할 일 목록에 우두머리 줄이 없다" % v)
	var cg := p.current_goal()
	print("   마을 화살표: %s (%s) · 남은 마을 할 일 %d" % [cg.get("label", "-"), cg.get("kind", "-"), og.size() - 1])
	if cg.is_empty() or p.goal_world(cg) == Vector2.INF:
		_bad("%s: 마을에서 화살표가 아무것도 안 짚는다" % v)
	# 우두머리 레벨이면 화살표가 붉은 틈부터 짚어야 한다 - 메인 퀘스트와 같은 말.
	if String(cg.get("key", "")) != "우두머리길":
		_bad("%s: LV %d (우두머리 LV %d) 인데 화살표가 붉은 틈이 아니라 %s 를 짚는다" % [
			v, Battle.level, Battle.boss_lv(v), cg.get("label", "-")])
	# 자정 - 하루는 실시간 6분이라 구역 도중에 자주 온다. 잘 곳과 우두머리가 둘 다 있어야.
	JourneyState.minutes = JourneyState.DAY_END
	var ng := p.current_goal()
	var night_row := false
	for q in p.open_goals():
		if String(q.get("kind", "")) in ["sleep", "depart"]:
			night_row = true
	print("   자정 화살표: %s · 잘 곳 줄 %s" % [ng.get("label", "-"), night_row])
	if String(ng.get("key", "")) != "우두머리길":
		_bad("%s: 자정에 우두머리 레벨인데 화살표가 %s 를 짚는다" % [v, ng.get("label", "없음")])
	if not night_row:
		_bad("%s: 자정인데 잘 곳(잠자리·정류장) 줄이 없다" % v)
	JourneyState.minutes = JourneyState.DAY_START
	var exit_tile: Vector2i = Vector2i(gate["tile"]) if not gate.is_empty() else p.spawn_tile()
	await _close(p)
	# ── 우두머리의 길
	JourneyState.exit_scene = vpath
	JourneyState.exit_tile = exit_tile
	var r: Place = await _open(Place.BOSS_ROAD_SCENE)
	var lair_door: Dictionary = r.doors()[1]
	var foes: int = r.foes_left()
	print("   길: %s · 졸개 %d · 들어온 자리 ~ 방 문 %.1f초" % [r.place_name(), foes,
		_secs(r, r.spawn_tile(), Vector2i(lair_door["tile"]))])
	if foes != Battle.ROAD_COUNT:
		_bad("%s 길: 졸개가 %d (기대 %d)" % [v, foes, Battle.ROAD_COUNT])
	if r.door_locked(lair_door) == "":
		_bad("%s 길: 졸개가 있는데 방 문이 열려 있다" % v)
	if String(r.current_goal().get("kind", "")) != "shade" or r.goal_world(r.current_goal()) == Vector2.INF:
		_bad("%s 길: 졸개가 남았는데 화살표가 졸개를 안 짚는다" % v)
	for sh in r._shades.duplicate():
		r.on_shade_down(sh)
	await get_tree().process_frame
	if r.door_locked(lair_door) != "":
		_bad("%s 길: 졸개를 다 잡았는데 방 문이 잠겨 있다" % v)
	var g2 := r.current_goal()
	if String(g2.get("key", "")) != "우두머리방" or r.goal_world(g2) == Vector2.INF:
		_bad("%s 길: 졸개를 다 잡은 뒤 화살표가 방 문을 안 짚는다 (%s)" % [v, g2])
	await _close(r)
	# ── 우두머리 방
	var l: Place = await _open(BossRoad.LAIR_SCENE)
	var boss: Shade = l._boss_shade()
	if boss == null:
		_bad("%s 방: 우두머리가 없다" % v)
		await _close(l)
		return
	var bg := l.current_goal()
	if String(bg.get("kind", "")) != "boss" or l.goal_world(bg) == Vector2.INF:
		_bad("%s 방: 화살표가 우두머리를 안 짚는다 (%s)" % [v, bg])
	var bs := _secs(l, l.spawn_tile(), boss.at_tile)
	print("   방: %s · 들어온 자리 ~ 우두머리 %.1f초 · 호위 %d" % [l.place_name(), bs, l.foes_left() - 1])
	for sh in l._shades.duplicate():
		if sh != boss:
			l.on_shade_down(sh)
	l.on_shade_down(boss)
	if not Battle.boss_down(v):
		_bad("%s 방: 우두머리를 잡았는데 처치가 안 적혔다" % v)
	# 승리 판은 2.2초 뒤에 뜬다.
	await get_tree().create_timer(2.6).timeout
	var bc = l.get_node_or_null("BossClear")
	if bc == null:
		_bad("%s 방: 승리 판이 안 떴다" % v)
	else:
		print("   승리 판: 다음 = %s" % bc.next_title)
		if bc.next_title == "":
			_bad("%s 방: 승리 판에 다음 장이 없다" % v)
	var eg := l.current_goal()
	if String(eg.get("kind", "")) != "exit":
		_bad("%s 방: 우두머리를 잡은 뒤 화살표가 나가는 문을 안 짚는다 (%s)" % [v, eg])
	await _close(l)
	var idx := Quests.ORDER.find(v)
	if idx + 1 < Quests.ORDER.size():
		var nv := String(Quests.ORDER[idx + 1])
		if not ResourceLoader.exists(String(TravelBoard.PLACES[nv][0])):
			_bad("%s: 다음 구역 씬이 없다" % nv)


## 이야기가 연 층 끝에서 계단이 잠기고, 화살표가 나가는 문을 짚고, 다음에 들어오면
## 막힌 층 앞 쉼터부터인가. 같은 날 다시 올라도 층이 빈 채로 열리지 않나.
func _tower_cap_check() -> void:
	var cap := Loop.tower_cap()
	JourneyState.exit_scene = "res://scenes/journey/%s.tscn" % VILLAGE_SCENE["윤슬"]
	JourneyState.exit_tile = Vector2i(10, 10)
	Loop.tower_now = cap
	var t: Place = await _open(Place.TOWER_SCENE)
	var n0: int = t.foes_left()
	for sh in t._shades.duplicate():
		t.on_shade_down(sh)
	await get_tree().process_frame
	var stairs: Dictionary = t.doors()[1]
	var why: String = t.door_locked(stairs)
	var g := t.current_goal()
	print("\n[탑 %d층 = 열린 끝] 몬스터 %d · 계단: %s · 화살표: %s" % [cap, n0, why, g.get("label", "-")])
	if why == "":
		_bad("탑 %d층: 열린 끝인데 계단이 열려 있다" % cap)
	if String(g.get("kind", "")) != "exit":
		_bad("탑 %d층: 열린 끝에서 화살표가 나가는 문을 안 짚는다" % cap)
	await _close(t)
	if Loop.tower_start() > cap:
		_bad("탑: 열린 끝(%d)을 넘은 층(%d)부터 시작한다" % [cap, Loop.tower_start()])
	# 껐다 켜서 같은 층으로 이어하면 - 이번에 오르며 쓴 층이라 비어 있어야 한다 (축복을 또 못 받게).
	var t1: Place = await _open(Place.TOWER_SCENE)
	if t1.foes_left() != 0:
		_bad("탑 %d층: 이어하기로 돌아왔는데 몬스터가 다시 섰다 (%d) - 껐다 켜서 축복을 또 받는다" % [cap, t1.foes_left()])
	await _close(t1)
	# 마을에서 새로 오르면 같은 날이어도 층이 다시 차 있어야 한다.
	Loop.start_climb()
	var t2: Place = await _open(Place.TOWER_SCENE)
	if t2.foes_left() != n0:
		_bad("탑 %d층: 새로 오르는데 몬스터가 %d/%d - 빈 층에서 축복만 받아 간다" % [cap, t2.foes_left(), n0])
	await _close(t2)
	Loop.tower_now = 1


func _final() -> void:
	var m := MainQuest.now()
	print("\n[끝장] 메인: %s / %s" % [m["head"], m["goal"]])
	if int(m["chapter"]) != MainQuest.TOTAL:
		_bad("꽃눈벌 뒤 메인 퀘스트가 10장이 아니다 (%d)" % int(m["chapter"]))
	if not Quests.is_unlocked(Quests.TOWER):
		_bad("꽃눈벌 우두머리를 잡았는데 잿마루 타워가 안 열렸다")
	Battle.level = 50
	JourneyState.minutes = JourneyState.DAY_START
	JourneyState.here = Quests.TOWER
	var tpath := String(TravelBoard.PLACES[Quests.TOWER][0])
	var p: Place = await _open(tpath)
	var gate := {}
	for d in p._gates:
		if String(d.get("gate", "")) == "boss":
			gate = d
		elif String(d.get("gate", "")) == "tower":
			_bad("잿마루 타워 안에 꿈의 탑(푸른 틈)이 있다")
	for sh in p._shades:
		if is_instance_valid(sh) and bool(sh.foe["boss"]):
			_bad("잿마루 타워 한 장에 우두머리(%s)가 서 있다 - 방에 있어야" % sh.shade_kind)
	var cg := p.current_goal()
	print("   타워: 몬스터 %d · 화살표 %s (%s)" % [p._shades.size(), cg.get("label", "-"), cg.get("kind", "-")])
	if gate.is_empty():
		_bad("잿마루 타워에 붉은 틈(야근 계단길)이 없다")
		await _close(p)
		return
	var gs := _secs(p, p.spawn_tile(), Vector2i(gate["tile"]))
	print("   타워: 도착 ~ 붉은 틈 %.1f초" % gs)
	if gs < 0.0:
		_bad("잿마루 타워: 붉은 틈까지 길이 없다")
	if String(cg.get("key", "")) != "우두머리길":
		_bad("잿마루 타워: LV 50 인데 화살표가 붉은 틈이 아니라 %s" % cg.get("label", "없음"))
	await _close(p)
	# 야근 계단길
	JourneyState.exit_scene = tpath
	JourneyState.exit_tile = Vector2i(gate["tile"])
	var r: Place = await _open(Place.BOSS_ROAD_SCENE)
	var lair_door: Dictionary = r.doors()[1]
	print("   길: %s · 졸개 %d · 들어온 자리 ~ 방 문 %.1f초" % [r.place_name(), r.foes_left(),
		_secs(r, r.spawn_tile(), Vector2i(lair_door["tile"]))])
	if r.place_name() != "야근 계단길" or r.foes_left() != Battle.ROAD_COUNT:
		_bad("마지막 장 길이 이상하다: %s · 졸개 %d" % [r.place_name(), r.foes_left()])
	if r.door_locked(lair_door) == "":
		_bad("야근 계단길: 졸개가 있는데 방 문이 열려 있다")
	for sh in r._shades.duplicate():
		r.on_shade_down(sh)
	await get_tree().process_frame
	if r.door_locked(lair_door) != "":
		_bad("야근 계단길: 졸개를 다 잡았는데 방 문이 잠겨 있다")
	await _close(r)
	# 야근 대마왕의 방
	var l: Place = await _open(BossRoad.LAIR_SCENE)
	var boss: Shade = l._boss_shade()
	if boss == null or boss.shade_kind != "night":
		_bad("대마왕의 방에 야근 대마왕이 없다")
		await _close(l)
		return
	var n0: int = l.foes_left()
	boss.foe["hp"] = int(float(boss.foe["hp_max"]) * 0.45)
	await get_tree().process_frame
	await get_tree().process_frame
	var n1: int = l.foes_left()
	print("   방: %s · 몬스터 %d ~ 반쯤 깎으니 %d (추가 업무)" % [l.place_name(), n0, n1])
	if n1 != n0 + 2:
		_bad("대마왕 2단계: 반쯤 깎았는데 졸개가 안 나왔다 (%d ~ %d)" % [n0, n1])
	for sh in l._shades.duplicate():
		if sh != boss:
			l.on_shade_down(sh)
	l.on_shade_down(boss)
	if not JourneyState.quest_done("엔딩:대마왕") or not Battle.boss_down("잿마루"):
		_bad("대마왕을 쓰러뜨렸는데 엔딩이 안 적혔다")
	await get_tree().create_timer(2.6).timeout
	if l.get_node_or_null("BossClear") != null:
		_bad("대마왕 뒤에 승리 판(다음 구역)이 떴다 - 엔딩이 와야 한다")
	await _close(l)


## 처음 켠 사람 - 꿈속 사무실. 화살표가 무언가를 짚고, 정류장까지 걸어갈 길이 있나.
func _prologue() -> void:
	var m := MainQuest.now()
	print("\n[프롤로그] 메인: %s / %s" % [m["head"], m["goal"]])
	if int(m["chapter"]) != 0:
		_bad("새로 시작했는데 메인 퀘스트가 프롤로그가 아니다 (%d장)" % int(m["chapter"]))
	JourneyState.here = "잿마루"
	var p: Place = await _open(String(TravelBoard.PLACES[Quests.TOWER][0]))
	var cg := p.current_goal()
	var s := _secs(p, p.spawn_tile(), p.depart_tile())
	print("   사무실: 몬스터 %d · 화살표 %s (%s) · 도착 ~ 정류장 %.1f초" % [p._shades.size(),
		cg.get("label", "-"), cg.get("kind", "-"), s])
	if not p._shades.is_empty():
		_bad("프롤로그 사무실에 몬스터가 있다")
	if not p._gates.is_empty():
		_bad("프롤로그 사무실에 틈(%d)이 열려 있다" % p._gates.size())
	if cg.is_empty() or p.goal_world(cg) == Vector2.INF:
		_bad("프롤로그: 화살표가 아무것도 안 짚는다")
	if s < 0.0:
		_bad("프롤로그: 정류장까지 걸어갈 길이 없다")
	await _close(p)


## 깨어난 뒤 "오늘도 출근한다" - 윤슬로 돌아와 끝판 뒤 놀이(꿈의 탑). 메인 퀘스트는
## 탑을 말한다 - 화살표와 푸른 틈이 그리 이어지나.
func _after_ending() -> void:
	JourneyState.mark_quest("엔딩:대마왕")
	JourneyState.mark_quest("엔딩:출근")
	var m := MainQuest.now()
	print("\n[끝판 뒤] 메인: %s / %s · 탑 열린 데 %d" % [m["head"], m["goal"], Loop.tower_cap()])
	JourneyState.here = "윤슬"
	JourneyState.minutes = JourneyState.DAY_START
	var p: Place = await _open("res://scenes/journey/%s.tscn" % VILLAGE_SCENE["윤슬"])
	var tgate := {}
	for d in p._gates:
		if String(d.get("gate", "")) == "tower":
			tgate = d
	var cg := p.current_goal()
	print("   윤슬: 푸른 틈 %s · 화살표 %s (%s)" % [tgate.get("label", "없음"), cg.get("label", "-"), cg.get("kind", "-")])
	if tgate.is_empty():
		_bad("끝판 뒤 윤슬에 푸른 틈(탑)이 없다")
	elif _secs(p, p.spawn_tile(), Vector2i(tgate["tile"])) < 0.0:
		_bad("끝판 뒤: 푸른 틈까지 길이 없다")
	if String(cg.get("key", "")) != "꿈의탑":
		_bad("끝판 뒤 메인 퀘스트는 꿈의 탑인데 화살표는 %s 를 짚는다" % cg.get("label", "없음"))
	await _close(p)


func _open(path: String) -> Place:
	var p: Place = load(path).instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	return p


func _close(p: Place) -> void:
	p.queue_free()
	await get_tree().process_frame


func _secs(p: Place, a: Vector2i, b: Vector2i) -> float:
	if not p._walkable(b):
		b = p._nearest_walkable(b)
	if not p._walkable(a):
		a = p._nearest_walkable(a)
	if a.x < 0 or b.x < 0:
		return -1.0
	if a == b:
		return 0.0
	var pts := p._astar.get_id_path(a, b)
	if pts.size() < 2:
		return -1.0
	var d := 0.0
	for i in range(1, pts.size()):
		d += Vector2(pts[i] - pts[i - 1]).length() * Place.TILE
	return d / p.walker.speed

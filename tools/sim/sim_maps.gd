extends Node
## **지도 시뮬레이션** - 모든 마을과 딸린 맵을 띄워 길·거리·몬스터 자리를 잰다.
##
##     xvfb-run -a godot --headless --path . res://tools/sim/SimMaps.tscn
##
## 재는 것:
##   - 도착 자리에서 인연·문·틈·정류장·잠자리·가 볼 자리까지 **실제로 걸을 길이 있나**
##   - 그 길이 몇 초인가 (걷는 빠르기 그대로) - 인연끼리 가장 가까운 거리
##   - 도착하자마자 몬스터 곁인가 (쉬러 온 자리에서 곧장 싸움이 붙으면 안 된다)
##   - 몬스터가 문·인연·틈에 너무 붙어 서 있나

const VILLAGES := {
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
	JourneyState.mark_quest("보스:윤슬")
	for v in VILLAGES:
		JourneyState.here = v
		await _probe("res://scenes/journey/%s.tscn" % VILLAGES[v], v)
		JourneyState.exit_scene = "res://scenes/journey/%s.tscn" % VILLAGES[v]
		JourneyState.exit_tile = Vector2i(10, 10)
		await _probe("res://scenes/journey/interiors/BossRoad.tscn", v + " 길")
		await _probe("res://scenes/journey/interiors/BossLair.tscn", v + " 방")
	Loop.tower_now = 5
	await _probe("res://scenes/journey/interiors/TowerFloor.tscn", "탑 5층")
	# 마지막 장 (0.1.189) - 타워 → 야근 계단길 → 대마왕의 방
	for v in VILLAGES:
		JourneyState.mark_quest("보스:" + String(v))
	JourneyState.here = "잿마루"
	await _probe("res://scenes/journey/Jaenmaru.tscn", "잿마루 타워")
	JourneyState.exit_scene = "res://scenes/journey/Jaenmaru.tscn"
	JourneyState.exit_tile = Vector2i(10, 10)
	await _probe("res://scenes/journey/interiors/BossRoad.tscn", "타워 길")
	await _probe("res://scenes/journey/interiors/BossLair.tscn", "타워 방")
	print("\n==== 문제 %d개 ====" % issues.size())
	for i in issues:
		print("  - ", i)
	get_tree().quit()


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


func _probe(path: String, label: String) -> void:
	var p: Place = load(path).instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	var sp := p.spawn_tile()
	var sz := p.tile_size()
	var targets: Array = []
	for f in p._folk:
		if is_instance_valid(f):
			targets.append(["인연 " + f.who, f.at_tile])
	for d in p._doors:
		targets.append(["문 " + String(d.get("label", "")), Vector2i(d["tile"])])
	for z in p.quest_zones():
		targets.append(["자리 " + String(z[0]), Vector2i(z[1])])
	if p.depart_tile().x >= 0:
		targets.append(["정류장", p.depart_tile()])
	if p.sleep_tile().x >= 0:
		targets.append(["잠자리", p.sleep_tile()])
	var far := 0.0
	var sum := 0.0
	var n := 0
	for t in targets:
		var s := _secs(p, sp, Vector2i(t[1]))
		if s < 0.0:
			issues.append("%s: %s 까지 걸어갈 길이 없다 %s" % [label, t[0], t[1]])
			continue
		far = maxf(far, s)
		sum += s
		n += 1
	# 인연끼리 가장 가까운 거리 (칸)
	var near_pairs: Array = []
	var people: Array = []
	for f in p._folk:
		if is_instance_valid(f) and not f.is_spot:
			people.append(f)
	var nn_sum := 0.0
	for a in people:
		var best := INF
		for b in people:
			if a != b:
				best = minf(best, Vector2(a.at_tile - b.at_tile).length())
		if best < INF:
			nn_sum += best
		if best < 3.0:
			near_pairs.append(a.who)
	var nn_avg := nn_sum / maxf(1.0, float(people.size()))
	# 몬스터
	var at_spawn := 0
	var near_door := 0
	for sh in p._shades:
		if not is_instance_valid(sh):
			continue
		if sh.global_position.distance_to(p.world_of(sp)) < Place.ENGAGE * 1.6:
			at_spawn += 1
		for d in p._doors:
			if sh.global_position.distance_to(d["world"]) < 30.0:
				near_door += 1
	if at_spawn > 0:
		issues.append("%s: 도착 자리 바로 곁에 몬스터 %d" % [label, at_spawn])
	if near_door > 0:
		issues.append("%s: 문 바로 곁에 몬스터 %d" % [label, near_door])
	if not near_pairs.is_empty():
		issues.append("%s: 세 칸 안에 붙어 선 인연 %s" % [label, str(near_pairs)])
	print("%-12s %2dx%2d · 목표 %2d곳 평균 %4.1f초 최장 %4.1f초 · 인연 %d (이웃 평균 %.1f칸) · 몬스터 %d" % [
		label, sz.x, sz.y, n, sum / maxf(1.0, n), far, people.size(), nn_avg, p._shades.size()])
	p.queue_free()
	await get_tree().process_frame

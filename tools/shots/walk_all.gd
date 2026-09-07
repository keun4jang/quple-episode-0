extends Node
## 모든 곳을 실제로 걸어서 훑는다 - 줍기 · 문 · 인연 · 정류장 · 잠자리.
##
## `SimJourney` 는 잿마루·윤슬·볕뉘·고향만, 그것도 몇 자리만 걷는다.
## 여기서는 열 마을과 고향, 실내 여섯까지 **갈 수 있어야 하는 자리를 다**
## 걸어서 확인한다. 인연은 대화 사거리(`Place.TALK_RANGE`) 안에 서면 된
## 것으로 친다 - 그 사람 칸 자체는 막혀 있어 발로 밟을 수 없다.
##
## 소품을 옮기거나 지도를 손본 뒤에 돌린다. **정적 검사로는 안 걸린다** -
## 칸 단위로는 뚫려 있는데 몸이 실제로는 못 지나는 자리를 잡는 것이
## 목적이라, 진짜 길찾기로 걸어 봐야만 나온다.
##
##   godot --headless --path . res://tools/shots/WalkAll.tscn        # 다
##   godot --headless --path . res://tools/shots/WalkAll.tscn -- 2   # 나눠서
##
## 한 번에 다 돌리면 몇 분 걸린다. 1·2·3 으로 나눠 돌릴 수 있다.

var _pass := 0
var _fail := 0
var _bad: Array = []

func ok(c: bool, n: String) -> void:
	if c:
		_pass += 1
	else:
		_fail += 1
		_bad.append(n)
		print("  FAIL ", n)


func _walk(p, goal: Vector2, secs: float, near: float) -> bool:
	p.walk_to(goal)
	var spent := 0.0
	while spent < secs and p.is_walking_to():
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()
	while spent < secs and p.walker.global_position.distance_to(goal) > near * 0.5:
		p.walker.set_input((goal - p.walker.global_position).normalized())
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()
	p.walker.set_input(Vector2.ZERO)
	p.stop_walk_to()
	await get_tree().process_frame
	return p.walker.global_position.distance_to(goal) <= near


func _sweep(name: String, path: String, budget: float) -> void:
	print("\n[", name, "]")
	var p = load(path).instantiate()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	var home: Vector2 = p.walker.global_position

	for pk in p.pickups():
		p.walker.global_position = home
		var t := Vector2i(int(pk[0]), int(pk[1]))
		ok(await _walk(p, p.world_of(t), budget, 24.0),
			"%s: 줍기 %s %s" % [name, pk[2] if pk.size() > 2 else "", t])

	for d in p.doors():
		p.walker.global_position = home
		var dt: Vector2i = d["tile"]
		var got: bool = await _walk(p, p.world_of(dt), budget, 24.0)
		ok(got, "%s: 문 '%s' %s" % [name, d.get("label", ""), dt])
		if got:
			ok(p._can_enter() != null,
				"%s: 문 '%s' 앞에서 들어갈 수 있다" % [name, d.get("label", "")])

	for f in p._folk:
		if not is_instance_valid(f) or String(f.who) == "":
			continue
		p.walker.global_position = home
		# 인연·자리는 그 칸을 밟을 수 없다 - 대화 사거리 안이면 된다.
		ok(await _walk(p, f.global_position, budget, Place.TALK_RANGE),
			"%s: %s '%s' 곁" % [name, "자리" if f.is_spot else "인연", f.who])

	var dep: Vector2i = p.depart_tile()
	if dep.x >= 0:
		p.walker.global_position = home
		ok(await _walk(p, p.world_of(dep), budget, 24.0), "%s: 정류장 %s" % [name, dep])

	var bed: Vector2i = p.sleep_tile()
	if bed.x >= 0:
		p.walker.global_position = home
		ok(await _walk(p, p.world_of(bed), budget, 24.0), "%s: 잠자리 %s" % [name, bed])

	p.queue_free()
	await get_tree().process_frame


const OUT = [
	["잿마루", "res://scenes/journey/Jaenmaru.tscn"],
	["윤슬", "res://scenes/journey/Yunseul.tscn"],
	["볕뉘", "res://scenes/journey/Byeotnwi.tscn"],
	["가풀재", "res://scenes/journey/Gapuljae.tscn"],
	["하늬섬", "res://scenes/journey/Hanuiseom.tscn"],
	["굽이나루", "res://scenes/journey/Gubinaru.tscn"],
	["방울못", "res://scenes/journey/Bangulmot.tscn"],
	["갈밭머리", "res://scenes/journey/Galbatmeori.tscn"],
	["솔은재", "res://scenes/journey/Soleunjae.tscn"],
	["꽃눈벌", "res://scenes/journey/Kkonnunbeol.tscn"],
	["고향", "res://scenes/journey/Home.tscn"],
]

const INSIDE = [
	["가게 안", "res://scenes/journey/interiors/ShopInterior.tscn", "윤슬"],
	["등대 안", "res://scenes/journey/interiors/LighthouseInterior.tscn", "윤슬"],
	["그늘 자리", "res://scenes/journey/interiors/ShadeSpot.tscn", "볕뉘"],
	# 샛길은 **들어온 마을마다 지형이 다르다** (`SidePathInterior.PATHS`).
	# 넷째 칸이 없으면 나가는 문 경로가 윤슬로 남아 늘 첫 번째(굽이나루)
	# 지형만 돌았다 - 솔그늘·밭사잇길이 통째로 안 돌아 봐진 채였다.
	["모래톱 샛길", "res://scenes/journey/interiors/SidePathInterior.tscn",
		"굽이나루", "res://scenes/journey/Gubinaru.tscn"],
	["솔그늘 샛길", "res://scenes/journey/interiors/SidePathInterior.tscn",
		"솔은재", "res://scenes/journey/Soleunjae.tscn"],
	["밭사잇길", "res://scenes/journey/interiors/SidePathInterior.tscn",
		"꽃눈벌", "res://scenes/journey/Kkonnunbeol.tscn"],
	["능 길", "res://scenes/journey/interiors/TombPathInterior.tscn", "솔은재"],
	["모임터", "res://scenes/journey/interiors/GatherGround.tscn", "꽃눈벌"],
]


func _ready() -> void:
	SaveManager.set_flag(HowToPlay.FLAG, true)
	JourneyState.reset()
	JourneyState.pick("map")
	JourneyState.pick("camera")

	var which := "all"
	for a in OS.get_cmdline_user_args():
		which = a

	var from := 0
	var to := OUT.size()
	if which == "1":
		to = 4
	elif which == "2":
		from = 4
		to = 8
	elif which == "3":
		from = 8

	for i in range(from, to):
		await _sweep(String(OUT[i][0]), String(OUT[i][1]), 14.0)

	if which in ["all", "3"]:
		for room in INSIDE:
			JourneyState.here = String(room[2])
			JourneyState.exit_scene = String(room[3]) if room.size() > 3 \
				else "res://scenes/journey/Yunseul.tscn"
			JourneyState.exit_tile = Vector2i(24, 12)
			# 샛길 셋은 아래 끝에서 위 끝까지 굽이도는 긴 길이라 20초쯤
			# 걸린다 - 방 하나 크기로 재면 걷는 중에 실패로 친다.
			var budget: float = 26.0 if room.size() > 3 else 12.0
			await _sweep(String(room[0]), String(room[1]), budget)

	print("\n=== %d 통과 / %d 실패 ===" % [_pass, _fail])
	if not _bad.is_empty():
		print("못 간 곳:")
		for b in _bad:
			print("  - ", b)
	get_tree().quit(1 if _fail > 0 else 0)
